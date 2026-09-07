#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include "treeutil.sp"
#pragma newdecls required
#pragma semicolon 1
// 全局变量：缓存距离ConVar，避免每帧重复获取
ConVar g_cvAimbotDistance;
float g_fAimbotDistance; // 缓存ConVar数值，提升性能

public void OnPluginStart()
{
    // 移除废弃的 FCVAR_PLUGIN 标志，仅保留有效标志
    g_cvAimbotDistance = CreateConVar(
        "sm_aimbot_distance", 
        "2000.0", 
        "Aimbot activation distance (set to 1.0 to disable distance limit)",
        FCVAR_NOTIFY | FCVAR_DONTRECORD,
        true, 1.0, true, 9999.0
    );
    
    // 缓存初始ConVar值
    g_fAimbotDistance = g_cvAimbotDistance.FloatValue;
    
    // 监听ConVar变化，实时更新缓存
    HookConVarChange(g_cvAimbotDistance, OnConVarChange);
}

public void OnConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    g_fAimbotDistance = StringToFloat(newValue);
}

bool IsAiHunter(int iClient)
{
    return (GetEntProp(iClient, Prop_Send, "m_zombieClass") == 3);
}


public Action OnPlayerRunCmd(int iClient, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (!IsValidInfectedAI(iClient)  || GetEntityMoveType(iClient) & MOVETYPE_LADDER)
	{
		return Plugin_Continue;
	}
	if (!IsAiHunter(iClient))
	{
		return Plugin_Continue;
	}
	int iClosestTarget = GetClosestValidSurvivor(iClient);
	if (iClosestTarget > 0)
	{
		float f_SpawnPos[3];
		GetClientEyePosition(iClient, f_SpawnPos);
		if(!L4D2_IsVisibleToPlayer(iClosestTarget, 2, 3, 0, f_SpawnPos))
		{
			LookAtClient(iClient, iClosestTarget);
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}


stock void LookAtClient(int iClient, int iTarget)
{
	float fTargetPos[3]; float fTargetAngles[3]; float fClientPos[3]; float fFinalPos[3];
	GetClientEyePosition(iClient, fClientPos);
	GetClientEyePosition(iTarget, fTargetPos);
	GetClientEyeAngles(iTarget, fTargetAngles);
	float fVecFinal[3];
	AddInFrontOf(fTargetPos, fTargetAngles, 7.0, fVecFinal);
	MakeVectorFromPoints(fClientPos, fVecFinal, fFinalPos);
	GetVectorAngles(fFinalPos, fFinalPos);
	TeleportEntity(iClient, NULL_VECTOR, fFinalPos, NULL_VECTOR);
}

stock void AddInFrontOf(float fVecOrigin[3], float fVecAngle[3], float fUnits, float fOutPut[3])
{
	float fVecView[3]; GetViewVector(fVecAngle, fVecView);
	
	fOutPut[0] = fVecView[0] * fUnits + fVecOrigin[0];
	fOutPut[1] = fVecView[1] * fUnits + fVecOrigin[1];
	fOutPut[2] = fVecView[2] * fUnits + fVecOrigin[2];
}

stock void GetViewVector(float fVecAngle[3], float fOutPut[3])
{
	fOutPut[0] = Cosine(fVecAngle[1] / (180 / FLOAT_PI));
	fOutPut[1] = Sine(fVecAngle[1] / (180 / FLOAT_PI));
	fOutPut[2] = -Sine(fVecAngle[0] / (180 / FLOAT_PI));
}

// 判断目标是否处于正在起身或正在倒地状态
bool Is_InGetUp_Or_Incapped(int client)
{
	int character_index = IdentifySurvivor(client);
	if (character_index != view_as<int>(SC_INVALID))
	{
		int sequence = GetEntProp(client, Prop_Send, "m_nSequence");
		if (sequence == GetUpAnimations[character_index][ID_HUNTER] || sequence == GetUpAnimations[character_index][ID_CHARGER] || sequence == GetUpAnimations[character_index][ID_CHARGER_WALL] || sequence == GetUpAnimations[character_index][ID_CHARGER_GROUND])
		{
			return true;
		}
		else if (sequence == IncappAnimations[character_index][ID_SINGLE_PISTOL] || sequence == IncappAnimations[character_index][ID_DUAL_PISTOLS])
		{
			return true;
		}
		return false;
	}
	return false;
}

// 校验：是否为有效感染者AI（核心修复逻辑）
stock bool IsValidInfectedAI(int client)
{
    // 条件：有效索引 + 在游戏中 + 是机器人（AI） + 感染者阵营（Team3） + 存活
    if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsFakeClient(client))
    {
        return false;
    }
    if (GetClientTeam(client) != 3 || !IsPlayerAlive(client))
    {
        return false;
    }
    return true;
}

// 校验：是否为有效幸存者（排除AI/倒地/被控制的幸存者）
stock bool IsValidTargetSurvivor(int client)
{
    if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
    {
        return false;
    }
    // 幸存者阵营（Team2） + 非AI + 未倒地/被控制/挂边
    if (GetClientTeam(client) != 2 || L4D_IsPlayerIncapacitated(client) || L4D_IsPlayerHangingFromLedge(client))
    {
        return false;
    }
    if (IsSurvivorPinned(client) || Is_InGetUp_Or_Incapped(client))
    {
        return false;
    }
    return true;
}

// 校验：幸存者是否被控制（舌头/扑击/骑乘等）
stock bool IsSurvivorPinned(int client)
{
    return (GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0) ||
           (GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0) ||
           (GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0) ||
           (GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0) ||
           (GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0);
}



// 获取最近的有效幸存者（优化距离判断逻辑）
stock int GetClosestValidSurvivor(int iClient)
{
    float fClientPos[3];
    GetClientAbsOrigin(iClient, fClientPos);
    
    int iClosestTarget = -1;
    // 替换未定义的 FLT_MAX 为超大浮点数（99999.0）
    float fClosestDist = 99999.0; 
    
    for (int i = 1; i <= MaxClients; i++)
    {
        // 跳过无效幸存者
        if (!IsValidTargetSurvivor(i))
        {
            continue;
        }
        
        // 计算距离
        float fTargetPos[3];
        GetClientAbsOrigin(i, fTargetPos);
        float fDistance = GetVectorDistance(fClientPos, fTargetPos);
        
        // 距离限制：仅当ConVar>1.0时生效（1.0禁用限制）
        if (g_fAimbotDistance > 1.0 && fDistance > g_fAimbotDistance)
        {
            continue;
        }
        
        // 更新最近目标
        if (fDistance < fClosestDist)
        {
            fClosestDist = fDistance;
            iClosestTarget = i;
        }
    }
    
    return iClosestTarget;
}

// 修复点2：自定义浮点取模函数（替代未定义的 fmod）
stock float FloatMod666(float num, float mod)
{
    if (mod == 0.0) return 0.0;
    float result = num - (RoundToFloor(num / mod) * mod);
    return result;
}

// 修复点3：自定义角度归一化函数（无 fmod 依赖）
stock float NormalizeAngle(float angle)
{
    angle = FloatMod666(angle, 360.0);
    if (angle < 0.0)
    {
        angle += 360.0;
    }
    return angle;
}

// 修复点4：自定义浮点钳制函数（替代未定义的 ClampFloat）
stock float CustomClampFloat(float value, float min, float max)
{
    if (value < min) return min;
    if (value > max) return max;
    return value;
}

// 计算瞄准角度（修正视角逻辑，添加角度钳制）
stock void CalculateAimAngles(int iShooter, int iTarget, float outAngles[3])
{
    float fShooterEye[3], fTargetEye[3], fDirVec[3];
    
    // 获取双方眼睛位置（更精准的瞄准点）
    GetClientEyePosition(iShooter, fShooterEye);
    GetClientEyePosition(iTarget, fTargetEye);
    
    // 计算方向向量并转换为角度
    MakeVectorFromPoints(fShooterEye, fTargetEye, fDirVec);
    GetVectorAngles(fDirVec, outAngles);
    
    // 修复点5：使用自定义钳制函数，避免 ClampFloat 未定义
    outAngles[0] = CustomClampFloat(outAngles[0], -89.0, 89.0);
    // 归一化水平角（0~360度）
    outAngles[1] = NormalizeAngle(outAngles[1]);
    // 滚转角置0（避免视角倾斜）
    outAngles[2] = 0.0;
}
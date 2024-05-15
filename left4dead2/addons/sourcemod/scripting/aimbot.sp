#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
/****************************************************************************************************
ETIQUETTE.
*****************************************************************************************************/
#pragma newdecls required
#pragma semicolon 1

/****************************************************************************************************
BOOLS.
*****************************************************************************************************/
/****************************************************************************************************
CONVARS.
*****************************************************************************************************/
ConVar g_cvDistance = null;

public void OnPluginStart()
{
	g_cvDistance = CreateConVar("sm_aimbot_distance", "800.0", "Will only activate aimbot if target is within this distance of client (1.0 to disable)");
}

bool IsAiCharget(int client)
{
	if (GetEntProp(client, Prop_Send, "m_zombieClass") == 6 && GetEntProp(client, Prop_Send, "m_isGhost") != 1)
	{
		return true;
	}
	else
	{
		return false;
	}
}
bool IsAiJockey(int client)
{
	if (GetEntProp(client, Prop_Send, "m_zombieClass") == 5 && GetEntProp(client, Prop_Send, "m_isGhost") != 1)
	{
		return true;
	}
	else
	{
		return false;
	}
}

public Action OnPlayerRunCmd(int iClient, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (!IsValidClient(iClient) || !IsPlayerAlive(iClient) || GetEntityMoveType(iClient) & MOVETYPE_LADDER)
	{
		return Plugin_Continue;
	}
	if (IsAiCharget(iClient) && IsCharging(iClient))
	{
		return Plugin_Continue;
	}
	if (IsAiJockey(iClient))
	{
		return Plugin_Continue;
	}
	int iTarget = GetClosestClient(iClient);
	if (iTarget > 0)
	{
		if(buttons & IN_ATTACK || buttons & IN_ATTACK2 || !(GetEntityFlags(iClient) & FL_ONGROUND))
		{
			LookAtClient(iClient, iTarget);
		}
	}
	// No Spread Addition
	return Plugin_Changed;
}

static bool IsCharging(int client) 
{
	static int ent;
	ent = GetEntPropEnt(client, Prop_Send, "m_customAbility");
	return ent > MaxClients && GetEntProp(ent, Prop_Send, "m_isCharging");
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
	//PrintToChatAll("222222222");
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

stock int GetClosestClient(int iClient)
{
	float fClientOrigin[3], fTargetOrigin[3];
	GetClientAbsOrigin(iClient, fClientOrigin);
	int iClosestTarget = -1;
	
	float fClosestDistance = -1.0;
	float fTargetDistance;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidSurvivor(i) && !IsPinned(i) && !L4D_IsPlayerIncapacitated(i) && !L4D_IsPlayerHangingFromLedge(i))	//排除本人是目标、目标非本队，目标已死亡
		{
		
			GetClientAbsOrigin(i, fTargetOrigin);		//获取目标坐标
			fTargetDistance = GetVectorDistance(fClientOrigin, fTargetOrigin);	//获取目标与本人的距离

			if (fTargetDistance > fClosestDistance && fClosestDistance > -1.0)		//目标与本人的距离比之前循环大的话直接中断
			{
				continue;
			}

			if (g_cvDistance.FloatValue != 0.0 && fTargetDistance > g_cvDistance.FloatValue)	//目标距离比设定的800范围大的话也中断
			{
				continue;
			}
			
			fClosestDistance = fTargetDistance;
			iClosestTarget = i;
		}
	}
	
	return iClosestTarget;
}


stock bool IsValidClient(int client)
{
	if(!(1 <= client <= MaxClients) || !IsClientInGame(client) || !IsFakeClient(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client))
	{
		return false;
	}
	return true;
}

stock bool IsPinned(int client)
{
	bool bIsPinned = false;
	if(GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0) bIsPinned = true;
	if(GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0) bIsPinned = true;
	if(GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0) bIsPinned = true;
	if(GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0) bIsPinned = true;
	if(GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0) bIsPinned = true;	
	return bIsPinned;
}

stock bool IsValid(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}

stock bool IsValidSurvivor(int client)
{
	return IsValid(client) && GetClientTeam(client) == 2;
}


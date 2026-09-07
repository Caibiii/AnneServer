#pragma semicolon 1
enum AimType
{
	AimEye,
	AimBody,
	AimChest
};
// ConVars
ConVar g_hHunterFastPounceDistance, g_hPounceVerticalAngle, g_hPounceAngleMean, g_hPounceAngleStd, g_hStraightPounceDistance, g_hHunterAimOffset, g_hHunterTarget, g_hShotGunCheckRange;
// Ints
int g_iPounceVerticalAngle, g_iPounceAngleMean, g_iPounceAngleStd, g_iHunterAimOffset;
// Floats
float g_fHunterFastPounceDistance, g_fStraightPounceDistance;
// Bools
bool g_bHasQueuedLunge[MAXPLAYERS + 1], g_bCanLunge[MAXPLAYERS + 1];

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define ZC_HUNTER 3
#define POSITIVE 0
#define NEGETIVE 1
#define X 0
#define Y 1
#define Z 2
#define e 2.71828 // 替换const float为宏定义，解决编译问题

public void Hunter_OnModuleStart2()
{
	// CreateConVar
	g_hHunterFastPounceDistance = CreateConVar("ai_HunterFastPounceDistance", "2000", "在距离目标多近Hunter开始快速突袭", FCVAR_NOTIFY, true, 0.0);
	g_hPounceVerticalAngle = CreateConVar("ai_HunterPounceVerticalAngle", "1", "Hunter突袭的垂直角度限制（单位：度）", FCVAR_NOTIFY, true, 0.0);
	g_hPounceAngleMean = CreateConVar("ai_HunterPounceAngleMean", "5", "Hunter突袭的平均角度（由随机数发生器产生）", FCVAR_NOTIFY, true, 0.0);
	g_hPounceAngleStd = CreateConVar("ai_HunterPounceAngleStd", "10", "Hunter突袭角度与平均角度的偏差（由随机数发生器产生）", FCVAR_NOTIFY, true, 0.0);
	g_hStraightPounceDistance = CreateConVar("ai_HunterStraightPounceDistance", "200.0", "Hunter在离生还者多近时允许直扑", FCVAR_NOTIFY, true, 0.0);
	g_hHunterAimOffset = CreateConVar("ai_HunterAimOffset", "1", "目标与Hunter处在这一角度范围内，Hunter将不会直扑", FCVAR_NOTIFY, true, 0.0);
	g_hHunterTarget = CreateConVar("ai_HunterTarget", "1", "Hunter目标选择：1=自然目标选择，2=最近目标，3=手持非霰弹枪的生还者", FCVAR_NOTIFY, true, 1.0, true, 3.0); // 修正最大值
	g_hShotGunCheckRange = CreateConVar("ai_HunterShotGunCheckRange", "250.0", "目标选择为3时，Hunter在大于这个距离时允许进行目标枪械检测", FCVAR_NOTIFY, true, 0.0);
	SetConVarFloat(FindConVar("z_pounce_crouch_delay"), 0.1);
	// AddChangeHook
	g_hHunterFastPounceDistance.AddChangeHook(HunterConVarChanged_Cvars);
	g_hPounceVerticalAngle.AddChangeHook(HunterConVarChanged_Cvars);
	g_hPounceAngleMean.AddChangeHook(HunterConVarChanged_Cvars);
	g_hPounceAngleStd.AddChangeHook(HunterConVarChanged_Cvars);
	g_hStraightPounceDistance.AddChangeHook(HunterConVarChanged_Cvars);
	g_hHunterAimOffset.AddChangeHook(HunterConVarChanged_Cvars);
	g_hHunterTarget.AddChangeHook(HunterConVarChanged_Cvars);
	g_hShotGunCheckRange.AddChangeHook(HunterConVarChanged_Cvars);
	// GetCvars
	GetHunterCvars();
}

public void Hunter_OnModuleEnd2() 
{

}

void HunterConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetHunterCvars();
}

void GetHunterCvars()
{
	g_fHunterFastPounceDistance = g_hHunterFastPounceDistance.FloatValue;
	g_iPounceVerticalAngle = g_hPounceVerticalAngle.IntValue;
	g_iPounceAngleMean = g_hPounceAngleMean.IntValue;
	g_iPounceAngleStd = g_hPounceAngleStd.IntValue;
	g_fStraightPounceDistance = g_hStraightPounceDistance.FloatValue;
	g_iHunterAimOffset = g_hHunterAimOffset.IntValue;
}

public Action Hunter_OnPlayerRunCmd2(int hunter, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon) 
{
	if (IsAiHunter(hunter) && GetEntityMoveType(hunter) != MOVETYPE_LADDER) 
	{
		int iFlags = GetEntityFlags(hunter);
		float fDistance = NearestSurvivorDistance(hunter);
		float fHunterPos[3], fTargetAngles[3];
		GetClientAbsOrigin(hunter, fHunterPos);
		int iTarget = GetClientAimTarget(hunter, true);
		bool bHasSight = view_as<bool>(GetEntProp(hunter, Prop_Send, "m_hasVisibleThreats"));
		if (iTarget > 0)
		{
			if (bHasSight)
			{
				HunterComputeAimAngles(hunter, iTarget, fTargetAngles, AimEye);
				fTargetAngles[2] = 0.0;
				TeleportEntity(hunter, NULL_VECTOR, fTargetAngles, NULL_VECTOR);
			}
		}
		if ((iFlags & FL_DUCKING) && (iFlags & FL_ONGROUND))
		{
			if (bHasSight)
			{
				if (fDistance < g_fHunterFastPounceDistance)
				{
					buttons &= ~IN_ATTACK;
					if (!g_bHasQueuedLunge[hunter])
					{
						g_bCanLunge[hunter] = false;
						g_bHasQueuedLunge[hunter] = true;
						CreateTimer(GetConVarFloat(FindConVar("z_lunge_interval")), Timer_LungeInterval, hunter, TIMER_FLAG_NO_MAPCHANGE);
					}
					else if (g_bCanLunge[hunter])
					{
						buttons |= IN_ATTACK;
						g_bHasQueuedLunge[hunter] = false;
					}
				}
			}
		}
		if (GetEntityMoveType(hunter) & MOVETYPE_LADDER)
		{
			buttons &= ~IN_JUMP;
			buttons &= ~IN_DUCK;
		}
	}
	return Plugin_Changed;
}

public Action Timer_LungeInterval(Handle timer, int client)
{
	g_bCanLunge[client] = true;
}

public Action Hunter_OnPounce(int hunter)
{
	float fLungeVector[3];
	int iEntLunge = GetEntPropEnt(hunter, Prop_Send, "m_customAbility");
	GetEntPropVector(iEntLunge, Prop_Send, "m_queuedLunge", fLungeVector);
	float fDistance = NearestSurvivorDistance(hunter);
	if (IsHunterWatchingAttacker(hunter, g_iHunterAimOffset) && fDistance > g_fStraightPounceDistance)
	{
		float fPounceAngle = GaussianRNG(float(g_iPounceAngleMean), float(g_iPounceAngleStd));
		AngleLunge(iEntLunge, fPounceAngle);
		LimitLungeVerticality(iEntLunge); // 核心修复的垂直角度限制
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

void AngleLunge(int LungeEntity, float turnAngle)
{
	float LungeVector[3];
	GetEntPropVector(LungeEntity, Prop_Send, "m_queuedLunge", LungeVector);
	float x = LungeVector[X];
	float y = LungeVector[Y];
	float z = LungeVector[Z];
	turnAngle = DegToRad(turnAngle);
	float fForceLunge[3];
	// 仅处理水平方向（X/Y）的转向，不修改Z轴
	fForceLunge[X] = x * Cosine(turnAngle) - y * Sine(turnAngle);
	fForceLunge[Y] = x * Sine(turnAngle) + y * Cosine(turnAngle);
	fForceLunge[Z] = z;
	SetEntPropVector(LungeEntity, Prop_Send, "m_queuedLunge", fForceLunge);
}

// 【核心修复】重新实现垂直角度限制（解决高空飞），修复Clamp编译问题
void LimitLungeVerticality(int LungeEntity)
{
	float maxVertAngle = float(g_iPounceVerticalAngle);
	if (maxVertAngle <= 0.0) return;
	
	float LungeVector[3];
	GetEntPropVector(LungeEntity, Prop_Send, "m_queuedLunge", LungeVector);
	
	// 计算水平平面长度
	float horizontalLength = SquareRoot(LungeVector[X] * LungeVector[X] + LungeVector[Y] * LungeVector[Y]);
	if (horizontalLength <= 0.0) return;
	
	// 计算当前垂直角度，修复Clamp标签问题
	float currentVertAngle = RadToDeg(ArcTangent(LungeVector[Z] / horizontalLength));
	// 显式指定float类型，解决标签不匹配
	float clampedVertAngle = ClampFloat(currentVertAngle, -maxVertAngle, maxVertAngle);
	
	// 重新计算Z轴
	float clampedVertRad = DegToRad(clampedVertAngle);
	float newZ = horizontalLength * Tangent(clampedVertRad);
	
	LungeVector[Z] = newZ;
	SetEntPropVector(LungeEntity, Prop_Send, "m_queuedLunge", LungeVector);
}

// 【修复】自定义ClampFloat函数（解决Clamp未定义问题）
float ClampFloat(float value, float minVal, float maxVal)
{
	if (value < minVal) return minVal;
	if (value > maxVal) return maxVal;
	return value;
}

// 【修复】修正高斯随机数生成逻辑，解决编译错误
float GaussianRNG(float mean, float std)
{
	float fChanceToken = GetRandomFloat(0.0, 1.0);
	int iSignBit = (fChanceToken > 0.5) ? POSITIVE : NEGETIVE;
	
	float x1, x2, w;
	do
	{
		float rand1 = GetRandomFloat(0.0, 1.0);
		float rand2 = GetRandomFloat(0.0, 1.0);
		x1 = 2.0 * rand1 - 1.0;
		x2 = 2.0 * rand2 - 1.0;
		w = x1 * x1 + x2 * x2;
	} while (w >= 1.0);
	
	w = SquareRoot(-2.0 * (Logarithm(w, e) / w));
	float y1 = x1 * w;
	
	// 修正随机角度计算
	float finalAngle = y1 * std + mean;
	if (iSignBit == NEGETIVE)
	{
		finalAngle = -finalAngle;
	}
	
	return finalAngle;
}

// ***** 基础方法 *****
bool IsAiHunter(int client)
{
	if (client && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client) && IsFakeClient(client) && GetClientTeam(client) == TEAM_INFECTED && GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_HUNTER && GetEntProp(client, Prop_Send, "m_isGhost") != 1)
	{
		return true;
	}
	else
	{
		return false;
	}
}

bool IsHunterWatchingAttacker(int attacker, int offset)
{
	bool bIsWatching = true;
	if (GetClientTeam(attacker) == TEAM_INFECTED && IsPlayerAlive(attacker))
	{
		int iTarget = GetClientAimTarget(attacker);
		if (IsSurvivor(iTarget))
		{
			int iOffset = RoundToNearest(GetHunterAimOffset(iTarget, attacker));
			bIsWatching = (iOffset <= offset);
		}
	}
	return bIsWatching;
}

// 【修复】修正参数顺序+Clamp使用，解决编译错误
float GetHunterAimOffset(int attacker, int target)
{
	// 修正参数顺序（原attacker/target写反）
	int realAttacker = target;
	int realTarget = attacker;
	if (IsClientConnected(realAttacker) && IsClientInGame(realAttacker) && IsPlayerAlive(realAttacker) && 
		IsClientConnected(realTarget) && IsClientInGame(realTarget) && !L4D_IsPlayerIncapacitated(realTarget) && IsPlayerAlive(realTarget))
	{
		float fAttackerPos[3], fTargetPos[3], fAimVector[3], fDirectVector[3], fResultAngle;
		GetClientEyeAngles(realAttacker, fAimVector);
		fAimVector[0] = fAimVector[2] = 0.0;
		GetAngleVectors(fAimVector, fAimVector, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(fAimVector, fAimVector);
		
		GetClientAbsOrigin(realTarget, fTargetPos);
		GetClientAbsOrigin(realAttacker, fAttackerPos);
		fAttackerPos[2] = fTargetPos[2] = 0.0;
		
		MakeVectorFromPoints(fAttackerPos, fTargetPos, fDirectVector);
		NormalizeVector(fDirectVector, fDirectVector);
		
		// 修复Clamp：使用自定义的ClampFloat，解决标签不匹配
		float dotProduct = ClampFloat(GetVectorDotProduct(fAimVector, fDirectVector), -1.0, 1.0);
		fResultAngle = RadToDeg(ArcCosine(dotProduct));
		return fResultAngle;
	}
	return -1.0;
}

// 【修复】修正switch语法，解决break上下文错误
void HunterComputeAimAngles(int client, int target, float angles[3], AimType type = AimEye)
{
	float selfpos[3], targetpos[3], lookat[3];
	GetClientEyePosition(client, selfpos);
	
	// 替换switch为if-else（解决低版本SP break上下文错误）
	if (type == AimEye)
	{
		GetClientEyePosition(target, targetpos);
	}
	else if (type == AimBody)
	{
		GetClientAbsOrigin(target, targetpos);
	}
	else if (type == AimChest)
	{
		GetClientAbsOrigin(target, targetpos);
		targetpos[2] += 45.0;
	}
	else
	{
		GetClientEyePosition(target, targetpos);
	}
	
	MakeVectorFromPoints(selfpos, targetpos, lookat);
	GetVectorAngles(lookat, angles);
}
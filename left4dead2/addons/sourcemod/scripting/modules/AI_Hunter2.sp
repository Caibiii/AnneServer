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

public void Hunter_OnModuleStart2()
{
	// CreateConVar
	g_hHunterFastPounceDistance = CreateConVar("ai_HunterFastPounceDistance", "2000", "在距离目标多近Hunter开始快速突袭", FCVAR_NOTIFY, true, 0.0);
	g_hPounceVerticalAngle = CreateConVar("ai_HunterPounceVerticalAngle", "7", "Hunter突袭的垂直角度限制", FCVAR_NOTIFY, true, 0.0);
	g_hPounceAngleMean = CreateConVar("ai_HunterPounceAngleMean", "10", "Hunter突袭的平均角度（由随机数发生器产生）", FCVAR_NOTIFY, true, 0.0);
	g_hPounceAngleStd = CreateConVar("ai_HunterPounceAngleStd", "20", "Hunter突袭角度与平均角度的偏差（由随机数发生器产生）", FCVAR_NOTIFY, true, 0.0);
	g_hStraightPounceDistance = CreateConVar("ai_HunterStraightPounceDistance", "200.0", "Hunter在离生还者多近时允许直扑", FCVAR_NOTIFY, true, 0.0);
	g_hHunterAimOffset = CreateConVar("ai_HunterAimOffset", "360", "目标与Hunter处在这一角度范围内，Hunter将不会直扑", FCVAR_NOTIFY, true, 0.0);
	g_hHunterTarget = CreateConVar("ai_HunterTarget", "1", "Hunter目标选择：1=自然目标选择，2=最近目标，3=手持非霰弹枪的生还者", FCVAR_NOTIFY, true, 1.0, true, 2.0);
	g_hShotGunCheckRange = CreateConVar("ai_HunterShotGunCheckRange", "250.0", "目标选择为3时，Hunter在大于这个距离时允许进行目标枪械检测", FCVAR_NOTIFY, true, 0.0);
	SetConVarInt(FindConVar("z_pounce_crouch_delay"), 0);
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

		//buttons &= ~IN_ATTACK2;
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
		LimitLungeVerticality(iEntLunge);
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
	fForceLunge[X] = x * Cosine(turnAngle) - y * Sine(turnAngle);
	fForceLunge[Y] = x * Sine(turnAngle) + y * Cosine(turnAngle);
	fForceLunge[Z] = z;
	SetEntPropVector(LungeEntity, Prop_Send, "m_queuedLunge", fForceLunge);
}

void LimitLungeVerticality(int LungeEntity)
{
	float vertAngle = float(g_iPounceVerticalAngle);
	float LungeVector[3];
	GetEntPropVector(LungeEntity, Prop_Send, "m_queuedLunge", LungeVector);
	float x = LungeVector[X];
	float y = LungeVector[Y];
	float z = LungeVector[Z];
	vertAngle = DegToRad(vertAngle);
	float fFlatLunge[3];
	fFlatLunge[Y] = y * Cosine(vertAngle) - z * Sine(vertAngle);
	fFlatLunge[Z] = y * Sine(vertAngle) + z * Cosine(vertAngle);
	fFlatLunge[X] = x * Cosine(vertAngle) + z * Sine(vertAngle);
	fFlatLunge[Z] = x * -Sine(vertAngle) + z * Cosine(vertAngle);
	SetEntPropVector(LungeEntity, Prop_Send, "m_queuedLunge", fFlatLunge);
}

float GaussianRNG(float mean, float std)
{
	float fChanceToken = GetRandomFloat(0.0, 1.0);
	int iSignBit;
	if (fChanceToken > 0.5)
	{
		iSignBit = POSITIVE;
	}
	else
	{
		iSignBit = NEGETIVE;
	}
	float x1, x2, w;
	do
	{
		float rand1 = GetRandomFloat(0.0, 1.0);
		float rand2 = GetRandomFloat(0.0, 1.0);
		x1 = 2.0 * rand1 - 1.0;
		x2 = 2.0 * rand2 - 1.0;
		w = x1 * x1 + x2 * x2;
	} while (w >= 1.0);
	static float e = 2.71828;
	w = SquareRoot(-2.0 * (Logarithm(w, e) / w));
	float y1 = x1 * w;
	float y2 = x2 * w;
	float z1 = y1 * std + mean;
	float z2 = y2 * std - mean;
	if (iSignBit == NEGETIVE)
	{
		return z1;
	}
	else
	{
		return z2;
	}
}

// ***** 方法 *****
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
			if (iOffset <= offset)
			{
				bIsWatching = true;
			}
			else
			{
				bIsWatching = false;
			}
		}
	}
	return bIsWatching;
}

float GetHunterAimOffset(int attacker, int target)
{
	if (IsClientConnected(attacker) && IsClientInGame(attacker) && IsPlayerAlive(attacker) && IsClientConnected(target) && IsClientInGame(target) && !L4D_IsPlayerIncapacitated(target)&& IsPlayerAlive(target))
	{
		float fAttackerPos[3], fTargetPos[3], fAimVector[3], fDirectVector[3], fResultAngle;
		GetClientEyeAngles(attacker, fAimVector);
		fAimVector[0] = fAimVector[2] = 0.0;
		GetAngleVectors(fAimVector, fAimVector, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(fAimVector, fAimVector);
		// 获取目标位置
		GetClientAbsOrigin(target, fTargetPos);
		GetClientAbsOrigin(attacker, fAttackerPos);
		fAttackerPos[2] = fTargetPos[2] = 0.0;
		MakeVectorFromPoints(fAttackerPos, fTargetPos, fDirectVector);
		NormalizeVector(fDirectVector, fDirectVector);
		// 计算角度
		fResultAngle = RadToDeg(ArcCosine(GetVectorDotProduct(fAimVector, fDirectVector)));
		return fResultAngle;
	}
	return -1.0;
}
void HunterComputeAimAngles(int client, int target, float angles[3], AimType type = AimEye)
{
	float selfpos[3], targetpos[3], lookat[3];
	GetClientEyePosition(client, selfpos);
	switch (type)
	{
		case AimEye:
		{
			GetClientEyePosition(target, targetpos);
		}
		case AimBody:
		{
			GetClientAbsOrigin(target, targetpos);
		}
		case AimChest:
		{
			GetClientAbsOrigin(target, targetpos);
			targetpos[2] += 45.0;
		}
	}
	MakeVectorFromPoints(selfpos, targetpos, lookat);
	GetVectorAngles(lookat, angles);
}
#pragma semicolon 1
#pragma tabsize 0
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
enum L4D2_Infected
{
	L4D2Infected_Smoker = 1,
	L4D2Infected_Boomer,
	L4D2Infected_Hunter,
	L4D2Infected_Spitter,
	L4D2Infected_Jockey,
	L4D2Infected_Charger,
	L4D2Infected_Witch,
	L4D2Infected_Tank
};

stock L4D2_Infected GetInfectedClass(int client)
{
	return view_as<L4D2_Infected>(GetEntProp(client, Prop_Send, "m_zombieClass"));
}

bool IsSurvivor(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}

bool IsBotInfected(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3 && IsFakeClient(client);
}

bool IsPinned(int client)
{
	return GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0
		|| GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0
		|| GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0
		|| GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0
		|| GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0;
}

bool IsPinnedByAnother(int victim, int attacker)
{
	int pinner = GetEntPropEnt(victim, Prop_Send, "m_pounceAttacker");
	if(pinner > 0 && pinner != attacker)
		return true;
	pinner = GetEntPropEnt(victim, Prop_Send, "m_jockeyAttacker");
	if(pinner > 0 && pinner != attacker)
		return true;
	pinner = GetEntPropEnt(victim, Prop_Send, "m_tongueOwner");
	return pinner > 0 && pinner != attacker;
}

int GetClosestSurvivor(float pos[3], int excludeSurvivor = -1, bool allowChargerPinned = false)
{
	int closest = -1;
	float closestDistance;
	float targetPos[3];
	for(int client = 1; client <= MaxClients; client++)
	{
		if(!IsSurvivor(client) || !IsPlayerAlive(client) || client == excludeSurvivor)
			continue;
		bool pinned = allowChargerPinned ? IsPinnedByAnother(client, 0) : IsPinned(client);
		if(pinned)
			continue;

		GetClientAbsOrigin(client, targetPos);
		float distance = GetVectorDistance(pos, targetPos);
		if(closest == -1 || distance < closestDistance)
		{
			closest = client;
			closestDistance = distance;
		}
	}
	return closest;
}

float NearestSurvivorDistance(int client)
{
	float self[3], target[3];
	float nearest = -1.0;
	GetClientAbsOrigin(client, self);
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsSurvivor(i) && IsPlayerAlive(i) && !IsPinnedByAnother(i, 0))
		{
			GetClientAbsOrigin(i, target);
			float distance = GetVectorDistance(self, target);
			if(nearest < 0.0 || distance < nearest)
				nearest = distance;
		}
	}
	return nearest < 0.0 ? 999999.0 : nearest;
}

bool IsValidSurvivor(int client)
{
	return IsSurvivor(client);
}

float g_fDelay[MAXPLAYERS + 1][8];
int g_iState[MAXPLAYERS + 1][8];

void DelayStart(int client, int no)
{
	g_fDelay[client][no] = GetGameTime();
}

bool DelayExpired(int client, int no, float delay)
{
	return GetGameTime() - g_fDelay[client][no] > delay;
}

void SetState(int client, int no, int value)
{
	g_iState[client][no] = value;
}

int GetState(int client, int no)
{
	return g_iState[client][no];
}

void InitStatus()
{
	float time = GetGameTime();
	for(int i; i < MAXPLAYERS + 1; ++i)
	{
		for(int j; j < 8; ++j)
		{
			g_fDelay[i][j] = time;
			g_iState[i][j] = 0;
		}
	}
}

bool Do_Bhop(int client, int &buttons, float vec[3])
{
	if(buttons & IN_FORWARD || buttons & IN_BACK || buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT)
		return ClientPush(client, vec);
	return false;
}

bool ClientPush(int client, float vec[3])
{
	float curvel[3] = {0.0};
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", curvel);
	AddVectors(curvel, vec, curvel);
	if(GetVectorLength(curvel) <= 250.0)
	{
		NormalizeVector(curvel, curvel);
		ScaleVector(curvel, 251.0);
	}
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, curvel);
	return true;
}

float[] CalculateVel(float self_pos[3], float target_pos[3], float force)
{
	float vecbuffer[3] = {0.0};
	SubtractVectors(target_pos, self_pos, vecbuffer);
	NormalizeVector(vecbuffer, vecbuffer);
	ScaleVector(vecbuffer, force);
	return vecbuffer;
}

enum AimType
{
	AimEye,
	AimBody,
	AimChest
};

ConVar g_hHunterFastPounceDistance, g_hPounceVerticalAngle, g_hPounceAngleMean, g_hPounceAngleStd, g_hStraightPounceDistance, g_hHunterAimOffset, g_hHunterTarget, g_hShotGunCheckRange;
int g_iPounceVerticalAngle, g_iPounceAngleMean, g_iPounceAngleStd, g_iHunterAimOffset;
float g_fHunterFastPounceDistance, g_fStraightPounceDistance;
bool g_bHasQueuedLunge[MAXPLAYERS + 1], g_bCanLunge[MAXPLAYERS + 1];

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define ZC_HUNTER 3
#define POSITIVE 0
#define NEGETIVE 1
#define X 0
#define Y 1
#define Z 2
#define e 2.71828

public void Hunter_OnModuleStart2()
{
	g_hHunterFastPounceDistance = CreateConVar("ai_HunterFastPounceDistance", "2000", "在距离目标多近Hunter开始快速突袭", FCVAR_NOTIFY, true, 0.0);
	g_hPounceVerticalAngle = CreateConVar("ai_HunterPounceVerticalAngle", "1", "Hunter突袭的垂直角度限制（单位：度）", FCVAR_NOTIFY, true, 0.0);
	g_hPounceAngleMean = CreateConVar("ai_HunterPounceAngleMean", "5", "Hunter突袭的平均角度（由随机数发生器产生）", FCVAR_NOTIFY, true, 0.0);
	g_hPounceAngleStd = CreateConVar("ai_HunterPounceAngleStd", "10", "Hunter突袭角度与平均角度的偏差（由随机数发生器产生）", FCVAR_NOTIFY, true, 0.0);
	g_hStraightPounceDistance = CreateConVar("ai_HunterStraightPounceDistance", "200", "Hunter在离生还者多近时允许直扑", FCVAR_NOTIFY, true, 0.0);
	g_hHunterAimOffset = CreateConVar("ai_HunterAimOffset", "1", "目标与Hunter处在这一角度范围内，Hunter将不会直扑", FCVAR_NOTIFY, true, 0.0);
	g_hHunterTarget = CreateConVar("ai_HunterTarget", "1", "Hunter目标选择：1=自然目标选择，2=最近目标，3=手持非霰弹枪的生还者", FCVAR_NOTIFY, true, 1.0, true, 3.0);
	g_hShotGunCheckRange = CreateConVar("ai_HunterShotGunCheckRange", "250", "目标选择为3时，Hunter在大于这个距离时允许进行目标枪械检测", FCVAR_NOTIFY, true, 0.0);
	SetConVarInt(FindConVar("z_pounce_crouch_delay"), 0);
	g_hHunterFastPounceDistance.AddChangeHook(HunterConVarChanged_Cvars);
	g_hPounceVerticalAngle.AddChangeHook(HunterConVarChanged_Cvars);
	g_hPounceAngleMean.AddChangeHook(HunterConVarChanged_Cvars);
	g_hPounceAngleStd.AddChangeHook(HunterConVarChanged_Cvars);
	g_hStraightPounceDistance.AddChangeHook(HunterConVarChanged_Cvars);
	g_hHunterAimOffset.AddChangeHook(HunterConVarChanged_Cvars);
	g_hHunterTarget.AddChangeHook(HunterConVarChanged_Cvars);
	g_hShotGunCheckRange.AddChangeHook(HunterConVarChanged_Cvars);
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
	if(IsAiHunter(hunter) && GetEntityMoveType(hunter) != MOVETYPE_LADDER)
	{
		int iFlags = GetEntityFlags(hunter);
		float fDistance = NearestSurvivorDistance(hunter);
		float fHunterPos[3], fTargetAngles[3];
		GetClientAbsOrigin(hunter, fHunterPos);
		int iTarget = GetClientAimTarget(hunter, true);
		if(iTarget > 0 && IsPinnedByAnother(iTarget, hunter))
			iTarget = GetClosestSurvivor(fHunterPos, -1, true);
		bool bHasSight = view_as<bool>(GetEntProp(hunter, Prop_Send, "m_hasVisibleThreats"));
		if(iTarget > 0 && bHasSight)
		{
			HunterComputeAimAngles(hunter, iTarget, fTargetAngles, AimEye);
			fTargetAngles[2] = 0.0;
			TeleportEntity(hunter, NULL_VECTOR, fTargetAngles, NULL_VECTOR);
		}
		if((iFlags & FL_DUCKING) && (iFlags & FL_ONGROUND) && bHasSight && fDistance < g_fHunterFastPounceDistance)
		{
			buttons &= ~IN_ATTACK;
			if(!g_bHasQueuedLunge[hunter])
			{
				g_bCanLunge[hunter] = false;
				g_bHasQueuedLunge[hunter] = true;
				CreateTimer(GetConVarFloat(FindConVar("z_lunge_interval")), Timer_LungeInterval, hunter, TIMER_FLAG_NO_MAPCHANGE);
			}
			else if(g_bCanLunge[hunter])
			{
				buttons |= IN_ATTACK;
				g_bHasQueuedLunge[hunter] = false;
			}
		}
		if(GetEntityMoveType(hunter) & MOVETYPE_LADDER)
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
	return Plugin_Stop;
}

public Action Hunter_OnPounce(int hunter)
{
	float fLungeVector[3];
	int iEntLunge = GetEntPropEnt(hunter, Prop_Send, "m_customAbility");
	GetEntPropVector(iEntLunge, Prop_Send, "m_queuedLunge", fLungeVector);
	float fDistance = NearestSurvivorDistance(hunter);
	if(IsHunterWatchingAttacker(hunter, g_iHunterAimOffset) && fDistance > g_fStraightPounceDistance)
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
	float maxVertAngle = float(g_iPounceVerticalAngle);
	if(maxVertAngle <= 0.0)
		return;

	float LungeVector[3];
	GetEntPropVector(LungeEntity, Prop_Send, "m_queuedLunge", LungeVector);
	float horizontalLength = SquareRoot(LungeVector[X] * LungeVector[X] + LungeVector[Y] * LungeVector[Y]);
	if(horizontalLength <= 0.0)
		return;

	float currentVertAngle = RadToDeg(ArcTangent(LungeVector[Z] / horizontalLength));
	float clampedVertAngle = ClampFloat(currentVertAngle, -maxVertAngle, maxVertAngle);
	float clampedVertRad = DegToRad(clampedVertAngle);
	float newZ = horizontalLength * Tangent(clampedVertRad);
	LungeVector[Z] = newZ;
	SetEntPropVector(LungeEntity, Prop_Send, "m_queuedLunge", LungeVector);
}

float ClampFloat(float value, float minVal, float maxVal)
{
	if(value < minVal)
		return minVal;
	if(value > maxVal)
		return maxVal;
	return value;
}

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
	} while(w >= 1.0);

	w = SquareRoot(-2.0 * (Logarithm(w, e) / w));
	float y1 = x1 * w;
	float finalAngle = y1 * std + mean;
	if(iSignBit == NEGETIVE)
		finalAngle = -finalAngle;
	return finalAngle;
}

bool IsAiHunter(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client) && IsFakeClient(client)
		&& GetClientTeam(client) == TEAM_INFECTED && GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_HUNTER
		&& GetEntProp(client, Prop_Send, "m_isGhost") != 1;
}

bool IsHunterWatchingAttacker(int attacker, int offset)
{
	bool bIsWatching = true;
	if(GetClientTeam(attacker) == TEAM_INFECTED && IsPlayerAlive(attacker))
	{
		int iTarget = GetClientAimTarget(attacker);
		if(IsSurvivor(iTarget))
		{
			int iOffset = RoundToNearest(GetHunterAimOffset(iTarget, attacker));
			bIsWatching = (iOffset <= offset);
		}
	}
	return bIsWatching;
}

float GetHunterAimOffset(int attacker, int target)
{
	int realAttacker = target;
	int realTarget = attacker;
	if(IsClientConnected(realAttacker) && IsClientInGame(realAttacker) && IsPlayerAlive(realAttacker)
		&& IsClientConnected(realTarget) && IsClientInGame(realTarget) && !L4D_IsPlayerIncapacitated(realTarget) && IsPlayerAlive(realTarget))
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
		float dotProduct = ClampFloat(GetVectorDotProduct(fAimVector, fDirectVector), -1.0, 1.0);
		fResultAngle = RadToDeg(ArcCosine(dotProduct));
		return fResultAngle;
	}
	return -1.0;
}

void HunterComputeAimAngles(int client, int target, float angles[3], AimType type = AimEye)
{
	float selfpos[3], targetpos[3], lookat[3];
	GetClientEyePosition(client, selfpos);
	if(type == AimEye)
		GetClientEyePosition(target, targetpos);
	else if(type == AimBody)
		GetClientAbsOrigin(target, targetpos);
	else if(type == AimChest)
	{
		GetClientAbsOrigin(target, targetpos);
		targetpos[2] += 45.0;
	}
	else
		GetClientEyePosition(target, targetpos);
	MakeVectorFromPoints(selfpos, targetpos, lookat);
	GetVectorAngles(lookat, angles);
}

#define HUNTERATTACKTIME 10.0
#define HUNTERREPEATSPEED 4
#define HUNTERONGTOUNDSTATE 1
#define HUNTERFLYSTATE 2
#define HUNTERCOOLDOWNTIME 0.0
#define VEM_MAX 200.0

public void Hunter_OnModuleStart()
{
}

public void Hunter_OnModuleEnd()
{
}

public Action Hunter_OnPlayerRunCmd(int hunter, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if(GetEntityMoveType(hunter) != MOVETYPE_LADDER)
	{
		Action react = Plugin_Continue;
		bool internaltrigger = false;
		if(!DelayExpired(hunter, 1, HUNTERATTACKTIME) && GetEntityMoveType(hunter) != MOVETYPE_LADDER)
		{
			buttons |= IN_DUCK;
			if(!(GetRandomInt(0, HUNTERREPEATSPEED)))
			{
				buttons |= IN_ATTACK;
				internaltrigger = true;
			}
			react = Plugin_Changed;
		}
		if(!(GetEntityFlags(hunter) & FL_ONGROUND) && GetState(hunter, HUNTERFLYSTATE) == 0)
		{
			DelayStart(hunter, 2);
			SetState(hunter, HUNTERONGTOUNDSTATE, 0);
			SetState(hunter, HUNTERFLYSTATE, 1);
		}
		else if(!(GetEntityFlags(hunter) & FL_ONGROUND))
		{
			if(GetState(hunter, 0) == IN_FORWARD)
			{
				buttons |= IN_FORWARD;
				vel[0] = VEM_MAX;
				if(GetState(hunter, HUNTERONGTOUNDSTATE) == 0 && DelayExpired(hunter, 2, 0.2))
				{
					if(angles[2] == 0.0)
					{
						angles[0] = GetRandomFloat(-10.0, 10.0);
						TeleportEntity(hunter, NULL_VECTOR, angles, NULL_VECTOR);
					}
					SetState(hunter, HUNTERONGTOUNDSTATE, 1);
				}
				react = Plugin_Changed;
			}
			else if(!(GetState(hunter, 2) == 1))
				SetState(hunter, HUNTERFLYSTATE, 0);
		}
		if(DelayExpired(hunter, 0, 0.1) && (buttons & IN_ATTACK) && (GetEntityFlags(hunter) & FL_ONGROUND))
		{
			float dist = NearestSurvivorDistance(hunter);
			DelayStart(hunter, 0);
			if(!internaltrigger && !(buttons & IN_BACK) && dist < 1000.0 && DelayExpired(hunter, 1, HUNTERATTACKTIME + HUNTERCOOLDOWNTIME))
				DelayStart(hunter, 1);
			if(GetRandomInt(0, 1) == 0)
			{
				if(dist < 1000.0)
				{
					if(angles[2] == 0.0)
					{
						if(GetRandomInt(0, 4))
							angles[0] = GetRandomFloat(20.0, 10.0);
						else
							angles[0] = GetRandomFloat(-10.0, -20.0);
						TeleportEntity(hunter, NULL_VECTOR, angles, NULL_VECTOR);
					}
					SetState(hunter, 0, IN_FORWARD);
				}
				else
					SetState(hunter, 0, 0);
			}
			else
				SetState(hunter, 0, 0);
			react = Plugin_Changed;
		}
		return react;
	}
	return Plugin_Continue;
}

#define JockeyBoostForward 80.0

ConVar g_hJockeyLeapRange;
ConVar g_hHopActivationProximity;
ConVar g_hJockeyLeapAgain;

public void Jockey_OnModuleStart()
{
	g_hHopActivationProximity = CreateConVar("ai_hop_activation_proximity", "800", "How close a jockey will approach before it starts hopping");
	g_hJockeyLeapRange = FindConVar("z_jockey_leap_range");
	g_hJockeyLeapRange.SetInt(1000);
	g_hJockeyLeapAgain = FindConVar("z_jockey_leap_again_timer");
	g_hJockeyLeapAgain.SetFloat(0.1);
	FindConVar("z_leap_attach_distance").SetFloat(250.0);
	FindConVar("z_leap_force_attach_distance").SetFloat(250.0);
	FindConVar("z_leap_far_attach_delay").SetFloat(0.0);
	FindConVar("z_leap_max_distance").SetFloat(600.0);
	FindConVar("z_leap_power").SetFloat(450.0);
}

public void Jockey_OnModuleEnd()
{
	g_hJockeyLeapRange.RestoreDefault();
	g_hJockeyLeapAgain.RestoreDefault();
	FindConVar("z_leap_attach_distance").RestoreDefault();
	FindConVar("z_leap_force_attach_distance").RestoreDefault();
	FindConVar("z_leap_far_attach_delay").RestoreDefault();
	FindConVar("z_leap_max_distance").RestoreDefault();
	FindConVar("z_leap_power").RestoreDefault();
}

public Action Jockey_OnPlayerRunCmd(int jockey, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	static float LeftGroundMaxSpeed[MAXPLAYERS + 1];
	int target = GetClientAimTarget(jockey, true);
	if(target > 0 && IsPinnedByAnother(target, jockey))
	{
		float jockeyPos[3];
		GetClientAbsOrigin(jockey, jockeyPos);
		target = GetClosestSurvivor(jockeyPos, -1, true);
	}
	float Velocity[3];
	GetEntPropVector(jockey, Prop_Data, "m_vecVelocity", Velocity);
	float currentspeed = SquareRoot(Pow(Velocity[0], 2.0) + Pow(Velocity[1], 2.0));
	int flags = GetEntityFlags(jockey);
	if(!(flags & FL_ONGROUND) && LeftGroundMaxSpeed[jockey] == -1.0)
		LeftGroundMaxSpeed[jockey] = GetEntPropFloat(jockey, Prop_Data, "m_flMaxspeed");
	if(GetEntProp(jockey, Prop_Send, "m_hasVisibleThreats") == 0)
		return Plugin_Continue;

	float dist = NearestSurvivorDistance(jockey);
	if(currentspeed > 130.0 && dist < g_hHopActivationProximity.FloatValue)
	{
		if(flags & FL_ONGROUND)
		{
			if(dist < 250.0 && DelayExpired(jockey, 0, g_hJockeyLeapAgain.FloatValue))
			{
				if(LeftGroundMaxSpeed[jockey] != -1.0 && currentspeed > 250.0)
				{
					float CurVelVec[3];
					GetEntPropVector(jockey, Prop_Data, "m_vecAbsVelocity", CurVelVec);
					if(GetVectorLength(CurVelVec) > LeftGroundMaxSpeed[jockey])
					{
						NormalizeVector(CurVelVec, CurVelVec);
						ScaleVector(CurVelVec, LeftGroundMaxSpeed[jockey]);
						TeleportEntity(jockey, NULL_VECTOR, NULL_VECTOR, CurVelVec);
					}
					LeftGroundMaxSpeed[jockey] = -1.0;
				}
				if(GetState(jockey, 0) == IN_JUMP)
				{
					bool IsWatchingJockey = IsTargetWatchingAttacker(jockey, 20);
					if(angles[2] == 0.0 && IsWatchingJockey)
					{
						angles[0] = GetRandomFloat(-20.0, 0.0);
						TeleportEntity(jockey, NULL_VECTOR, angles, NULL_VECTOR);
					}
					buttons |= IN_ATTACK;
					SetState(jockey, 0, IN_ATTACK);
				}
				else
				{
					if(angles[2] == 0.0)
					{
						angles[0] = GetRandomFloat(20.0, 0.0);
						TeleportEntity(jockey, NULL_VECTOR, angles, NULL_VECTOR);
					}
					buttons |= IN_JUMP;
					switch(GetRandomInt(0, 2))
					{
						case 0:
							buttons |= IN_DUCK;
						case 1:
							buttons |= IN_ATTACK2;
					}
					SetState(jockey, 0, IN_JUMP);
				}
			}
			else if(IsValidSurvivor(target))
			{
				float target_pos[3] = {0.0}, vel_buffer[3] = {0.0};
				GetClientAbsOrigin(target, target_pos);
				vel_buffer = CalculateVel(Velocity, target_pos, 90.0);
				buttons |= IN_ATTACK;
				if(Do_Bhop(jockey, buttons, vel_buffer))
					return Plugin_Changed;
			}
		}
		if(GetEntityMoveType(jockey) & MOVETYPE_LADDER)
		{
			buttons &= ~IN_JUMP;
			buttons &= ~IN_DUCK;
		}
	}
	return Plugin_Continue;
}

bool IsAiJockey(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client) && IsFakeClient(client)
		&& GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 5
		&& GetEntProp(client, Prop_Send, "m_isGhost") != 1;
}

#define SEQUENCE_ONEHAND 49
#define SEQUENCE_UNDERHAND 50
#define SEQUENCE_TWOHAND 51

public void Tank_OnModuleStart()
{
	HookEvent("tank_spawn", evt_TankSpawn);
}

public void Tank_OnModuleEnd()
{
}

public void evt_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(IsAiTank(client))
		SDKHook(client, SDKHook_PostThinkPost, UpdateThink);
}

public void UpdateThink(int client)
{
	switch(GetEntProp(client, Prop_Send, "m_nSequence"))
	{
		case 15, 16, 17:
			SetEntPropFloat(client, Prop_Send, "m_flPlaybackRate", 2.0);
		case 18, 19, 20, 21, 22, 23:
			SetEntPropFloat(client, Prop_Send, "m_flPlaybackRate", 4.0);
		case 54, 55, 56, 57, 58, 59, 60:
			SetEntPropFloat(client, Prop_Send, "m_flPlaybackRate", 999.0);
	}
}

public Action L4D2_OnSelectTankAttack(int client, int &sequence)
{
	if(sequence == SEQUENCE_UNDERHAND)
	{
		sequence = GetRandomInt(0, 1) ? SEQUENCE_ONEHAND : SEQUENCE_TWOHAND;
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public void L4D_TankClaw_DoSwing_Pre(int tank, int claw)
{
	SetConVarString(FindConVar("z_tank_throw_force"), "600");
}

public Action L4D_OnCThrowActivate(int ability)
{
	SetConVarString(FindConVar("z_tank_throw_force"), "600");
	int tankclient = GetEntPropEnt(ability, Prop_Data, "m_hOwnerEntity");
	if(IsAiTank(tankclient))
		RequestFrame(NextFrame_JumpRock, tankclient);
	return Plugin_Continue;
}

void NextFrame_JumpRock(int tankclient)
{
	if(IsAiTank(tankclient))
	{
		float tankpos[3] = {0.0};
		GetClientAbsOrigin(tankclient, tankpos);
		int target = GetClosestSurvivor(tankpos);
		if(IsSurvivor(target) && GetEntityFlags(tankclient) & FL_ONGROUND)
		{
			float eyeangles[3] = {0.0}, lookat[3] = {0.0};
			GetClientEyeAngles(tankclient, eyeangles);
			GetAngleVectors(eyeangles, lookat, NULL_VECTOR, NULL_VECTOR);
			NormalizeVector(lookat, lookat);
			ScaleVector(lookat, 200.0);
			lookat[2] = 200.0;
			TeleportEntity(tankclient, NULL_VECTOR, NULL_VECTOR, lookat);
		}
	}
}

bool IsAiTank(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client) && IsFakeClient(client)
		&& GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8
		&& GetEntProp(client, Prop_Send, "m_isGhost") != 1;
}

ConVar g_hShoveControlCooldown;
float g_fShoveControlCooldownEnd[MAXPLAYERS + 1];

public void OnPluginStart() 
{
	g_hShoveControlCooldown = CreateConVar("ai_si_shove_cooldown", "1.5", "Time after a shove before a Hunter or Jockey can pin a survivor again", FCVAR_NOTIFY, true, 0.0);
	HookEvent("player_spawn", InitialiseSpecialInfected);
	HookEvent("ability_use", OnAbilityUse); 
	Hunter_OnModuleStart2();
	Hunter_OnModuleStart();
	Jockey_OnModuleStart();
	Tank_OnModuleStart();

}

public void OnPluginEnd() 
{
	Hunter_OnModuleEnd2();
	Hunter_OnModuleEnd();
	Jockey_OnModuleEnd();
	Tank_OnModuleEnd();
}

/***********************************************************************************************************************************************************************************

																	KEEP SI AGGRESSIVE
																	
***********************************************************************************************************************************************************************************/

public Action L4D_OnFirstSurvivorLeftSafeArea()
{
	InitStatus();
}


/***********************************************************************************************************************************************************************************

																		SI MOVEMENT
																	
***********************************************************************************************************************************************************************************/
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon) 
{
	if(!IsPinningASurvivor(client))
	{
		if(IsShoveControlCooldownActive(client))
		{
			buttons &= ~IN_ATTACK;
			return Plugin_Changed;
		}

		switch(GetInfectedClass(client)) 
		{
			case L4D2Infected_Hunter:
			{
				Hunter_OnPlayerRunCmd2(client, buttons, impulse, vel, angles, weapon);
				Hunter_OnPlayerRunCmd(client, buttons, impulse, vel, angles, weapon);
			}
			case L4D2Infected_Jockey:
			{
				Jockey_OnPlayerRunCmd(client, buttons, impulse, vel, angles, weapon);
			}
			default :
			{
				
			}
		}
	}
	return Plugin_Continue;
}

/***********************************************************************************************************************************************************************************

																		EVENT HOOKS

***********************************************************************************************************************************************************************************/
public Action InitialiseSpecialInfected(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_fShoveControlCooldownEnd[client] = 0.0;
	if(IsAiHunter(client)) 
	{
		g_bHasQueuedLunge[client] = false;
	}
	return Plugin_Continue;
}

public Action OnAbilityUse(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(IsAiHunter(client)) 
	{
		static char sAbilityName[32];
		sAbilityName[0] = 0;
		event.GetString("ability", sAbilityName, sizeof(sAbilityName));
		//if(strcmp(sAbilityName, "ability_charge") == 0) 
			//Charger_OnCharge(client);
		if (strcmp(sAbilityName, "ability_lunge") == 0 && !IsShoveControlCooldownActive(client))
			Hunter_OnPounce(client);
	}
	return Plugin_Continue;
}

public Action L4D_OnShovedBySurvivor(int client, int victim, const float vecDir[3])
{
	if(IsAiHunter(victim) && GetEntPropEnt(victim, Prop_Send, "m_pounceVictim") <= 0 && !(GetEntityFlags(victim) & FL_ONGROUND))
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public void L4D_OnShovedBySurvivor_Post(int client, int victim, const float vecDir[3])
{
	if(IsAiHunter(victim) || IsAiJockey(victim))
	{
		StartShoveControlCooldown(victim);
	}
}

public Action L4D_ActivateAbility_Hunter(int client, int ability)
{
	if(IsAiHunter(client) && IsShoveControlCooldownActive(client))
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action L4D2_ActivateAbility_Jockey(int client, int ability)
{
	if(IsAiJockey(client) && IsShoveControlCooldownActive(client))
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action L4D_OnPouncedOnSurvivor(int victim, int attacker)
{
	if(IsBotInfected(attacker) && IsPinnedByAnother(victim, attacker))
		return Plugin_Handled;
	if(IsAiHunter(attacker) && IsShoveControlCooldownActive(attacker))
		return Plugin_Handled;
	return Plugin_Continue;
}

public Action L4D2_OnJockeyRide(int victim, int attacker)
{
	if(IsBotInfected(attacker) && IsPinnedByAnother(victim, attacker))
		return Plugin_Handled;
	if(IsAiJockey(attacker) && IsShoveControlCooldownActive(attacker))
		return Plugin_Handled;
	return Plugin_Continue;
}

public Action L4D_OnGrabWithTongue(int victim, int attacker)
{
	if(IsBotInfected(attacker) && IsPinnedByAnother(victim, attacker))
		return Plugin_Handled;
	return Plugin_Continue;
}

bool IsShoveControlCooldownActive(int client)
{
	return GetGameTime() < g_fShoveControlCooldownEnd[client];
}

void StartShoveControlCooldown(int client)
{
	g_fShoveControlCooldownEnd[client] = GetGameTime() + g_hShoveControlCooldown.FloatValue;
}

/***********************************************************************************************************************************************************************************

																	TRACKING SURVIVORS' AIM

***********************************************************************************************************************************************************************************/



bool IsTargetWatchingAttacker(int attacker, int offsetThreshold) 
{
	static bool isWatching;
	isWatching = true;
	if(IsBotInfected(attacker) && IsPlayerAlive(attacker)) 
	{
		int target = GetClientAimTarget(attacker);
		if(IsSurvivor(target) && IsPlayerAlive(target)) 
		{
			int aimOffset = RoundToNearest(GetPlayerAimOffset(target, attacker));
			if(aimOffset <= offsetThreshold) 
				isWatching = true;
			else 
				isWatching = false;
		} 
	}	
	return isWatching;
}


float GetPlayerAimOffset(int attacker, int target) 
{
	if(!IsClientInGame(attacker) || !IsPlayerAlive(attacker))
		ThrowError("Client is not Alive."); 
	if(!IsClientInGame(target) || !IsPlayerAlive(target))
		ThrowError("Target is not Alive.");
		
	static float attackerPos[3], targetPos[3];
	static float aimVector[3], directVector[3];

	// Get the unit vector representing the attacker's aim
	GetClientEyeAngles(attacker, aimVector);
	aimVector[0] = aimVector[2] = 0.0; // Restrict pitch and roll, consider yaw only (angles on horizontal plane)
	GetAngleVectors(aimVector, aimVector, NULL_VECTOR, NULL_VECTOR); // extract the forward vector[3]
	NormalizeVector(aimVector, aimVector); // convert into unit vector
	
	// Get the unit vector representing the vector between target and attacker
	GetClientAbsOrigin(target, targetPos); 
	GetClientAbsOrigin(attacker, attackerPos);
	attackerPos[2] = targetPos[2] = 0.0; // Restrict to XY coordinates
	MakeVectorFromPoints(attackerPos, targetPos, directVector);
	NormalizeVector(directVector, directVector);
	
	// Calculate the angle between the two unit vectors
	return RadToDeg(ArcCosine(GetVectorDotProduct(aimVector, directVector)));
}

bool IsPinningASurvivor(int client) 
{
	bool isPinning = false;
	if( IsBotInfected(client) && IsPlayerAlive(client) ) 
	{
		if( GetEntPropEnt(client, Prop_Send, "m_tongueVictim") > 0 ) isPinning = true; // smoker
		if( GetEntPropEnt(client, Prop_Send, "m_pounceVictim") > 0 ) isPinning = true; // hunter
		if( GetEntPropEnt(client, Prop_Send, "m_carryVictim") > 0 ) isPinning = true; // charger carrying
		if( GetEntPropEnt(client, Prop_Send, "m_pummelVictim") > 0 ) isPinning = true; // charger pounding
		if( GetEntPropEnt(client, Prop_Send, "m_jockeyVictim") > 0 ) isPinning = true; // jockey
	}
	return isPinning;
}
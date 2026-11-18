#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define ZC_BOOMER 2

stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}

stock bool IsValidSurvivor(int client)
{
	return IsValidClient(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}

stock bool IsClientIncapped(int client)
{
	if (!IsValidClient(client) || !IsPlayerAlive(client)) { return false; }
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}

stock void CopyVectors(float origin[3], float result[3])
{
	result[0] = origin[0];
	result[1] = origin[1];
	result[2] = origin[2];
}

int g_iClosestSurvCache[MAXPLAYERS + 1];
float g_fClosestSurvCacheTime[MAXPLAYERS + 1];
stock int GetClosetSurvivor(int client, int exclude_client = -1)
{
	float fNow = GetGameTime();
	if (g_fClosestSurvCacheTime[client] == fNow)
		return g_iClosestSurvCache[client];

	int iClosest = 0;
	float fMinDist = 999999.0;
	static float selfPos[3], targetPos[3];
	GetClientAbsOrigin(client, selfPos);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i == exclude_client) { continue; }
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != TEAM_SURVIVOR) { continue; }
		GetClientAbsOrigin(i, targetPos);
		float dist = GetVectorDistance(selfPos, targetPos);
		if (dist < fMinDist)
		{
			fMinDist = dist;
			iClosest = i;
		}
	}
	g_iClosestSurvCache[client] = iClosest;
	g_fClosestSurvCacheTime[client] = fNow;
	return iClosest;
}

#define CVAR_FLAG FCVAR_NOTIFY
#define EYE_ANGLE_UP_HEIGHT 15.0
#define NAV_MESH_HEIGHT 20.0
#define FALL_DETECT_HEIGHT 120.0
#define COMMAND_INTERVAL 1.0
#define PLAYER_HEIGHT 72.0
#define TURN_ANGLE_DIVIDE 6.0
#define FORCE_BILE_DELAY_TICKS 4
#define BILE_WINDOW_EXTRA 1.5
#define CHASE_PUSH_SPEED 150.0
#define DEBUG_ALL 0

enum AimType
{
	AimEye,
	AimBody,
	AimChest
};

public Plugin myinfo =
{
	name 			= "Ai Boomer 2.0",
	author 			= "夜羽真白",
	description 	= "Ai Boomer 增强 2.0 版本",
	version 		= "2023/1/17",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

ConVar
	g_hAllowBhop,
	g_hBhopSpeed,
	g_hUpVision,
	g_hTurnVision,
	g_hForceBile,
	g_hBileFindRange,
	g_hVomitRange,
	g_hVomitDuration,
	g_hVomitInterval,
	g_hTurnInterval,
	g_hAllowInDegreeForceBile,
	g_hAllowAutoFrame;

bool
	can_bile[MAXPLAYERS + 1],
	in_bile_interval[MAXPLAYERS + 1] = { false },
	isInBileState[MAXPLAYERS + 1] = { false },
	g_bForceBileFired[MAXPLAYERS + 1] = { false };

int
	bile_frame[MAXPLAYERS + 1][2],

	secondCheckFrame[MAXPLAYERS + 1],

	g_iVictimCache[MAXPLAYERS + 1];

ArrayList
	targetList[MAXPLAYERS + 1] = { null };

public void OnPluginStart()
{

	for (int i = 0; i < MAXPLAYERS + 1; i++) { can_bile[i] = true; }

	g_hAllowBhop = CreateConVar("ai_BoomerBhop", "1", "是否开启 Boomer 连跳", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hBhopSpeed = CreateConVar("ai_BoomerBhopSpeed", "150.0", "Boomer 连跳速度", CVAR_FLAG, true, 0.0);
	g_hUpVision = CreateConVar("ai_BoomerUpVision", "1", "Boomer 喷吐时是否上抬视角", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hTurnVision = CreateConVar("ai_BoomerTurnVision", "1", "Boomer 喷吐时是否旋转视角", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hForceBile = CreateConVar("ai_BoomerForceBile", "0", "是否开启生还者到 Boomer 喷吐范围内强制被喷", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hBileFindRange = CreateConVar("ai_BoomerBileFindRange", "300", "在这个距离内有被控或倒地的生还 Boomer 会优先攻击，0 = 禁用", CVAR_FLAG, true, 0.0);
	g_hTurnInterval = CreateConVar("ai_BoomerTurnInterval", "15", "Boomer 喷吐旋转视角时每隔多少帧转移一个目标", CVAR_FLAG, true, 0.0);

	g_hAllowInDegreeForceBile = CreateConVar("ai_BoomerDegreeForceBile", "30", "允许在目标处于 Boomer 准星这一角度内且视线通畅时强制喷吐，0 = 禁用，推荐 20~40", CVAR_FLAG, true, 0.0);
	g_hAllowAutoFrame = CreateConVar("ai_BoomerAutoFrame", "1", "是否允许 Boomer 根据目标的角度自动计算视野在下一个目标的帧数", CVAR_FLAG, true, 0.0, true, 1.0);

	g_hVomitRange = FindConVar("z_vomit_range");
	g_hVomitDuration = FindConVar("z_vomit_duration");
	g_hVomitInterval = FindConVar("z_vomit_interval");

	HookEvent("player_spawn", evt_PlayerSpawn);
	HookEvent("player_shoved", evt_PlayerShoved);
	HookEvent("player_now_it", evt_PlayerNowIt);
	HookEvent("round_start", evt_RoundStart);

	SetConVarFloat(FindConVar("boomer_exposed_time_tolerance"), 10000.0);
	SetConVarFloat(FindConVar("boomer_vomit_delay"), 0.1);
}
public void OnPluginEnd()
{
	FindConVar("boomer_exposed_time_tolerance").RestoreDefault();
	FindConVar("boomer_vomit_delay").RestoreDefault();
	for (int i = 0; i < MAXPLAYERS + 1; i++)
	{
		delete targetList[i];
		targetList[i] = null;
	}
}

public void evt_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 0; i < MAXPLAYERS + 1; i++) { secondCheckFrame[i] = 0; g_iVictimCache[i] = 0; }
}

public void evt_PlayerShoved(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsBoomer(client)) { return; }
	in_bile_interval[client] = true;
	if (targetList[client] != null) { targetList[client].Clear(); }
	bile_frame[client][0] = bile_frame[client][1] = 0;

	CreateTimer(1.5, Timer_ResetAbility, GetClientUserId(client));
}

public void OnClientDisconnect(int client)
{
	isInBileState[client] = false;
	secondCheckFrame[client] = 0;
	g_iVictimCache[client] = 0;
}

public void evt_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsBoomer(client)) { return; }
	can_bile[client] = true;
	in_bile_interval[client] = false;
	bile_frame[client][0] = bile_frame[client][1] = 0;

	if (targetList[client] != null) { targetList[client].Clear(); }
	else { targetList[client] = new ArrayList(2); }
}

public void evt_PlayerNowIt(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker")), victim = GetClientOfUserId(event.GetInt("userid"));
	if (!IsBoomer(attacker) || !IsPlayerAlive(attacker) || !IsValidSurvivor(victim) || !IsPlayerAlive(victim)) { return; }
	isInBileState[victim] = true;

	CreateTimer(FindConVar("sb_vomit_blind_time").FloatValue, resetBileStateHandler, GetClientUserId(victim));
}
public Action resetBileStateHandler(Handle timer, int userid)
{

	int client = GetClientOfUserId(userid);
	if (client > 0)
	{
		isInBileState[client] = false;
		secondCheckFrame[client] = 0;
	}
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{

	if (client < 1 || client > MaxClients || !IsFakeClient(client))
		return Plugin_Continue;
	if (!IsBoomer(client)) { return Plugin_Continue; }
	// 兜底：插件 late load 或事件缺失时列表可能未创建，懒创建避免 Invalid Handle
	if (targetList[client] == null) { targetList[client] = new ArrayList(2); }
	float self_pos[3], self_eye_pos[3], targetPos[3], target_eye_pos[3], vec_speed[3], aim_angles[3], vel_buffer[3], targetDist, cur_speed, height, engage_dist;
	int flags, target, ability, isAbilityUsing, i;
	bool has_sight;
	flags = GetEntityFlags(client);
	// 目标优先使用引擎 victim（L4D2_OnChooseVictim 缓存），失效才取最近生还者
	target = g_iVictimCache[client];
	if (!IsValidSurvivor(target) || !IsPlayerAlive(target)) { target = GetClosetSurvivor(client); }

	if (target <= 0) { return Plugin_Continue; }
	ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
	if (!IsValidEntity(ability)) { return Plugin_Continue; }
	has_sight = view_as<bool>(GetEntProp(client, Prop_Send, "m_hasVisibleThreats"));
	isAbilityUsing = GetEntProp(ability, Prop_Send, "m_isSpraying");
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vec_speed);
	cur_speed = SquareRoot(Pow(vec_speed[0], 2.0) + Pow(vec_speed[1], 2.0));
	GetClientAbsOrigin(client, self_pos);
	GetEntPropVector(target, Prop_Send, "m_vecOrigin", targetPos);
	GetClientEyePosition(client, self_eye_pos);
	targetDist = GetVectorDistance(self_pos, targetPos);
	engage_dist = g_hVomitRange.FloatValue * 0.95;

	Action react = Plugin_Continue;
	// 每 tick 转向主目标，为开火与强喷做准备
	if (has_sight && IsValidSurvivor(target) && !in_bile_interval[client] && targetList[client].Length < 1)
	{
		height = self_pos[2] - targetPos[2];
		if (targetDist <= g_hVomitRange.FloatValue)
		{

			ComputeAimAngles(client, target, aim_angles, AimEye);
			if (g_hUpVision.BoolValue)
			{
				if (height == 0.0 || height < 0.0) { aim_angles[0] -= targetDist / (PLAYER_HEIGHT * 0.8); }
				else if (height > 0.0) { aim_angles[0] -= targetDist / (PLAYER_HEIGHT * 1.5); }
			}
			TeleportEntity(client, NULL_VECTOR, aim_angles, NULL_VECTOR);

			if (g_hAllowInDegreeForceBile.FloatValue > 0.0 && isInAimOffset(client, target, g_hAllowInDegreeForceBile.FloatValue) && !isInBileState[target] && isAbilityUsing)
			{
				if (secondCheckFrame[target] < FORCE_BILE_DELAY_TICKS && !isInBileState[target]) { secondCheckFrame[target]++; }
				else if (!isInBileState[target] && secondCheck(client, target))
				{

					L4D_CTerrorPlayer_OnVomitedUpon(target, client);
					isInBileState[target] = true;
					secondCheckFrame[target] = 0;
				}
			}
		}
	}
	// 旋转补喷：本轮已喷（can_bile=false）且还有待补目标；窗口 = 开火到 z_vomit_interval
	if (targetList[client].Length >= 1 && !can_bile[client] && g_hTurnVision.BoolValue)
	{

		if (bile_frame[client][0] < targetList[client].Length)
		{

			int turnTarget, targetFrame;
			float turnAngle, turnDist;
			turnTarget = targetList[client].Get(bile_frame[client][0], 1);
			turnAngle = targetList[client].Get(bile_frame[client][0], 0);
			if(GetClientAbsOrigin(turnTarget, targetPos) && IsValidSurvivor(turnTarget) && IsPlayerAlive(turnTarget))
			{
				height = self_pos[2] - targetPos[2];
				turnDist = GetVectorDistance(self_pos, targetPos);

				ComputeAimAngles(client, turnTarget, aim_angles, AimEye);
				if (g_hUpVision.BoolValue)
				{
					if (height == 0.0 || height < 0.0) { aim_angles[0] -= turnDist / (PLAYER_HEIGHT * 0.8); }
					else if (height > 0.0) { aim_angles[0] -= turnDist / (PLAYER_HEIGHT * 1.5); }
				}
				TeleportEntity(client, NULL_VECTOR, aim_angles, NULL_VECTOR);

				targetFrame = g_hAllowAutoFrame.BoolValue ? RoundToNearest(turnAngle / TURN_ANGLE_DIVIDE) : g_hTurnInterval.IntValue;

				if (g_hAllowInDegreeForceBile.FloatValue > 0.0 && g_hAllowAutoFrame.BoolValue && targetFrame == 0)
				{
					L4D_CTerrorPlayer_OnVomitedUpon(turnTarget, client);
					isInBileState[turnTarget] = true;
					secondCheckFrame[turnTarget] = 0;
					bile_frame[client][0] += 1;
					return Plugin_Continue;
				}
				if (bile_frame[client][1] < targetFrame)
				{

					if (g_hAllowInDegreeForceBile.FloatValue > 0.0)
					{
						if (secondCheckFrame[turnTarget] < targetFrame && !isInBileState[turnTarget])
						{
							secondCheckFrame[turnTarget]++;
						}
						else if (!isInBileState[turnTarget] && secondCheck(client, turnTarget))
						{
							L4D_CTerrorPlayer_OnVomitedUpon(turnTarget, client);
							isInBileState[turnTarget] = true;
							secondCheckFrame[turnTarget] = 0;
							bile_frame[client][1] = targetFrame;
						}
						else if (isInBileState[turnTarget])
						{
							bile_frame[client][1] = secondCheckFrame[turnTarget] = 0;
							bile_frame[client][0] += 1;
							return Plugin_Continue;
						}
					}
					bile_frame[client][1] += 1;
				}

				else if (bile_frame[client][0] >= targetList[client].Length)
				{
					targetList[client].Clear();
					bile_frame[client][0] = bile_frame[client][1] = 0;
				}

				else
				{
					bile_frame[client][0] += 1;
					bile_frame[client][1] = 0;
				}
			}
			else
			{
				// 目标已死/失效，跳到下一个
				bile_frame[client][0] += 1;
				bile_frame[client][1] = 0;
			}
		}
	}

	// 主动开火：trace 视线判定替代 has_sight，距离放宽到 0.95 倍喷吐距离
	if ((flags & FL_ONGROUND) && IsValidSurvivor(target) && IsVisibleTarget(client, target)
		&& targetDist <= engage_dist && !in_bile_interval[client] && can_bile[client])
	{
		buttons |= IN_FORWARD;
		buttons |= IN_ATTACK;
		react = Plugin_Changed;

		// 新一轮：清旧补喷列表与轮转帧，立即进入本轮状态
		if (targetList[client] != null) { targetList[client].Clear(); }
		bile_frame[client][0] = bile_frame[client][1] = 0;
		can_bile[client] = false;
		in_bile_interval[client] = true;

		CreateTimer(g_hVomitInterval.FloatValue, Timer_ResetAbility, GetClientUserId(client));
		CreateTimer(g_hVomitDuration.FloatValue + BILE_WINDOW_EXTRA, Timer_EndBileWindow, GetClientUserId(client));
	}

	if (IsValidSurvivor(target) && (IsClientIncapped(target) || IsSurvivorPinned(target)) && targetDist <= 80.0)
	{
		if (FloatAbs(self_pos[2] - targetPos[2]) > PLAYER_HEIGHT) { return react; }
		GetClientEyePosition(target, target_eye_pos);
		if (!L4D2_IsVisibleToPlayer(client, TEAM_SURVIVOR, TEAM_INFECTED, 0, target_eye_pos)) { return react; }
		buttons |= IN_ATTACK2;
		react = Plugin_Changed;
	}

	// ForceBile： Boomer 喷吐上升沿触发一次，范围内可见生还全部强喷；不再依赖 buttons & IN_ATTACK，避免 CD 状态竞争
	if (g_hForceBile.BoolValue && isAbilityUsing && !g_bForceBileFired[client])
	{
		g_bForceBileFired[client] = true;
		for (i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i) || isInBileState[i]) { continue; }
			GetClientEyePosition(i, target_eye_pos);
			if (GetVectorDistance(self_eye_pos, target_eye_pos) > g_hVomitRange.FloatValue) { continue; }
			Handle trace = TR_TraceRayFilterEx(self_eye_pos, target_eye_pos, MASK_VISIBLE, RayType_EndPoint, TR_VomitClientFilter, client);
			if (!TR_DidHit(trace) || TR_GetEntityIndex(trace) == i)
			{
				L4D_CTerrorPlayer_OnVomitedUpon(i, client);
				isInBileState[i] = true;
			}
			delete trace;
		}
	}
	else if (!isAbilityUsing)
	{
		g_bForceBileFired[client] = false;
	}

	if (g_hAllowBhop.BoolValue && has_sight && (flags & FL_ONGROUND) && ((0.5 * g_hVomitRange.FloatValue) < targetDist && targetDist < 1000.0) && cur_speed > 100.0 && IsValidSurvivor(target))
	{
		vel_buffer = CalculateVel(self_pos, targetPos, g_hBhopSpeed.FloatValue);
		buttons |= IN_JUMP;
		buttons |= IN_DUCK;
		if (Do_Bhop(client, buttons, vel_buffer)) { return Plugin_Changed; }
	}

	// 主动逼近：超出开火距离且视线通畅时，向目标持续推送移动速度（含撞墙/坠落检测）
	if (IsValidSurvivor(target) && targetDist > engage_dist && IsVisibleTarget(client, target))
	{
		vel_buffer = CalculateVel(self_pos, targetPos, CHASE_PUSH_SPEED);
		if (Dont_HitWall_Or_Fall(client, vel_buffer))
		{
			AddVectors(vel, vel_buffer, vel);
			buttons |= IN_FORWARD;
			react = Plugin_Changed;
		}
	}

	if (GetEntityMoveType(client) & MOVETYPE_LADDER)
	{
		buttons &= ~IN_ATTACK;
		buttons &= ~IN_ATTACK2;
		buttons &= ~IN_JUMP;
		buttons &= ~IN_DUCK;
		react = Plugin_Changed;
	}
	return react;
}

stock bool IsSurvivorPinned(int client)
{
    return (GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0) ||
           (GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0) ||
           (GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0) ||
           (GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0) ||
           (GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0);
}


bool secondCheck(int client, int target)
{
	if (!IsBoomer(client) || !IsPlayerAlive(client) || !IsValidSurvivor(target) || !IsPlayerAlive(target)) { return false; }

	float selfPos[3] = {0.0}, targetPos[3] = {0.0}, dist;
	GetClientEyePosition(client, selfPos);
	GetClientEyePosition(target, targetPos);
	dist = GetVectorDistance(selfPos, targetPos);
	if (dist > g_hVomitRange.FloatValue || !isInAimOffset(client, target, g_hAllowInDegreeForceBile.FloatValue) || isInBileState[target]) { return false; }
	Handle trace = TR_TraceRayFilterEx(selfPos, targetPos, MASK_VISIBLE, RayType_EndPoint, TR_VomitClientFilter, client);
	if (!TR_DidHit(trace) || TR_GetEntityIndex(trace) == target)
	{

		delete trace;
		return true;
	}
	delete trace;
	return false;
}

stock bool IsVisibleTarget(int client, int target)
{
	if (!IsValidClient(client) || !IsPlayerAlive(client) || !IsValidSurvivor(target) || !IsPlayerAlive(target)) { return false; }
	static float self_eye_pos[3], target_eye_pos[3];
	GetClientEyePosition(client, self_eye_pos);
	GetClientEyePosition(target, target_eye_pos);
	bool visible = false;
	Handle trace = TR_TraceRayFilterEx(self_eye_pos, target_eye_pos, MASK_VISIBLE, RayType_EndPoint, TR_VomitClientFilter, client);
	if (!TR_DidHit(trace) || TR_GetEntityIndex(trace) == target) { visible = true; }
	delete trace;
	return visible;
}

bool TR_VomitClientFilter(int entity, int contentsMask, int self)
{

	if (entity > 0 && entity <= MaxClients && isInBileState[entity]) { return false; }
	return entity != self;
}

public Action Timer_ResetAbility(Handle timer, int userid)
{

	int client = GetClientOfUserId(userid);
	if (client > 0 && IsBoomer(client) && IsPlayerAlive(client))
	{
		can_bile[client] = true;
		in_bile_interval[client] = false;
		return Plugin_Continue;
	}
	return Plugin_Stop;
}
public Action Timer_EndBileWindow(Handle timer, int userid)
{

	int client = GetClientOfUserId(userid);
	if (client > 0 && IsBoomer(client))
	{
		// 补喷窗口结束：清空待补目标与轮转帧；喷吐 CD 由 Timer_ResetAbility 独立管理
		if (targetList[client] != null) { targetList[client].Clear(); }
		bile_frame[client][0] = bile_frame[client][1] = 0;
		return Plugin_Continue;
	}
	return Plugin_Stop;
}

public Action L4D2_OnChooseVictim(int specialInfected, int &curTarget)
{
	if (IsBoomer(specialInfected) && IsPlayerAlive(specialInfected))
	{
		// 缓存引擎当前意图目标，供 OnPlayerRunCmd 统一使用
		g_iVictimCache[specialInfected] = curTarget;

		float eyePos[3] = {0.0}, targetEyePos[3] = {0.0}, flatEye[3] = {0.0}, flatTarget[3] = {0.0}, dist = 0.0;
		GetClientEyePosition(specialInfected, eyePos);

		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR && IsPlayerAlive(i) && (IsClientIncapped(i) || IsSurvivorPinned(i)))
			{
				GetClientEyePosition(i, targetEyePos);
				// 水平距离用于范围判定
				CopyVectors(eyePos, flatEye);
				CopyVectors(targetEyePos, flatTarget);
				flatEye[2] = flatTarget[2] = 0.0;
				dist = GetVectorDistance(flatEye, flatTarget);
				if (g_hBileFindRange.FloatValue > 0.0 && dist <= g_hBileFindRange.FloatValue)
				{
					// 视线 trace 必须用真实眼位，不能用 z=0 的点（楼上/坡地会打墙）
					Handle hTrace = TR_TraceRayFilterEx(eyePos, targetEyePos, MASK_VISIBLE, RayType_EndPoint, TR_VomitClientFilter, specialInfected);
					if (!TR_DidHit(hTrace) || TR_GetEntityIndex(hTrace) == i)
					{

						delete hTrace;
						curTarget = i;
						g_iVictimCache[specialInfected] = i;
						return Plugin_Changed;
					}
					delete hTrace;
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action L4D_OnVomitedUpon(int victim, int &attacker, bool &boomerExplosion)
{
	isInBileState[victim] = true;

	if (targetList[attacker] == null) { targetList[attacker] = new ArrayList(2); }
	if (!IsBoomer(attacker) && targetList[attacker].Length > 1) { return Plugin_Continue; }

	int i;
	float eyePos[3] = {0.0}, targetEyePos[3] = {0.0}, dist, angle;
	GetClientEyePosition(attacker, eyePos);
	for (i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i) || isInBileState[i]) { continue; }
		GetClientEyePosition(i, targetEyePos);
		dist = GetVectorDistance(eyePos, targetEyePos);
		if (dist > g_hVomitRange.FloatValue) { continue; }
		Handle trace = TR_TraceRayFilterEx(eyePos, targetEyePos, MASK_VISIBLE, RayType_EndPoint, TR_VomitClientFilter, attacker);

		if (!TR_DidHit(trace) || TR_GetEntityIndex(trace) == i)
		{
			angle = getSelfTargetAngle(attacker, i);
			targetList[attacker].Set(targetList[attacker].Push(angle), i, 1);
		}
		delete trace;
	}
	if (targetList[attacker].Length > 1) { targetList[attacker].Sort(Sort_Ascending, Sort_Float); }
	return Plugin_Continue;
}

bool IsBoomer(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && IsFakeClient(client)
		&& GetClientTeam(client) == TEAM_INFECTED
		&& GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_BOOMER;
}

float[] CalculateVel(float self_pos[3], float target_pos[3], float force)
{
	float vecbuffer[3] = {0.0};
	SubtractVectors(target_pos, self_pos, vecbuffer);
	NormalizeVector(vecbuffer, vecbuffer);
	ScaleVector(vecbuffer, force);
	return vecbuffer;
}

bool Dont_HitWall_Or_Fall(int client, float vel[3])
{
	int down_hullray_hitent = -1;
	char down_hullray_hitent_classname[16] = {'\0'};
	float selfpos[3] = {0.0}, resultpos[3] = {0.0}, mins[3] = {0.0}, maxs[3] = {0.0}, hullray_endpos[3] = {0.0}, down_hullray_startpos[3] = {0.0}, down_hullray_endpos[3] = {0.0}, down_hullray_hitpos[3] = {0.0};
	GetClientAbsOrigin(client, selfpos);
	AddVectors(selfpos, vel, resultpos);
	GetClientMins(client, mins);
	GetClientMaxs(client, maxs);
	selfpos[2] += NAV_MESH_HEIGHT;
	resultpos[2] += NAV_MESH_HEIGHT;

	Handle hTrace = TR_TraceHullFilterEx(selfpos, resultpos, mins, maxs, MASK_NPCSOLID_BRUSHONLY, TR_EntityFilter);
	if (TR_DidHit(hTrace))
	{
		TR_GetEndPosition(hullray_endpos, hTrace);
		if (GetVectorDistance(selfpos, hullray_endpos) <= NAV_MESH_HEIGHT)
		{
			delete hTrace;
			return false;
		}
	}
	delete hTrace;
	resultpos[2] -= NAV_MESH_HEIGHT;

	down_hullray_startpos = resultpos;
	CopyVectors(down_hullray_startpos, down_hullray_endpos);
	down_hullray_endpos[2] -= 100000.0;
	Handle hDownTrace = TR_TraceHullFilterEx(down_hullray_startpos, down_hullray_endpos, mins, maxs, MASK_NPCSOLID_BRUSHONLY, TR_EntityFilter);
	if (TR_DidHit(hDownTrace))
	{
		TR_GetEndPosition(down_hullray_hitpos, hDownTrace);

		if (FloatAbs(down_hullray_startpos[2] - down_hullray_hitpos[2]) > FALL_DETECT_HEIGHT)
		{
			delete hDownTrace;
			return false;
		}
		down_hullray_hitent = TR_GetEntityIndex(hDownTrace);
		GetEdictClassname(down_hullray_hitent, down_hullray_hitent_classname, sizeof(down_hullray_hitent_classname));
		if (strcmp(down_hullray_hitent_classname, "trigger_hurt") == 0)
		{
			delete hDownTrace;
			return false;
		}
		delete hDownTrace;
		return true;
	}
	delete hDownTrace;
	return false;
}
bool TR_EntityFilter(int entity, int mask)
{
	if (entity > 0 && entity <= MaxClients) { return false; }
	else
	{
		char classname[32] = {'\0'};
		GetEdictClassname(entity, classname, sizeof(classname));
		if (strcmp(classname, "infected") == 0 || strcmp(classname, "witch") == 0 || strcmp(classname, "prop_physics") == 0 || strcmp(classname, "tank_rock") == 0) { return false; }
	}
	return true;
}

bool Do_Bhop(int client, int &buttons, float vec[3])
{
	if (buttons & IN_FORWARD || buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT) { if (ClientPush(client, vec)) { return true; } }
	return false;
}
bool ClientPush(int client, float vec[3])
{
	float curvel[3] = {0.0};
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", curvel);
	AddVectors(curvel, vec, curvel);
	if (Dont_HitWall_Or_Fall(client, curvel))
	{
		if (GetVectorLength(curvel) <= 250.0)
		{
			NormalizeVector(curvel, curvel);
			ScaleVector(curvel, 251.0);
		}
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, curvel);
		return true;
	}
	return false;
}

void ComputeAimAngles(int client, int target, float angles[3], AimType type = AimEye)
{
	float selfpos[3], targetpos[3], lookat[3];
	GetClientEyePosition(client, selfpos);
	switch (type)
	{
		case AimEye: { GetClientEyePosition(target, targetpos); }
		case AimBody: { GetClientAbsOrigin(target, targetpos); }
		case AimChest:
		{
			GetClientAbsOrigin(target, targetpos);
			targetpos[2] += 45.0;
		}
	}
	MakeVectorFromPoints(selfpos, targetpos, lookat);
	GetVectorAngles(lookat, angles);
}

static bool isInAimOffset(int attacker, int target, float offset)
{
	if (!IsBoomer(attacker) || !IsPlayerAlive(attacker) || !IsValidSurvivor(target) || !IsPlayerAlive(target)) { return false; }
	static float angle;
	angle = getSelfTargetAngle(attacker, target);
	return angle != -1.0 && angle <= offset;
}

static float getSelfTargetAngle(int attacker, int target)
{
	if (!IsBoomer(attacker) || !IsPlayerAlive(attacker) || !IsValidSurvivor(target) || !IsPlayerAlive(target)) { return -1.0; }
	static float selfEyePos[3], targetEyePos[3], resultPos[3], selfEyeVector[3];

	GetClientEyePosition(attacker, selfEyePos);
	GetClientEyePosition(target, targetEyePos);
	selfEyePos[2] = targetEyePos[2] = 0.0;
	MakeVectorFromPoints(selfEyePos, targetEyePos, resultPos);
	NormalizeVector(resultPos, resultPos);

	GetClientEyeAngles(attacker, selfEyePos);
	selfEyePos[0] = selfEyePos[2] = 0.0;
	GetAngleVectors(selfEyePos, selfEyeVector, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(selfEyeVector, selfEyeVector);
	float dot = GetVectorDotProduct(selfEyeVector, resultPos);
	if (dot > 1.0) { dot = 1.0; }
	else if (dot < -1.0) { dot = -1.0; }
	return RadToDeg(ArcCosine(dot));
}
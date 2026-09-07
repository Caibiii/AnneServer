#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法
#define BOOST			60.0
#define PLAYER_HEIGHT	72.0
#define DEBUG_CHARGER_TARGET 0
#define FIXFLY			1

static ConVar g_hCvarEnable, g_hChargerBhop,
	g_hCvarChargeProximity, g_hCvarHealthThreshold,
	g_hChargeMaxSpeed, g_hChargeStartSpeed;
static int g_iCvarChargeProximity, g_iCvarHealthThreshold;
static float g_fChargeMaxSpeed, g_fChargeStartSpeed;
static bool g_bCvarEnable, g_bChargerBhop;

static int 
	g_bShouldCharge[MAXPLAYERS+ 1];

static bool 
	g_bModify[MAXPLAYERS + 1];

void Charger_OnModuleStart() {
	g_hCvarEnable 						= CreateConVar( "AI_HardSI_Charger_enable",   		"1",   		"0=Improves the Charger behaviour off, 1=Improves the Charger behaviour on.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	g_hChargerBhop 						= CreateConVar("ai_charger_bhop",			  		"1",	 	"Flag to enable bhop facsimile on AI chargers", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarChargeProximity 				= CreateConVar("ai_charge_proximity", 		  		"300", 		"How close a charger will approach before charging", FCVAR_NOTIFY, true, 0.0);	
	g_hCvarHealthThreshold 				= CreateConVar("ai_health_threshold_charger", 		"300", 		"Charger will charge if its health drops to this level", FCVAR_NOTIFY, true, 0.0);	

	g_hChargeMaxSpeed =			FindConVar("z_charge_max_speed");
	g_hChargeStartSpeed =		FindConVar("z_charge_start_speed");

	GetCvars();
	g_hCvarEnable.AddChangeHook(ConVarChanged_EnableCvars);
	g_hChargerBhop.AddChangeHook(CvarChanged);
	g_hCvarChargeProximity.AddChangeHook(CvarChanged);
	g_hCvarHealthThreshold.AddChangeHook(CvarChanged);
	g_hChargeMaxSpeed.AddChangeHook(CvarChanged);
	g_hChargeStartSpeed.AddChangeHook(CvarChanged);

	//HookEvent("charger_charge_start",	Event_ChargerChargeStart);
}

static void _OnModuleStart()
{
}

void Charger_OnModuleEnd() 
{
}

static void ConVarChanged_EnableCvars(ConVar hCvar, const char[] sOldVal, const char[] sNewVal)
{
    GetCvars();
    if(g_bCvarEnable)
    {
        _OnModuleStart();
    }
    else
    {
        Charger_OnModuleEnd();
    }
}

static void CvarChanged(ConVar hCvar, const char[] sOldVal, const char[] sNewVal)
{
	GetCvars();
}

static void GetCvars()
{
	g_bCvarEnable = g_hCvarEnable.BoolValue;
	g_bChargerBhop = g_hChargerBhop.BoolValue;
	g_iCvarChargeProximity = g_hCvarChargeProximity.IntValue;
	g_iCvarHealthThreshold = g_hCvarHealthThreshold.IntValue;

	g_fChargeMaxSpeed =			g_hChargeMaxSpeed.FloatValue;
	g_fChargeStartSpeed =		g_hChargeStartSpeed.FloatValue;
}

void Charger_OnSpawn(int botCharger) {
	if(!g_bCvarEnable) return;

	g_bShouldCharge[botCharger] = false;
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

stock Action Charger_OnPlayerRunCmd(int charger, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon ) {
	if(!g_bCvarEnable) return Plugin_Continue;

	// prevent charge until survivors are within the defined proximity
	float chargerPos[3] ,targetPos[3];
	GetClientAbsOrigin(charger, chargerPos);
	int target = GetClosestClient(charger); 
	if(target > 0)
	{
		GetClientAbsOrigin(target, targetPos);
		float nearestSurDist = GetVectorDistance(chargerPos, targetPos);
		if (nearestSurDist < 100.0)
		{
			if(!IsCharging(charger))
			{
				LookAtClient(charger, target);
				g_bShouldCharge[charger] = true;
			}
			if(!Is_InGetUp_Or_Incapped(target))
			{
				buttons |= IN_ATTACK;
			}
			buttons |= IN_ATTACK2;
			return Plugin_Changed;
		}
		if( GetEntProp(charger, Prop_Send, "m_iHealth") > g_iCvarHealthThreshold && nearestSurDist > g_iCvarChargeProximity ) 
		{	
			if( !g_bShouldCharge[charger] ) 
			{ 				
				ResetAbilityTime(charger, 0.1);
			} 			
		} 
		else 
		{
			if(!IsCharging(charger))
			{
				LookAtClient(charger, target);
			}
			g_bShouldCharge[charger] = true;
		}
		if (!g_bChargerBhop || GetEntityMoveType(charger) == MOVETYPE_LADDER || GetEntProp(charger, Prop_Data, "m_nWaterLevel") > 1 || !GetEntProp(charger, Prop_Send, "m_hasVisibleThreats"))
			return Plugin_Continue;

		static float val;
		static float vVel[3];
		GetEntPropVector(charger, Prop_Data, "m_vecVelocity", vVel);
		vVel[2] = 0.0;
		val = GetVectorLength(vVel);
		if (!CheckPlayerMove(charger, val))
			return Plugin_Continue;

		static float vAng[3];
		if (IsGrounded(charger)) {
			g_bModify[charger] = false;

			if (CurTargetDistance(charger) > 150.0 && -1.0 < nearestSurDist < 1500) {
				GetClientEyeAngles(charger, vAng);
				return BunnyHop(charger, buttons, vAng);
			}
		}
		else {
			if (g_bModify[charger] || val < GetEntPropFloat(charger, Prop_Send, "m_flMaxspeed") + BOOST)
				return Plugin_Continue;

			if (IsCharging(charger))
				return Plugin_Continue;

			target = GetClientAimTarget(charger, false);
			if (!IsAliveSur(target))
				target = GetCurTarget(charger);

			if (!IsAliveSur(target))
				return Plugin_Continue;

			static float vPos[3];
			static float vTar[3];
			static float vEye1[3];
			static float vEye2[3];
			GetClientAbsOrigin(charger, vPos);
			GetClientAbsOrigin(target, vTar);
			val = GetVectorDistance(vPos, vTar);
			if (val < 100.0 || val > 440.0)
				return Plugin_Continue;

			GetClientEyePosition(charger, vEye1);
			if (vEye1[2] < vTar[2])
				return Plugin_Continue;

			GetClientEyePosition(target, vEye2);
			if (vPos[2] > vEye2[2])
				return Plugin_Continue;

			vAng = vVel;
			vAng[2] = 0.0;
			NormalizeVector(vAng, vAng);

			static float vBuf[3];
			MakeVectorFromPoints(vPos, vTar, vBuf);
			vBuf[2] = 0.0;
			NormalizeVector(vBuf, vBuf);
			if (RadToDeg(ArcCosine(GetVectorDotProduct(vAng, vBuf))) < 90.0)
				return Plugin_Continue;

			if (vecHitWall(charger, vPos, vTar))
				return Plugin_Continue;

			MakeVectorFromPoints(vPos, vEye2, vVel);
			TeleportEntity(charger, NULL_VECTOR, NULL_VECTOR, vVel);
			g_bModify[charger] = true;
		}
	}
	return Plugin_Continue;
}
/*
static void Event_ChargerChargeStart(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!g_bCvarEnable || !client || !IsClientInGame(client) || !IsFakeClient(client))
		return;

	ChargerCharge(client);
}
*/
// other------------------

static Action BunnyHop(int client, int &buttons, const float vAng[3]) {
	float vVec[3];
	if (buttons & IN_FORWARD && !(buttons & IN_BACK)) {
		GetAngleVectors(vAng, vVec, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(vVec, vVec);
		ScaleVector(vVec, BOOST * 2.0);
		float vVel[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);
		AddVectors(vVel, vVec, vVel);
		if (CheckHopVel(client, vAng, vVel)) {
			buttons |= IN_DUCK;
			buttons |= IN_JUMP;
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
			return Plugin_Changed;
		}
	}
	else if (buttons & IN_BACK && !(buttons & IN_FORWARD)) {
		GetAngleVectors(vAng, vVec, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(vVec, vVec);
		ScaleVector(vVec, -BOOST);
		float vVel[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);
		AddVectors(vVel, vVec, vVel);
		if (CheckHopVel(client, vAng, vVel)) {
			buttons |= IN_DUCK;
			buttons |= IN_JUMP;
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
			return Plugin_Changed;
		}
	}

	if (buttons & IN_MOVERIGHT && !(buttons & IN_MOVELEFT)) {
		GetAngleVectors(vAng, NULL_VECTOR, vVec, NULL_VECTOR);
		NormalizeVector(vVec, vVec);
		ScaleVector(vVec, BOOST);
		float vVel[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);
		AddVectors(vVel, vVec, vVel);
		if (CheckHopVel(client, vAng, vVel)) {
			buttons |= IN_DUCK;
			buttons |= IN_JUMP;
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
			return Plugin_Changed;
		}
	}
	else if (buttons & IN_MOVELEFT && !(buttons & IN_MOVERIGHT)) {
		GetAngleVectors(vAng, NULL_VECTOR, vVec, NULL_VECTOR);
		NormalizeVector(vVec, vVec);
		ScaleVector(vVec, -BOOST);
		float vVel[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);
		AddVectors(vVel, vVec, vVel);
		if (CheckHopVel(client, vAng, vVel)) {
			buttons |= IN_DUCK;
			buttons |= IN_JUMP;
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

static bool IsCharging(int client) {
	static int ent;
	ent = GetEntPropEnt(client, Prop_Send, "m_customAbility");
	return ent > MaxClients && GetEntProp(ent, Prop_Send, "m_isCharging");
}

void ChargerCharge(int client) {
	int target = GetClientAimTarget(client, false); //g_iCurTarget[client];
	if (!IsAliveSur(target) || IsIncapacitated(target) || L4D_GetPinnedInfected(target) > 0 || entHitWall(client, target))
		target = GetClosestClient(client);

	if (!IsAliveSur(target))
		return;

	float vVel[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);

	float vel = GetVectorLength(vVel);
	vel = vel < g_fChargeStartSpeed ? g_fChargeStartSpeed : vel;

	float vPos[3], vTar[3];
	GetClientAbsOrigin(client, vPos);
	GetClientAbsOrigin(target, vTar);
	float height = vTar[2] - vPos[2];
	if (height >= 44.0) {
		vTar[2] += 44.0;
		vel += FloatAbs(height);
		vTar[2] += GetVectorDistance(vPos, vTar) / vel * PLAYER_HEIGHT;
	}

	if (!IsGrounded(client))
		vel += g_fChargeMaxSpeed;

	MakeVectorFromPoints(vPos, vTar, vVel);

	float vAng[3];
	GetVectorAngles(vVel, vAng);
	NormalizeVector(vVel, vVel);
	ScaleVector(vVel, vel);

	int flags = GetEntityFlags(client);
	SetEntityFlags(client, (flags & ~FL_FROZEN) & ~FL_ONGROUND);
	TeleportEntity(client, NULL_VECTOR, vAng, vVel);
	SetEntityFlags(client, flags);
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

			fClosestDistance = fTargetDistance;
			iClosestTarget = i;
		}
	}
	
	return iClosestTarget;
}

// left4dhooks api------------------

#if FIXFLY
	// 避免charger仰角携带玩家冲出地图外 (from umlka AI_HardSI/ai_charger.sp)
	public void L4D2_OnStartCarryingVictim_Post(int victim, int attacker) {
		if (GetEntPropEnt(attacker, Prop_Send, "m_carryVictim") != -1) {
			DataPack dPack = new DataPack();
			dPack.WriteCell(GetClientUserId(victim));
			dPack.WriteCell(GetClientUserId(attacker));
			RequestFrame(NextFrame_SetVelocity, dPack);
		}
	}

	void NextFrame_SetVelocity(DataPack dPack) {
		dPack.Reset();
		int victim = dPack.ReadCell();
		int attacker = dPack.ReadCell();
		delete dPack;

		victim = GetClientOfUserId(victim);
		if (!victim || !IsClientInGame(victim))
			return;

		attacker = GetClientOfUserId(attacker);
		if (!attacker || !IsClientInGame(attacker))
			return;

		if (GetEntPropEnt(attacker, Prop_Send, "m_carryVictim") == -1)
			return;

		if (GetEntPropEnt(attacker, Prop_Send, "m_pummelVictim") != -1)
			return;

		float vVel[3];
		GetEntPropVector(attacker, Prop_Data, "m_vecVelocity", vVel);

		TeleportEntity(attacker, NULL_VECTOR, NULL_VECTOR, vVel);
	}
#endif
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION 	"2.6a"
#define CVAR_FLAGS		FCVAR_NOTIFY
#define GAMEDATA		"l4d2_doorlock"
#define SOUND_COUNTDOWN "buttons/blip1.wav"
#define SOUND_MOVEOUT 	"ui/survival_teamrec.wav"
#define SOUND_BREAK1	"physics/metal/metal_box_break1.wav"
#define SOUND_BREAK2	"physics/metal/metal_box_break2.wav"

Handle
	g_hTimer,
	g_hSDK_IsCheckpointDoor,
	g_hSDK_IsCheckpointExitDoor;

ConVar
	g_hSbStop,
	g_hNbStop,
	g_hAllow,
	g_hGameMode,
	g_hModes,
	g_hModesOff,
	g_hModesTog,
	g_hFreezeNodoor,
	g_hDisplayMode,
	g_hBreakTheDoor,
	g_hPrepareTime1r,
	g_hPrepareTime2r,
	g_hClientTimeOut,
	g_hDisplayPanel;

bool
	g_bCvarAllow,
	g_bMapStarted,
	g_bIsFirstRound,
	g_bFreezeAllowed,
	g_bFreezeNodoor,
	g_bBreakTheDoor,
	g_bIsClientLoading[MAXPLAYERS + 1];

int
	g_iStartDoor,
	g_iCountDown,
	g_iRoundStart,
	g_iPlayerSpawn,
	g_iPrepareTime1r,
	g_iPrepareTime2r,
	g_iClientTimeOut,
	g_iDisplayPanel,
	g_iDisplayMode,
	g_iClientTimeout[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "L4D2 Door Lock",
	author = "Glide Loading",
	description = "Saferoom Door locked until all players loaded and infected are ready to spawn",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showpost.php?p=1373587&postcount=136"
};

public void OnPluginStart()
{
	vInitGameData();
	LoadTranslations("doorlock.phrases");

	CreateConVar("l4d2_dlock_version", PLUGIN_VERSION, "Plugin version", FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_REPLICATED);

	g_hAllow = CreateConVar("l4d2_dlock_allow", "1", "0=Plugin off, 1=Plugin on.", CVAR_FLAGS);
	g_hModes = CreateConVar("l4d2_dlock_modes", "", "Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS);
	g_hModesOff = CreateConVar("l4d2_dlock_modes_off", "", "Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS);
	g_hModesTog = CreateConVar("l4d2_dlock_modes_tog", "0", "Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS);
	g_hFreezeNodoor = CreateConVar("l4d2_dlock_freezenodoor", "1", "Freeze survivors if start saferoom door is absent");
	g_hPrepareTime1r = CreateConVar("l4d2_dlock_prepare1st", "7", "How many seconds plugin will wait after all clients have loaded before starting first round on a map", CVAR_FLAGS);
	g_hPrepareTime2r = CreateConVar("l4d2_dlock_prepare2nd", "7", "How many seconds plugin will wait after all clients have loaded before starting second round on a map", CVAR_FLAGS);
	g_hClientTimeOut = CreateConVar("l4d2_dlock_timeout", "45", "How many seconds plugin will wait after a map starts before giving up on waiting for a client", CVAR_FLAGS);
	g_hBreakTheDoor = CreateConVar("l4d2_dlock_weakdoor", "1", "Saferoom door will be breaked, once opened.", CVAR_FLAGS);
	g_hDisplayPanel = CreateConVar("l4d2_dlock_displaypanel", "2", "Display players state panel. 0-disabled, 1-hide failed, 2-full info", CVAR_FLAGS);
	g_hDisplayMode = CreateConVar("l4d2_dlock_displaymode", "1", "Set the display mode for the countdown. (0-off,1-hint, 2-center, 3-chat. any other value to hide countdown)", CVAR_FLAGS);

	g_hSbStop = FindConVar("sb_stop");
	g_hNbStop = FindConVar("nb_stop");
	g_hGameMode = FindConVar("mp_gamemode");
	g_hGameMode.AddChangeHook(vConVarChanged_Allow);
	g_hModes.AddChangeHook(vConVarChanged_Allow);
	g_hModesOff.AddChangeHook(vConVarChanged_Allow);
	g_hModesTog.AddChangeHook(vConVarChanged_Allow);
	g_hAllow.AddChangeHook(vConVarChanged_Allow);
	
	g_hFreezeNodoor.AddChangeHook(vConVarChanged_General);
	g_hPrepareTime1r.AddChangeHook(vConVarChanged_General);
	g_hPrepareTime2r.AddChangeHook(vConVarChanged_General);
	g_hClientTimeOut.AddChangeHook(vConVarChanged_General);
	g_hBreakTheDoor.AddChangeHook(vConVarChanged_General);
	g_hDisplayPanel.AddChangeHook(vConVarChanged_General);
	g_hDisplayMode.AddChangeHook(vConVarChanged_General);

	//AutoExecConfig(true, "l4d2_doorlock");
}

public void OnConfigsExecuted()
{
	vIsAllowed();
}

void vConVarChanged_Allow(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vIsAllowed();
}

void vConVarChanged_General(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetCvars();
}

void vGetCvars()
{
	bool bLast = g_bBreakTheDoor;

	g_bFreezeNodoor = g_hFreezeNodoor.BoolValue;
	g_iPrepareTime1r = g_hPrepareTime1r.IntValue;
	g_iPrepareTime2r = g_hPrepareTime2r.IntValue;
	g_iClientTimeOut = g_hClientTimeOut.IntValue;
	g_bBreakTheDoor = g_hBreakTheDoor.BoolValue;
	g_iDisplayPanel = g_hDisplayPanel.IntValue;
	g_iDisplayMode = g_hDisplayMode.IntValue;

	if (bLast != g_bBreakTheDoor) {
		if (bIsValidEntRef(g_iStartDoor))
			UnhookSingleEntityOutput(g_iStartDoor, "OnOpen", OnOpen);

		vInitPlugin();
	}
}

//Silvers
void vIsAllowed()
{
	bool bCvarAllow = g_hAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	vGetCvars();

	if (g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true) {
		g_bCvarAllow = true;
		vInitPlugin();
		HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
		HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
		//HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_PostNoCopy);
		HookEvent("player_team", Event_PlayerTeam);
	}
	else if (g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false)) {
		g_bCvarAllow = false;
		UnhookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
		UnhookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
		//UnhookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_PostNoCopy);
		UnhookEvent("player_team", Event_PlayerTeam);
	
		vResetPlugin();
		delete g_hTimer;
		vUnFreezeBots();
		vUnFreezePlayers();

		if (bIsValidEntRef(g_iStartDoor))
			UnhookSingleEntityOutput(g_iStartDoor, "OnOpen", OnOpen);
	}
}

int g_iCurrentMode;
bool IsAllowedGameMode()
{
	if (!g_hGameMode)
		return false;

	int iCvarModesTog = g_hModesTog.IntValue;
	if (iCvarModesTog != 0) {
		if (g_bMapStarted == false)
			return false;

		g_iCurrentMode = 0;

		int entity = CreateEntityByName("info_gamemode");
		if (IsValidEntity(entity)) {
			DispatchSpawn(entity);
			HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
			ActivateEntity(entity);
			AcceptEntityInput(entity, "PostSpawnActivate");
			if (IsValidEntity(entity)) // Because sometimes "PostSpawnActivate" seems to kill the ent.
				RemoveEdict(entity); // Because multiple plugins creating at once, avoid too many duplicate ents in the same frame
		}

		if (g_iCurrentMode == 0)
			return false;

		if (!(iCvarModesTog & g_iCurrentMode))
			return false;
	}

	char sGameModes[64], sGameMode[64];
	g_hGameMode.GetString(sGameMode, sizeof(sGameMode));
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);

	g_hModes.GetString(sGameModes, sizeof(sGameModes));
	if (sGameModes[0]) {
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if (StrContains(sGameModes, sGameMode, false) == -1)
			return false;
	}

	g_hModesOff.GetString(sGameModes, sizeof(sGameModes));
	if (sGameModes[0]) {
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if (StrContains(sGameModes, sGameMode, false) != -1)
			return false;
	}

	return true;
}

void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	if (strcmp(output, "OnCoop") == 0)
		g_iCurrentMode = 1;
	else if (strcmp(output, "OnSurvival") == 0)
		g_iCurrentMode = 2;
	else if (strcmp(output, "OnVersus") == 0)
		g_iCurrentMode = 4;
	else if (strcmp(output, "OnScavenge") == 0)
		g_iCurrentMode = 8;
}

public Action OnPlayerRunCmd(int client)
{
	if (!g_iCountDown || !g_bFreezeAllowed)
		return Plugin_Continue;

	if (GetClientTeam(client) == 2)
		SetEntityMoveType(client, MOVETYPE_NONE);
		
	return Plugin_Continue;
}

public void OnClientDisconnect(int client)
{
	g_iClientTimeout[client] = 0;
	g_bIsClientLoading[client] = false;
}

public void OnMapStart()
{
	g_bMapStarted = true;
	g_bIsFirstRound = true;

	PrecacheSound(SOUND_BREAK1);
	PrecacheSound(SOUND_BREAK2);
	PrecacheSound(SOUND_MOVEOUT);
	PrecacheSound(SOUND_COUNTDOWN);
}

public void OnMapEnd()
{
	vResetPlugin();
	g_bMapStarted = false;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	vResetPlugin();
	g_bIsFirstRound = false;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	int m_spawnflags;
	int entity = MaxClients + 1;
	while ((entity = FindEntityByClassname(entity, "prop_door_rotating_checkpoint")) != INVALID_ENT_REFERENCE) 
	{
		if (GetEntProp(entity, Prop_Send, "m_bLocked") != 1)
			continue;

		m_spawnflags = GetEntProp(entity, Prop_Data, "m_spawnflags");
		if (m_spawnflags & 8192 == 0 || m_spawnflags & 32768 != 0)
			continue;

		if (!SDKCall(g_hSDK_IsCheckpointDoor, entity))
			continue;

		if (!SDKCall(g_hSDK_IsCheckpointExitDoor, entity))
			continue;

		g_iStartDoor = EntIndexToEntRef(entity);
		if (!g_bBreakTheDoor) {
			SetVariantString("OnOpen !self:Lock::0.0:-1");
			AcceptEntityInput(entity, "AddOutput");
		}
		else
			HookSingleEntityOutput(entity, "OnOpen", OnOpen);

		break;
	}
	vStartSequence();
}

void vResetPlugin()
{
	g_iCountDown = 0;
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	g_bFreezeAllowed = false;

	delete g_hTimer;

	for (int i = 1; i <= MaxClients; i++)
		vResetLoading(i);
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_iCountDown)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client && IsClientInGame(client) && !IsFakeClient(client))
		vResetLoading(client);
}

void vResetLoading(int client)
{
	g_iClientTimeout[client] = 0;
	g_bIsClientLoading[client] = false;
}

void vStartSequence()
{
	delete g_hTimer;
	g_iCountDown = -1;
	g_bFreezeAllowed = true;
	g_hNbStop.SetInt(1); // 没有安全门则连同僵尸特感一起定住
	g_hTimer = CreateTimer(1.0, tmrLoading, _, TIMER_REPEAT);
}

Action tmrLoading(Handle timer)
{
	if (g_iCountDown >= 0) {
		if (g_iCountDown >= (g_bIsFirstRound ? g_iPrepareTime1r : g_iPrepareTime2r)) {
			g_iCountDown = 0;

			vUnLockDoor();

			if (!g_bFreezeAllowed)
				vUnFreezeBots();
			else
				vUnFreezePlayers();

			vPlaySound(SOUND_MOVEOUT);
			vPrintTextAll("%t", "DL_Moveout");

			g_hTimer = null;
			return Plugin_Stop;
		}
		else {
			vPlaySound(SOUND_COUNTDOWN);

			if (!g_bFreezeAllowed)
				vPrintTextAll("%t", "DL_Locked", (g_bIsFirstRound ? g_iPrepareTime1r : g_iPrepareTime2r) - g_iCountDown);
			else
				vPrintTextAll("%t", "DL_Frozen", (g_bIsFirstRound ? g_iPrepareTime1r : g_iPrepareTime2r) - g_iCountDown);

			g_iCountDown++;
		}
	}
	else
		g_iCountDown = bIsFinishedLoading() ? 0 : -1;

	return Plugin_Continue;
}

void vLoadingPanel()
{
	int i;
	int iLoading;
	int iConnected;
	int iLoadFailed;
	for (i = 1; i <= MaxClients; i++) {
		if (IsClientConnected(i) && !IsFakeClient(i)) {
			if (g_bIsClientLoading[i])
				iLoading++;
			else if (g_iClientTimeout[i] >= g_iClientTimeOut)
				iLoadFailed++;
			else 
				iConnected++;
		}
	}

	Panel panel;
	char sStrings[254];

	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client) && !IsFakeClient(client)) {
			panel = new Panel();

			SetGlobalTransTarget(client);
			FormatEx(sStrings, sizeof(sStrings), "%t", "DL_Menu_Header");
			panel.DrawText(sStrings);

			if (iLoading) {
				FormatEx(sStrings, sizeof(sStrings), "%t", "DL_Menu_Connecting");
				panel.DrawText(sStrings);

				iLoading = 0;
				for (i = 1; i <= MaxClients; i++) {
					if (IsClientConnected(i) && !IsFakeClient(i) && g_bIsClientLoading[i]) {
						iLoading++;
						FormatEx(sStrings, sizeof(sStrings), "->%d. %N", iLoading, i);
						panel.DrawText(sStrings);
					}
				}
			}

			if (iConnected) {
				FormatEx(sStrings, sizeof(sStrings), "%t", "DL_Menu_Ingame");
				panel.DrawText(sStrings);

				iConnected = 0;
				for (i = 1; i <= MaxClients; i++) {
					if (IsClientConnected(i) && !IsFakeClient(i) && !g_bIsClientLoading[i] && g_iClientTimeout[i] < g_iClientTimeOut) {
						iConnected++;
						FormatEx(sStrings, sizeof(sStrings), "->%d. %N", iConnected, i);
						panel.DrawText(sStrings);
					}
				}
			}

			if (g_iDisplayPanel > 1) {
				if (iLoadFailed) {
					FormatEx(sStrings, sizeof(sStrings), "%t", "DL_Menu_Fail");
					panel.DrawText(sStrings);

					iLoadFailed = 0;
					for (i = 1; i <= MaxClients; i++) {
						if (IsClientConnected(i) && !IsFakeClient(i) && !g_bIsClientLoading[i] && g_iClientTimeout[i] >= g_iClientTimeOut) {
							iLoadFailed++;
							FormatEx(sStrings, sizeof(sStrings), "->%d. %N", iLoadFailed, i);
							panel.DrawText(sStrings);
						}
					}
				}
			}

			panel.Send(client, iPanelHandler, 5);
			delete panel;
		}
	}
}

int iPanelHandler(Menu menu, MenuAction action, int param1, int param2)
{
	return 0;
}

void vLockDoor()
{
	SetEntProp(g_iStartDoor, Prop_Send, "m_spawnflags", 36864);
}

void vUnLockDoor()
{
	if (bIsValidEntRef(g_iStartDoor))
		SetEntProp(g_iStartDoor, Prop_Send, "m_spawnflags", 8192);
}

void vFreezeBots()
{
	g_hSbStop.SetInt(1);
}

void vUnFreezeBots()
{
	g_hSbStop.SetInt(0);
}

void vUnFreezePlayers()
{
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetEntityMoveType(i) == MOVETYPE_NONE) {
			SetEntityMoveType(i, MOVETYPE_WALK);
		}
	}

	g_hNbStop.SetInt(0);
}

void vInitPlugin()
{
	if(bHasAnySurvivorLeftSafeArea())
		return;

	if(g_hTimer || g_iCountDown || bIsValidEntRef(g_iStartDoor))
		return;

	g_iStartDoor = 0;

	
}


bool bHasAnySurvivorLeftSafeArea()
{
	int entity = GetPlayerResourceEntity();
	if (entity == INVALID_ENT_REFERENCE)
		return false;

	return !!GetEntProp(entity, Prop_Send, "m_hasAnySurvivorLeftSafeArea");
}

//https://forums.alliedmods.net/showthread.php?p=2700212
void OnOpen(const char[] output, int entity, int activator, float delay)
{
	char sModel[PLATFORM_MAX_PATH];
	GetEntPropString(entity, Prop_Data, "m_ModelName", sModel, sizeof(sModel));

	float vPos[3], vAng[3], vDir[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPos);
	GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);
	// GetEntPropVector(entity, Prop_Data, "m_angRotationOpenForward", vDir);

	// Make old door non-solid, so physics door does not collide and stutter
	// Collison group fixes "in solid list (not solid)"
	SetEntProp(entity, Prop_Send, "m_CollisionGroup", 1);
	SetEntProp(entity, Prop_Data, "m_CollisionGroup", 1);

	// Teleport up to prevent using and door shadow showing. Must stay alive or L4D1 crashes.
	vPos[2] += 10000.0;
	TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
	vPos[2] -= 10000.0;

	// Hide old door
	SetEntityRenderMode(entity, RENDER_TRANSALPHA);
	SetEntityRenderColor(entity, 0, 0, 0, 0);

	UnhookSingleEntityOutput(entity, "OnOpen", OnOpen);

	// Create new physics door
	int door = CreateEntityByName("prop_physics");
	DispatchKeyValue(door, "spawnflags", "4"); // Prevent collision - make non-solid
	DispatchKeyValue(door, "model", sModel);
	DispatchSpawn(door);

	// Teleport to current door, ready to take it's attachments
	TeleportEntity(door, vPos, vAng, NULL_VECTOR);

	// Handle fall animation from old door
	SetVariantString("unlock");
	AcceptEntityInput(entity, "SetAnimation");

	SetEntProp(entity, Prop_Send, "m_spawnflags", 36864); // Prevent +USE + Door silent

	// Wait for handle to fall (does not work for wooden handle - Last Stand: TODO FIXME) - deleting crashes in L4D1 so keeping it alive.
	// SetVariantString("OnUser4 !self:Kill::1.0:1");
	// AcceptEntityInput(entity, "AddOutput");
	// AcceptEntityInput(entity, "FireUser4");

	// Find attachments, swap to our new door
	entity = EntRefToEntIndex(entity);

	for (int att = 0; att < 2048; att++) {
		if (IsValidEdict(att)) {
			if (HasEntProp(att, Prop_Send, "moveparent") && GetEntPropEnt(att, Prop_Send, "moveparent") == entity) {
				SetVariantString("!activator");
				AcceptEntityInput(att, "SetParent", door);
			}
		}
	}

	// Tilt ang away
	GetAngleVectors(vAng, vDir, NULL_VECTOR, NULL_VECTOR);

	float dist = strcmp(sModel, "models/props_doors/checkpoint_door_-01.mdl") == 0 ? -10.0 : 10.0;

	vPos[0] += (vDir[0] * dist);
	vPos[1] += (vDir[1] * dist);
	vAng[0] = dist;
	vDir[0] = 0.0;
	vDir[1] = vAng[1] < 270.0 ? 10.0 : -10.0 * dist;
	vDir[2] = 0.0;

	TeleportEntity(door, vPos, vAng, vDir);

	EmitSoundToAll(GetRandomInt(0, 1) ? SOUND_BREAK1 : SOUND_BREAK2, door);
}

bool bIsAnyClientLoading()
{
	for (int i = 1; i <= MaxClients; i++) {
		if (g_bIsClientLoading[i])
			return true;
	}
	return false;
}

bool bIsFinishedLoading()
{
	for (int i = 1; i <= MaxClients; i++)
		g_bIsClientLoading[i] = IsClientConnected(i) && !IsClientInGame(i) && !IsFakeClient(i) && ++g_iClientTimeout[i] < g_iClientTimeOut;

	if (g_iDisplayPanel > 0 && g_bIsFirstRound)
		vLoadingPanel();

	return !bIsAnyClientLoading();
}

void vPrintTextAll(const char[] format, any ...)
{
	char buffer[254];

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i)) {
			SetGlobalTransTarget(i);
			VFormat(buffer, sizeof(buffer), format, 2);
			switch (g_iDisplayMode) {
				case 1:
					PrintHintText(i, "%s", buffer);
				case 2:
					PrintCenterText(i, "%s", buffer);
				case 3:
					PrintToChat(i, "%s", buffer);
			}
		}
	}
}

bool bIsValidEntRef(int entity)
{
	return entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE;
}

void vPlaySound(const char[] sSound)
{
	EmitSoundToAll(sSound, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
}

void vInitGameData()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(sPath))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	StartPrepSDKCall(SDKCall_Entity);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CPropDoorRotatingCheckpoint::IsCheckpointDoor"))
		SetFailState("Failed to find offset: \"CPropDoorRotatingCheckpoint::IsCheckpointDoor\"");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	if (!(g_hSDK_IsCheckpointDoor = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"CPropDoorRotatingCheckpoint::IsCheckpointDoor\"");

	StartPrepSDKCall(SDKCall_Entity);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CPropDoorRotatingCheckpoint::IsCheckpointExitDoor"))
		SetFailState("Failed to find offset: \"CPropDoorRotatingCheckpoint::IsCheckpointExitDoor\"");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	if (!(g_hSDK_IsCheckpointExitDoor = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"CPropDoorRotatingCheckpoint::IsCheckpointExitDoor\"");

	delete hGameData;
}

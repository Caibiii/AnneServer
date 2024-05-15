#pragma semicolon 1
#pragma tabsize 0
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#undef REQUIRE_PLUGIN
#define CVAR_FLAG FCVAR_NOTIFY
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

//********************************************************************************//
#define MODEL_SMOKER "models/infected/smoker.mdl"
#define MODEL_BOOMER "models/infected/boomer.mdl"
#define MODEL_HUNTER "models/infected/hunter.mdl"
#define MODEL_SPITTER "models/infected/spitter.mdl"
#define MODEL_JOCKEY "models/infected/jockey.mdl"
#define MODEL_CHARGER "models/infected/charger.mdl"
#define GAMEDATA "spawn_infected_nolimit"
Handle hConf = null;
static Handle hCreateSmoker = null;
#define NAME_CreateSmoker "NextBotCreatePlayerBot<Smoker>"
#define SIG_CreateSmoker_LINUX "@_Z22NextBotCreatePlayerBotI6SmokerEPT_PKc"
#define SIG_CreateSmoker_WINDOWS "\\x55\\x8B\\x2A\\x83\\x2A\\x2A\\xA1\\x2A\\x2A\\x2A\\x2A\\x33\\x2A\\x89\\x2A\\x2A\\x56\\x57\\x8B\\x2A\\x2A\\x68\\x10"
static Handle hCreateBoomer = null;
#define NAME_CreateBoomer "NextBotCreatePlayerBot<Boomer>"
#define SIG_CreateBoomer_LINUX "@_Z22NextBotCreatePlayerBotI6BoomerEPT_PKc"
#define SIG_CreateBoomer_WINDOWS "\\x55\\x8B\\x2A\\x83\\x2A\\x2A\\xA1\\x2A\\x2A\\x2A\\x2A\\x33\\x2A\\x89\\x2A\\x2A\\x56\\x57\\x8B\\x2A\\x2A\\x68\\x30"
static Handle hCreateHunter = null;
#define NAME_CreateHunter "NextBotCreatePlayerBot<Hunter>"
#define SIG_CreateHunter_LINUX "@_Z22NextBotCreatePlayerBotI6HunterEPT_PKc"
#define SIG_CreateHunter_WINDOWS "\\x55\\x8B\\x2A\\x83\\x2A\\x2A\\xA1\\x2A\\x2A\\x2A\\x2A\\x33\\x2A\\x89\\x2A\\x2A\\x56\\x57\\x8B\\x2A\\x2A\\x68\\xD0"
static Handle hCreateSpitter = null;
#define NAME_CreateSpitter "NextBotCreatePlayerBot<Spitter>"
#define SIG_CreateSpitter_LINUX "@_Z22NextBotCreatePlayerBotI7SpitterEPT_PKc"
#define SIG_CreateSpitter_WINDOWS "\\x55\\x8B\\x2A\\x83\\x2A\\x2A\\xA1\\x2A\\x2A\\x2A\\x2A\\x33\\x2A\\x89\\x2A\\x2A\\x56\\x57\\x8B\\x2A\\x2A\\x68\\x00"
static Handle hCreateJockey = null;
#define NAME_CreateJockey "NextBotCreatePlayerBot<Jockey>"
#define SIG_CreateJockey_LINUX "@_Z22NextBotCreatePlayerBotI6JockeyEPT_PKc"
#define SIG_CreateJockey_WINDOWS "\\x55\\x8B\\x2A\\x83\\x2A\\x2A\\xA1\\x2A\\x2A\\x2A\\x2A\\x33\\x2A\\x89\\x2A\\x2A\\x56\\x57\\x8B\\x2A\\x2A\\x68\\x70\\x90"
static Handle hCreateCharger = null;
#define NAME_CreateCharger "NextBotCreatePlayerBot<Charger>"
#define SIG_CreateCharger_LINUX "@_Z22NextBotCreatePlayerBotI7ChargerEPT_PKc"
#define SIG_CreateCharger_WINDOWS "\\x55\\x8B\\x2A\\x83\\x2A\\x2A\\xA1\\x2A\\x2A\\x2A\\x2A\\x33\\x2A\\x89\\x2A\\x2A\\x56\\x57\\x8B\\x2A\\x2A\\x68\\x40"
static Handle hCreateTank = null;
#define NAME_CreateTank "NextBotCreatePlayerBot<Tank>"
#define SIG_CreateTank_LINUX "@_Z22NextBotCreatePlayerBotI4TankEPT_PKc"
#define SIG_CreateTank_WINDOWS "\\x55\\x8B\\x2A\\x83\\x2A\\x2A\\xA1\\x2A\\x2A\\x2A\\x2A\\x33\\x2A\\x89\\x2A\\x2A\\x56\\x57\\x8B\\x2A\\x2A\\x68\\xF0"

#define SIG_L4D1CreateSmoker_WINDOWS "\\x83\\x2A\\x2A\\x56\\x57\\x68\\x20\\xED"
#define SIG_L4D1CreateBoomer_WINDOWS "\\x83\\x2A\\x2A\\x56\\x57\\x68\\x10"
#define SIG_L4D1CreateHunter_WINDOWS "\\x83\\x2A\\x2A\\x56\\x57\\x68\\x20\\x35"
#define SIG_L4D1CreateTank_WINDOWS "\\x83\\x2A\\x2A\\x56\\x57\\x68\\x80"

static Handle hInfectedAttackSurvivorTeam = null;
#define NAME_InfectedAttackSurvivorTeam "Infected::AttackSurvivorTeam"
#define SIG_InfectedAttackSurvivorTeam_LINUX "@_ZN8Infected18AttackSurvivorTeamEv"
#define SIG_InfectedAttackSurvivorTeam_WINDOWS "\\x56\\x2A\\x2A\\x2A\\x2A\\xE1\\x1C"
#define SIG_L4D1InfectedAttackSurvivorTeam_WINDOWS "\\x80\\xB9\\x99"
//********************************************************************************//

public Plugin myinfo = 
{
	name 			= "AnneServer InfectedSpawn",
	author 			= "Caibiii",
	description 	= "AnneServer InfectedSpawn",
	version 		= "2021-7-7",
	url 			= "https://github.com/Caibiii/AnneServer"
}

ConVar 
	g_hSiLimit,
	g_hSiInterval;	
int 
	g_iSiLimit,
	g_iTeleCount[MAXPLAYERS + 1] = {0},
	g_iTargetSurvivor = -1, 
	g_iTeleportIndex = 0,
	g_iSpawnMaxCount = 0;
float 
	g_fSpawnDistance,
	g_fTeleportDistance,
	g_fSiInterval,
	g_LastPosition[MAXPLAYERS + 1][3];
	//g_lastMoveTime[MAXPLAYERS + 1];
bool 
	LeftSafeArea =false,
	g_bIsLate = false;
Handle 
	g_hTeleHandle = INVALID_HANDLE;
ArrayList 
	NearSpawnAreas,
	hereProximates;
DataPack
	hPack;
public void OnPluginStart()
{
	GetGamedata();
	g_hSiLimit = CreateConVar("l4d_infected_limit", "6", "一次刷出多少特感", CVAR_FLAG, true, 0.0);
	g_hSiInterval = CreateConVar("versus_special_respawn_interval", "16.0", "对抗模式下刷特时间控制", CVAR_FLAG, true, 0.0);
	HookEvent("player_death", evt_PlayerDeath, EventHookMode_PostNoCopy);
	HookEvent("round_start", evt_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("finale_win", evt_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", evt_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", evt_RoundEnd, EventHookMode_PostNoCopy);
	g_hSiInterval.AddChangeHook(ConVarChanged_Cvars);
	g_hSiLimit.AddChangeHook(MaxPlayerZombiesChanged_Cvars);
	GetCvars();
	RegAdminCmd("sm_startspawn", Cmd_StartSpawn, ADMFLAG_ROOT, "管理员重置刷特时钟");
}

public void OnGameFrame()
{
	if((g_iTeleportIndex <  1 && g_iSpawnMaxCount < 1))
	{
		g_iTeleportIndex = 0; g_iSpawnMaxCount = 0;
	}
	else if(g_iTeleportIndex > 0)
	{
		if(MaxSpecials() >= g_iSiLimit)
		{
			g_iTeleportIndex = 0; g_iSpawnMaxCount = 0;
		}
		else
		{
			g_fTeleportDistance += 20.0;
			if(g_fTeleportDistance > 800.0)
			{
				g_fTeleportDistance = 800.0;
			}
			float fSpawnPos[3];
			if(GetSpawnPos(fSpawnPos, g_iTargetSurvivor, true))	
			{
				g_fTeleportDistance = 500.0;
				g_iTeleportIndex -= 1;
				hPack = new DataPack();
				hPack.WriteFloat(fSpawnPos[0]); hPack.WriteFloat(fSpawnPos[1]); hPack.WriteFloat(fSpawnPos[2]);
				RequestFrame(SpawnInfected, hPack);  //存储坐标转到下一帧去生成特感
			}
		}
	}
	else if(g_bIsLate && g_iSpawnMaxCount > 0)
	{
		if(MaxSpecials() >= g_iSiLimit)
		{
			g_iTeleportIndex = 0; g_iSpawnMaxCount = 0;
		}
		else
		{
			g_fSpawnDistance += 20.0;
			if(g_fSpawnDistance > 800.0)
			{
				g_fSpawnDistance = 800.0;
			}
			float fSpawnPos[3];
			if(GetSpawnPos(fSpawnPos, g_iTargetSurvivor))	
			{
				g_fSpawnDistance = 500.0;
				g_iSpawnMaxCount -= 1;
				hPack = new DataPack();
				hPack.WriteFloat(fSpawnPos[0]); hPack.WriteFloat(fSpawnPos[1]); hPack.WriteFloat(fSpawnPos[2]);
				RequestFrame(SpawnInfected, hPack); //存储坐标转到下一帧去生成特感
				
			}
		}
	}		
}


stock bool GetSpawnPos(float fSpawnPos[3], int TargetSurvivor, bool IsTeleport = false)
{
    if(IsValidSurvivor(TargetSurvivor))
	{
		float AreaSize[3], X_Min, X_Max, Y_Min, Y_Max;
		float distance;
		if(IsTeleport)
		{
			distance = g_fTeleportDistance * 1.5;
		}
		else
		{
			distance = g_fSpawnDistance * 1.5;
		}
		Address fSpawnPosArea;
        static int LengthCount;
		int index;
        while(PlayerVisibleToSDK(fSpawnPos,fSpawnPosArea) || IsPlayerStuck(fSpawnPos) || !NavAreaBuildPath(fSpawnPosArea, LengthCount, distance))
        {
			LengthCount++;
			if(LengthCount >= NearSpawnAreas.Length )
			{
				LengthCount = 0;
				return false;
			} 
			index = LengthCount - 1;
			fSpawnPosArea = NearSpawnAreas.Get(index);
			L4D_GetNavAreaCenter(fSpawnPosArea, fSpawnPos);
			L4D_GetNavAreaSize(fSpawnPosArea, AreaSize);
			X_Min = fSpawnPos[0] - AreaSize[0] * 0.5; X_Max = fSpawnPos[0] + AreaSize[0] * 0.5;
			Y_Min = fSpawnPos[1] - AreaSize[1] * 0.5; Y_Max = fSpawnPos[1] + AreaSize[1] * 0.5;
			fSpawnPos[0] = GetRandomFloat(X_Min, X_Max); fSpawnPos[1] = GetRandomFloat(Y_Min, Y_Max);
			if(AreaSize[2] < 0.0 )
			{
				fSpawnPos[2] = fSpawnPos[2] - AreaSize[2] * 0.5;
			}
			else
			{
				fSpawnPos[2] = fSpawnPos[2] + AreaSize[2] * 0.5;
			}
        }
        return true;
    }
    return false;
}
//检查特感NAV流动距离，全插件性能开销第二大，不能放任一直大量使用，不然服务器会爆红SV和VAR，需要增加上限次数限制
stock bool NavAreaBuildPath(Address fSpawnPosArea, int LengthCount, float dist)
{
	float fSurvivorPos[3];
	Address fSurvivorPosArea;
	if(dist < 1000.0)
	{
		if (IsValidSurvivor(g_iTargetSurvivor) && IsPlayerAlive(g_iTargetSurvivor))
		{
			GetClientAbsOrigin(g_iTargetSurvivor, fSurvivorPos);
			fSurvivorPosArea = L4D_GetNearestNavArea(fSurvivorPos, 120.0, true, false, false, 3);
			if(L4D2_NavAreaBuildPath(fSpawnPosArea, fSurvivorPosArea, dist, 3, true))
			{
				int index = LengthCount - 1;
				//PrintToChatAll("当前距离为%f", dist);
				NearSpawnAreas.Erase(index);
				return true;
			}
		}
	}
	else if(g_bIsLate) 	//当前情况刷特困难，暂停刷特让服务器缓缓
	{
		g_bIsLate = false;
		CreateTimer(1.0, Timer_g_bIsLate);
	}
	return false;
}

void SpawnInfected(DataPack fSpawnPos_Pack)
{
	float fSpawnPos[3];
	fSpawnPos_Pack.Reset();
	fSpawnPos[0] = fSpawnPos_Pack.ReadFloat(); fSpawnPos[1] = fSpawnPos_Pack.ReadFloat(); fSpawnPos[2] = fSpawnPos_Pack.ReadFloat(); fSpawnPos[2] += 18.0;
	delete fSpawnPos_Pack;
	int spawnedClient, iZombieClass;
	iZombieClass = 3;
	switch (iZombieClass)
	{
		case 1:
		{
			spawnedClient = CreateInfected("smoker");
		}
		case 2:
		{
			spawnedClient = CreateInfected("boomer");
		}
		case 3:
		{
			spawnedClient = CreateInfected("hunter");
		}
		case 4:
		{
			spawnedClient = CreateInfected("spitter");
		}
		case 5:
		{
			spawnedClient = CreateInfected("jockey");
		}
		case 6:
		{
			spawnedClient = CreateInfected("charger");
		}
	}
	g_LastPosition[spawnedClient] = fSpawnPos;
	//g_lastMoveTime[spawnedClient] = GetGameTime();
	TeleportEntity(spawnedClient, fSpawnPos, NULL_VECTOR, NULL_VECTOR);
	g_iTeleCount[spawnedClient] = 0;
}

public Action Timer_g_bIsLate(Handle timer)
{
	g_fSpawnDistance = 500.0;
	g_fTeleportDistance = 500.0;
	g_bIsLate = true;
	return Plugin_Continue;
}

void FindNearbySpawnAreas()
{
	NearSpawnAreas = new ArrayList();
	float fSpawnPos[3], fSurvivorPos[3];
	int count = 0;
	while (count < hereProximates.Length)
	{
		L4D_GetNavAreaCenter(hereProximates.Get(count), fSpawnPos);
		if (IsValidSurvivor(g_iTargetSurvivor) && IsPlayerAlive(g_iTargetSurvivor))
		{
			GetClientAbsOrigin(g_iTargetSurvivor, fSurvivorPos);
			if (GetVectorDistance(fSpawnPos, fSurvivorPos) < 650.0)
			{
				PushArrayCell(NearSpawnAreas, hereProximates.Get(count));
			}
		}
		count++; 
	}
}

public Action Timer_PositionSi(Handle timer)
{
	if(g_bIsLate && g_iSpawnMaxCount < 1)
	{
		float NextSpawnTime = GetRandomFloat(g_fSiInterval * 1.2, g_fSiInterval * 1.5);
		CreateTimer(NextSpawnTime, SpawnNewInfected);
		g_bIsLate = false;
	}
	for (int client = 1; client <= MaxClients; client++)
	{
		if(IsInfectedBot(client) && IsPlayerAlive(client) && !IsPinningSomeone(client))
		{
			L4D_WarpToValidPositionIfStuck(client);
			float fSelfPos[3] = {0.0};
			GetClientAbsOrigin(client, fSelfPos);
			Address fSpawnPosArea = L4D_GetNearestNavArea(fSelfPos, 120.0, true, false, false, 3);
			if(!PlayerVisibleToSDK(fSelfPos,fSpawnPosArea) || GetVectorDistance(g_LastPosition[client], fSelfPos) < 30.0)
			{
				g_iTeleCount[client] += 10;
				if (g_iTeleCount[client] > 49)
				{
					FindNearbySpawnAreas();
					g_iTeleCount[client] = 0;
					KickClient(client);
					g_iTeleportIndex += 1;
					g_fTeleportDistance = 500.0;
				}
			}
			else
			{			
				g_iTeleCount[client] = 0;
			}
		}
		else
		{
			g_iTeleCount[client] = 0;
		}
	}
	return Plugin_Continue;
}

stock Action Cmd_StartSpawn(int client, int args)
{
	if (L4D_HasAnySurvivorLeftSafeArea())
	{
		ResetStatus();
		LeftSafeArea = true;
		g_bIsLate = true;
		hereProximates = new ArrayList();
		L4D_GetAllNavAreas(hereProximates);
		g_iTeleportIndex = 0;
		g_iSpawnMaxCount = 0;
		CreateTimer(0.1, SpawnNewInfected);
		g_hTeleHandle = CreateTimer(0.5, Timer_PositionSi, _, TIMER_REPEAT);
	}
	return Plugin_Handled;
}

public Action SpawnNewInfected(Handle timer)
{
	if(LeftSafeArea)
	{
		if(MaxSpecials() < g_iSiLimit)
		{
			FindNearbySpawnAreas();
		}
		RequestFrame(NextFrame);
	}
	return Plugin_Stop;
}

void NextFrame()
{
	g_iSpawnMaxCount = g_iSiLimit;
	g_fSpawnDistance = 500.0;
	g_bIsLate = true;
}

int MaxSpecials()
{
	int MaxSpecialCount = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsInfectedBot(client) && IsPlayerAlive(client))
		{
			MaxSpecialCount++;
		}
		if (IsValidSurvivor(client) && IsPlayerAlive(client))
		{
			g_iTargetSurvivor = client;
		}
	}
	return MaxSpecialCount;
}


void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void MaxPlayerZombiesChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iSiLimit = g_hSiLimit.IntValue;
}

void GetCvars()
{
	g_fSiInterval = g_hSiInterval.FloatValue;
	g_iSiLimit = g_hSiLimit.IntValue;
}

public void evt_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	InitStatus();
	CreateTimer(1.0, SafeRoomReset, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action SafeRoomReset(Handle timer)
{
	ResetStatus();
	return Plugin_Continue;
}
public void ResetStatus()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsInfectedBot(client) && IsPlayerAlive(client))
		{
			g_iTeleCount[client] = 0;
		}
		if (!L4D_HasAnySurvivorLeftSafeArea())
		{
			if(IsValidSurvivor(client) && !IsPlayerAlive(client))
			{
				L4D_RespawnPlayer(client);
			}
		}
	}
}

public void evt_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	InitStatus();
}

public void InitStatus()
{
	if (g_hTeleHandle != INVALID_HANDLE)
	{
		delete g_hTeleHandle;
		g_hTeleHandle = INVALID_HANDLE;
	}
	g_bIsLate = false;
	LeftSafeArea = false;
	g_iSpawnMaxCount = 0;
	g_iTeleportIndex = 0;
}

public void evt_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsInfectedBot(client))
	{
		g_iTeleCount[client] = 0;
		CreateTimer(0.3, Timer_KickBot, client);
	}	
}

public Action Timer_KickBot(Handle timer, int client)
{
	if (IsClientInGame(client) && !IsClientInKickQueue(client) && IsFakeClient(client))
	{
		KickClient(client);
	}
	return Plugin_Continue;
}

bool IsInfectedBot(int client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && IsFakeClient(client) && GetClientTeam(client) == TEAM_INFECTED && GetEntProp(client, Prop_Send, "m_zombieClass") <= 6 && GetEntProp(client, Prop_Send, "m_zombieClass") >=1)
	{
		return true;
	}
	else
	{
		return false;
	}
}

stock bool PlayerVisibleToSDK(float targetposition[3], Address fSpawnPosArea)
{
	float position[3];
	float distance;
	float fTargetPos[3];
	fTargetPos = targetposition;
	fTargetPos[2] += 45.0;
	if (IsClientInGame(g_iTargetSurvivor) && GetClientTeam(g_iTargetSurvivor) == 2 && IsPlayerAlive(g_iTargetSurvivor))
	{
		GetClientAbsOrigin(g_iTargetSurvivor, position);
		distance = GetVectorDistance(targetposition, position);
		if(distance < 300.0)
		{
			return true;
		}
		if(L4D2_IsVisibleToPlayer(g_iTargetSurvivor, 2, 3, fSpawnPosArea, fTargetPos))
		{
			return true;
		}
	}
	return false;
}

bool IsPinningSomeone(int client)
{
	bool bIsPinning = false;
	if (IsInfectedBot(client))
	{
		if (GetEntPropEnt(client, Prop_Send, "m_tongueVictim") > 0) bIsPinning = true;
		if (GetEntPropEnt(client, Prop_Send, "m_jockeyVictim") > 0) bIsPinning = true;
		if (GetEntPropEnt(client, Prop_Send, "m_pounceVictim") > 0) bIsPinning = true;
		if (GetEntPropEnt(client, Prop_Send, "m_pummelVictim") > 0) bIsPinning = true;
		if (GetEntPropEnt(client, Prop_Send, "m_carryVictim") > 0) bIsPinning = true;
	}
	return bIsPinning;
}

public Action L4D_OnGetScriptValueInt(const char[] key, int &retVal)
{
	if ((strcmp(key, "cm_ShouldHurry", false) == 0) || (strcmp(key, "cm_AggressiveSpecials", false) == 0) && retVal != 1)
	{
		retVal = 1;
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

//********************************************************************************//
//********************************************************************************//
//********************************************************************************//
//********************************************************************************//
public void OnMapStart()
{
	InitStatus();
	CheckandPrecacheModel(MODEL_SMOKER);
	CheckandPrecacheModel(MODEL_BOOMER);
	CheckandPrecacheModel(MODEL_HUNTER);
	CheckandPrecacheModel(MODEL_SPITTER);
	CheckandPrecacheModel(MODEL_JOCKEY);
	CheckandPrecacheModel(MODEL_CHARGER);
}

void CheckandPrecacheModel(const char[] model)
{
	if (!IsModelPrecached(model))
	{
		PrecacheModel(model, true);
	}
}

int CreateInfected(const char[] zomb)
{
	int bot = -1;
	if (StrEqual(zomb, "smoker", false))
	{
		bot = SDKCall(hCreateSmoker, "Smoker");
		if (ValidClient(bot)) SetEntityModel(bot, MODEL_SMOKER);
	}
	else if (StrEqual(zomb, "boomer", false))
	{
		bot = SDKCall(hCreateBoomer, "Boomer");
		if (ValidClient(bot)) SetEntityModel(bot, MODEL_BOOMER);
	}
	else if (StrEqual(zomb, "hunter", false))
	{
		bot = SDKCall(hCreateHunter, "Hunter");
		if (ValidClient(bot)) SetEntityModel(bot, MODEL_HUNTER);
	}
	else if (StrEqual(zomb, "spitter", false))
	{
		bot = SDKCall(hCreateSpitter, "Spitter");
		if (ValidClient(bot)) SetEntityModel(bot, MODEL_SPITTER);
	}
	else if (StrEqual(zomb, "jockey", false))
	{
		bot = SDKCall(hCreateJockey, "Jockey");
		if (ValidClient(bot)) SetEntityModel(bot, MODEL_JOCKEY);
	}
	else if (StrEqual(zomb, "charger", false))
	{
		bot = SDKCall(hCreateCharger, "Charger");
		if (ValidClient(bot)) SetEntityModel(bot, MODEL_CHARGER);
	}
	if (ValidClient(bot))
	{
		ChangeClientTeam(bot, 3);
		//SDKCall(hRoundRespawn, bot);
		//SetEntProp(bot, Prop_Send, "m_isGhost", 1);
		SetEntProp(bot, Prop_Send, "m_usSolidFlags", 16);
		SetEntProp(bot, Prop_Send, "movetype", 2);
		SetEntProp(bot, Prop_Send, "deadflag", 0);
		SetEntProp(bot, Prop_Send, "m_lifeState", 1);
		//SetEntProp(bot, Prop_Send, "m_fFlags", 129);
		SetEntProp(bot, Prop_Send, "m_iObserverMode", 0);
		SetEntProp(bot, Prop_Send, "m_iPlayerState", 0);
		SetEntProp(bot, Prop_Send, "m_zombieState", 0);
		DispatchSpawn(bot);
		ActivateEntity(bot);
	}
	return bot;
}

void GetGamedata()
{
	char filePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, filePath, sizeof(filePath), "gamedata/%s.txt", GAMEDATA);
	if( FileExists(filePath) )
	{
		hConf = LoadGameConfigFile(GAMEDATA);
	}
	else
	{
		Handle fileHandle = OpenFile(filePath, "w");
		if (fileHandle == null)
		{ SetFailState("[SM] Couldn't generate gamedata file!"); }
		
		WriteFileLine(fileHandle, "\"Games\"");
		WriteFileLine(fileHandle, "{");
		WriteFileLine(fileHandle, "	\"left4dead\"");
		WriteFileLine(fileHandle, "	{");
		WriteFileLine(fileHandle, "		\"Signatures\"");
		WriteFileLine(fileHandle, "		{");
		WriteFileLine(fileHandle, "			\"%s\"", NAME_InfectedAttackSurvivorTeam);
		WriteFileLine(fileHandle, "			{");
		WriteFileLine(fileHandle, "				\"library\"	\"server\"");
		WriteFileLine(fileHandle, "				\"linux\"	\"%s\"", SIG_InfectedAttackSurvivorTeam_LINUX);
		WriteFileLine(fileHandle, "				\"windows\"	\"%s\"", SIG_L4D1InfectedAttackSurvivorTeam_WINDOWS);
		WriteFileLine(fileHandle, "				\"mac\"		\"%s\"", SIG_InfectedAttackSurvivorTeam_LINUX);
		WriteFileLine(fileHandle, "			}");
		WriteFileLine(fileHandle, "			\"%s\"", NAME_CreateSmoker);
		WriteFileLine(fileHandle, "			{");
		WriteFileLine(fileHandle, "				\"library\"	\"server\"");
		WriteFileLine(fileHandle, "				\"linux\"	\"%s\"", SIG_CreateSmoker_LINUX);
		WriteFileLine(fileHandle, "				\"windows\"	\"%s\"", SIG_L4D1CreateSmoker_WINDOWS);
		WriteFileLine(fileHandle, "				\"mac\"		\"%s\"", SIG_CreateSmoker_LINUX);
		WriteFileLine(fileHandle, "			}");
		WriteFileLine(fileHandle, "			\"%s\"", NAME_CreateBoomer);
		WriteFileLine(fileHandle, "			{");
		WriteFileLine(fileHandle, "				\"library\"	\"server\"");
		WriteFileLine(fileHandle, "				\"linux\"	\"%s\"", SIG_CreateBoomer_LINUX);
		WriteFileLine(fileHandle, "				\"windows\"	\"%s\"", SIG_L4D1CreateBoomer_WINDOWS);
		WriteFileLine(fileHandle, "				\"mac\"		\"%s\"", SIG_CreateBoomer_LINUX);
		WriteFileLine(fileHandle, "			}");
		WriteFileLine(fileHandle, "			\"%s\"", NAME_CreateHunter);
		WriteFileLine(fileHandle, "			{");
		WriteFileLine(fileHandle, "				\"library\"	\"server\"");
		WriteFileLine(fileHandle, "				\"linux\"	\"%s\"", SIG_CreateHunter_LINUX);
		WriteFileLine(fileHandle, "				\"windows\"	\"%s\"", SIG_L4D1CreateHunter_WINDOWS);
		WriteFileLine(fileHandle, "				\"mac\"		\"%s\"", SIG_CreateHunter_LINUX);
		WriteFileLine(fileHandle, "			}");
		WriteFileLine(fileHandle, "			\"%s\"", NAME_CreateTank);
		WriteFileLine(fileHandle, "			{");
		WriteFileLine(fileHandle, "				\"library\"	\"server\"");
		WriteFileLine(fileHandle, "				\"linux\"	\"%s\"", SIG_CreateTank_LINUX);
		WriteFileLine(fileHandle, "				\"windows\"	\"%s\"", SIG_L4D1CreateTank_WINDOWS);
		WriteFileLine(fileHandle, "				\"mac\"		\"%s\"", SIG_CreateTank_LINUX);
		WriteFileLine(fileHandle, "			}");
		WriteFileLine(fileHandle, "		}");
		WriteFileLine(fileHandle, "	}");
		WriteFileLine(fileHandle, "	\"left4dead2\"");
		WriteFileLine(fileHandle, "	{");
		WriteFileLine(fileHandle, "		\"Signatures\"");
		WriteFileLine(fileHandle, "		{");
		WriteFileLine(fileHandle, "			\"%s\"", NAME_InfectedAttackSurvivorTeam);
		WriteFileLine(fileHandle, "			{");
		WriteFileLine(fileHandle, "				\"library\"	\"server\"");
		WriteFileLine(fileHandle, "				\"linux\"	\"%s\"", SIG_InfectedAttackSurvivorTeam_LINUX);
		WriteFileLine(fileHandle, "				\"windows\"	\"%s\"", SIG_InfectedAttackSurvivorTeam_WINDOWS);
		WriteFileLine(fileHandle, "				\"mac\"		\"%s\"", SIG_InfectedAttackSurvivorTeam_LINUX);
		WriteFileLine(fileHandle, "			}");
		WriteFileLine(fileHandle, "			\"%s\"", NAME_CreateSmoker);
		WriteFileLine(fileHandle, "			{");
		WriteFileLine(fileHandle, "				\"library\"	\"server\"");
		WriteFileLine(fileHandle, "				\"linux\"	\"%s\"", SIG_CreateSmoker_LINUX);
		WriteFileLine(fileHandle, "				\"windows\"	\"%s\"", SIG_CreateSmoker_WINDOWS);
		WriteFileLine(fileHandle, "				\"mac\"		\"%s\"", SIG_CreateSmoker_LINUX);
		WriteFileLine(fileHandle, "			}");
		WriteFileLine(fileHandle, "			\"%s\"", NAME_CreateBoomer);
		WriteFileLine(fileHandle, "			{");
		WriteFileLine(fileHandle, "				\"library\"	\"server\"");
		WriteFileLine(fileHandle, "				\"linux\"	\"%s\"", SIG_CreateBoomer_LINUX);
		WriteFileLine(fileHandle, "				\"windows\"	\"%s\"", SIG_CreateBoomer_WINDOWS);
		WriteFileLine(fileHandle, "				\"mac\"		\"%s\"", SIG_CreateBoomer_LINUX);
		WriteFileLine(fileHandle, "			}");
		WriteFileLine(fileHandle, "			\"%s\"", NAME_CreateHunter);
		WriteFileLine(fileHandle, "			{");
		WriteFileLine(fileHandle, "				\"library\"	\"server\"");
		WriteFileLine(fileHandle, "				\"linux\"	\"%s\"", SIG_CreateHunter_LINUX);
		WriteFileLine(fileHandle, "				\"windows\"	\"%s\"", SIG_CreateHunter_WINDOWS);
		WriteFileLine(fileHandle, "				\"mac\"		\"%s\"", SIG_CreateHunter_LINUX);
		WriteFileLine(fileHandle, "			}");
		WriteFileLine(fileHandle, "			\"%s\"", NAME_CreateSpitter);
		WriteFileLine(fileHandle, "			{");
		WriteFileLine(fileHandle, "				\"library\"	\"server\"");
		WriteFileLine(fileHandle, "				\"linux\"	\"%s\"", SIG_CreateSpitter_LINUX);
		WriteFileLine(fileHandle, "				\"windows\"	\"%s\"", SIG_CreateSpitter_WINDOWS);
		WriteFileLine(fileHandle, "				\"mac\"		\"%s\"", SIG_CreateSpitter_LINUX);
		WriteFileLine(fileHandle, "			}");
		WriteFileLine(fileHandle, "			\"%s\"", NAME_CreateJockey);
		WriteFileLine(fileHandle, "			{");
		WriteFileLine(fileHandle, "				\"library\"	\"server\"");
		WriteFileLine(fileHandle, "				\"linux\"	\"%s\"", SIG_CreateJockey_LINUX);
		WriteFileLine(fileHandle, "				\"windows\"	\"%s\"", SIG_CreateJockey_WINDOWS);
		WriteFileLine(fileHandle, "				\"mac\"		\"%s\"", SIG_CreateJockey_LINUX);
		WriteFileLine(fileHandle, "			}");
		WriteFileLine(fileHandle, "			\"%s\"", NAME_CreateCharger);
		WriteFileLine(fileHandle, "			{");
		WriteFileLine(fileHandle, "				\"library\"	\"server\"");
		WriteFileLine(fileHandle, "				\"linux\"	\"%s\"", SIG_CreateCharger_LINUX);
		WriteFileLine(fileHandle, "				\"windows\"	\"%s\"", SIG_CreateCharger_WINDOWS);
		WriteFileLine(fileHandle, "				\"mac\"		\"%s\"", SIG_CreateCharger_LINUX);
		WriteFileLine(fileHandle, "			}");
		WriteFileLine(fileHandle, "			\"%s\"", NAME_CreateTank);
		WriteFileLine(fileHandle, "			{");
		WriteFileLine(fileHandle, "				\"library\"	\"server\"");
		WriteFileLine(fileHandle, "				\"linux\"	\"%s\"", SIG_CreateTank_LINUX);
		WriteFileLine(fileHandle, "				\"windows\"	\"%s\"", SIG_CreateTank_WINDOWS);
		WriteFileLine(fileHandle, "				\"mac\"		\"%s\"", SIG_CreateTank_LINUX);
		WriteFileLine(fileHandle, "			}");
		WriteFileLine(fileHandle, "		}");
		WriteFileLine(fileHandle, "	}");
		WriteFileLine(fileHandle, "}");
		
		CloseHandle(fileHandle);
		hConf = LoadGameConfigFile(GAMEDATA);
		if (hConf == null)
		{ SetFailState("[SM] Failed to load auto-generated gamedata file!"); }
	}
	PrepSDKCall();
}

void LoadStringFromAdddress(Address addr, char[] buffer, int maxlength) {
	int i = 0;
	while(i < maxlength) {
		char val = LoadFromAddress(addr + view_as<Address>(i), NumberType_Int8);
		if(val == 0) {
			buffer[i] = 0;
			break;
		}
		buffer[i] = val;
		i++;
	}
	buffer[maxlength - 1] = 0;
}

Handle PrepCreateBotCallFromAddress(Handle hSiFuncTrie, const char[] siName) {
	Address addr;
	StartPrepSDKCall(SDKCall_Static);
	if (!GetTrieValue(hSiFuncTrie, siName, addr) || !PrepSDKCall_SetAddress(addr))
	{
		SetFailState("Unable to find NextBotCreatePlayer<%s> address in memory.", siName);
		return null;
	}
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
	return EndPrepSDKCall();	
}

void PrepWindowsCreateBotCalls(Address jumpTableAddr) 
{
	Handle hInfectedFuncs = CreateTrie();
	for(int i = 0; i < 7; i++) 
	{
		Address caseBase = jumpTableAddr + view_as<Address>(i * 12);
		Address siStringAddr = view_as<Address>(LoadFromAddress(caseBase + view_as<Address>(1), NumberType_Int32));
		static char siName[32];
		LoadStringFromAdddress(siStringAddr, siName, sizeof(siName));

		Address funcRefAddr = caseBase + view_as<Address>(6); // 2nd byte of call, 5+1 byte offset.
		int funcRelOffset = LoadFromAddress(funcRefAddr, NumberType_Int32);
		Address callOffsetBase = caseBase + view_as<Address>(10); // first byte of next instruction after the CALL instruction
		Address nextBotCreatePlayerBotTAddr = callOffsetBase + view_as<Address>(funcRelOffset);
		//PrintToServer("Found NextBotCreatePlayerBot<%s>() @ %08x", siName, nextBotCreatePlayerBotTAddr);
		SetTrieValue(hInfectedFuncs, siName, nextBotCreatePlayerBotTAddr);
	}

	hCreateSmoker = PrepCreateBotCallFromAddress(hInfectedFuncs, "Smoker");
	if (hCreateSmoker == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateSmoker); return; }

	hCreateBoomer = PrepCreateBotCallFromAddress(hInfectedFuncs, "Boomer");
	if (hCreateBoomer == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateBoomer); return; }

	hCreateHunter = PrepCreateBotCallFromAddress(hInfectedFuncs, "Hunter");
	if (hCreateHunter == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateHunter); return; }

	hCreateTank = PrepCreateBotCallFromAddress(hInfectedFuncs, "Tank");
	if (hCreateTank == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateTank); return; }
	
	hCreateSpitter = PrepCreateBotCallFromAddress(hInfectedFuncs, "Spitter");
	if (hCreateSpitter == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateSpitter); return; }
	
	hCreateJockey = PrepCreateBotCallFromAddress(hInfectedFuncs, "Jockey");
	if (hCreateJockey == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateJockey); return; }

	hCreateCharger = PrepCreateBotCallFromAddress(hInfectedFuncs, "Charger");
	if (hCreateCharger == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateCharger); return; }
}

void PrepL4D2CreateBotCalls() 
{
		StartPrepSDKCall(SDKCall_Static);
		if (!PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, NAME_CreateSpitter))
		{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateSpitter); return; }
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
		hCreateSpitter = EndPrepSDKCall();
		if (hCreateSpitter == null)
		{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateSpitter); return; }
		
		StartPrepSDKCall(SDKCall_Static);
		if (!PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, NAME_CreateJockey))
		{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateJockey); return; }
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
		hCreateJockey = EndPrepSDKCall();
		if (hCreateJockey == null)
		{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateJockey); return; }
		
		StartPrepSDKCall(SDKCall_Static);
		if (!PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, NAME_CreateCharger))
		{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateCharger); return; }
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
		hCreateCharger = EndPrepSDKCall();
		if (hCreateCharger == null)
		{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateCharger); return; }
}

void PrepL4D1CreateBotCalls() 
{
	StartPrepSDKCall(SDKCall_Static);
	if (!PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, NAME_CreateSmoker))
	{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateSmoker); return; }
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
	hCreateSmoker = EndPrepSDKCall();
	if (hCreateSmoker == null)
	{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateSmoker); return; }
	
	StartPrepSDKCall(SDKCall_Static);
	if (!PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, NAME_CreateBoomer))
	{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateBoomer); return; }
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
	hCreateBoomer = EndPrepSDKCall();
	if (hCreateBoomer == null)
	{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateBoomer); return; }
	
	StartPrepSDKCall(SDKCall_Static);
	if (!PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, NAME_CreateHunter))
	{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateHunter); return; }
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
	hCreateHunter = EndPrepSDKCall();
	if (hCreateHunter == null)
	{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateHunter); return; }
	
	StartPrepSDKCall(SDKCall_Static);
	if (!PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, NAME_CreateTank))
	{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateTank); return; }
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
	hCreateTank = EndPrepSDKCall();
	if (hCreateTank == null)
	{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateTank); return; }
}

void PrepSDKCall()
{
	if (hConf == null)
	{ SetFailState("Unable to find %s.txt gamedata.", GAMEDATA); return; }
	
	Address replaceWithBot = GameConfGetAddress(hConf, "NextBotCreatePlayerBot.jumptable");
	
	if (replaceWithBot != Address_Null && LoadFromAddress(replaceWithBot, NumberType_Int8) == 0x68) {
		PrepWindowsCreateBotCalls(replaceWithBot);
	}
	else
	{
		PrepL4D2CreateBotCalls();
		PrepL4D1CreateBotCalls();
	}
	
	StartPrepSDKCall(SDKCall_Entity);
	if (!PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, NAME_InfectedAttackSurvivorTeam))
	{ SetFailState("Unable to find %s signature in gamedata file.", NAME_InfectedAttackSurvivorTeam); return; }
	hInfectedAttackSurvivorTeam = EndPrepSDKCall();
	if (hInfectedAttackSurvivorTeam == null)
	{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_InfectedAttackSurvivorTeam); return; }
}
stock bool ValidClient(int client, bool replaycheck = false) 
{
	if ( client <= 0 || client > MaxClients ) return false;
	if ( !IsClientInGame(client) ) return false;
	if (replaycheck) 
	{
		if ( IsClientSourceTV(client) || IsClientReplay(client) ) return false;
	}
	return true;
}
stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}

stock bool IsValidSurvivor(int client)
{
	return IsValidClient(client) && GetClientTeam(client) == view_as<int>(TEAM_SURVIVOR);
}

bool IsPlayerStuck(float vPos[3])
{
	float vAng1[3], vAng2[3];
	vAng1[0] = vPos[0] - 15.0;
	vAng1[1] = vPos[1] + 15.0;
	vAng1[2] = vPos[2] + 70.0;
	vAng2[0] = vPos[0] + 15.0;
	vAng2[1] = vPos[1] - 15.0;
	vAng2[2] = vPos[2] + 10.0;
	TR_TraceRayFilter(vAng1, vAng2,MASK_NPCSOLID_BRUSHONLY,RayType_EndPoint, TraceFilter_Stuck);
	if (TR_DidHit())
	{
		return true;
	}
	vAng1[0] = vPos[0] - 15.0;
	vAng1[1] = vPos[1] - 15.0;
	vAng1[2] = vPos[2] + 10.0;
	vAng2[0] = vPos[0] + 15.0;
	vAng2[1] = vPos[1] + 15.0;
	vAng2[2] = vPos[2] + 70.0;
	TR_TraceRayFilter(vAng1, vAng2,MASK_NPCSOLID_BRUSHONLY,RayType_EndPoint, TraceFilter_Stuck);
	if (TR_DidHit())
	{
		return true;
	}
	return false;
}

stock bool TraceFilter_Stuck(int entity, int contentsMask)
{
	if (entity <= MaxClients || !IsValidEntity(entity))
	{
		return false;
	}
	else
	{
		static char sClassName[20];
		GetEntityClassname(entity, sClassName, sizeof(sClassName));
		if (strcmp(sClassName, "env_physics_blocker") == 0 && !EnvBlockType(entity))
		{
			return false;
		}
	}
	return true;
}

stock bool EnvBlockType(int entity)
{
	int BlockType = GetEntProp(entity, Prop_Data, "m_nBlockType");
	if(BlockType == 1 || BlockType == 2)
	{
		return false;
	}
	else
	{
		return true;
	}
}
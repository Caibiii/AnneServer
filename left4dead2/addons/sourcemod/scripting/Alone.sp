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
//********************************************************************************//

public Plugin myinfo = 
{
	name 			= "AnneServer InfectedSpawn",
	author 			= "Caibiii",
	description 	= "AnneServer InfectedSpawn",
	version 		= "2021-7-7",
	url 			= "https://github.com/Caibiii/AnneServer"
}

char infected_name[][] = 
{
    "",
    "smoker",
    "boomer",
    "hunter",
    "spitter",
    "jockey",
    "charger"
};

// Cvars
ConVar 
	g_hSiLimit, 						//一波特感生成数量上限
	g_hSiInterval;						//每波特感生成基础间隔
// Ints
int 
	g_iSiLimit, 						//特感数量
	g_iTeleCount[MAXPLAYERS + 1] = {0}, //每个特感传送的不被看到次数
	g_iTargetSurvivor = -1, 			//OnGameFrame参数里，以该目标生成生成网络，寻找生成目标
	g_iTeleportIndex = 0,				//当前传送队列长度
	g_iSpawnMaxCount = 0;				//当前可生成特感数量
// Floats
float 
	g_fSpawnDistance, 					//特感的当前生成距离
	g_fTeleportDistance,				//特感当前传送生成距离
	g_fSiInterval,						//特感的生成时间间隔
	g_LastPosition[MAXPLAYERS + 1][3];	//记录Client上个坐标
	//g_lastMoveTime[MAXPLAYERS + 1];		//记录Client上个时间戳
// Bools
bool 
	LeftSafeArea =false,					//是否离开安全区域
	g_bIsLate = false;						//text插件是否发送开启刷特命令
// Handle
Handle 
	g_hTeleHandle = INVALID_HANDLE;				//传送sdk Handle
// ArrayList
ArrayList 
	NearSpawnAreas,
	hereProximates;							//储存特感生成的navid，用来限制特感不能生成在同一块Navid上
DataPack
	hPack;
public void OnPluginStart()
{
	GetGamedata();
	// CreateConVar
	g_hSiLimit = CreateConVar("l4d_infected_limit", "6", "一次刷出多少特感", CVAR_FLAG, true, 0.0);
	g_hSiInterval = CreateConVar("versus_special_respawn_interval", "16.0", "对抗模式下刷特时间控制", CVAR_FLAG, true, 0.0);
	// HookEvents
	HookEvent("player_death", evt_PlayerDeath, EventHookMode_PostNoCopy);
	HookEvent("round_start", evt_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("finale_win", evt_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", evt_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", evt_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_PostNoCopy);
	// AddChangeHook
	g_hSiInterval.AddChangeHook(ConVarChanged_Cvars);
	g_hSiLimit.AddChangeHook(MaxPlayerZombiesChanged_Cvars);
	// GetCvars
	GetCvars();
	RegAdminCmd("sm_startspawn", Cmd_StartSpawn, ADMFLAG_ROOT, "管理员重置刷特时钟");
}
// *********************
//		  重要功能部分
// *********************
/* 玩家受伤,增加对smoker得伤害 */
public void Event_PlayerHurt(Event event, const char[] name, bool dont_broadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int damage = GetEventInt(event, "dmg_health");
	int eventhealth = GetEventInt(event, "health");
	int AddDamage = 0;
	if (IsValidSurvivor(attacker) && IsInfectedBot(victim) && GetEntProp(victim, Prop_Send, "m_zombieClass") == 1)
	{
		if( GetEntPropEnt(victim, Prop_Send, "m_tongueVictim") > 0 )
		{
			AddDamage = damage * 5;
		}
		int health = eventhealth - AddDamage;
		if (health < 1)
		{
			health = 0;
		}
		SetEntityHealth(victim, health);
		SetEventInt(event, "health", health);
	}
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
public Action Timer_g_bIsLate(Handle timer)
{
	//FindNearbySpawnAreas();
	g_fSpawnDistance = 500.0;
	g_fTeleportDistance = 500.0;
	g_bIsLate = true;
	return Plugin_Continue;
}


//寻找生还附近的NAV，并将ID存储进NearSpawnAreas，全插件性能开销最大，少用，在适当的时候使用即可
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
			if (GetVectorDistance(fSpawnPos, fSurvivorPos) < 650.0)			//如是，设定距离为850内均符合；增加特感生成在前面的可能性
			{
				PushArrayCell(NearSpawnAreas, hereProximates.Get(count));
			}
		}
		count++; 
	}
}

//产生特感函数
void SpawnInfected(DataPack fSpawnPos_Pack)
{
	fSpawnPos_Pack.Reset();
	float fSpawnPos[3];
	fSpawnPos[0] = fSpawnPos_Pack.ReadFloat();
	fSpawnPos[1] = fSpawnPos_Pack.ReadFloat();
	fSpawnPos[2] = fSpawnPos_Pack.ReadFloat();
	fSpawnPos[2] += 18.0;
	delete fSpawnPos_Pack;
	int count, spawnedClient, iZombieClass;
	iZombieClass = GetRandomInt(1, 6);
	while (iZombieClass == 2 || iZombieClass == 4 || GetInfectedCount(iZombieClass) >= GetServerLimit(iZombieClass))
	{
		iZombieClass = GetRandomInt(1, 6);
		count++;
		if(count > 21)
		{
			iZombieClass = 3;
			break;
		}
	}
	switch (iZombieClass)
	{
		case 1:
		{
			spawnedClient = CreateInfected("smoker");  	//产生特感
		}
		case 2:
		{
			spawnedClient = CreateInfected("boomer");		//产生特感
		}
		case 3:
		{
			spawnedClient = CreateInfected("hunter");		//产生特感
		}
		case 4:
		{
			spawnedClient = CreateInfected("spitter");		//产生特感
		}
		case 5:
		{
			spawnedClient = CreateInfected("jockey");		//产生特感
		}
		case 6:
		{
			spawnedClient = CreateInfected("charger");		//产生特感
		}
	}
	g_LastPosition[spawnedClient] = fSpawnPos;				//记录产生特感的位置，可能什么时候能用的上
	//g_lastMoveTime[spawnedClient] = GetGameTime();			//记录产生特感的时间，可能什么时候能用的上
	TeleportEntity(spawnedClient, fSpawnPos, NULL_VECTOR, NULL_VECTOR);  	//需要将特感实体传送到该位置，不然不知道产生在什么B地方
	g_iTeleCount[spawnedClient] = 0;					//产生特感后检测下哪些特感满了
}
//传送落后特感
public Action Timer_PositionSi(Handle timer)
{
	if(g_bIsLate && g_iSpawnMaxCount < 1)
	{
		float NextSpawnTime = GetRandomFloat(g_fSiInterval * 1.2, g_fSiInterval * 1.5);
		CreateTimer(NextSpawnTime, SpawnNewInfected);
		g_bIsLate = false;
		//PrintToChatAll("\x04当前特感已全部复活，开始下波倒计时%i秒",RoundToFloor(NextSpawnTime));
	}
	for (int client = 1; client <= MaxClients; client++)
	{
		if(IsInfectedBot(client)  && IsPlayerAlive(client) && !IsPinningSomeone(client))
		{
			L4D_WarpToValidPositionIfStuck(client);
			float fSelfPos[3];
			GetClientAbsOrigin(client, fSelfPos);
			Address fSpawnPosArea = L4D_GetNearestNavArea(fSelfPos, 120.0, true, false, false, 3);
			if (!PlayerVisibleToSDK(fSelfPos,fSpawnPosArea) || GetVectorDistance(g_LastPosition[client], fSelfPos) < 30.0)
			{
				if (g_iTeleCount[client] > 49)
				{
					FindNearbySpawnAreas();
					g_iTeleCount[client] = 0;
					KickClient(client);
					g_iTeleportIndex += 1;
					g_fTeleportDistance = 500.0;
				}
				g_iTeleCount[client] += 10;
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
// *********************
//		  重要功能部分
// *********************
stock Action Cmd_StartSpawn(int client, int args)
{
	if (L4D_HasAnySurvivorLeftSafeArea())
	{
		LeftSafeArea = true;
		ResetStatus();
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
	//PrintToChatAll("\x04开始找位准备复活  需复活的特感数量为%i只", g_iSiLimit);
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

// *********************
//		获取Cvar值
// *********************
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
// *********************
//		    事件
// *********************
public void evt_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	InitStatus();
	CreateTimer(1.0, SafeRoomReset, _, TIMER_FLAG_NO_MAPCHANGE);
}

// 开局重置特感状态
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
		CreateTimer(0.2, Timer_KickBot, client);
	}	
}

public Action Timer_KickBot(Handle timer, int client)
{
	if (IsClientInGame(client) && !IsClientInKickQueue(client) && IsFakeClient(client))
	{
		g_iTeleCount[client] = 0;
		KickClient(client);
	}
	return Plugin_Continue;
}
// *********************
//		   方法
// *********************
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
		//太近直接返回看见
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

stock bool IsGhost(int client)
{
    return (IsValidClient(client) && view_as<bool>(GetEntProp(client, Prop_Send, "m_isGhost")));
}

// @key：需要调整的 key 值
// @retVal：原 value 值，使用 return Plugin_Handled 覆盖
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
// 判断生还者是否有效，有效返回 true，无效返回 false
// @client：需要判断的生还者客户端索引
stock bool IsValidSurvivor(int client)
{
	return IsValidClient(client) && GetClientTeam(client) == view_as<int>(TEAM_SURVIVOR);
}

bool IsPlayerStuck(float vPos[3])
{
	float vAng1[3], vAng2[3];
	//体积的左上角
	vAng1[0] = vPos[0] - 15.0;
	vAng1[1] = vPos[1] + 15.0;
	vAng1[2] = vPos[2] + 70.0;
	//体积的右下角
	vAng2[0] = vPos[0] + 15.0;
	vAng2[1] = vPos[1] - 15.0;
	vAng2[2] = vPos[2] + 10.0;
	TR_TraceRayFilter(vAng1, vAng2,MASK_NPCSOLID_BRUSHONLY,RayType_EndPoint, TraceFilter_Stuck);
	if (TR_DidHit())
	{
		return true;
	}
	//体积的左下角
	vAng1[0] = vPos[0] - 15.0;
	vAng1[1] = vPos[1] - 15.0;
	vAng1[2] = vPos[2] + 10.0;
	//体积的右上角
	vAng2[0] = vPos[0] + 15.0;
	vAng2[1] = vPos[1] + 15.0;
	vAng2[2] = vPos[2] + 70.0;
	TR_TraceRayFilter(vAng1, vAng2,MASK_NPCSOLID_BRUSHONLY,RayType_EndPoint, TraceFilter_Stuck);
	if (TR_DidHit())
	{
		return true;
	}
	//体积的左下角
	vAng1[0] = vPos[0] - 15.0;
	vAng1[1] = vPos[1] - 15.0;
	vAng1[2] = vPos[2] + 10.0;
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
	//阻拦ai infected
	if(BlockType == 1 || BlockType == 2 )
	{
		return false;
	}
	else
	{
		return true;
	}
}

int GetServerLimit(int class)
{
    char cvar[16];
	Format(cvar, 16, "z_%s_limit", infected_name[class]);
    return FindConVar(cvar).IntValue;
}

int GetInfectedCount(int class)
{
    int count = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == 3  && GetEntProp(i, Prop_Send, "m_zombieClass") == class)
        {
			count++;
        }
    }
    return count;
}

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
	name 			= "Direct InfectedSpawn",
	author 			= "Caibiii, 夜羽真白，东",
	description 	= "特感刷新控制，传送落后特感",
	version 		= "2021.07.07修改",
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

ConVar 
	g_hSiLimit, 
	g_hSiInterval;
int 
	g_iSiLimit,
	g_iTimeSearchArea, 
	g_iTeleCount[MAXPLAYERS + 1] = {0},
	g_iTeleportIndex = 0,
	g_iSpawnMaxCount = 0, 
	iSurvivors[4] = {0}, 
	iSurvivorIndex = 0; 
float 
	g_fSpawnDistance, 
	g_fSiInterval,
	g_LastPosition[MAXPLAYERS + 1][3];
	//g_lastMoveTime[MAXPLAYERS + 1];
bool 
	LeftSafeArea = false,
	g_bIsLate = false;
Handle 
	g_hSpawnHandle = INVALID_HANDLE,
	g_hTeleHandle = INVALID_HANDLE;
ArrayList 
	NearSpawnAreas,
	hereProximates;
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
//寻找生还附近所有的NAVAREA，并存储在NearSpawnAreas，性能消耗较大，尽量单独进行处理
stock void FindNearbySpawnAreas()
{
	NearSpawnAreas = new ArrayList();
	float fSpawnPos[3], fSurvivorPos[3];
	int count, index, highflowSurvivor;
	Address fSpawnPosArea;
	highflowSurvivor = L4D_GetHighestFlowSurvivor();
	while (count < hereProximates.Length)
	{
		fSpawnPosArea = hereProximates.Get(count);
		L4D_FindRandomSpot(fSpawnPosArea, fSpawnPos);
		for (int client = 0; client < iSurvivorIndex; client++)
		{
			index = iSurvivors[client];
			if(IsClientInGame(index))
			{
				GetClientAbsOrigin(index, fSurvivorPos);
				if(index != highflowSurvivor)
				{
					if (GetVectorDistance(fSpawnPos, fSurvivorPos) < g_fSpawnDistance * 0.6)
					{
						PushArrayCell(NearSpawnAreas, fSpawnPosArea);
					}
				}
				else if (GetVectorDistance(fSpawnPos, fSurvivorPos) < g_fSpawnDistance)
				{
					PushArrayCell(NearSpawnAreas, fSpawnPosArea);
				}
			}
		}
		count++; 
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
			float fSpawnPos[3];
			if(GetSpawnPos(fSpawnPos))	
			{
				g_iTeleportIndex -= 1;
				int count, spawnedClient, iZombieClass;
				iZombieClass = GetRandomInt(1, 6);
				while (GetCount(iZombieClass) >= GetCountLimit(iZombieClass))
				{
					iZombieClass = GetRandomInt(1, 6);
					count++;
					if(count > 30)
					{
						iZombieClass = 3;
						break;
					}
				}
				spawnedClient = CreateInfected(infected_name[iZombieClass]);
				g_LastPosition[spawnedClient] = fSpawnPos;		//记录特感的初始复活坐标，检测传送特感用到
				//g_lastMoveTime[spawnedClient] = GetGameTime();	//记录特感的复活时间，暂无用到的地方
				TeleportEntity(spawnedClient, fSpawnPos, NULL_VECTOR, NULL_VECTOR);
				g_iTeleCount[spawnedClient] = 0;
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
			float fSpawnPos[3];
			if(NearSpawnAreas.Length == 0)
			{
				FindNearbySpawnAreas();
				return;
			}
			if(GetSpawnPos(fSpawnPos))	
			{
				g_iSpawnMaxCount -= 1;
				int count, spawnedClient, iZombieClass;
				iZombieClass = GetRandomInt(1, 6);
				while (GetCount(iZombieClass) >= GetCountLimit(iZombieClass))
				{
					iZombieClass = GetRandomInt(1, 6);
					count++;
					if(count > 30)
					{
						iZombieClass = 3;
						break;
					}
				}
				spawnedClient = CreateInfected(infected_name[iZombieClass]);
				g_LastPosition[spawnedClient] = fSpawnPos;		//记录特感的初始复活坐标，检测传送特感用到
				//g_lastMoveTime[spawnedClient] = GetGameTime();	//记录特感的复活时间，暂无用到的地方
				TeleportEntity(spawnedClient, fSpawnPos, NULL_VECTOR, NULL_VECTOR);
				g_iTeleCount[spawnedClient] = 0;
			}
		}
	}	
}

stock bool GetSpawnPos(float fSpawnPos[3])
{
    float AreaSize[3], X_Min, X_Max, Y_Min, Y_Max;
    Address fSpawnPosArea;
	int RandomInt;
    for(int LengthCount = 0; LengthCount < 50; LengthCount++)
    {
		RandomInt = GetRandomInt(0, NearSpawnAreas.Length - 1);
        fSpawnPosArea = NearSpawnAreas.Get(RandomInt);
		//L4D_FindRandomSpot(fSpawnPosArea, fSpawnPos);
		L4D_GetNavAreaCenter(fSpawnPosArea, fSpawnPos);		//可以提前存储
		L4D_GetNavAreaSize(fSpawnPosArea, AreaSize);			//可以提前存储
		X_Min = fSpawnPos[0] - AreaSize[0] * 0.5; X_Max = fSpawnPos[0] + AreaSize[0] * 0.5;
		Y_Min = fSpawnPos[1] - AreaSize[1] * 0.5; Y_Max = fSpawnPos[1] + AreaSize[1] * 0.5;
		fSpawnPos[0] = GetRandomFloat(X_Min, X_Max); fSpawnPos[1] = GetRandomFloat(Y_Min, Y_Max);
		//有些NAVAREA高度不一致，需要通过加减高度修复避免特感复活进入地下
		if(AreaSize[2] < 0.0 )
		{
			fSpawnPos[2] = fSpawnPos[2] - AreaSize[2] * 0.5;
		}
		else
		{
			fSpawnPos[2] = fSpawnPos[2] + AreaSize[2] * 0.5;
		}
		fSpawnPos[2] += 18.0;	//稍微提高的高度，防止特感进入地下
        if(!PlayerVisibleToSDK(fSpawnPos, fSpawnPosArea) && NavAreaBuildPath(fSpawnPosArea, RandomInt) && !IsPlayerStuck(fSpawnPos))
        {	
			RemoveFromArray(NearSpawnAreas, RandomInt);		//移除该块NAV避免特感扎堆复活
			return true;
        }
    }
	return false;
}


//性能消耗较大，服务器可能承受不住，如果对单名生还进行检测距离，减少处理量，找位效果虽差一些,但可能效果更好，不再那么集中？
stock bool NavAreaBuildPath(Address fSpawnPosArea, int RandomInt)
{
	float fSurvivorPos[3];
	int iSurvivorsIndex;
	float dist = g_fSpawnDistance * 1.5;
	for (int client = 0; client < iSurvivorIndex; client++)
	{
		iSurvivorsIndex = iSurvivors[client];
		GetClientAbsOrigin(iSurvivorsIndex, fSurvivorPos);
		if(L4D2_NavAreaBuildPath(fSpawnPosArea, L4D_GetNearestNavArea(fSurvivorPos, 120.0, true, false, false, 3), dist, 3, true))
		{
			return true;
		}
	}
	RemoveFromArray(NearSpawnAreas, RandomInt);		//不符合的直接移除，避免不必要的重复工作
	return false;
}

//客户端和坐标的视线检测，PVE、云服务器性能不好放宽松些，使用单射线检测即可，
stock bool PlayerVisibleToSDK(float targetposition[3], Address fSpawnPosArea)
{
	float position[3];
	float distance;
	float fTargetPos[3];
	fTargetPos = targetposition;
	fTargetPos[2] += 45.0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsValidSurvivor(client) && IsPlayerAlive(client))
		{
			GetClientAbsOrigin(client, position);
			distance = GetVectorDistance(targetposition, position);
			//限制下特感最近的复活距离，250应该差不多了
			if(distance < 250.0)
			{
				return true;
			}
			if(L4D2_IsVisibleToPlayer(client, 2, 3, fSpawnPosArea, fTargetPos))
			{
				return true;
			}
		}
	}
	return false;
}

public Action Timer_TeleHandle(Handle timer)
{
	//所有特感产生完毕后开始下一波计时器
	if(g_bIsLate && g_iSpawnMaxCount < 1)
	{
		//当所有特感产生完毕后直接开始倒计时默认16*1.3 - 16*1.5秒之间
		float NextSpawnTime = GetRandomFloat(g_fSiInterval * 1.2, g_fSiInterval * 1.5);
		CreateTimer(NextSpawnTime, SpawnNewInfected);
		g_bIsLate = false;
	}
	//特感在5秒内还未产生完成时，开始重新寻找生化附近的NAVAREA并存储起来，一般不会触发这里
	if(g_iSpawnMaxCount > 0)
	{
		g_iTimeSearchArea ++;
		if(g_iTimeSearchArea > 10)
		{
			g_iTimeSearchArea = 0;
			g_fSpawnDistance = 1250.0;		//加大范围1250应该足够应付大部分空旷地图了，至少官图是没有问题的
			FindNearbySpawnAreas();
		}
	}
	else
	{
		g_iTimeSearchArea = 0;
	}
	//特感传送检测：在5秒内看不到生化或者距离复活距离30（大概率卡住了）踢出并进入传送队列
	Address fSpawnPosArea;
	float fSelfPos[3];
	for (int client = 1; client <= MaxClients; client++)
	{
		if(IsInfectedBot(client)  && IsPlayerAlive(client) && !IsPinningSomeone(client))
		{
			L4D_WarpToValidPositionIfStuck(client);
			GetClientAbsOrigin(client, fSelfPos);
			fSpawnPosArea = L4D_GetLastKnownArea(client);
			if (!InfectedVisibleToSDK(fSelfPos, fSpawnPosArea) || GetVectorDistance(g_LastPosition[client], fSelfPos) < 50.0)
			{
				if (g_iTeleCount[client] > 49)
				{
					FindNearbySpawnAreas();
					g_iTeleCount[client] = 0;
					KickClient(client);
					g_iTeleportIndex += 1;	//传送+1
					g_fSpawnDistance = 500.0;
				}
				g_iTeleCount[client] += 5;
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

//管理员重置刷特时钟，当前由text.smx出门控制
stock Action Cmd_StartSpawn(int client, int args)
{
	if (L4D_HasAnySurvivorLeftSafeArea())
	{
		LeftSafeArea = true;
		ResetStatus();
		hereProximates = new ArrayList();
		L4D_GetAllNavAreas(hereProximates);
		g_iTeleportIndex = 0;
		CreateTimer(0.1, SpawnNewInfected);
		//CreateTimer(g_fSiInterval, SpawnNewInfected);
		//CreateTimer(0.1, Timer_Function, _, TIMER_REPEAT);
		g_hTeleHandle = CreateTimer(0.5, Timer_TeleHandle, _, TIMER_REPEAT);
	}
	return Plugin_Handled;
}
//刷特前的一些准备，使用下一帧用法避免FindNearbySpawnAreas()和找位函数一起导致服务器卡顿
public Action SpawnNewInfected(Handle timer)
{
	if(LeftSafeArea)
	{
		if(MaxSpecials() < g_iSiLimit)
		{
			FindNearbySpawnAreas();	//性能消耗较大，单独进行处理
		}
		g_iTimeSearchArea = 0;
		g_iSpawnMaxCount = g_iSiLimit;
		g_fSpawnDistance = 800.0;
		g_bIsLate = true;
	}
	return Plugin_Stop;
}
//返回场上所有特感数量
int MaxSpecials()
{
	iSurvivorIndex = 0; int MaxSpecialCount = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsInfectedBot(client) && IsPlayerAlive(client))
		{
			MaxSpecialCount++;
		}
		if (IsValidSurvivor(client) && IsPlayerAlive(client))
		{
			if(/*!IsPinned(client) &&*/ !L4D_IsPlayerIncapacitated(client) && !L4D_IsPlayerHangingFromLedge(client))
			{
				iSurvivors[iSurvivorIndex] = client;
				iSurvivorIndex += 1;
			}
		}
	}
	return MaxSpecialCount;
}

stock bool InfectedVisibleToSDK(float targetposition[3], Address fSpawnPosArea)
{
	float fTargetPos[3];
	fTargetPos = targetposition;
	fTargetPos[2] += 45.0;
	for (int client = 0; client < iSurvivorIndex; client++)
	{
		if(IsClientInGame(iSurvivors[client]))
		{
			//无视距离，只需要看不见就行，防止隔墙卡住特感
			if(L4D2_IsVisibleToPlayer(iSurvivors[client], 2, 3, fSpawnPosArea, fTargetPos))
			{
				return true;
			}
		}
	}
	return false;
}

//使用两条射线交叉随便检测下是否卡住即可
stock bool IsPlayerStuck(float vPos[3])
{
	float vAng1[3], vAng2[3];
	vAng1[0] = vPos[0] - 15.0; vAng1[1] = vPos[1] + 15.0; vAng1[2] = vPos[2] + 70.0;
	vAng2[0] = vPos[0] + 15.0; vAng2[1] = vPos[1] - 15.0; vAng2[2] = vPos[2] + 10.0;
	TR_TraceRayFilter(vAng1, vAng2,MASK_NPCSOLID_BRUSHONLY,RayType_EndPoint, TraceFilter_Stuck);
	if (TR_DidHit())
	{
		//PrintToConsoleAll("这TM都能卡住？");
		return true;
	}
	vAng1[0] = vPos[0] - 15.0; vAng1[1] = vPos[1] - 15.0; vAng1[2] = vPos[2] + 10.0;
	vAng2[0] = vPos[0] + 15.0; vAng2[1] = vPos[1] + 15.0; vAng2[2] = vPos[2] + 70.0;
	TR_TraceRayFilter(vAng1, vAng2,MASK_NPCSOLID_BRUSHONLY,RayType_EndPoint, TraceFilter_Stuck);
	if (TR_DidHit())
	{
		//PrintToConsoleAll("这TM都能卡住？");
		return true;
	}
	return false;
}
//总有奇奇怪怪的东西阻挡视线，肯定不止这些
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
//总有奇奇怪怪的东西阻挡视线，肯定不止这些
stock bool EnvBlockType(int entity)
{
	int BlockType = GetEntProp(entity, Prop_Data, "m_nBlockType");
	if(BlockType == 1 || BlockType == 2 )
	{
		return false;
	}
	else
	{
		return true;
	}
}

//一些事件的东西，一般不需要改动
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
	if (g_hSpawnHandle != INVALID_HANDLE)
	{
		delete g_hSpawnHandle;
		g_hSpawnHandle = INVALID_HANDLE;
	}
	g_iTimeSearchArea = 0;
	g_bIsLate = false;
	LeftSafeArea = false;
	g_iSpawnMaxCount = 0;
	g_iTeleportIndex = 0;
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

stock int GetCountLimit(int class)
{
    char cvar[16];
	Format(cvar, 16, "z_%s_limit", infected_name[class]);
    return FindConVar(cvar).IntValue;
}

stock int GetCount(int class)
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

public void evt_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsInfectedBot(client))
	{
		g_iTeleCount[client] = 0;
		CreateTimer(5.0, Timer_KickBot, client);
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

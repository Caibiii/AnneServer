#pragma semicolon 1
#pragma tabsize 0
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#undef REQUIRE_PLUGIN
#define CVAR_FLAG FCVAR_NOTIFY
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define NAV_SEARCH_RANGE 250.0
#define MIN_SPAWN_POS_DISTANCE 100.0
#define MAX_CLIENTS MAXPLAYERS + 1
#define TOTAL_ENTITY_LIMIT 28
#define GAMEDATA "spawn_infected_nolimit"

#define MODEL_SMOKER "models/infected/smoker.mdl"
#define MODEL_BOOMER "models/infected/boomer.mdl"
#define MODEL_HUNTER "models/infected/hunter.mdl"
#define MODEL_SPITTER "models/infected/spitter.mdl"
#define MODEL_JOCKEY "models/infected/jockey.mdl"
#define MODEL_CHARGER "models/infected/charger.mdl"

const float SURVIVOR_DIST_THRESHOLD = 400.0;
const float STUCK_MOVE_THRESHOLD = 100.0;
const int STUCK_COUNT_STEP = 5;
const float SPAWN_DIST_DEFAULT = 700.0;
const float SPAWN_Z_OFFSET = 45.0;

const float SPAWN_DIST_STEP = 100.0;
const float RESPAWN_DELAY_MULT = 1.5;
const float KICK_BOT_DELAY = 0.2;
const int DOOR_CHECK_TICKS = 2;
const float DOOR_DAMAGE_DIST = 120.0;
const float DOOR_DAMAGE = 1200.0;
#define DOOR_DMG_TYPE (1 << 1)

#define BOT_SOLID_FLAGS 16
#define BOT_MOVETYPE_WALK 2

#define NAME_CreateSmoker "NextBotCreatePlayerBot<Smoker>"
#define NAME_CreateBoomer "NextBotCreatePlayerBot<Boomer>"
#define NAME_CreateHunter "NextBotCreatePlayerBot<Hunter>"
#define NAME_CreateSpitter "NextBotCreatePlayerBot<Spitter>"
#define NAME_CreateJockey "NextBotCreatePlayerBot<Jockey>"
#define NAME_CreateCharger "NextBotCreatePlayerBot<Charger>"
#define NAME_InfectedAttackSurvivorTeam "Infected::AttackSurvivorTeam"

public Plugin myinfo = {
    name = "Direct InfectedSpawn",
    author = "Caibiii",
    description = "特感刷新控制，传送落后特感",
    version = "2026.10.10",
    url = "https://github.com/Caibiii/AnneServer"
};

Handle hConf = null;
static Handle hCreateSmoker = null, hCreateBoomer = null, hCreateHunter = null;
static Handle hCreateSpitter = null, hCreateJockey = null, hCreateCharger = null;
static Handle hInfectedAttackSurvivorTeam = null;

ConVar h_Cvar_SiLimit, h_Cvar_SiInterval, h_Cvar_SpawnMinDist, h_Cvar_Alone, h_Cvar_Hunter, ReturnBlood, Hud_Text;
ConVar h_Cvar_MaxProcessPerFrame, h_Cvar_NavAreaScanPerFrame, h_Cvar_StuckMaxCount, h_Cvar_SpawnDistMax;
ArrayList h_ArrayList_NearAreas, h_ArrayList_AvailableInfectedClasses, h_ArrayList_AllNavAreas;
ArrayList h_ArrayList_ValidSpawnPositions;
float g_f_NextRespawnTime = -1.0;

static bool g_b_FrameTaskLock = false;
static int g_i_ValidAreaScanIdx = 0;
static bool g_b_IsFindingSpawnArea = false;
static int g_i_StuckTickCount = 0;
int g_i_SiLimit = 0, g_i_InfectedStuckCount[MAX_CLIENTS] = {0}, g_i_TeleportQueueIndex = 0, g_i_MaxSpawnCount = 0;
int g_i_NearAreaScanIdx = 0;
int g_i_FirstSpawnRetry = 0;
int g_i_MaxProcessPerFrame = 15, g_i_NavAreaScanPerFrame = 400, g_i_StuckMaxCount = 50;
float g_f_SpawnDistMax = 1200.0;
float g_f_SpawnDistance = 0.0, g_f_SpawnInterval = 0.0, g_f_SpawnMinDistance = 0.0;
float g_f_InfectedLastPos[MAX_CLIENTS][3];
bool g_b_IsLateSpawn = false;

char g_sz_InfectedNames[][] = {"", "smoker", "boomer", "hunter", "spitter", "jockey", "charger"};

public void OnPluginStart() {
    h_ArrayList_NearAreas = new ArrayList();
    h_ArrayList_AvailableInfectedClasses = new ArrayList();
    h_ArrayList_AllNavAreas = new ArrayList();
    h_ArrayList_ValidSpawnPositions = new ArrayList(3);
    GetGamedata();
    RegisterConVars();
    HookGameEvents();
    LoadConVarValues();
}

public void OnPluginEnd()
{
    delete h_ArrayList_NearAreas;
    delete h_ArrayList_AvailableInfectedClasses;
    delete h_ArrayList_AllNavAreas;
    delete h_ArrayList_ValidSpawnPositions;
	delete hConf;
}

public void OnMapStart()
{
	if (SpawnCountdown_IsRunning())
	{
		SpawnCountdown_Stop();
	} 
    ResetPluginStatus(true);
	h_ArrayList_AllNavAreas.Clear();
	L4D_GetAllNavAreas(h_ArrayList_AllNavAreas);
    PrecacheInfectedModels();
	CreateTimer(3.0, Timer_ProcessSafeAreaNavAreas, _, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(0.5, Timer_CheckInfectedStuck, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

void RegisterConVars()
{
	Hud_Text = CreateConVar("Hud_Text", "0", "是否开启HUD", CVAR_FLAG, true, 0.0, true, 1.0);
	ReturnBlood = CreateConVar("ReturnBlood", "0", "是否开启杀特回血2HP", CVAR_FLAG, true, 0.0, true, 1.0);
	h_Cvar_Alone = CreateConVar("AloneMode", "0", "是否开启单人装逼模式", CVAR_FLAG, true, 0.0, true, 1.0);
	h_Cvar_Hunter = CreateConVar("HunterMode", "0", "是否开启Hunter模式", CVAR_FLAG, true, 0.0, true, 1.0);
    h_Cvar_SiLimit = CreateConVar("l4d_infected_limit", "6", "一次刷出多少特感", CVAR_FLAG, true, 0.0);
    h_Cvar_SiInterval = CreateConVar("versus_special_respawn_interval", "16.0", "对抗模式下刷特基础时间；以4特×1.5为基准，每增减1特倍率增减0.1", CVAR_FLAG, true, 0.0);
    h_Cvar_SpawnMinDist = CreateConVar("spawn_min_dist", "250.0", "刷特最近距离设定", CVAR_FLAG, true, 0.0);
    h_Cvar_SiInterval.AddChangeHook(OnSpawnIntervalChanged);
    h_Cvar_SiLimit.AddChangeHook(OnSiLimitChanged);
    h_Cvar_SpawnMinDist.AddChangeHook(OnSpawnMinDistChanged);
    h_Cvar_MaxProcessPerFrame = CreateConVar("max_process_per_frame", "30", "每帧处理候选刷点数量上限(性能)", CVAR_FLAG, true, 1.0, true, 100.0);
    h_Cvar_NavAreaScanPerFrame = CreateConVar("nav_area_scan_per_frame", "1000", "每帧扫描附近导航区域数量上限(性能)", CVAR_FLAG, true, 1.0, true, 2000.0);
    h_Cvar_StuckMaxCount = CreateConVar("stuck_max_count", "50", "特感卡住计数上限，超过后传送重刷", CVAR_FLAG, true, 1.0, true, 500.0);
    h_Cvar_SpawnDistMax = CreateConVar("spawn_dist_max", "1000.0", "刷特距离上限，超过后重置为默认距离", CVAR_FLAG, true, 100.0, true, 5000.0);
    h_Cvar_MaxProcessPerFrame.AddChangeHook(OnPerfCvarsChanged);
    h_Cvar_NavAreaScanPerFrame.AddChangeHook(OnPerfCvarsChanged);
    h_Cvar_StuckMaxCount.AddChangeHook(OnPerfCvarsChanged);
    h_Cvar_SpawnDistMax.AddChangeHook(OnPerfCvarsChanged);
}

void HookGameEvents() {
    HookEvent("player_death", OnPlayerDeath, EventHookMode_PostNoCopy);
    HookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);
    HookEvent("finale_win", OnRoundEnd, EventHookMode_PostNoCopy);
    HookEvent("map_transition", OnRoundEnd, EventHookMode_PostNoCopy);
    HookEvent("mission_lost", OnRoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_PostNoCopy);
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	g_f_NextRespawnTime = -1.0;
	if (SpawnCountdown_IsRunning())
	{
		SpawnCountdown_Stop();
	}
	// 离开安全区立即首刷，不经过 0.5 秒计时器粒度
	g_i_FirstSpawnRetry = 0;
	CreateTimer(0.0, Timer_InstantFirstSpawn, _, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}

// 离开安全区后尽快触发首刷；若游戏尚未标记离开状态则短暂重试，
// 多次失败后回退到原来的 0.5 秒计时器逻辑，保证不会漏刷。
public Action Timer_InstantFirstSpawn(Handle h_Timer)
{
	if (!L4D_HasAnySurvivorLeftSafeArea())
	{
		if (++g_i_FirstSpawnRetry <= 10)
		{
			CreateTimer(0.1, Timer_InstantFirstSpawn, _, TIMER_FLAG_NO_MAPCHANGE);
		}
		else
		{
			g_f_NextRespawnTime = GetGameTime();
		}
		return Plugin_Stop;
	}
	g_i_FirstSpawnRetry = 0;
	TriggerNewInfectedSpawn();
	return Plugin_Stop;
}

public Action Timer_ProcessSafeAreaNavAreas(Handle h_Timer) {
    for (int i = h_ArrayList_AllNavAreas.Length - 1; i >= 0; i--)
	{
        Address h_NavArea = h_ArrayList_AllNavAreas.Get(i);
        if ((L4D_GetNavArea_AttributeFlags(h_NavArea) & NAV_BASE_AVOID) || (L4D_GetNavArea_SpawnAttributes(h_NavArea) & NAV_SPAWN_CHECKPOINT))
		{
            h_ArrayList_AllNavAreas.Erase(i);
        }
    }
    return Plugin_Stop;
}

public void Event_PlayerHurt(Event event, const char[] name, bool dont_broadcast)
{
	if(!h_Cvar_Alone.BoolValue)
		return;
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if (IsValidSurvivor(attacker) && IsValidInfectedBot(victim) && GetEntProp(victim, Prop_Send, "m_zombieClass") == 1)
	{
		if( GetEntPropEnt(victim, Prop_Send, "m_tongueVictim") <= 0 )
			return;
		int damage = GetEventInt(event, "dmg_health");
		int health = GetEventInt(event, "health") - damage * 5;
		if (health < 1)
			health = 0;
		SetEntityHealth(victim, health);
	}
}

stock void FindSurvivorNearNavAreas()
{
    if (g_i_NearAreaScanIdx == 0)
	{
        h_ArrayList_NearAreas.Clear();
    }
    int i_ProcessedCount = 0;
    float f_SpawnPos[3], f_SurvivorPos[3];
    int i_TargetSurvivor = GetFirstValidSurvivor();
    while (g_i_NearAreaScanIdx < h_ArrayList_AllNavAreas.Length && i_ProcessedCount < g_i_NavAreaScanPerFrame)
    {
        Address h_NavArea = h_ArrayList_AllNavAreas.Get(g_i_NearAreaScanIdx);
		L4D_GetNavAreaCenter(h_NavArea, f_SpawnPos);
        for (int i_SurvivorIdx = 1; i_SurvivorIdx <= MaxClients; i_SurvivorIdx++)
		{
            if (!IsValidSurvivor(i_SurvivorIdx) || !IsPlayerAlive(i_SurvivorIdx)) continue;
            GetClientAbsOrigin(i_SurvivorIdx, f_SurvivorPos);
            float f_DistThreshold = (i_SurvivorIdx == i_TargetSurvivor) ? g_f_SpawnDistance : SURVIVOR_DIST_THRESHOLD;
            if (GetVectorDistance(f_SpawnPos, f_SurvivorPos) < f_DistThreshold)
            {
                h_ArrayList_NearAreas.Push(h_NavArea);
                break;
            }
        }
        g_i_NearAreaScanIdx++;
        i_ProcessedCount++;
    }
    if (g_i_NearAreaScanIdx >= h_ArrayList_AllNavAreas.Length)
	{
        g_i_NearAreaScanIdx = 0;
        g_b_FrameTaskLock = false;
        RequestFrame(StartFrameBasedSpawnAreaFilter);
    }
	else
	{
        RequestFrame(FindSurvivorNearNavAreas);
    }
}
// 校验：幸存者是否被控制（舌头/扑击/骑乘等）
stock bool IsSurvivorPinned(int client)
{
    return (GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0) ||
           (GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0) ||
           (GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0) ||
           (GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0) ||
           (GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0);
}
void StartFrameBasedSpawnAreaFilter() {
    g_i_ValidAreaScanIdx = 0;
    g_b_IsFindingSpawnArea = true;
    h_ArrayList_ValidSpawnPositions.Clear();
}

void StopFrameBasedSpawnAreaFilter() {
    g_b_IsFindingSpawnArea = false;
    g_i_ValidAreaScanIdx = 0;
    h_ArrayList_ValidSpawnPositions.Clear();
}

// 强制特感激进模式
public Action L4D_OnGetScriptValueInt(const char[] s_Key, int &i_RetVal) {
    if ((strcmp(s_Key, "cm_ShouldHurry", false) == 0 || strcmp(s_Key, "cm_AggressiveSpecials", false) == 0) && i_RetVal != 1) {
        i_RetVal = 1;
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

public void OnGameFrame()
{
	if (!g_b_IsFindingSpawnArea)
	{
		for (int i_Client = 1; i_Client <= MaxClients; i_Client++)
		{
			if (IsValidInfectedBot(i_Client) && IsPlayerAlive(i_Client))
			{
				if (GetEntityMoveType(i_Client) & MOVETYPE_LADDER)
				{
					
				}
				else
				{
					SDKCall(hInfectedAttackSurvivorTeam, i_Client);
				}
			}
		}
		return;
	}
    int i_ProcessedCount = 0;
    int i_NearAreasLen = h_ArrayList_NearAreas.Length;
	float f_SpawnPos[3], f_AreaSize[3];
	Address h_NavArea;
	float f_BaseSpawnDist = g_f_SpawnDistance + NAV_SEARCH_RANGE;
    while (g_i_ValidAreaScanIdx < i_NearAreasLen && i_ProcessedCount < g_i_MaxProcessPerFrame)
    {
        h_NavArea = h_ArrayList_NearAreas.Get(g_i_ValidAreaScanIdx);
		L4D_GetNavAreaCenter(h_NavArea, f_SpawnPos);
		L4D_GetNavAreaSize(h_NavArea, f_AreaSize);
		f_SpawnPos[0] = GetRandomFloat(f_SpawnPos[0] - f_AreaSize[0] * 0.5, f_SpawnPos[0] + f_AreaSize[0] * 0.5);
		f_SpawnPos[1] = GetRandomFloat(f_SpawnPos[1] - f_AreaSize[1] * 0.5, f_SpawnPos[1] + f_AreaSize[1] * 0.5);
		f_SpawnPos[2] = f_SpawnPos[2] + (f_AreaSize[2] < 0.0 ? -f_AreaSize[2] : f_AreaSize[2]) * 0.5 + 10.0;
		if(!IsTooCloseToExistingPositions(f_SpawnPos))
		{
			int i_ClosestSurvivor;
			float f_ClosestDist;
			if(!IsPositionVisibleToAllAliveSurvivor(f_SpawnPos, h_NavArea, i_ClosestSurvivor, f_ClosestDist, true) && i_ClosestSurvivor != -1)
			{
				Address h_SurvivorNavArea = L4D_GetLastKnownArea(i_ClosestSurvivor);
				if (L4D2_NavAreaBuildPath(h_NavArea, h_SurvivorNavArea, f_BaseSpawnDist, TEAM_INFECTED, false)  && !IsPositionStuck(f_SpawnPos))
				{
					h_ArrayList_ValidSpawnPositions.PushArray(f_SpawnPos, 3);
				}
			}
		}
		g_i_ValidAreaScanIdx++;
		i_ProcessedCount++;
    }
    if (g_i_ValidAreaScanIdx >= i_NearAreasLen)
	{
        if (g_i_MaxSpawnCount > 0 || g_i_TeleportQueueIndex > 0)
		{
            RequestFrame(ProcessInfectedSpawn);
        }
        g_b_IsFindingSpawnArea = false;
    }
}

public void ProcessInfectedSpawn()
{
    if (g_i_MaxSpawnCount + g_i_TeleportQueueIndex <= 0) {
        return;
    }
    while (h_ArrayList_ValidSpawnPositions.Length > 0 && (g_i_MaxSpawnCount + g_i_TeleportQueueIndex) > 0)
    {
        float f_SpawnPos[3];
        if (!GetRandomValidPositionFromCache(f_SpawnPos)) {
            break;
        }
        Address NavArea = L4D_GetNearestNavArea(f_SpawnPos, NAV_SEARCH_RANGE, false, false, false, TEAM_INFECTED);
		int i_DummyClient;
		float f_DummyDist;
        if (IsPositionVisibleToAllAliveSurvivor(f_SpawnPos, NavArea, i_DummyClient, f_DummyDist, true))
		{
            continue;
        }
		int i_InfectedType;
		if(h_Cvar_Hunter.BoolValue)
		{
			i_InfectedType = 3;
		}
		else
		{
			i_InfectedType = SelectRandomInfectedType();
		}
        int i_SpawnedClient = CreateInfected(g_sz_InfectedNames[i_InfectedType]);
        if (i_SpawnedClient == -1 || !IsClientInGame(i_SpawnedClient)) {
            continue;
        }
        if (g_i_TeleportQueueIndex > 0) {
            g_i_TeleportQueueIndex--;
        } else if (g_i_MaxSpawnCount > 0) {
            g_i_MaxSpawnCount--;
        }
        InitInfectedSpawnState(i_SpawnedClient, f_SpawnPos);
    }
    if ((g_i_MaxSpawnCount + g_i_TeleportQueueIndex) > 0) {
        AdjustSpawnDistanceAndRetry();
    }
}

void AdjustSpawnDistanceAndRetry()
{
    StopFrameBasedSpawnAreaFilter();
    if (g_f_SpawnDistance >= g_f_SpawnDistMax)
    {
        g_f_SpawnDistance = SPAWN_DIST_DEFAULT;
        if(!g_b_FrameTaskLock)
        {
            g_b_FrameTaskLock = true;
            RequestFrame(FindSurvivorNearNavAreas);
        }
    }
    else
    {
        g_f_SpawnDistance += SPAWN_DIST_STEP;
        StartFrameBasedSpawnAreaFilter();
        if(!g_b_FrameTaskLock)
        {
            g_b_FrameTaskLock = true;
            RequestFrame(FindSurvivorNearNavAreas);
        }
    }
}

static bool GetRandomValidPositionFromCache(float f_SpawnPos[3])
{
    int arrayLen = h_ArrayList_ValidSpawnPositions.Length;
    if (arrayLen == 0) return false;
    int i_RandomIdx = GetRandomInt(0, arrayLen - 1);
    h_ArrayList_ValidSpawnPositions.GetArray(i_RandomIdx, f_SpawnPos, 3);
    h_ArrayList_ValidSpawnPositions.Erase(i_RandomIdx);
    return true;
}

public Action Timer_CheckInfectedStuck(Handle h_Timer)
{
    if (g_b_IsLateSpawn && g_i_MaxSpawnCount <= 0 && g_f_NextRespawnTime < 0.0)
    {
		h_ArrayList_AvailableInfectedClasses.Clear();
		if (SpawnCountdown_IsRunning())
		{
			SpawnCountdown_Stop();
		}
		float totalWait = g_f_SpawnInterval * 1.4;
		if(Hud_Text.BoolValue)
		{
			SpawnCountdown_Start(totalWait);
		}
		g_f_NextRespawnTime = GetGameTime() + totalWait;
		if(Hud_Text.BoolValue)
		{
			SpawnCountdown_Start(totalWait);
		}
		g_f_NextRespawnTime = GetGameTime() + totalWait;
		g_b_IsLateSpawn = false;
    }
    g_i_StuckTickCount++;
    bool b_CheckDoors = (g_i_StuckTickCount % DOOR_CHECK_TICKS == 0);
    for (int i_Client = 1; i_Client <= MaxClients; i_Client++)
    {
        if (!IsValidInfectedBot(i_Client) || !IsPlayerAlive(i_Client) || IsInfectedPinningSomeone(i_Client))
        {
            g_i_InfectedStuckCount[i_Client] = 0;
            continue;
        }
        L4D_WarpToValidPositionIfStuck(i_Client);
        float f_CurrentPos[3];
        GetClientAbsOrigin(i_Client, f_CurrentPos);
		if (b_CheckDoors)
		{
			int i_DoorEnt = L4D_FindEntityByClassnameNearest("prop_door_rotating", f_CurrentPos, DOOR_DAMAGE_DIST);
			if (i_DoorEnt > 0)
			{
				SDKHooks_TakeDamage(i_DoorEnt, i_Client, i_Client, DOOR_DAMAGE, DOOR_DMG_TYPE, _, f_CurrentPos);
			}
		}
        Address h_SpawnArea = L4D_GetLastKnownArea(i_Client);
        bool b_IsStuck = (!IsInfectedVisible(f_CurrentPos, h_SpawnArea))
                      || GetVectorDistance(g_f_InfectedLastPos[i_Client], f_CurrentPos) < STUCK_MOVE_THRESHOLD;
        if (b_IsStuck)
            ProcessInfectedStuck(i_Client);
        else
            g_i_InfectedStuckCount[i_Client] = 0;
    }
	if (g_f_NextRespawnTime >= 0.0 && GetGameTime() >= g_f_NextRespawnTime)
	{
		g_f_NextRespawnTime = -1.0;
		TriggerNewInfectedSpawn();
	}
    return Plugin_Continue;
}

void ProcessInfectedStuck(int i_Client)
{
    if (g_i_InfectedStuckCount[i_Client] > g_i_StuckMaxCount)
	{
        g_f_SpawnDistance = SPAWN_DIST_DEFAULT;
        g_i_InfectedStuckCount[i_Client] = -1000;
        g_i_TeleportQueueIndex++;
        h_ArrayList_AvailableInfectedClasses.Push(GetEntProp(i_Client, Prop_Send, "m_zombieClass"));
		KickClient(i_Client);
        RequestFrame(StartFrameBasedSpawnAreaFilter);
    }
	else
	{
        g_i_InfectedStuckCount[i_Client] += STUCK_COUNT_STEP;
    }
}

void ResetPluginStatus(bool b_KickInfectedBots = false)
{
    g_b_FrameTaskLock = false;
	g_b_IsFindingSpawnArea = false;
    g_i_ValidAreaScanIdx = 0;
	g_i_NearAreaScanIdx = 0;
	g_i_MaxSpawnCount = 0;
    g_i_TeleportQueueIndex = 0;
	g_b_IsLateSpawn = false;
	g_f_NextRespawnTime = -1.0;
	g_i_FirstSpawnRetry = 0;
    h_ArrayList_NearAreas.Clear();
    h_ArrayList_AvailableInfectedClasses.Clear();
    h_ArrayList_ValidSpawnPositions.Clear();
	if (SpawnCountdown_IsRunning())
	{
		SpawnCountdown_Stop();
	}
	if (!b_KickInfectedBots)
		return;
    for (int i_Client = 1; i_Client <= MaxClients; i_Client++)
	{
        if (IsValidInfectedBot(i_Client))
		{
            g_i_InfectedStuckCount[i_Client] = 0;
            if (IsClientInGame(i_Client) && !IsClientInKickQueue(i_Client)) {
                KickClient(i_Client);
            }
        }
        if (!L4D_HasAnySurvivorLeftSafeArea() && IsValidSurvivor(i_Client) && !IsPlayerAlive(i_Client))
		{
            L4D_RespawnPlayer(i_Client);
        }
    }
}

void TriggerNewInfectedSpawn()
{
    if (!L4D_HasAnySurvivorLeftSafeArea())
	{
        g_b_IsLateSpawn = false;
        return;
    }
    g_i_TeleportQueueIndex = 0;
	g_b_IsLateSpawn = true;
	g_i_MaxSpawnCount = g_i_SiLimit - GetCurrentSpecialCount();
	g_f_SpawnDistance = SPAWN_DIST_DEFAULT;
	InitAvailableInfectedClasses();
	int totalCount = GetInGameSurvivorCount() + GetAllInfectedCount() + g_i_MaxSpawnCount;
	if (totalCount > TOTAL_ENTITY_LIMIT) {
		int exceed = totalCount - TOTAL_ENTITY_LIMIT;
		g_i_MaxSpawnCount = g_i_MaxSpawnCount - exceed;
	}

	if (g_i_MaxSpawnCount > 0 || g_i_TeleportQueueIndex > 0) {
		h_ArrayList_ValidSpawnPositions.Clear();
		if(!g_b_FrameTaskLock)
        {
            g_b_FrameTaskLock = true;
            RequestFrame(FindSurvivorNearNavAreas);
        }
	}
	if (SpawnCountdown_IsRunning())
	{
		SpawnCountdown_Stop();
	}
}

stock void InitAvailableInfectedClasses() {
    h_ArrayList_AvailableInfectedClasses.Clear();
    bool b_Alonemode = h_Cvar_Alone.BoolValue;    // 新增：实时读
    for (int i = 1; i <= 6; i++) {
        if (b_Alonemode && (i == 2 || i == 4))    // 新增：Alone 模式硬禁 boomer/spitter
            continue;
        int CurrentCount = GetInfectedCurrentCount(i);
        int MaxLimit = GetInfectedMaxLimit(i);
        int ArrayLimit = MaxLimit - CurrentCount;
        if (ArrayLimit <= 0) continue;
        for (int a = 1; a <= ArrayLimit; a++) {
            h_ArrayList_AvailableInfectedClasses.Push(i);
        }
    }
}

stock void InitInfectedSpawnState(int i_Client, float f_SpawnPos[3]) {
    g_f_InfectedLastPos[i_Client] = f_SpawnPos;
    TeleportEntity(i_Client, f_SpawnPos, NULL_VECTOR, NULL_VECTOR);
    L4D_WarpToValidPositionIfStuck(i_Client);
    g_i_InfectedStuckCount[i_Client] = 0;
    SDKCall(hInfectedAttackSurvivorTeam, i_Client);
}

stock void PrecacheInfectedModels() {
    PrecacheModelIfNeed(MODEL_SMOKER);
    PrecacheModelIfNeed(MODEL_BOOMER);
    PrecacheModelIfNeed(MODEL_HUNTER);
    PrecacheModelIfNeed(MODEL_SPITTER);
    PrecacheModelIfNeed(MODEL_JOCKEY);
    PrecacheModelIfNeed(MODEL_CHARGER);
}

stock void PrecacheModelIfNeed(const char[] sModelPath) {
    if (!IsModelPrecached(sModelPath)) {
        PrecacheModel(sModelPath, true);
    }
}

stock int SelectRandomInfectedType() {
    if (h_ArrayList_AvailableInfectedClasses == null || h_ArrayList_AvailableInfectedClasses.Length <= 0) {
        return 3;
    }

    int i_RandomIdx = GetRandomInt(0, h_ArrayList_AvailableInfectedClasses.Length - 1);
    int i_Type = h_ArrayList_AvailableInfectedClasses.Get(i_RandomIdx);
    if (i_Type == 2 || i_Type == 4)
	{
        i_RandomIdx = GetRandomInt(0, h_ArrayList_AvailableInfectedClasses.Length - 1);
        i_Type = h_ArrayList_AvailableInfectedClasses.Get(i_RandomIdx);
    }

    h_ArrayList_AvailableInfectedClasses.Erase(i_RandomIdx);
    return i_Type;
}

stock bool IsPositionVisibleToAllAliveSurvivor(const float f_TargetPos[3], Address h_NavArea, int &i_ClosestSurvivor, float &f_ClosestDist, bool b_CheckMinDist)
{
	i_ClosestSurvivor = -1;
	f_ClosestDist = 999999.0;
	float f_SurvivorPos[3], f_CheckPos[3];
    f_CheckPos = f_TargetPos;
    f_CheckPos[2] += SPAWN_Z_OFFSET;
    for (int i_Survivor = 1; i_Survivor <= MaxClients; i_Survivor++)
    {
        if (IsValidSurvivor(i_Survivor) && IsPlayerAlive(i_Survivor))
        {
            GetClientAbsOrigin(i_Survivor, f_SurvivorPos);
            float f_CurrDist = GetVectorDistance(f_TargetPos, f_SurvivorPos);
			if (f_CurrDist < f_ClosestDist)
			{
				f_ClosestDist = f_CurrDist;
				i_ClosestSurvivor = i_Survivor;
			}
            if (b_CheckMinDist && f_CurrDist < g_f_SpawnMinDistance)
                return true;
			if (f_CurrDist < g_f_SpawnDistMax && L4D2_IsVisibleToPlayer(i_Survivor, TEAM_SURVIVOR, TEAM_INFECTED, h_NavArea, f_CheckPos))
                return true;
        }
    }
	return false;
}

stock bool IsInfectedVisible(const float f_TargetPos[3], Address h_NavArea)
{
	int i_DummyClient;
	float f_DummyDist;
	return IsPositionVisibleToAllAliveSurvivor(f_TargetPos, h_NavArea, i_DummyClient, f_DummyDist, false);
}

stock bool IsPositionStuck(float f_Pos[3])
{
    float f_RayStart1[3], f_RayEnd1[3];
	f_RayStart1[0] = f_Pos[0] - 15.0; f_RayStart1[1] = f_Pos[1] + 15.0; f_RayStart1[2] = f_Pos[2] + 70.0;
	f_RayEnd1[0] = f_Pos[0] + 15.0; f_RayEnd1[1] = f_Pos[1] - 15.0; f_RayEnd1[2] = f_Pos[2] + 10.0;
    if (TraceRayForStuck(f_RayStart1, f_RayEnd1)) return true;
	float f_RayStart2[3], f_RayEnd2[3];
	f_RayStart2[0] = f_Pos[0] - 15.0; f_RayStart2[1] = f_Pos[1] - 15.0; f_RayStart2[2] = f_Pos[2] + 10.0;
	f_RayEnd2[0] = f_Pos[0] + 15.0; f_RayEnd2[1] = f_Pos[1] + 15.0; f_RayEnd2[2] = f_Pos[2] + 70.0;
    if (TraceRayForStuck(f_RayStart2, f_RayEnd2)) return true;
    return false;
}

stock bool TraceRayForStuck(float f_Start[3], float f_End[3]) {
    TR_TraceRayFilter(f_Start, f_End, MASK_NPCSOLID_BRUSHONLY, RayType_EndPoint, TraceFilter_IgnoreInvalid);
    return TR_DidHit();
}

stock bool TraceFilter_IgnoreInvalid(int i_Entity, int i_ContentsMask) {
    if (i_Entity <= MaxClients || !IsValidEntity(i_Entity)) return false;

    static char s_ClassName[20];
    GetEntityClassname(i_Entity, s_ClassName, sizeof(s_ClassName));
    if (strcmp(s_ClassName, "env_physics_blocker") == 0 && !IsValidPhysicsBlocker(i_Entity)) {
        return false;
    }
    return true;
}

stock bool IsTooCloseToExistingPositions(float f_NewPos[3])
{
    if (h_ArrayList_ValidSpawnPositions == null)
        return false;
    int i_ExistingCount = h_ArrayList_ValidSpawnPositions.Length;
    if (i_ExistingCount == 0)
        return false;
    float f_ExistingPos[3];
    for (int i = 0; i < i_ExistingCount; i++)
    {
        h_ArrayList_ValidSpawnPositions.GetArray(i, f_ExistingPos, 3);
        if (GetVectorDistance(f_NewPos, f_ExistingPos) < MIN_SPAWN_POS_DISTANCE)
            return true;
    }
    return false;
}

stock bool IsValidPhysicsBlocker(int i_Entity) {
    int i_BlockType = GetEntProp(i_Entity, Prop_Data, "m_nBlockType");
    return !(i_BlockType == 1 || i_BlockType == 2);
}
/*
static int GetFirstValidSurvivor() {
    int i_Survivor = L4D_GetHighestFlowSurvivor();
    if (IsValidSurvivor(i_Survivor) && IsPlayerAlive(i_Survivor) && !L4D_IsPlayerIncapacitated(i_Survivor) && !L4D_IsPlayerHangingFromLedge(i_Survivor)) {
        return i_Survivor;
    }
    return -1;
}
*/
static int GetFirstValidSurvivor() {
    int i_Best = -1;
    float f_BestFlow = -1.0;
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsValidSurvivor(i) || !IsPlayerAlive(i)) continue;
        float f_Flow = L4D2Direct_GetFlowDistance(i);
        if (f_Flow > f_BestFlow) {      // 与 GetLastFlowSurvivor 一致，flow 无效者自然跳过
            f_BestFlow = f_Flow;
            i_Best = i;
        }
    }
    return i_Best;
}

stock int GetCurrentSpecialCount() {
    int i_SpecialCount = 0;
    for (int i_Client = 1; i_Client <= MaxClients; i_Client++) {
        if (IsClientInGame(i_Client) && IsValidInfectedBot(i_Client) && IsPlayerAlive(i_Client)) {
            i_SpecialCount++;
        }
    }
    return i_SpecialCount;
}

stock int GetInGameSurvivorCount() {
    int count = 0;
    for (int i_Client = 1; i_Client <= MaxClients; i_Client++) {
        if (IsClientInGame(i_Client) && IsValidSurvivor(i_Client)) {
            count++;
        }
    }
    return count;
}

stock int GetAllInfectedCount() {
    int count = 0;
    for (int i_Client = 1; i_Client <= MaxClients; i_Client++) {
        if (IsClientInGame(i_Client) && IsValidInfectedBot(i_Client)) {
            count++;
        }
    }
    return count;
}

void OnSpawnIntervalChanged(ConVar h_Cvar, const char[] s_OldVal, const char[] s_NewVal) { LoadConVarValues(); }
void OnSiLimitChanged(ConVar h_Cvar, const char[] s_OldVal, const char[] s_NewVal) { g_i_SiLimit = h_Cvar_SiLimit.IntValue; }
void OnSpawnMinDistChanged(ConVar h_Cvar, const char[] s_OldVal, const char[] s_NewVal) { g_f_SpawnMinDistance = h_Cvar_SpawnMinDist.FloatValue; }
void OnPerfCvarsChanged(ConVar h_Cvar, const char[] s_OldVal, const char[] s_NewVal) { LoadConVarValues(); }

void LoadConVarValues() {
    g_f_SpawnInterval = h_Cvar_SiInterval.FloatValue;
    g_i_SiLimit = h_Cvar_SiLimit.IntValue;
    g_f_SpawnMinDistance = h_Cvar_SpawnMinDist.FloatValue;
    g_i_MaxProcessPerFrame = h_Cvar_MaxProcessPerFrame.IntValue;
    g_i_NavAreaScanPerFrame = h_Cvar_NavAreaScanPerFrame.IntValue;
    g_i_StuckMaxCount = h_Cvar_StuckMaxCount.IntValue;
    g_f_SpawnDistMax = h_Cvar_SpawnDistMax.FloatValue;
}

public void OnRoundStart(Event h_Event, const char[] s_Name, bool b_DontBroadcast)
{
    ResetPluginStatus();
    CreateTimer(1.0, Timer_ResetSafeRoomState, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ResetSafeRoomState(Handle h_Timer)
{
    ResetPluginStatus(true);
    return Plugin_Stop;
}

public void OnRoundEnd(Event h_Event, const char[] s_Name, bool b_DontBroadcast)
{
    ResetPluginStatus();
}

public void OnPlayerDeath(Event h_Event, const char[] s_Name, bool b_DontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(h_Event, "userid"));
	int killer  = GetClientOfUserId(GetEventInt(h_Event, "attacker"));
	if(IsValidInfectedBot(victim))
	{
		g_i_InfectedStuckCount[victim] = -1000;
		int i_ZombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
		if (i_ZombieClass != 4)
		{
			CreateTimer(KICK_BOT_DELAY, Timer_KickInfectedBot, GetClientUserId(victim));
		}
		if(IsValidSurvivor(killer))
		{
			if(ReturnBlood.BoolValue)
			{
				int maxhp = GetEntProp(killer, Prop_Data, "m_iMaxHealth");
				int targetHealth = GetEntProp(killer, Prop_Send, "m_iHealth");
				targetHealth += 2;
				if(targetHealth > maxhp)
				{
					targetHealth = maxhp;
				}
				if(!L4D_IsPlayerIncapacitated(killer))
				{
					SetEntProp(killer, Prop_Send, "m_iHealth", targetHealth);
				}
			}
		}
	}
}

public Action Timer_KickInfectedBot(Handle h_Timer, int i_UserId) {
	int i_Client = GetClientOfUserId(i_UserId);
	if (i_Client > 0 && IsClientInGame(i_Client) && !IsClientInKickQueue(i_Client) && IsFakeClient(i_Client)) {
		g_i_InfectedStuckCount[i_Client] = -1000;
		KickClient(i_Client);
	}
	return Plugin_Continue;
}

stock bool IsInfectedPinningSomeone(int i_Client) {
    if (!IsValidInfectedBot(i_Client)) return false;
    return GetEntPropEnt(i_Client, Prop_Send, "m_tongueVictim") > 0
        || GetEntPropEnt(i_Client, Prop_Send, "m_jockeyVictim") > 0
        || GetEntPropEnt(i_Client, Prop_Send, "m_pounceVictim") > 0
        || GetEntPropEnt(i_Client, Prop_Send, "m_pummelVictim") > 0
        || GetEntPropEnt(i_Client, Prop_Send, "m_carryVictim") > 0;
}

stock bool IsValidInfectedBot(int i_Client) {
    if (i_Client <= 0 || i_Client > MaxClients || !IsClientInGame(i_Client) || !IsFakeClient(i_Client)) {
        return false;
    }
    int i_ZombieClass = GetEntProp(i_Client, Prop_Send, "m_zombieClass");
    return GetClientTeam(i_Client) == TEAM_INFECTED && i_ZombieClass >= 1 && i_ZombieClass <= 6;
}

stock bool IsValidClient(int i_Client, bool b_CheckReplay = false) {
    if (i_Client <= 0 || i_Client > MaxClients || !IsClientInGame(i_Client)) return false;
    return b_CheckReplay ? (!IsClientSourceTV(i_Client) && !IsClientReplay(i_Client)) : true;
}

stock int GetInfectedMaxLimit(int i_Class) {
    char s_CvarName[16];
    Format(s_CvarName, 16, "z_%s_limit", g_sz_InfectedNames[i_Class]);
    ConVar h_Cvar = FindConVar(s_CvarName);
    return (h_Cvar != null) ? h_Cvar.IntValue : 0;
}

stock int GetInfectedCurrentCount(int i_Class) {
    int i_Count = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED && GetEntProp(i, Prop_Send, "m_zombieClass") == i_Class) {
            i_Count++;
        }
    }
    return i_Count;
}

stock bool IsValidSurvivor(int i_Client) {
    return IsValidClient(i_Client) && GetClientTeam(i_Client) == TEAM_SURVIVOR;
}

int CreateInfected(const char[] zomb) {
    int bot = -1;
    if (StrEqual(zomb, "smoker", false)) {
        bot = SDKCall(hCreateSmoker, "Smoker");
        if (IsValidClient(bot)) SetEntityModel(bot, MODEL_SMOKER);
    } else if (StrEqual(zomb, "boomer", false)) {
        bot = SDKCall(hCreateBoomer, "Boomer");
        if (IsValidClient(bot)) SetEntityModel(bot, MODEL_BOOMER);
    } else if (StrEqual(zomb, "hunter", false)) {
        bot = SDKCall(hCreateHunter, "Hunter");
        if (IsValidClient(bot)) SetEntityModel(bot, MODEL_HUNTER);
    } else if (StrEqual(zomb, "spitter", false)) {
        bot = SDKCall(hCreateSpitter, "Spitter");
        if (IsValidClient(bot)) SetEntityModel(bot, MODEL_SPITTER);
    } else if (StrEqual(zomb, "jockey", false)) {
        bot = SDKCall(hCreateJockey, "Jockey");
        if (IsValidClient(bot)) SetEntityModel(bot, MODEL_JOCKEY);
    } else if (StrEqual(zomb, "charger", false)) {
        bot = SDKCall(hCreateCharger, "Charger");
        if (IsValidClient(bot)) SetEntityModel(bot, MODEL_CHARGER);
    }

    if (IsValidClient(bot)) {
        ChangeClientTeam(bot, TEAM_INFECTED);
        SetEntProp(bot, Prop_Send, "m_usSolidFlags", 16);
        SetEntProp(bot, Prop_Send, "movetype", 2);
        SetEntProp(bot, Prop_Send, "deadflag", 0);
        SetEntProp(bot, Prop_Send, "m_lifeState", 1);
        SetEntProp(bot, Prop_Send, "m_iObserverMode", 0);
        SetEntProp(bot, Prop_Send, "m_iPlayerState", 0);
        SetEntProp(bot, Prop_Send, "m_zombieState", 0);
        DispatchSpawn(bot);
        ActivateEntity(bot);
    }
    return bot;
}

void GetGamedata() {
    char filePath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, filePath, sizeof(filePath), "gamedata/%s.txt", GAMEDATA);
    if (FileExists(filePath)) {
        hConf = LoadGameConfigFile(GAMEDATA);
    }
    PrepSDKCall();
}

void LoadStringFromAdddress(Address addr, char[] buffer, int maxlength) {
    int i = 0;
    while (i < maxlength) {
        char val = LoadFromAddress(addr + view_as<Address>(i), NumberType_Int8);
        if (val == 0) { buffer[i] = 0; break; }
        buffer[i] = val;
        i++;
    }
    buffer[maxlength - 1] = 0;
}

Handle PrepCreateBotCallFromAddress(Handle hSiFuncTrie, const char[] siName) {
    Address addr;
    StartPrepSDKCall(SDKCall_Static);
    if (!GetTrieValue(hSiFuncTrie, siName, addr) || !PrepSDKCall_SetAddress(addr)) {
        SetFailState("Unable to find NextBotCreatePlayer<%s> address in memory.", siName);
        return null;
    }
    PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
    PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
    return EndPrepSDKCall();
}

void PrepWindowsCreateBotCalls(Address jumpTableAddr) {
    Handle hInfectedFuncs = CreateTrie();
    for (int i = 0; i < 7; i++) {
        Address caseBase = jumpTableAddr + view_as<Address>(i * 12);
        Address siStringAddr = view_as<Address>(LoadFromAddress(caseBase + view_as<Address>(1), NumberType_Int32));
        static char siName[32];
        LoadStringFromAdddress(siStringAddr, siName, sizeof(siName));

        Address funcRefAddr = caseBase + view_as<Address>(6);
        int funcRelOffset = LoadFromAddress(funcRefAddr, NumberType_Int32);
        Address callOffsetBase = caseBase + view_as<Address>(10);
        Address nextBotCreatePlayerBotTAddr = callOffsetBase + view_as<Address>(funcRelOffset);

        SetTrieValue(hInfectedFuncs, siName, nextBotCreatePlayerBotTAddr);
    }

    hCreateSmoker = PrepCreateBotCallFromAddress(hInfectedFuncs, "Smoker");
    if (hCreateSmoker == null) { SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateSmoker); return; }
    hCreateBoomer = PrepCreateBotCallFromAddress(hInfectedFuncs, "Boomer");
    if (hCreateBoomer == null) { SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateBoomer); return; }
    hCreateHunter = PrepCreateBotCallFromAddress(hInfectedFuncs, "Hunter");
    if (hCreateHunter == null) { SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateHunter); return; }
    hCreateSpitter = PrepCreateBotCallFromAddress(hInfectedFuncs, "Spitter");
    if (hCreateSpitter == null) { SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateSpitter); return; }
    hCreateJockey = PrepCreateBotCallFromAddress(hInfectedFuncs, "Jockey");
    if (hCreateJockey == null) { SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateJockey); return; }
    hCreateCharger = PrepCreateBotCallFromAddress(hInfectedFuncs, "Charger");
    if (hCreateCharger == null) { SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateCharger); return; }
    delete hInfectedFuncs;
}

void PrepL4D2CreateBotCalls() {
    hCreateSpitter = PrepSDKCallForBot(NAME_CreateSpitter);
    if (hCreateSpitter == null) { SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateSpitter); return; }
    hCreateJockey = PrepSDKCallForBot(NAME_CreateJockey);
    if (hCreateJockey == null) { SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateJockey); return; }
    hCreateCharger = PrepSDKCallForBot(NAME_CreateCharger);
    if (hCreateCharger == null) { SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateCharger); return; }
}

void PrepL4D1CreateBotCalls() {
    hCreateSmoker = PrepSDKCallForBot(NAME_CreateSmoker);
    if (hCreateSmoker == null) { SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateSmoker); return; }
    hCreateBoomer = PrepSDKCallForBot(NAME_CreateBoomer);
    if (hCreateBoomer == null) { SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateBoomer); return; }
    hCreateHunter = PrepSDKCallForBot(NAME_CreateHunter);
    if (hCreateHunter == null) { SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateHunter); return; }
}

Handle PrepSDKCallForBot(const char[] botName) {
    StartPrepSDKCall(SDKCall_Static);
    if (!PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, botName)) {
        SetFailState("Unable to find %s signature in gamedata file.", botName);
        return null;
    }
    PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
    PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
    return EndPrepSDKCall();
}

void PrepSDKCall() {
    if (hConf == null) { SetFailState("Unable to find %s.txt gamedata.", GAMEDATA); return; }

    Address replaceWithBot = GameConfGetAddress(hConf, "NextBotCreatePlayerBot.jumptable");
    if(replaceWithBot != Address_Null && LoadFromAddress(replaceWithBot, NumberType_Int8) == 0x68) {
        PrepWindowsCreateBotCalls(replaceWithBot);
    } else {
        PrepL4D2CreateBotCalls();
        PrepL4D1CreateBotCalls();
    }

    StartPrepSDKCall(SDKCall_Entity);
    if (!PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, NAME_InfectedAttackSurvivorTeam)) {
        SetFailState("Unable to find %s signature in gamedata file.", NAME_InfectedAttackSurvivorTeam); return;
    }
    hInfectedAttackSurvivorTeam = EndPrepSDKCall();
    if (hInfectedAttackSurvivorTeam == null) {
        SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_InfectedAttackSurvivorTeam); return;
    }
}

CountdownTimer SpawnCountdownPointer()
{
    return L4D2Direct_GetScavengeRoundSetupTimer();
}

stock void SpawnCountdown_Start(float flDuration)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            ShowVGUIPanel(i, "ready_countdown", _, true);
        }
    }
    CTimer_Start(SpawnCountdownPointer(), flDuration);
}

stock bool SpawnCountdown_IsRunning()
{
    return CTimer_HasStarted(SpawnCountdownPointer());
}

stock void SpawnCountdown_Stop()
{
    CTimer_Invalidate(SpawnCountdownPointer());
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            ShowVGUIPanel(i, "ready_countdown", _, false);
        }
    }
}

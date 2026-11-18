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
const float SPAWN_DIST_DEFAULT = 500.0;
const float SPAWN_Z_OFFSET = 45.0;
const float CROUCH_SPAWN_Z_OFFSET = 25.0;
const float HIGH_SPAWN_HEIGHT = 100.0;
const float HIGH_PATH_COMPENSATION_MULT = 2.0;
const float HIGH_PATH_COMPENSATION_MAX = 500.0;
const int RECENT_SPAWN_HISTORY_SIZE = 24;
const float RECENT_SPAWN_RADIUS = 350.0;
const float RECENT_SPAWN_WEIGHT = 0.05;
const float BATCH_SPAWN_SEPARATION = 400.0;
const float LOW_SPAWN_WEIGHT = 0.20;
const float VERY_LOW_SPAWN_WEIGHT = 0.05;

const float SPAWN_DIST_STEP = 100.0;
const float RESPAWN_DELAY_MULT = 1.5;
const float KICK_BOT_DELAY = 0.2;
// 刷点 Flow 小于队尾生还者 Flow 时，视为整个队伍的地图流程后方。
const float FLOW_BEHIND_TOLERANCE = 0.0;

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
    version = "2026.11.18",
    url = "https://github.com/Caibiii/AnneServer"
};

Handle hConf = null;
static Handle hCreateSmoker = null, hCreateBoomer = null, hCreateHunter = null;
static Handle hCreateSpitter = null, hCreateJockey = null, hCreateCharger = null;
static Handle hInfectedAttackSurvivorTeam = null;

ConVar h_Cvar_SiLimit, h_Cvar_SiInterval, h_Cvar_SpawnMinDist, h_Cvar_Alone, h_Cvar_Hunter, h_Cvar_BackSpawnChance, ReturnBlood, Hud_Text;
ConVar h_Cvar_MaxProcessPerFrame, h_Cvar_NavAreaScanPerFrame, h_Cvar_PathBuildPerFrame, h_Cvar_StuckMaxCount, h_Cvar_SpawnDistMax;
ConVar h_Cvar_SvPressureMs, h_Cvar_SvCriticalMs, h_Cvar_SvRecoverMs, h_Cvar_SvRecoverDelay;
ArrayList h_ArrayList_NearAreas, h_ArrayList_AvailableInfectedClasses, h_ArrayList_AllNavAreas;
ArrayList h_ArrayList_ValidSpawnPositions;
ArrayList h_ArrayList_RecentSpawnPositions;
ArrayList h_ArrayList_BatchSpawnPositions;
StringMap h_Map_PathFailCache;
float g_f_NextRespawnTime = -1.0;

static bool g_b_FrameTaskLock = false;
static int g_i_ValidAreaScanIdx = 0;
static bool g_b_IsFindingSpawnArea = false;
static int g_i_StuckTickCount = 0;
int g_i_SiLimit = 0, g_i_InfectedStuckCount[MAX_CLIENTS] = {0}, g_i_TeleportQueueIndex = 0, g_i_MaxSpawnCount = 0;
int g_i_NearAreaScanIdx = 0;
int g_i_FirstSpawnRetry = 0;
int g_i_MaxProcessPerFrame = 15, g_i_NavAreaScanPerFrame = 400, g_i_PathBuildPerFrame = 20, g_i_StuckMaxCount = 50;
int g_i_DynamicPathBuildPerFrame = 20, g_i_DynamicNavAreaScanPerFrame = 800;
float g_f_SvPressureMs = 10.53, g_f_SvCriticalMs = 11.11, g_f_SvRecoverMs = 10.53, g_f_SvRecoverDelay = 1.0;
float g_f_LastGameFrameTime = 0.0, g_f_SmoothedFrameMs = 0.0, g_f_SvRecoveryStartTime = 0.0;
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
    h_ArrayList_RecentSpawnPositions = new ArrayList(3);
    h_ArrayList_BatchSpawnPositions = new ArrayList(3);
    h_Map_PathFailCache = new StringMap();
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
    delete h_ArrayList_RecentSpawnPositions;
    delete h_ArrayList_BatchSpawnPositions;
    delete h_Map_PathFailCache;
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
	h_Cvar_BackSpawnChance = CreateConVar("spawn_back_chance", "0.25", "正常模式地图流程后方刷特概率，每局随机0.3-0.8；单人/Hunter模式固定0.25", CVAR_FLAG, true, 0.0, true, 1.0);
    h_Cvar_SiLimit = CreateConVar("l4d_infected_limit", "6", "一次刷出多少特感", CVAR_FLAG, true, 0.0);
    h_Cvar_SiInterval = CreateConVar("versus_special_respawn_interval", "16.0", "对抗模式下刷特基础时间；以6特×1.5为基准，每增减1特倍率增减0.1", CVAR_FLAG, true, 0.0);
    h_Cvar_SpawnMinDist = CreateConVar("spawn_min_dist", "250.0", "刷特最近距离设定", CVAR_FLAG, true, 0.0);
    h_Cvar_SiInterval.AddChangeHook(OnSpawnIntervalChanged);
    h_Cvar_SiLimit.AddChangeHook(OnSiLimitChanged);
    h_Cvar_SpawnMinDist.AddChangeHook(OnSpawnMinDistChanged);
    h_Cvar_MaxProcessPerFrame = CreateConVar("max_process_per_frame", "20", "每帧处理候选刷点数量上限(性能)", CVAR_FLAG, true, 1.0, true, 100.0);
    h_Cvar_NavAreaScanPerFrame = CreateConVar("nav_area_scan_per_frame", "800", "每帧扫描附近导航区域数量上限(性能)", CVAR_FLAG, true, 1.0, true, 2000.0);
    h_Cvar_PathBuildPerFrame = CreateConVar("path_build_per_frame", "20", "每帧导航路径计算次数上限", CVAR_FLAG, true, 1.0, true, 100.0);
    h_Cvar_SvPressureMs = CreateConVar("spawn_sv_pressure_ms", "10.53", "服务器低于95FPS时每帧寻路固定降至5次(帧耗时毫秒)", CVAR_FLAG, true, 1.0, true, 200.0);
    h_Cvar_SvCriticalMs = CreateConVar("spawn_sv_critical_ms", "11.11", "服务器低于90FPS时每帧寻路固定降至1次(帧耗时毫秒)", CVAR_FLAG, true, 1.0, true, 200.0);
    h_Cvar_SvRecoverMs = CreateConVar("spawn_sv_recover_ms", "10.53", "服务器高于95FPS时恢复正常寻路次数(帧耗时毫秒)", CVAR_FLAG, true, 1.0, true, 200.0);
    h_Cvar_SvRecoverDelay = CreateConVar("spawn_sv_recover_delay", "0.5", "FPS持续高于95多少秒后恢复正常找位压力", CVAR_FLAG, true, 0.0, true, 60.0);
    h_Cvar_StuckMaxCount = CreateConVar("stuck_max_count", "50", "特感卡住计数上限，超过后传送重刷", CVAR_FLAG, true, 1.0, true, 500.0);
    h_Cvar_SpawnDistMax = CreateConVar("spawn_dist_max", "1000.0", "刷特距离上限，超过后重置为默认距离", CVAR_FLAG, true, 100.0, true, 5000.0);
    h_Cvar_MaxProcessPerFrame.AddChangeHook(OnPerfCvarsChanged);
    h_Cvar_NavAreaScanPerFrame.AddChangeHook(OnPerfCvarsChanged);
    h_Cvar_PathBuildPerFrame.AddChangeHook(OnPerfCvarsChanged);
    h_Cvar_SvPressureMs.AddChangeHook(OnPerfCvarsChanged);
    h_Cvar_SvCriticalMs.AddChangeHook(OnPerfCvarsChanged);
    h_Cvar_SvRecoverMs.AddChangeHook(OnPerfCvarsChanged);
    h_Cvar_SvRecoverDelay.AddChangeHook(OnPerfCvarsChanged);
    h_Cvar_StuckMaxCount.AddChangeHook(OnPerfCvarsChanged);
    h_Cvar_SpawnDistMax.AddChangeHook(OnPerfCvarsChanged);
}

void HookGameEvents() {
    HookEvent("player_death", OnPlayerDeath, EventHookMode_PostNoCopy);
    HookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);
    HookEvent("finale_win", OnRoundEnd, EventHookMode_PostNoCopy);
    HookEvent("map_transition", OnRoundEnd, EventHookMode_PostNoCopy);
    HookEvent("mission_lost", OnRoundEnd, EventHookMode_PostNoCopy);
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
        if (h_NavArea == Address_Null)
		{
			h_ArrayList_AllNavAreas.Erase(i);
			continue;
		}
        if ((L4D_GetNavArea_AttributeFlags(h_NavArea) & NAV_BASE_AVOID) || L4D_GetNavArea_SpawnAttributes(h_NavArea) & NAV_SPAWN_CHECKPOINT || L4D_NavArea_GetElevator(h_NavArea) > 0)
		{
            h_ArrayList_AllNavAreas.Erase(i);
			
        }
    }
    return Plugin_Stop;
}

stock void FindSurvivorNearNavAreas()
{
    if (g_i_NearAreaScanIdx == 0)
	{
        h_ArrayList_NearAreas.Clear();
    }
    int i_ProcessedCount = 0;
    float f_SpawnPos[3];
    int i_TargetSurvivor = GetFirstValidSurvivor();
    int i_Survivors[MAX_CLIENTS], i_SurvivorCount = 0;
    float f_SurvivorPositions[MAX_CLIENTS][3];
    for (int i_Survivor = 1; i_Survivor <= MaxClients; i_Survivor++)
	{
		if (!IsValidSurvivor(i_Survivor) || !IsPlayerAlive(i_Survivor) || IsSurvivorPinned(i_Survivor)) continue;
		i_Survivors[i_SurvivorCount] = i_Survivor;
		GetClientAbsOrigin(i_Survivor, f_SurvivorPositions[i_SurvivorCount]);
		i_SurvivorCount++;
	}
    while (g_i_NearAreaScanIdx < h_ArrayList_AllNavAreas.Length && i_ProcessedCount < g_i_DynamicNavAreaScanPerFrame)
    {
        Address h_NavArea = h_ArrayList_AllNavAreas.Get(g_i_NearAreaScanIdx);
        if (h_NavArea == Address_Null)
		{
			g_i_NearAreaScanIdx++;
			i_ProcessedCount++;
			continue;
		}
		L4D_GetNavAreaCenter(h_NavArea, f_SpawnPos);
        for (int i_SurvivorIdx = 0; i_SurvivorIdx < i_SurvivorCount; i_SurvivorIdx++)
		{
            int i_Survivor = i_Survivors[i_SurvivorIdx];
            float f_DistThreshold = (i_Survivor == i_TargetSurvivor) ? g_f_SpawnDistance : SURVIVOR_DIST_THRESHOLD;
            if (GetVectorDistance(f_SpawnPos, f_SurvivorPositions[i_SurvivorIdx]) < f_DistThreshold)
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

bool IsCachedPathFailure(Address h_NavArea, Address h_SurvivorNavArea, float f_PathDist)
{
	char s_PathKey[32];
	Format(s_PathKey, sizeof(s_PathKey), "%d:%d", h_NavArea, h_SurvivorNavArea);
	float f_CachedFailDist;
	return h_Map_PathFailCache.GetValue(s_PathKey, f_CachedFailDist) && f_CachedFailDist >= f_PathDist;
}

void RememberPathFailure(Address h_NavArea, Address h_SurvivorNavArea, float f_PathDist)
{
	char s_PathKey[32];
	Format(s_PathKey, sizeof(s_PathKey), "%d:%d", h_NavArea, h_SurvivorNavArea);
	float f_CachedFailDist;
	if (!h_Map_PathFailCache.GetValue(s_PathKey, f_CachedFailDist) || f_PathDist > f_CachedFailDist)
	{
		h_Map_PathFailCache.SetValue(s_PathKey, f_PathDist);
	}
}

void UpdateAdaptivePathPressure()
{
	float f_Now = GetEngineTime();
	if (g_f_LastGameFrameTime > 0.0)
	{
		float f_FrameMs = (f_Now - g_f_LastGameFrameTime) * 1000.0;
		if (f_FrameMs > 0.0 && f_FrameMs < 250.0)
		{
			g_f_SmoothedFrameMs = (g_f_SmoothedFrameMs <= 0.0) ? f_FrameMs : g_f_SmoothedFrameMs * 0.8 + f_FrameMs * 0.2;
			if (g_f_SmoothedFrameMs > g_f_SvCriticalMs)
			{
				g_f_SvRecoveryStartTime = 0.0;
				g_i_DynamicNavAreaScanPerFrame = 400;
				if (g_i_DynamicPathBuildPerFrame != 1)
				{
					g_i_DynamicPathBuildPerFrame = 1;
				}
			}
			else if (g_f_SmoothedFrameMs > g_f_SvPressureMs)
			{
				g_f_SvRecoveryStartTime = 0.0;
				g_i_DynamicNavAreaScanPerFrame = 400;
				if (g_i_DynamicPathBuildPerFrame != 5)
				{
					g_i_DynamicPathBuildPerFrame = 5;
				}
			}
			else if (g_f_SmoothedFrameMs < g_f_SvRecoverMs)
			{
				if (g_i_DynamicPathBuildPerFrame != g_i_PathBuildPerFrame || g_i_DynamicNavAreaScanPerFrame != g_i_NavAreaScanPerFrame)
				{
					if (g_f_SvRecoveryStartTime <= 0.0)
					{
						g_f_SvRecoveryStartTime = f_Now;
					}
					else if (f_Now - g_f_SvRecoveryStartTime >= g_f_SvRecoverDelay)
					{
						g_i_DynamicPathBuildPerFrame = g_i_PathBuildPerFrame;
						g_i_DynamicNavAreaScanPerFrame = g_i_NavAreaScanPerFrame;
						g_f_SvRecoveryStartTime = 0.0;
					}
				}
				else
				{
					g_f_SvRecoveryStartTime = 0.0;
				}
			}
			else
			{
				g_f_SvRecoveryStartTime = 0.0;
			}
		}
	}
	g_f_LastGameFrameTime = f_Now;
}

public void OnGameFrame()
{
	UpdateAdaptivePathPressure();
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
    int i_PathBuildCount = 0;
    int i_NearAreasLen = h_ArrayList_NearAreas.Length;
	float f_SpawnPos[3], f_AreaSize[3];
	Address h_NavArea;
	float f_BaseSpawnDist;
	switch (GetRandomInt(1, 2))
	{
		case 1:
		{
			f_BaseSpawnDist = g_f_SpawnDistMax;
		}
		case 2:
		{
			f_BaseSpawnDist = g_f_SpawnDistance + NAV_SEARCH_RANGE;
		}
		default:
		{
			f_BaseSpawnDist = g_f_SpawnDistance;
		}
	}
    while (g_i_ValidAreaScanIdx < i_NearAreasLen && i_ProcessedCount < g_i_MaxProcessPerFrame)
    {
        h_NavArea = h_ArrayList_NearAreas.Get(g_i_ValidAreaScanIdx);
        if (h_NavArea == Address_Null)
		{
			g_i_ValidAreaScanIdx++;
			i_ProcessedCount++;
			continue;
		}
		L4D_GetNavAreaCenter(h_NavArea, f_SpawnPos);
		L4D_GetNavAreaSize(h_NavArea, f_AreaSize);
		f_SpawnPos[0] = GetRandomFloat(f_SpawnPos[0] - f_AreaSize[0] * 0.5, f_SpawnPos[0] + f_AreaSize[0] * 0.5);
		f_SpawnPos[1] = GetRandomFloat(f_SpawnPos[1] - f_AreaSize[1] * 0.5, f_SpawnPos[1] + f_AreaSize[1] * 0.5);
		f_SpawnPos[2] = f_SpawnPos[2] + (f_AreaSize[2] < 0.0 ? -f_AreaSize[2] : f_AreaSize[2]) * 0.5 + 10.0;
		if(!IsTooCloseToExistingPositions(f_SpawnPos))
		{
			int i_ClosestSurvivor;
			float f_ClosestDist;
			if(!IsSpawnPositionVisible(f_SpawnPos, h_NavArea, i_ClosestSurvivor, f_ClosestDist) && i_ClosestSurvivor != -1)
			{
				if (!L4D_IsPlayerHangingFromLedge(i_ClosestSurvivor) && !L4D_IsPlayerIncapacitated(i_ClosestSurvivor) && !IsSurvivorPinned(i_ClosestSurvivor)
					&& i_PathBuildCount < g_i_DynamicPathBuildPerFrame)
				{
					Address h_SurvivorNavArea = L4D_GetLastKnownArea(i_ClosestSurvivor);
					float f_PathDist = GetSpawnPathDistance(f_SpawnPos, i_ClosestSurvivor, f_BaseSpawnDist);
					bool b_PathFound = false;
					if (h_SurvivorNavArea != Address_Null && !IsCachedPathFailure(h_NavArea, h_SurvivorNavArea, f_PathDist))
					{
						b_PathFound = L4D2_NavAreaBuildPath(h_NavArea, h_SurvivorNavArea, f_PathDist, TEAM_INFECTED, false);
						i_PathBuildCount++;
						if (!b_PathFound)
						{
							RememberPathFailure(h_NavArea, h_SurvivorNavArea, f_PathDist);
						}
					}
					if (b_PathFound)
					{
						h_ArrayList_ValidSpawnPositions.PushArray(f_SpawnPos, 3);
					}
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
        if (IsSpawnPositionVisible(f_SpawnPos, NavArea, i_DummyClient, f_DummyDist) || IsPositionStuck(f_SpawnPos))
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
        RememberSpawnPosition(f_SpawnPos);
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
    int i_ArrayLen = h_ArrayList_ValidSpawnPositions.Length;
    if (i_ArrayLen == 0) return false;

    bool b_RequireSeparation = false;
    float f_CandidatePos[3];
    for (int i = 0; i < i_ArrayLen; i++)
    {
        h_ArrayList_ValidSpawnPositions.GetArray(i, f_CandidatePos, 3);
        if (IsAwayFromCurrentBatch(f_CandidatePos))
        {
            b_RequireSeparation = true;
            break;
        }
    }

    float f_TotalWeight = 0.0;
    for (int i = 0; i < i_ArrayLen; i++)
    {
        h_ArrayList_ValidSpawnPositions.GetArray(i, f_CandidatePos, 3);
        if (b_RequireSeparation && !IsAwayFromCurrentBatch(f_CandidatePos)) continue;
        f_TotalWeight += GetSpawnPositionWeight(f_CandidatePos);
    }

    float f_RandomWeight = GetRandomFloat(0.0, f_TotalWeight);
    int i_RandomIdx = -1;
    for (int i = 0; i < i_ArrayLen; i++)
    {
        h_ArrayList_ValidSpawnPositions.GetArray(i, f_CandidatePos, 3);
        if (b_RequireSeparation && !IsAwayFromCurrentBatch(f_CandidatePos)) continue;
        f_RandomWeight -= GetSpawnPositionWeight(f_CandidatePos);
        if (f_RandomWeight <= 0.0)
        {
            i_RandomIdx = i;
            break;
        }
    }

    if (i_RandomIdx == -1) return false;
    h_ArrayList_ValidSpawnPositions.GetArray(i_RandomIdx, f_SpawnPos, 3);
    h_ArrayList_ValidSpawnPositions.Erase(i_RandomIdx);
    return true;
}

static bool IsAwayFromCurrentBatch(const float f_SpawnPos[3])
{
    float f_BatchPos[3];
    for (int i = 0; i < h_ArrayList_BatchSpawnPositions.Length; i++)
    {
        h_ArrayList_BatchSpawnPositions.GetArray(i, f_BatchPos, 3);
        if (GetVectorDistance(f_SpawnPos, f_BatchPos) < BATCH_SPAWN_SEPARATION)
            return false;
    }
    return true;
}

static float GetSpawnPositionWeight(const float f_SpawnPos[3])
{
    float f_Weight = 1.0;
    float f_SurvivorPos[3];
    float f_ClosestDist = 999999.0;
    float f_ClosestSurvivorZ = f_SpawnPos[2];
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsValidSurvivor(i) || !IsPlayerAlive(i)) continue;
        GetClientAbsOrigin(i, f_SurvivorPos);
        float f_Dist = GetVectorDistance(f_SpawnPos, f_SurvivorPos);
        if (f_Dist < f_ClosestDist)
        {
            f_ClosestDist = f_Dist;
            f_ClosestSurvivorZ = f_SurvivorPos[2];
        }
    }

    float f_HeightDiff = f_SpawnPos[2] - f_ClosestSurvivorZ;
    if (f_HeightDiff < -250.0)
        f_Weight = VERY_LOW_SPAWN_WEIGHT;
    else if (f_HeightDiff < -80.0)
        f_Weight = LOW_SPAWN_WEIGHT;

    float f_RecentPos[3];
    for (int i = 0; i < h_ArrayList_RecentSpawnPositions.Length; i++)
    {
        h_ArrayList_RecentSpawnPositions.GetArray(i, f_RecentPos, 3);
        if (GetVectorDistance(f_SpawnPos, f_RecentPos) < RECENT_SPAWN_RADIUS)
        {
            f_Weight *= RECENT_SPAWN_WEIGHT;
            break;
        }
    }
    return f_Weight;
}

static void RememberSpawnPosition(const float f_SpawnPos[3])
{
    h_ArrayList_BatchSpawnPositions.PushArray(f_SpawnPos, 3);
    h_ArrayList_RecentSpawnPositions.PushArray(f_SpawnPos, 3);
    if (h_ArrayList_RecentSpawnPositions.Length > RECENT_SPAWN_HISTORY_SIZE)
        h_ArrayList_RecentSpawnPositions.Erase(0);
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

		float delayMultiplier = RESPAWN_DELAY_MULT + float(g_i_SiLimit - 6) * 0.1;
		float totalWait = g_f_SpawnInterval * delayMultiplier;
		if(totalWait < 1.0)
			totalWait = 1.0;
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
		int i_DoorEnt = L4D_FindEntityByClassnameNearest("prop_door_rotating", f_CurrentPos, DOOR_DAMAGE_DIST);
		if (i_DoorEnt > 0)
		{
			SDKHooks_TakeDamage(i_DoorEnt, i_Client, i_Client, DOOR_DAMAGE, DOOR_DMG_TYPE, _, f_CurrentPos);
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
    h_ArrayList_RecentSpawnPositions.Clear();
    h_ArrayList_BatchSpawnPositions.Clear();
    h_Map_PathFailCache.Clear();
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
    h_ArrayList_BatchSpawnPositions.Clear();
    h_Map_PathFailCache.Clear();
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

stock bool IsSpawnPositionVisible(const float f_TargetPos[3], Address h_NavArea, int &i_ClosestSurvivor, float &f_ClosestDist)
{
    if (!IsPositionVisibleToAllAliveSurvivor(f_TargetPos, h_NavArea, i_ClosestSurvivor, f_ClosestDist, true))
        return false;
    if (i_ClosestSurvivor == -1) return true;

    float f_SurvivorPos[3];
    GetClientAbsOrigin(i_ClosestSurvivor, f_SurvivorPos);
    if (f_TargetPos[2] - f_SurvivorPos[2] < HIGH_SPAWN_HEIGHT)
        return true;

    return IsPositionVisibleToAllAliveSurvivor(f_TargetPos, h_NavArea, i_ClosestSurvivor, f_ClosestDist, true, CROUCH_SPAWN_Z_OFFSET);
}

stock float GetSpawnPathDistance(const float f_SpawnPos[3], int i_Survivor, float f_BaseDist)
{
    float f_SurvivorPos[3];
    GetClientAbsOrigin(i_Survivor, f_SurvivorPos);
    float f_HeightDiff = f_SpawnPos[2] - f_SurvivorPos[2];
    if (f_HeightDiff < HIGH_SPAWN_HEIGHT) return f_BaseDist;

    float f_Compensation = f_HeightDiff * HIGH_PATH_COMPENSATION_MULT;
    if (f_Compensation > HIGH_PATH_COMPENSATION_MAX)
        f_Compensation = HIGH_PATH_COMPENSATION_MAX;
    return f_BaseDist + f_Compensation;
}

stock bool IsPositionVisibleToAllAliveSurvivor(const float f_TargetPos[3], Address h_NavArea, int &i_ClosestSurvivor, float &f_ClosestDist, bool b_CheckMinDist, float f_ZOffset = SPAWN_Z_OFFSET)
{
	i_ClosestSurvivor = -1;
	f_ClosestDist = 999999.0;
	float f_SurvivorPos[3], f_CheckPos[3];
    f_CheckPos = f_TargetPos;
    f_CheckPos[2] += f_ZOffset;
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
        if (L4D_IsPlayerIncapacitated(i) || L4D_IsPlayerHangingFromLedge(i)) continue;
        float f_Flow = L4D2Direct_GetFlowDistance(i);
        if (f_Flow > f_BestFlow) {      // 与 GetLastFlowSurvivor 一致，flow 无效者自然跳过
            f_BestFlow = f_Flow;
            i_Best = i;
        }
    }
    return i_Best;
}

// 返回地图 Flow 最低的有效存活生还者，即走在队伍最后的人。
static int GetLastFlowSurvivor()
{
	int i_TrailingSurvivor = -1;
	float f_LowestFlow = 999999.0;
	for (int i_Survivor = 1; i_Survivor <= MaxClients; i_Survivor++)
	{
		if (!IsValidSurvivor(i_Survivor) || !IsPlayerAlive(i_Survivor)
			|| L4D_IsPlayerIncapacitated(i_Survivor) || L4D_IsPlayerHangingFromLedge(i_Survivor))
		{
			continue;
		}
		float f_Flow = L4D2Direct_GetFlowDistance(i_Survivor);
		if (f_Flow > 0.0 && f_Flow < f_LowestFlow)
		{
			f_LowestFlow = f_Flow;
			i_TrailingSurvivor = i_Survivor;
		}
	}
	return i_TrailingSurvivor;
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
    g_i_PathBuildPerFrame = h_Cvar_PathBuildPerFrame.IntValue;
    g_i_DynamicPathBuildPerFrame = g_i_PathBuildPerFrame;
    g_i_DynamicNavAreaScanPerFrame = g_i_NavAreaScanPerFrame;
    g_f_SvPressureMs = h_Cvar_SvPressureMs.FloatValue;
    g_f_SvCriticalMs = h_Cvar_SvCriticalMs.FloatValue;
    g_f_SvRecoverMs = h_Cvar_SvRecoverMs.FloatValue;
    g_f_SvRecoverDelay = h_Cvar_SvRecoverDelay.FloatValue;
    g_f_SvRecoveryStartTime = 0.0;
    g_i_StuckMaxCount = h_Cvar_StuckMaxCount.IntValue;
    g_f_SpawnDistMax = h_Cvar_SpawnDistMax.FloatValue;
}

public void OnRoundStart(Event h_Event, const char[] s_Name, bool b_DontBroadcast)
{
    ResetPluginStatus();
	h_Cvar_BackSpawnChance.FloatValue = GetRandomFloat(0.25, 0.5);
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

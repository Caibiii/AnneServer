#pragma semicolon 1
#pragma tabsize 0
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
// 核心宏定义（按功能分类，便于维护）
#undef REQUIRE_PLUGIN
#define CVAR_FLAG FCVAR_NOTIFY
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define NAV_SEARCH_RANGE 250.0
#define SPAWN_DISTANCE_OFFSET 100.0
#define MIN_SPAWN_POS_DISTANCE 100.0
#define MAX_CLIENTS MAXPLAYERS + 1
#define TOTAL_ENTITY_LIMIT 28
#define GAMEDATA "spawn_infected_nolimit"

// 模型路径定义
#define MODEL_SMOKER "models/infected/smoker.mdl"
#define MODEL_BOOMER "models/infected/boomer.mdl"
#define MODEL_HUNTER "models/infected/hunter.mdl"
#define MODEL_SPITTER "models/infected/spitter.mdl"
#define MODEL_JOCKEY "models/infected/jockey.mdl"
#define MODEL_CHARGER "models/infected/charger.mdl"

// 性能控制常量（集中配置，便于调整）
const int MAX_PROCESS_PER_FRAME = 15;
const int MAX_TRIES_PER_NAVAREA = 1;
const float SURVIVOR_DIST_THRESHOLD = 400.0;
const float STUCK_MOVE_THRESHOLD = 100.0;
const int STUCK_MAX_COUNT = 50;
const int STUCK_COUNT_STEP = 5;
const float SPAWN_DIST_DEFAULT = 700.0;
const float SPAWN_DIST_MAX = 1200.0;
const float SPAWN_Z_OFFSET = 45.0;

// 签名定义（按特感类型分组）
#define NAME_CreateSmoker "NextBotCreatePlayerBot<Smoker>"
#define NAME_CreateBoomer "NextBotCreatePlayerBot<Boomer>"
#define NAME_CreateHunter "NextBotCreatePlayerBot<Hunter>"
#define NAME_CreateSpitter "NextBotCreatePlayerBot<Spitter>"
#define NAME_CreateJockey "NextBotCreatePlayerBot<Jockey>"
#define NAME_CreateCharger "NextBotCreatePlayerBot<Charger>"
#define NAME_CreateTank "NextBotCreatePlayerBot<Tank>"
#define NAME_InfectedAttackSurvivorTeam "Infected::AttackSurvivorTeam"
// 插件基础信息
public Plugin myinfo = {
    name = "Direct InfectedSpawn",
    author = "Caibiii",
    description = "特感刷新控制，传送落后特感",
    version = "2026.01.01修改（修复内存错误+性能优化）",
    url = "https://github.com/Caibiii/AnneServer"
};

// 全局句柄（按类型分组）
Handle hConf = null;
static Handle hCreateSmoker = null, hCreateBoomer = null, hCreateHunter = null;
static Handle hCreateSpitter = null, hCreateJockey = null, hCreateCharger = null, hCreateTank = null;
static Handle hInfectedAttackSurvivorTeam = null;

ConVar h_Cvar_SiLimit, h_Cvar_SiInterval, h_Cvar_SpawnMinDist, h_Cvar_Alone, h_Cvar_Hunter, ReturnBlood, Hud_Text;
ArrayList h_ArrayList_NearAreas, h_ArrayList_AvailableInfectedClasses, h_ArrayList_AllNavAreas;
ArrayList h_RandomIndices, h_ArrayList_ValidSpawnPositions;
Handle h_SingleRespawnTimer = INVALID_HANDLE;
// 全局变量（前缀区分类型，命名明确功能）
static bool g_b_FrameTaskLock = false;
static int g_i_CurrentNavAreaIndex = 0;
static bool g_b_IsFindingSpawnArea = false;
int g_i_SiLimit = 0, g_i_InfectedStuckCount[MAX_CLIENTS] = {0}, g_i_TeleportQueueIndex = 0, g_i_MaxSpawnCount = 0, g_i_CurrentNavAreaIdx = 0;
float g_f_SpawnDistance = 0.0, g_f_SpawnInterval = 0.0, g_f_SpawnMinDistance = 0.0;
float g_f_InfectedLastPos[MAX_CLIENTS][3];
bool g_b_IsLateSpawn = false;

// 缓存数组（复用避免重复创建）
float g_f_Cache_SpawnPos[3], g_f_Cache_SurvivorPos[3], g_f_Cache_OriginalZ[3];

// 特感名称映射（与类型索引对应）
char g_sz_InfectedNames[][] = {"", "smoker", "boomer", "hunter", "spitter", "jockey", "charger"};

// 插件启动初始化（顺序：数组→配置→变量→钩子→命令）
public void OnPluginStart() {
    h_ArrayList_NearAreas = new ArrayList();
    h_ArrayList_AvailableInfectedClasses = new ArrayList();
    h_ArrayList_AllNavAreas = new ArrayList();
    h_RandomIndices = new ArrayList();
    h_ArrayList_ValidSpawnPositions = new ArrayList(3);
    GetGamedata();
    RegisterConVars();
    HookGameEvents();
    LoadConVarValues();
}

// 插件卸载（释放资源）
public void OnPluginEnd() 
{
    delete h_ArrayList_NearAreas;
    delete h_ArrayList_AvailableInfectedClasses;
    delete h_ArrayList_AllNavAreas;
    delete h_RandomIndices;
    delete h_ArrayList_ValidSpawnPositions;
}

// 地图加载初始化
public void OnMapStart() 
{
	// 关闭VGUI倒计时
	if (SpawnCountdown_IsRunning())
	{
		SpawnCountdown_Stop();
	}
    // 新增：换图强制清空所有计时器，杜绝跨图残留
    if (h_SingleRespawnTimer != INVALID_HANDLE)
    {
        KillTimer(h_SingleRespawnTimer);
        h_SingleRespawnTimer = INVALID_HANDLE;
    }
    // 遍历并清理全局重复计时器
    // 原有代码不变
    ResetPluginStatus();
	h_ArrayList_AllNavAreas.Clear();
	L4D_GetAllNavAreas(h_ArrayList_AllNavAreas);
    PrecacheInfectedModels();
	CreateTimer(3.0, Timer_ProcessSafeAreaNavAreas);
	CreateTimer(0.5, Timer_CheckInfectedStuck, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE); 
}

// 注册控制台变量（集中管理，绑定回调）
void RegisterConVars() 
{
	Hud_Text = CreateConVar("Hud_Text", "0", "是否开启HUD", CVAR_FLAG, true, 0.0, true, 1.0);
	ReturnBlood = CreateConVar("ReturnBlood", "0", "是否开启杀特回血2HP", CVAR_FLAG, true, 0.0, true, 1.0);
	h_Cvar_Alone = CreateConVar("AloneMode", "0", "是否开启单人装逼模式", CVAR_FLAG, true, 0.0, true, 1.0);
	h_Cvar_Hunter = CreateConVar("HunterMode", "0", "是否开启Hunter模式", CVAR_FLAG, true, 0.0, true, 1.0);
    h_Cvar_SiLimit = CreateConVar("l4d_infected_limit", "6", "一次刷出多少特感", CVAR_FLAG, true, 0.0);
    h_Cvar_SiInterval = CreateConVar("versus_special_respawn_interval", "16.0", "对抗模式下刷特时间控制", CVAR_FLAG, true, 0.0);
    h_Cvar_SpawnMinDist = CreateConVar("spawn_min_dist", "250.0", "刷特最近距离设定", CVAR_FLAG, true, 0.0);
    h_Cvar_SiInterval.AddChangeHook(OnSpawnIntervalChanged);
    h_Cvar_SiLimit.AddChangeHook(OnSiLimitChanged);
    h_Cvar_SpawnMinDist.AddChangeHook(OnSpawnMinDistChanged);
}

// 注册游戏事件钩子
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
	CreateTimer(0.1, Timer_TriggerNewInfectedSpawn);
	if(h_Cvar_Alone.BoolValue)
	{
		SetConVarInt(FindConVar("z_spitter_limit"), 0);
		SetConVarInt(FindConVar("z_boomer_limit"), 0);
	}
}

// 过滤安全屋无效导航区(新增过滤电梯导航)
public Action Timer_ProcessSafeAreaNavAreas(Handle h_Timer) {
    for (int i = h_ArrayList_AllNavAreas.Length - 1; i >= 0; i--) 
	{
        Address h_NavArea = h_ArrayList_AllNavAreas.Get(i);
        if (h_NavArea == Address_Null || (L4D_GetNavArea_AttributeFlags(h_NavArea) & NAV_BASE_AVOID) || (L4D_GetNavArea_SpawnAttributes(h_NavArea) & NAV_SPAWN_CHECKPOINT) || L4D_NavArea_GetElevator(h_NavArea) != -1) 
		{
            h_ArrayList_AllNavAreas.Erase(i);
        }
    }
    return Plugin_Stop;
}
/* 玩家受伤,增加对smoker得伤害 */
public void Event_PlayerHurt(Event event, const char[] name, bool dont_broadcast)
{
	if(h_Cvar_Alone.BoolValue)
	{
		int victim = GetClientOfUserId(GetEventInt(event, "userid"));
		int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
		int damage = GetEventInt(event, "dmg_health");
		int eventhealth = GetEventInt(event, "health");
		int AddDamage = 0;
		if (IsValidSurvivor(attacker) && IsValidInfectedBot(victim) && GetEntProp(victim, Prop_Send, "m_zombieClass") == 1)
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
}

stock void FindSurvivorNearNavAreas() 
{
    if (g_i_CurrentNavAreaIdx == 0) 
	{
        h_ArrayList_NearAreas.Clear(); // 清空旧的筛选结果
    }
    int i_ProcessedCount = 0;
    float f_SpawnPos[3], f_SurvivorPos[3];
    int i_TargetSurvivor = GetFirstValidSurvivor();
    while (g_i_CurrentNavAreaIdx < h_ArrayList_AllNavAreas.Length && i_ProcessedCount < 400) 
    {
        Address h_NavArea = h_ArrayList_AllNavAreas.Get(g_i_CurrentNavAreaIdx);
		L4D_GetNavAreaCenter(h_NavArea, f_SpawnPos);
        for (int i_SurvivorIdx = 1; i_SurvivorIdx <= MaxClients; i_SurvivorIdx++)
		{
            if (!IsValidSurvivor(i_SurvivorIdx) || !IsPlayerAlive(i_SurvivorIdx)) continue;
            GetClientAbsOrigin(i_SurvivorIdx, f_SurvivorPos);
            float f_DistThreshold = (i_SurvivorIdx == i_TargetSurvivor) ? g_f_SpawnDistance : SURVIVOR_DIST_THRESHOLD;
            if (GetVectorDistance(f_SpawnPos, f_SurvivorPos) < f_DistThreshold) 
            {
                h_ArrayList_NearAreas.Push(h_NavArea);
                break; // 命中一个生还者即停止检查，减少循环
            }
        }
        g_i_CurrentNavAreaIdx++;
        i_ProcessedCount++;
    }
    if (g_i_CurrentNavAreaIdx >= h_ArrayList_AllNavAreas.Length) 
	{
        g_i_CurrentNavAreaIdx = 0;
        g_b_FrameTaskLock = false;
        RequestFrame(StartFrameBasedSpawnAreaFilter);
    } 
	else 
	{
        RequestFrame(FindSurvivorNearNavAreas);
    }
}

// 启动分帧筛选有效生成区
void StartFrameBasedSpawnAreaFilter() {
    g_i_CurrentNavAreaIndex = 0;
    g_b_IsFindingSpawnArea = true;
    h_ArrayList_ValidSpawnPositions.Clear();
}

// 停止分帧筛选（重置状态）
void StopFrameBasedSpawnAreaFilter() {
    g_b_IsFindingSpawnArea = false;
    g_i_CurrentNavAreaIndex = 0;
    h_ArrayList_ValidSpawnPositions.Clear();
}


// 每帧处理（分帧筛选+特感攻击指令）
public void OnGameFrame() 
{
	if(!g_b_IsFindingSpawnArea)
	{
		for (int i_Client = 1; i_Client <= MaxClients; i_Client++)
		{
			// 提前过滤：非特感Bot/非存活/正在控制玩家，直接重置计数并跳过
			if (IsValidInfectedBot(i_Client) && IsPlayerAlive(i_Client))
			{
				if(GetEntityMoveType(i_Client) & MOVETYPE_LADDER)
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
    int nearAreasLen = h_ArrayList_NearAreas.Length;
	float f_SpawnPos[3], f_AreaSize[3];
	Address h_NavArea, h_SurvivorNavArea;
	float f_BaseSpawnDist = g_f_SpawnDistance + NAV_SEARCH_RANGE;
    while (g_i_CurrentNavAreaIndex < nearAreasLen && i_ProcessedCount < MAX_PROCESS_PER_FRAME)
    {
        h_NavArea = h_ArrayList_NearAreas.Get(g_i_CurrentNavAreaIndex);
        L4D_GetNavAreaCenter(h_NavArea, f_SpawnPos);
        L4D_GetNavAreaSize(h_NavArea, f_AreaSize);
		f_SpawnPos[0] = GetRandomFloat(f_SpawnPos[0] - f_AreaSize[0] * 0.5, f_SpawnPos[0] + f_AreaSize[0] * 0.5);
		f_SpawnPos[1] = GetRandomFloat(f_SpawnPos[1] - f_AreaSize[1] * 0.5, f_SpawnPos[1] + f_AreaSize[1] * 0.5);
		f_SpawnPos[2] = f_SpawnPos[2] + (f_AreaSize[2] < 0.0 ? -f_AreaSize[2] : f_AreaSize[2]) * 0.5 + 10.0;
		if(!IsPositionVisibleToAllAliveSurvivor(f_SpawnPos, h_NavArea))
		{
			for (int i_SurvivorIdx = 1; i_SurvivorIdx <= MaxClients; i_SurvivorIdx++)
			{
				if (!IsValidSurvivor(i_SurvivorIdx) || !IsPlayerAlive(i_SurvivorIdx) || L4D2_GetSpecialInfectedDominatingMe(i_SurvivorIdx) >= 0 || L4D_IsPlayerIncapacitated(i_SurvivorIdx) || L4D_IsPlayerHangingFromLedge(i_SurvivorIdx)) continue;
				h_SurvivorNavArea = L4D_GetLastKnownArea(i_SurvivorIdx);
				if(L4D2_NavAreaBuildPath(h_NavArea, h_SurvivorNavArea, f_BaseSpawnDist, TEAM_INFECTED, false) && !IsTooCloseToExistingPositions(f_SpawnPos) && !IsPositionStuck(f_SpawnPos))
				{
					h_ArrayList_ValidSpawnPositions.PushArray(f_SpawnPos, 3);
					break;
				}
			}
		}
		g_i_CurrentNavAreaIndex++;
		i_ProcessedCount++;
    }
    if (g_i_CurrentNavAreaIndex >= nearAreasLen) 
	{
        if (g_i_MaxSpawnCount > 0 || g_i_TeleportQueueIndex > 0) 
		{
            RequestFrame(ProcessInfectedSpawn);
        }
        g_b_IsFindingSpawnArea = false;
    }
}
// 辅助函数：检测新坐标是否与已存入数组的坐标距离过近
stock bool IsTooCloseToExistingPositions(float f_NewPos[3])
{
    if (h_ArrayList_ValidSpawnPositions == null) return false;
    // 数组中每3个元素对应一个坐标（x,y,z），计算已存坐标数量
    int i_ExistingCount = h_ArrayList_ValidSpawnPositions.Length;
    
    // 没有已存坐标时，直接返回false（无需检测）
    if (i_ExistingCount == 0)
    {
        return false;
    }
    
    // 遍历所有已存坐标，检测距离
    for (int i = 0; i < i_ExistingCount; i++)
    {
        // 从数组中读取已存坐标的x/y/z
        float f_ExistingPos[3];
        h_ArrayList_ValidSpawnPositions.GetArray(i, f_ExistingPos, 3);
        
        // 计算新坐标与已存坐标的三维距离（缓存结果，避免重复计算）
        float f_Distance = GetVectorDistance(f_NewPos, f_ExistingPos);
        
        // 距离小于阈值，判定为“过近”，返回true
        if (f_Distance < MIN_SPAWN_POS_DISTANCE)
        {
            return true;
        }
    }
    
    // 所有已存坐标都满足最小间距，返回false
    return false;
}

public void ProcessInfectedSpawn() 
{
    int i_NeedSpawnCount = g_i_MaxSpawnCount + g_i_TeleportQueueIndex;
    if (i_NeedSpawnCount <= 0) {
        return;
    }
    while (h_ArrayList_ValidSpawnPositions.Length > 0 && (g_i_MaxSpawnCount + g_i_TeleportQueueIndex) > 0) 
    {
        float f_SpawnPos[3];
        if (!GetRandomValidPositionFromCache(f_SpawnPos)) {
            break;
        }
        Address NavArea = L4D_GetNearestNavArea(f_SpawnPos, NAV_SEARCH_RANGE, false, false, false, TEAM_INFECTED);
        if (NavArea == Address_Null || /*L4D_IsCompletelyVisibleToTeam(NavArea, TEAM_SURVIVOR) || */IsPositionVisibleToAllAliveSurvivor(f_SpawnPos, NavArea)) 
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
    if (g_f_SpawnDistance >= SPAWN_DIST_MAX)
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
        g_f_SpawnDistance += 100.0;
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

// 特感卡住检测与处理
public Action Timer_CheckInfectedStuck(Handle h_Timer)
{
    if (g_b_IsLateSpawn && g_i_MaxSpawnCount <= 0)
    {
		h_ArrayList_AvailableInfectedClasses.Clear();
		// 先销毁旧主计时器、清空游戏原生倒计时
		if (h_SingleRespawnTimer != INVALID_HANDLE)
		{
			KillTimer(h_SingleRespawnTimer);
			h_SingleRespawnTimer = INVALID_HANDLE;
		}
		if (SpawnCountdown_IsRunning())
		{
			SpawnCountdown_Stop();
		}

		float totalWait = g_f_SpawnInterval * 1.5;
		// 启动游戏原生CTimer倒计时（顶部自动显示ready_countdown条）
		if(Hud_Text.BoolValue)
		{
			SpawnCountdown_Start(totalWait);
		}
		// 创建后端触发计时器，计时结束执行刷特感逻辑
		h_SingleRespawnTimer = CreateTimer(totalWait, Timer_TriggerNewInfectedSpawn);

		g_b_IsLateSpawn = false;
    }
    // 仅遍历存活特感Bot（减少无效循环）
    for (int i_Client = 1; i_Client <= MaxClients; i_Client++)
    {
        // 提前过滤：非特感Bot/非存活/正在控制玩家，直接重置计数并跳过
        if (!IsValidInfectedBot(i_Client) || !IsPlayerAlive(i_Client) || L4D2_GetSpecialInfectedDominatingMe(i_Client) >= 0)
        {
            g_i_InfectedStuckCount[i_Client] = 0;
            continue;
        }
        L4D_WarpToValidPositionIfStuck(i_Client);
        float f_CurrentPos[3];
        GetClientAbsOrigin(i_Client, f_CurrentPos);
        Address h_SpawnArea = L4D_GetLastKnownArea(i_Client);
        bool b_IsStuck = (h_SpawnArea == Address_Null || !IsInfectedVisible(f_CurrentPos, h_SpawnArea)) 
                      || GetVectorDistance(g_f_InfectedLastPos[i_Client], f_CurrentPos) < STUCK_MOVE_THRESHOLD;
        if (b_IsStuck)
            ProcessInfectedStuck(i_Client);
        else
            g_i_InfectedStuckCount[i_Client] = 0;
    }
    return Plugin_Continue;
}
// 处理卡住的特感（踢出+重新生成）
void ProcessInfectedStuck(int i_Client) {
    if (g_i_InfectedStuckCount[i_Client] > STUCK_MAX_COUNT) {
        g_f_SpawnDistance = SPAWN_DIST_DEFAULT;
        g_i_InfectedStuckCount[i_Client] = -1000;
        g_i_TeleportQueueIndex++;
        h_ArrayList_AvailableInfectedClasses.Push(GetEntProp(i_Client, Prop_Send, "m_zombieClass"));
		KickClient(i_Client);
        RequestFrame(StartFrameBasedSpawnAreaFilter);
    } else {
        g_i_InfectedStuckCount[i_Client] += STUCK_COUNT_STEP;
    }
}

// 1. 修改 ResetPluginStatus 函数（新增踢掉所有特感Bot逻辑）
public void ResetPluginStatus() 
{
    g_b_FrameTaskLock = false;
	g_b_IsFindingSpawnArea = false;
    g_i_CurrentNavAreaIndex = 0;
	g_i_MaxSpawnCount = 0;
    g_i_TeleportQueueIndex = 0;
	g_b_IsLateSpawn = false;
    // 新增：强制清空所有数组，清除跨图脏数据
    h_ArrayList_NearAreas.Clear();
    h_ArrayList_AvailableInfectedClasses.Clear();
    h_ArrayList_ValidSpawnPositions.Clear();
    h_RandomIndices.Clear();
    for (int i_Client = 1; i_Client <= MaxClients; i_Client++) 
	{
        if (IsValidInfectedBot(i_Client)) 
		{
            g_i_InfectedStuckCount[i_Client] = 0;
            if (IsClientInGame(i_Client) && !IsClientInKickQueue(i_Client)) {
                KickClient(i_Client); // 过图强制踢掉所有特感Bot，避免计数异常
            }
        }
        if (!L4D_HasAnySurvivorLeftSafeArea() && IsValidSurvivor(i_Client) && !IsPlayerAlive(i_Client)) 
		{
            L4D_RespawnPlayer(i_Client);
        }
    }
	if (SpawnCountdown_IsRunning())
	{
		SpawnCountdown_Stop();
	}
}


// 2. 修改 Timer_TriggerNewInfectedSpawn 函数（新增安全区判断）
public Action Timer_TriggerNewInfectedSpawn(Handle h_Timer) 
{
    // 必须确认有生还者真的离开安全区，才允许生成特感
    if (!L4D_HasAnySurvivorLeftSafeArea()) 
	{
        g_b_IsLateSpawn = false;
        return Plugin_Stop;
    }
    g_i_TeleportQueueIndex = 0;
	g_b_IsLateSpawn = true;
	g_i_MaxSpawnCount = g_i_SiLimit - GetCurrentSpecialCount();
	g_f_SpawnDistance = SPAWN_DIST_DEFAULT;
	InitAvailableInfectedClasses();
	// 计算总实体数，避免超出上限（不变）
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
    h_SingleRespawnTimer = INVALID_HANDLE;
	// 关闭顶部倒计时面板，失效游戏原生计时器
	if (SpawnCountdown_IsRunning())
	{
		SpawnCountdown_Stop();
	}

    return Plugin_Stop;
}

// 初始化可用特感列表
stock void InitAvailableInfectedClasses() {
    h_ArrayList_AvailableInfectedClasses.Clear();
    for (int i = 1; i <= 6; i++) {
        int CurrentCount = GetInfectedCurrentCount(i);
        int MaxLimit = GetInfectedMaxLimit(i);
        int ArrayLimit = MaxLimit - CurrentCount;
        if (ArrayLimit <= 0) continue;

        for (int a = 1; a <= ArrayLimit; a++) {
            h_ArrayList_AvailableInfectedClasses.Push(i);
        }
    }
}

// 初始化特感生成状态
stock void InitInfectedSpawnState(int i_Client, float f_SpawnPos[3]) {
    g_f_InfectedLastPos[i_Client] = f_SpawnPos;
    TeleportEntity(i_Client, f_SpawnPos, NULL_VECTOR, NULL_VECTOR);
    L4D_WarpToValidPositionIfStuck(i_Client);
    g_i_InfectedStuckCount[i_Client] = 0;
    SDKCall(hInfectedAttackSurvivorTeam, i_Client);
}

// 预缓存特感模型
stock void PrecacheInfectedModels() {
    PrecacheModelIfNeed(MODEL_SMOKER);
    PrecacheModelIfNeed(MODEL_BOOMER);
    PrecacheModelIfNeed(MODEL_HUNTER);
    PrecacheModelIfNeed(MODEL_SPITTER);
    PrecacheModelIfNeed(MODEL_JOCKEY);
    PrecacheModelIfNeed(MODEL_CHARGER);
}

// 按需预缓存模型（避免重复）
stock void PrecacheModelIfNeed(const char[] sModelPath) {
    if (!IsModelPrecached(sModelPath)) {
        PrecacheModel(sModelPath, true);
    }
}

// 随机选择特感类型
stock int SelectRandomInfectedType() {
    if (h_ArrayList_AvailableInfectedClasses == null || h_ArrayList_AvailableInfectedClasses.Length <= 0) {
        return 3; // 默认猎人
    }

    int i_RandomIdx = GetRandomInt(0, h_ArrayList_AvailableInfectedClasses.Length - 1);
    int i_Type = h_ArrayList_AvailableInfectedClasses.Get(i_RandomIdx);
    // 避免连续选择Boomer/Spitter
    if (i_Type == 2 || i_Type == 4) 
	{
        i_RandomIdx = GetRandomInt(0, h_ArrayList_AvailableInfectedClasses.Length - 1);
        i_Type = h_ArrayList_AvailableInfectedClasses.Get(i_RandomIdx);
    }

    h_ArrayList_AvailableInfectedClasses.Erase(i_RandomIdx);
    return i_Type;
}
//判断该坐标是否可以看到生还或者距离小于250码
stock bool IsPositionVisibleToAllAliveSurvivor(float f_TargetPos[3], Address h_NavArea)
{
	float f_SurvivorPos[3], f_OriginalZ[3];
    f_OriginalZ = f_TargetPos;
    f_OriginalZ[2] += 45.0;
    for (int i_Survivor = 1; i_Survivor <= MaxClients; i_Survivor++)
    {
        if (IsValidSurvivor(i_Survivor) && IsPlayerAlive(i_Survivor))
        {
            GetClientAbsOrigin(i_Survivor, f_SurvivorPos);
            // 性能优化：缓存距离结果，仅计算一次
            float f_CurrDist = GetVectorDistance(f_TargetPos, f_SurvivorPos);
            if (f_CurrDist < g_f_SpawnMinDistance)
                return true;
            if (L4D2_IsVisibleToPlayer(i_Survivor, 2, 3, h_NavArea, f_OriginalZ))
                return true;
        }
    }
	return false;
}

// 检测特感是否被生还者可见
stock bool IsInfectedVisible(float f_TargetPos[3], Address h_NavArea)
{
	g_f_Cache_OriginalZ[0] = f_TargetPos[0];
    g_f_Cache_OriginalZ[1] = f_TargetPos[1];
    g_f_Cache_OriginalZ[2] = f_TargetPos[2] + SPAWN_Z_OFFSET;
	for (int i_Client = 1; i_Client <= MaxClients; i_Client++)
    {
        if (IsValidSurvivor(i_Client) && IsPlayerAlive(i_Client))
        {
            if (L4D2_IsVisibleToPlayer(i_Client, TEAM_SURVIVOR, TEAM_INFECTED, h_NavArea, g_f_Cache_OriginalZ))
            {
                return true;
            }
        }
    }
    return false;
}

// 检测位置是否卡点
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

// 射线检测卡点
stock bool TraceRayForStuck(float f_Start[3], float f_End[3]) {
    TR_TraceRayFilter(f_Start, f_End, MASK_NPCSOLID_BRUSHONLY, RayType_EndPoint, TraceFilter_IgnoreInvalid);
    return TR_DidHit();
}

// 射线过滤无效实体
stock bool TraceFilter_IgnoreInvalid(int i_Entity, int i_ContentsMask) {
    if (i_Entity <= MaxClients || !IsValidEntity(i_Entity)) return false;

    static char s_ClassName[20];
    GetEntityClassname(i_Entity, s_ClassName, sizeof(s_ClassName));
    if (strcmp(s_ClassName, "env_physics_blocker") == 0 && !IsValidPhysicsBlocker(i_Entity)) {
        return false;
    }
    return true;
}

// 判断物理阻挡有效性
stock bool IsValidPhysicsBlocker(int i_Entity) {
    int i_BlockType = GetEntProp(i_Entity, Prop_Data, "m_nBlockType");
    return !(i_BlockType == 1 || i_BlockType == 2);
}

// 获取最前面的有效生还者
static int GetFirstValidSurvivor() {
    int i_Survivor = L4D_GetHighestFlowSurvivor();
    if (IsValidSurvivor(i_Survivor) && IsPlayerAlive(i_Survivor) && !L4D_IsPlayerIncapacitated(i_Survivor) && !L4D_IsPlayerHangingFromLedge(i_Survivor)) {
        return i_Survivor;
    }
    return -1;
}

// 统计当前存活特感数量
stock int GetCurrentSpecialCount() {
    int i_SpecialCount = 0;
    for (int i_Client = 1; i_Client <= MaxClients; i_Client++) {
        if (IsClientInGame(i_Client) && IsValidInfectedBot(i_Client) && IsPlayerAlive(i_Client)) {
            i_SpecialCount++;
        }
    }
    return i_SpecialCount;
}

// 统计在场生还者数量（含死亡）
stock int GetInGameSurvivorCount() {
    int count = 0;
    for (int i_Client = 1; i_Client <= MaxClients; i_Client++) {
        if (IsClientInGame(i_Client) && IsValidSurvivor(i_Client)) {
            count++;
        }
    }
    return count;
}

// 统计所有特感数量（含死亡）
stock int GetAllInfectedCount() {
    int count = 0;
    for (int i_Client = 1; i_Client <= MaxClients; i_Client++) {
        if (IsClientInGame(i_Client) && IsValidInfectedBot(i_Client)) {
            count++;
        }
    }
    return count;
}

// 控制台变量变更回调
void OnSpawnIntervalChanged(ConVar h_Cvar, const char[] s_OldVal, const char[] s_NewVal) { LoadConVarValues(); }
void OnSiLimitChanged(ConVar h_Cvar, const char[] s_OldVal, const char[] s_NewVal) { g_i_SiLimit = h_Cvar_SiLimit.IntValue; }
void OnSpawnMinDistChanged(ConVar h_Cvar, const char[] s_OldVal, const char[] s_NewVal) { g_f_SpawnMinDistance = h_Cvar_SpawnMinDist.FloatValue; }

// 加载控制台变量值
void LoadConVarValues() {
    g_f_SpawnInterval = h_Cvar_SiInterval.FloatValue;
    g_i_SiLimit = h_Cvar_SiLimit.IntValue;
    g_f_SpawnMinDistance = h_Cvar_SpawnMinDist.FloatValue;
}

// 回合开始事件处理
public void OnRoundStart(Event h_Event, const char[] s_Name, bool b_DontBroadcast) 
{
    InitPluginStatus();
	if (h_SingleRespawnTimer != INVALID_HANDLE)
	{
		//PrintToChatAll("删除计时器");
		KillTimer(h_SingleRespawnTimer);
		h_SingleRespawnTimer = INVALID_HANDLE;
	}
    CreateTimer(1.0, Timer_ResetSafeRoomState, _, TIMER_FLAG_NO_MAPCHANGE);
}

// 重置安全屋状态
public Action Timer_ResetSafeRoomState(Handle h_Timer) 
{
    ResetPluginStatus();
    return Plugin_Stop;
}

// 回合结束事件处理
public void OnRoundEnd(Event h_Event, const char[] s_Name, bool b_DontBroadcast) 
{
    InitPluginStatus();
}

// 插件状态初始化（重置核心变量）
public void InitPluginStatus()
{
	g_b_IsFindingSpawnArea = false;
    g_i_CurrentNavAreaIndex = 0;
	g_i_MaxSpawnCount = 0;
    g_i_TeleportQueueIndex = 0;
	g_b_IsLateSpawn = false;
	if (SpawnCountdown_IsRunning())
	{
		SpawnCountdown_Stop();
	}
}

// 玩家死亡事件处理（清理特感Bot）
public void OnPlayerDeath(Event h_Event, const char[] s_Name, bool b_DontBroadcast) 
{
	int victim = GetClientOfUserId(GetEventInt(h_Event, "userid"));
	int killer  = GetClientOfUserId(GetEventInt(h_Event, "attacker"));
	if(IsValidInfectedBot(victim))
	{
		g_i_InfectedStuckCount[victim] = -1000;
		int i_ZombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
		if (i_ZombieClass == 4)
		{
			g_i_InfectedStuckCount[victim] = -1000;
		} 
		else 
		{
			CreateTimer(0.2, Timer_KickInfectedBot, victim);
		}
		if(IsValidSurvivor(killer))	//玩家幸存者杀死特殊感染者
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
// 踢出特感Bot
public Action Timer_KickInfectedBot(Handle h_Timer, int i_Client) {
    if (IsClientInGame(i_Client) && !IsClientInKickQueue(i_Client) && IsFakeClient(i_Client)) {
        g_i_InfectedStuckCount[i_Client] = -1000;
        KickClient(i_Client);
    }
    return Plugin_Continue;
}

// 判断玩家是否被特感控制
stock bool IsPlayerPinned(int i_Client) {
    return GetEntPropEnt(i_Client, Prop_Send, "m_tongueOwner") > 0
        || GetEntPropEnt(i_Client, Prop_Send, "m_pounceAttacker") > 0
        || GetEntPropEnt(i_Client, Prop_Send, "m_carryAttacker") > 0
        || GetEntPropEnt(i_Client, Prop_Send, "m_pummelAttacker") > 0
        || GetEntPropEnt(i_Client, Prop_Send, "m_jockeyAttacker") > 0;
}

// 判断特感是否正在控制玩家
stock bool IsInfectedPinningSomeone(int i_Client) {
    if (!IsValidInfectedBot(i_Client)) return false;
    return GetEntPropEnt(i_Client, Prop_Send, "m_tongueVictim") > 0
        || GetEntPropEnt(i_Client, Prop_Send, "m_jockeyVictim") > 0
        || GetEntPropEnt(i_Client, Prop_Send, "m_pounceVictim") > 0
        || GetEntPropEnt(i_Client, Prop_Send, "m_pummelVictim") > 0
        || GetEntPropEnt(i_Client, Prop_Send, "m_carryVictim") > 0;
}

// 判断玩家是否为幽灵状态
stock bool IsPlayerGhost(int i_Client) {
    return IsValidClient(i_Client) && view_as<bool>(GetEntProp(i_Client, Prop_Send, "m_isGhost"));
}

// 判断是否为有效特感Bot
stock bool IsValidInfectedBot(int i_Client) {
    if (i_Client <= 0 || i_Client > MaxClients || !IsClientInGame(i_Client) || !IsFakeClient(i_Client)) {
        return false;
    }
    int i_ZombieClass = GetEntProp(i_Client, Prop_Send, "m_zombieClass");
    return GetClientTeam(i_Client) == TEAM_INFECTED && i_ZombieClass >= 1 && i_ZombieClass <= 6;
}

// 客户端有效性判断（合并重复逻辑）
stock bool IsValidClient(int i_Client, bool b_CheckReplay = false) {
    if (i_Client <= 0 || i_Client > MaxClients || !IsClientInGame(i_Client)) return false;
    return b_CheckReplay ? (!IsClientSourceTV(i_Client) && !IsClientReplay(i_Client)) : true;
}

// 获取特感最大数量限制
stock int GetInfectedMaxLimit(int i_Class) {
    char s_CvarName[16];
    Format(s_CvarName, 16, "z_%s_limit", g_sz_InfectedNames[i_Class]);
    ConVar h_Cvar = FindConVar(s_CvarName);
    return (h_Cvar != null) ? h_Cvar.IntValue : 0;
}

// 获取当前特感数量
stock int GetInfectedCurrentCount(int i_Class) {
    int i_Count = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED && GetEntProp(i, Prop_Send, "m_zombieClass") == i_Class) {
            i_Count++;
        }
    }
    return i_Count;
}

// 判断是否为有效生还者
stock bool IsValidSurvivor(int i_Client) {
    return IsValidClient(i_Client) && GetClientTeam(i_Client) == TEAM_SURVIVOR;
}

// 强制特感激进模式
public Action L4D_OnGetScriptValueInt(const char[] s_Key, int &i_RetVal) {
    if ((strcmp(s_Key, "cm_ShouldHurry", false) == 0 || strcmp(s_Key, "cm_AggressiveSpecials", false) == 0) && i_RetVal != 1) {
        i_RetVal = 1;
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

// 创建特感（按类型分支）
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

// 加载游戏配置文件
void GetGamedata() {
    char filePath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, filePath, sizeof(filePath), "gamedata/%s.txt", GAMEDATA);
    if (FileExists(filePath)) {
        hConf = LoadGameConfigFile(GAMEDATA);
    }
    PrepSDKCall();
}

// 从内存地址读取字符串
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

// 准备特感创建SDKCall
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

// Windows平台特感创建调用准备
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
    hCreateTank = PrepCreateBotCallFromAddress(hInfectedFuncs, "Tank");
    if (hCreateTank == null) { SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateTank); return; }
    hCreateSpitter = PrepCreateBotCallFromAddress(hInfectedFuncs, "Spitter");
    if (hCreateSpitter == null) { SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateSpitter); return; }
    hCreateJockey = PrepCreateBotCallFromAddress(hInfectedFuncs, "Jockey");
    if (hCreateJockey == null) { SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateJockey); return; }
    hCreateCharger = PrepCreateBotCallFromAddress(hInfectedFuncs, "Charger");
    if (hCreateCharger == null) { SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateCharger); return; }
}

// L4D2特感创建调用准备
void PrepL4D2CreateBotCalls() {
    hCreateSpitter = PrepSDKCallForBot(NAME_CreateSpitter);
    if (hCreateSpitter == null) { SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateSpitter); return; }
    hCreateJockey = PrepSDKCallForBot(NAME_CreateJockey);
    if (hCreateJockey == null) { SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateJockey); return; }
    hCreateCharger = PrepSDKCallForBot(NAME_CreateCharger);
    if (hCreateCharger == null) { SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateCharger); return; }
}

// L4D1特感创建调用准备
void PrepL4D1CreateBotCalls() {
    hCreateSmoker = PrepSDKCallForBot(NAME_CreateSmoker);
    if (hCreateSmoker == null) { SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateSmoker); return; }
    hCreateBoomer = PrepSDKCallForBot(NAME_CreateBoomer);
    if (hCreateBoomer == null) { SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateBoomer); return; }
    hCreateHunter = PrepSDKCallForBot(NAME_CreateHunter);
    if (hCreateHunter == null) { SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateHunter); return; }
    hCreateTank = PrepSDKCallForBot(NAME_CreateTank);
    if (hCreateTank == null) { SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateTank); return; }
}

// 封装特感SDKCall准备（减少重复代码）
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

// 初始化SDKCall
void PrepSDKCall() {
    if (hConf == null) { SetFailState("Unable to find %s.txt gamedata.", GAMEDATA); return; }

    Address replaceWithBot = GameConfGetAddress(hConf, "NextBotCreatePlayerBot.jumptable");
    if (replaceWithBot != Address_Null && LoadFromAddress(replaceWithBot, NumberType_Int8) == 0x68) {
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

// 完全照搬Antibaiter：复用游戏内置拾荒倒计时作为我们的倒计时载体
CountdownTimer SpawnCountdownPointer()
{
    return L4D2Direct_GetScavengeRoundSetupTimer();
}

// 启动倒计时 + 打开顶部ready_countdown VGUI面板
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

// 判断倒计时是否运行中
stock bool SpawnCountdown_IsRunning()
{
    return CTimer_HasStarted(SpawnCountdownPointer());
}

// 判断倒计时是否走完
stock bool SpawnCountdown_IsElapsed()
{
    return CTimer_IsElapsed(SpawnCountdownPointer());
}

// 销毁倒计时 + 关闭顶部VGUI
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

// 获取剩余倒计时秒数（用于聊天打印）
stock float SpawnCountdown_GetRemaining()
{
    return CTimer_GetRemainingTime(SpawnCountdownPointer());
}

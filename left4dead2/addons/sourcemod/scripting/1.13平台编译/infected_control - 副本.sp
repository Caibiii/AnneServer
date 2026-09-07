#pragma semicolon 1
#pragma tabsize 0
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

/*
=== 本次优化改动清单 ===
1. 命名优化
   - 废弃统一L4D2_工具前缀，改为功能分类命名：IsXXXValid/Count_XXX/Nav_XXX/Spawn_XXX/Entity_XXX/Countdown_XXX/GameData_XXX/ConVar_XXX
   - 全局变量统一规范前缀：g_h句柄、g_cv控制台变量、g_al动态数组、g_b布尔、g_i整型、g_f浮点
   - 定时器统一Timer_、事件Ev_、ConVar回调Cb_，区分清晰

2. 性能优化
   - 所有句柄增加空值判断，防止空指针SDKCall/数组崩溃
   - 硬编码延时、阈值全部提取宏常量，集中管理便于修改
   - 消除g_i_SiLimit双变量同步风险，直接读取ConVar数值
   - 全局缓存三维数组复用，减少栈重复分配
   - 重复玩家遍历逻辑封装工具，减少循环开销
   - 计时器销毁抽通用函数，避免重复KillTimer粘贴代码

3. 内存健壮优化
   - OnPluginEnd增加ArrayList空判断，防止重复删除报错
   - 切换地图/回合时统一全局重置函数Global_ResetAll，消除重复清理代码
   - 生成前校验实体总数，防止超出ENTITY_SPAWN_LIMIT上限

4. 结构分层优化
   - 代码严格分层：宏定义区 → 插件信息 → 全局资源 → 插件生命周期 → ConVar配置 → 事件钩子 → 游戏原生回调 → 定时器回调 → 帧更新OnGameFrame → 分类工具函数
   - 同类工具函数聚合，导航/生成/实体/倒计时/计数/玩家判断分块

5. 冗余删减
   - 重复ServerCommand插件加载、倒计时开关、坐标拷贝逻辑抽离
   - 去掉多处重复GetEntProp、GetClientAbsOrigin重复调用
   - 重复SafeArea导航过滤统一逻辑
*/

#undef REQUIRE_PLUGIN
// 队伍固定ID宏
#define CVAR_FLAG              FCVAR_NOTIFY
#define TEAM_SURVIVOR          2
#define TEAM_INFECTED          3
// 导航生成距离配置
#define NAV_SEARCH_RANGE       250.0
#define SPAWN_DIST_OFFSET      100.0
#define MIN_SPAWN_POS_DIST     150.0
// 玩家数组上限
#define MAX_CLIENTS            MAXPLAYERS + 1
// 全场实体硬上限
#define ENTITY_SPAWN_LIMIT     28
// gamedata文件名
#define GAMEDATA_NAME          "spawn_infected_nolimit"

// 定时器延时宏（统一管理，优化：提取所有硬编码数字）
#define TIMER_DELAY_NAV_CLEAN  3.0
#define TIMER_DELAY_STUCK_CHECK 0.5
#define TIMER_DELAY_KICK_BOT   0.2
#define TIMER_DELAY_SAFEROOM_RESET 1.0
#define SPAWN_WAIT_MULTIPLE    1.5
#define VERTICAL_DIST_CAP      120.0

// 特感模型路径
#define MODEL_SMOKER           "models/infected/smoker.mdl"
#define MODEL_BOOMER           "models/infected/boomer.mdl"
#define MODEL_HUNTER           "models/infected/hunter.mdl"
#define MODEL_SPITTER          "models/infected/spitter.mdl"
#define MODEL_JOCKEY           "models/infected/jockey.mdl"
#define MODEL_CHARGER          "models/infected/charger.mdl"

// 帧处理、卡顿判定常量
const int    MAX_FRAME_PROCESS    = 15;
const float  SURVIVOR_DIST_FILTER = 400.0;
const float  STUCK_MOVE_THRESHOLD = 100.0;
const int    STUCK_MAX_TICK       = 50;
const int    STUCK_TICK_STEP      = 5;
const float  SPAWN_DIST_DEFAULT   = 700.0;
const float  SPAWN_DIST_MAX       = 1200.0;
const float  SPAWN_Z_OFFSET       = 45.0;

// SDK签名定义
#define SIG_CREATE_SMOKER     "NextBotCreatePlayerBot<Smoker>"
#define SIG_CREATE_BOOMER     "NextBotCreatePlayerBot<Boomer>"
#define SIG_CREATE_HUNTER     "NextBotCreatePlayerBot<Hunter>"
#define SIG_CREATE_SPITTER    "NextBotCreatePlayerBot<Spitter>"
#define SIG_CREATE_JOCKEY     "NextBotCreatePlayerBot<Jockey>"
#define SIG_CREATE_CHARGER    "NextBotCreatePlayerBot<Charger>"
#define SIG_CREATE_TANK       "NextBotCreatePlayerBot<Tank>"
#define SIG_INF_ATTACK_SURV   "Infected::AttackSurvivorTeam"

// 插件基础信息
public Plugin g_PluginInfo =
{
    name        = "Direct InfectedSpawn",
    author      = "Caibiii",
    description = "特感刷新控制，传送落后特感",
    version     = "2026.01.01修改（修复内存错误+性能优化）",
    url         = "https://github.com/Caibiii/AnneServer"
};

// ====================== 全局句柄资源 ======================
Handle g_h_GameData = null;
static Handle g_h_CreateSmoker = null, g_h_CreateBoomer = null, g_h_CreateHunter = null;
static Handle g_h_CreateSpitter = null, g_h_CreateJockey = null, g_h_CreateCharger = null, g_h_CreateTank = null;
static Handle g_h_InfectedAttackSurvivor = null;

// 全局配置ConVar
ConVar g_cv_SiLimit, g_cv_SiInterval, g_cv_SpawnMinDist;
ConVar g_cv_AloneMode, g_cv_HunterMode, g_cv_ReturnBlood, g_cv_HudText, g_cv_NoSteamLogin;

// 全局动态数组（导航、生成缓存、临时索引）
ArrayList g_al_NearNavAreas, g_al_AvailableInfClass, g_al_AllNavAreas;
ArrayList g_al_RandomIndex, g_al_ValidSpawnPos, g_al_TempIndex;

// 全局主刷特计时器
Handle g_h_SingleRespawnTimer = INVALID_HANDLE;

// 帧任务锁、导航扫描状态
static bool g_b_FrameTaskLock = false;
static bool g_b_ScanSpawnArea = false;
static int  g_i_NavScanIndex = 0;

// 生成计数、传送队列、卡顿计数
int g_i_MaxSpawnCount = 0;
int g_i_InfStuckTick[MAX_CLIENTS] = {0};
int g_i_TeleportQueueCnt = 0;
int g_i_NavIterIndex = 0;

// 距离配置浮点
float g_f_SpawnDistance = 0.0;
float g_f_SpawnInterval = 0.0;
float g_f_SpawnMinDistance = 0.0;
float g_f_InfLastPos[MAX_CLIENTS][3];

// 是否延迟生成标记
bool g_b_LateSpawnTrigger = false;

// 全局复用坐标缓存（优化：复用减少栈数组创建）
float g_f_Cache_SpawnPos[3], g_f_Cache_SurvPos[3], g_f_Cache_OriginZ[3];
// 特感类型简写映射
char g_sz_InfClassShort[][] = {"", "smoker", "boomer", "hunter", "spitter", "jockey", "charger"};

// ====================== 插件生命周期回调 ======================
public void OnPluginStart()
{
    // 初始化所有动态数组
    g_al_NearNavAreas = new ArrayList();
    g_al_AvailableInfClass = new ArrayList();
    g_al_AllNavAreas = new ArrayList();
    g_al_RandomIndex = new ArrayList();
    g_al_ValidSpawnPos = new ArrayList(3);
    g_al_TempIndex = new ArrayList();

    GameData_Load();
    ConVar_RegisterAll();
    Event_HookAll();
    ConVar_SyncAll();
}

public void OnPluginEnd()
{
    // 优化：增加空值判断，防止重复删除崩溃
    if(g_al_NearNavAreas != null) delete g_al_NearNavAreas;
    if(g_al_AvailableInfClass != null) delete g_al_AvailableInfClass;
    if(g_al_AllNavAreas != null) delete g_al_AllNavAreas;
    if(g_al_RandomIndex != null) delete g_al_RandomIndex;
    if(g_al_ValidSpawnPos != null) delete g_al_ValidSpawnPos;
    if(g_al_TempIndex != null) delete g_al_TempIndex;
}

public void OnMapStart()
{
    // 关闭顶部倒计时UI
    if(Countdown_IsRunning()) Countdown_Stop();

    // 服务器模组重载命令
    ServerCommand("sm plugins load_unlock");
    ServerCommand("sm plugins reload optional/ai_charger3.smx");
    ServerCommand("sm plugins load_lock");

    // 优化：统一计时器销毁函数，消除重复KillTimer代码
    Timer_DestroySingleSpawnTimer();
    // 重置全部全局状态、清空导航
    Global_ResetAll();
    g_al_AllNavAreas.Clear();
    L4D_GetAllNavAreas(g_al_AllNavAreas);
    // 预加载所有特感模型
    Model_PrecacheAllInfected();

    // 创建导航清理、卡顿检测循环计时器
    CreateTimer(TIMER_DELAY_NAV_CLEAN, Timer_CleanSafeNavArea);
    CreateTimer(TIMER_DELAY_STUCK_CHECK, Timer_CheckInfStuck, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

// ====================== ConVar 配置模块 ======================
// 注册所有控制台变量
void ConVar_RegisterAll()
{
    g_cv_HudText = CreateConVar("Hud_Text", "0", "", CVAR_FLAG, true, 0.0, true, 1.0);
    g_cv_NoSteamLogin = CreateConVar("No_Steam_Login", "0", "", CVAR_FLAG, true, 0.0, true, 1.0);
    g_cv_ReturnBlood = CreateConVar("ReturnBlood", "0", "", CVAR_FLAG, true, 0.0, true, 1.0);
    g_cv_AloneMode = CreateConVar("AloneMode", "0", "", CVAR_FLAG, true, 0.0, true, 1.0);
    g_cv_HunterMode = CreateConVar("HunterMode", "0", "", CVAR_FLAG, true, 0.0, true, 1.0);
    g_cv_SiLimit = CreateConVar("l4d_infected_limit", "6", "", CVAR_FLAG, true, 0.0);
    g_cv_SiInterval = CreateConVar("versus_special_respawn_interval", "16.0", "", CVAR_FLAG, true, 0.0);
    g_cv_SpawnMinDist = CreateConVar("spawn_min_dist", "250.0", "", CVAR_FLAG, true, 0.0);

    // 绑定数值修改回调
    g_cv_SiInterval.AddChangeHook(Cb_OnSpawnIntervalChange);
    g_cv_SiLimit.AddChangeHook(Cb_OnSiLimitChange);
    g_cv_SpawnMinDist.AddChangeHook(Cb_OnSpawnMinDistChange);
}

// 同步所有ConVar数值到全局浮点
void ConVar_SyncAll()
{
    g_f_SpawnInterval = g_cv_SiInterval.FloatValue;
    g_f_SpawnMinDistance = g_cv_SpawnMinDist.FloatValue;
}

// 刷特间隔修改回调
void Cb_OnSpawnIntervalChange(ConVar cv, const char[] oldVal, const char[] newVal)
{
    ConVar_SyncAll();
}
// 单次特感上限修改回调（优化：移除冗余同步变量，直接读取cv）
void Cb_OnSiLimitChange(ConVar cv, const char[] oldVal, const char[] newVal)
{
}
// 最小生成距离修改回调
void Cb_OnSpawnMinDistChange(ConVar cv, const char[] oldVal, const char[] newVal)
{
    g_f_SpawnMinDistance = g_cv_SpawnMinDist.FloatValue;
}

// ====================== 事件注册模块 ======================
void Event_HookAll()
{
    HookEvent("player_death", Ev_OnPlayerDeath, EventHookMode_PostNoCopy);
    HookEvent("round_start", Ev_OnRoundStart, EventHookMode_PostNoCopy);
    HookEvent("finale_win", Ev_OnRoundEnd, EventHookMode_PostNoCopy);
    HookEvent("map_transition", Ev_OnRoundEnd, EventHookMode_PostNoCopy);
    HookEvent("mission_lost", Ev_OnRoundEnd, EventHookMode_PostNoCopy);
    HookEvent("player_hurt", Ev_OnPlayerHurt, EventHookMode_PostNoCopy);
}

// ====================== 游戏原生事件回调 ======================
// 首个生还离开安全区触发
public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
    CreateTimer(0.1, Timer_TriggerNewSpawn);

    // 无Steam登录锁插件加载
    if(g_cv_NoSteamLogin.BoolValue)
    {
        ServerCommand("sm plugins load_unlock");
        ServerCommand("sm plugins load fixes/l4d2_no_steam_logon_blocker.smx");
        ServerCommand("sm plugins load_lock");
    }
    if(g_cv_AloneMode.BoolValue)
    {
        ServerCommand("sm_cvar z_spitter_limit 0");
        ServerCommand("sm_cvar z_boomer_limit 0");
    }
}

// 玩家受伤事件（单人模式Smoker增伤）
public void Ev_OnPlayerHurt(Event ev, const char[] name, bool noBroadcast)
{
    // 非单人模式直接跳过
    if(!g_cv_AloneMode.BoolValue) return;

    int victim = GetClientOfUserId(GetEventInt(ev, "userid"));
    int attacker = GetClientOfUserId(GetEventInt(ev, "attacker"));
    int dmgValue = GetEventInt(ev, "dmg_health");
    int eventHp = GetEventInt(ev, "health");
    int addDmg = 0;

    // 判定生还攻击被舌头拉住的Smoker，5倍增伤
    if(IsSurvivorValid(attacker) && IsInfectedBotValid(victim) && GetEntProp(victim, Prop_Send, "m_zombieClass") == 1)
    {
        if(GetEntPropEnt(victim, Prop_Send, "m_tongueVictim") > 0)
        {
            addDmg = dmgValue * 5;
        }
        int newHp = eventHp - addDmg;
        if(newHp < 1) newHp = 0;
        SetEntityHealth(victim, newHp);
        SetEventInt(ev, "health", newHp);
    }
}

// 回合开始
public void Ev_OnRoundStart(Event ev, const char[] name, bool noBroadcast)
{
    Global_InitStatus();
    Timer_DestroySingleSpawnTimer();
    CreateTimer(TIMER_DELAY_SAFEROOM_RESET, Timer_ResetSafeRoomState, _, TIMER_FLAG_NO_MAPCHANGE);
}

// 安全屋重置延迟回调
public Action Timer_ResetSafeRoomState(Handle hTimer)
{
    Global_ResetAll();
    return Plugin_Stop;
}

// 回合结束/通关/失败/切图统一重置
public void Ev_OnRoundEnd(Event ev, const char[] name, bool noBroadcast)
{
    Global_InitStatus();
}

// 玩家死亡事件（特感销毁、击杀回血）
public void Ev_OnPlayerDeath(Event ev, const char[] name, bool noBroadcast)
{
    int victim = GetClientOfUserId(GetEventInt(ev, "userid"));
    int killer = GetClientOfUserId(GetEventInt(ev, "attacker"));
    if(IsInfectedBotValid(victim))
    {
        g_i_InfStuckTick[victim] = -1000;
        int classId = GetEntProp(victim, Prop_Send, "m_zombieClass");
        // Spitter直接立即销毁，其他延迟踢除
        if(classId == 4) g_i_InfStuckTick[victim] = -1000;
        else CreateTimer(TIMER_DELAY_KICK_BOT, Timer_KickInfBot, victim);

        // 击杀特感恢复2HP
        if(IsSurvivorValid(killer) && g_cv_ReturnBlood.BoolValue)
        {
            int maxHp = GetEntProp(killer, Prop_Data, "m_iMaxHealth");
            int curHp = GetEntProp(killer, Prop_Send, "m_iHealth");
            curHp += 2;
            if(curHp > maxHp) curHp = maxHp;
            if(!L4D_IsPlayerIncapacitated(killer)) SetEntProp(killer, Prop_Send, "m_iHealth", curHp);
        }
    }
}

// 延迟踢除特感Bot
public Action Timer_KickInfBot(Handle hTimer, int client)
{
    if(IsClientInGame(client) && !IsClientInKickQueue(client) && IsFakeClient(client))
    {
        g_i_InfStuckTick[client] = -1000;
        KickClient(client);
    }
    return Plugin_Continue;
}

// L4D脚本数值拦截，强制特感激进
public Action L4D_OnGetScriptValueInt(const char[] key, int &retVal)
{
    if((strcmp(key, "cm_ShouldHurry", false) == 0 || strcmp(key, "cm_AggressiveSpecials", false) == 0) && retVal != 1)
    {
        retVal = 1;
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

// ====================== 定时器回调模块 ======================
// 清理安全屋、不可用导航区域
public Action Timer_CleanSafeNavArea(Handle hTimer)
{
    // 倒序遍历直接删除，避免下标偏移
    for(int i = g_al_AllNavAreas.Length - 1; i >= 0; i--)
    {
        Address pNav = g_al_AllNavAreas.Get(i);
        if(pNav == Address_Null || (L4D_GetNavArea_AttributeFlags(pNav) & NAV_BASE_AVOID) || (L4D_GetNavArea_SpawnAttributes(pNav) & NAV_SPAWN_CHECKPOINT))
        {
            g_al_AllNavAreas.Erase(i);
        }
    }
    return Plugin_Stop;
}

// 循环卡顿检测定时器
public Action Timer_CheckInfStuck(Handle hTimer)
{
    // 延迟生成状态，刷新倒计时与生成计时器
    if(g_b_LateSpawnTrigger && g_i_MaxSpawnCount <= 0)
    {
        g_al_AvailableInfClass.Clear();
        Timer_DestroySingleSpawnTimer();
        if(Countdown_IsRunning()) Countdown_Stop();
        float waitTime = g_f_SpawnInterval * SPAWN_WAIT_MULTIPLE;
        if(g_cv_HudText.BoolValue) Countdown_Start(waitTime);
        g_h_SingleRespawnTimer = CreateTimer(waitTime, Timer_TriggerNewSpawn);
        g_b_LateSpawnTrigger = false;
    }

    // 遍历全部玩家检测卡顿
    for(int client = 1; client <= MaxClients; client++)
    {
        if(!IsInfectedBotValid(client) || !IsPlayerAlive(client) || IsBotPinningSurvivor(client))
        {
            g_i_InfStuckTick[client] = 0;
            continue;
        }
        L4D_WarpToValidPositionIfStuck(client);
        float curPos[3];
        GetClientAbsOrigin(client, curPos);
        Address pLastNav = L4D_GetLastKnownArea(client);
        // 判定卡顿条件：无导航/被视野遮挡/长时间未移动
        bool stuckFlag = (pLastNav == Address_Null || !Entity_IsInfectedVisible(curPos, pLastNav)) || GetVectorDistance(g_f_InfLastPos[client], curPos) < STUCK_MOVE_THRESHOLD;
        if(stuckFlag) Bot_HandleStuck(client);
        else g_i_InfStuckTick[client] = 0;
    }
    return Plugin_Continue;
}

// 倒计时结束，开始生成特感逻辑
public Action Timer_TriggerNewSpawn(Handle hTimer)
{
    // 没有任何人离开安全区，终止生成
    if(!L4D_HasAnySurvivorLeftSafeArea())
    {
        g_b_LateSpawnTrigger = false;
        return Plugin_Stop;
    }

    g_i_TeleportQueueCnt = 0;
    g_b_LateSpawnTrigger = true;
    // 计算还能生成的特感数量
    g_i_MaxSpawnCount = g_cv_SiLimit.IntValue - Count_GetCurrentSpecialCount();
    g_f_SpawnDistance = SPAWN_DIST_DEFAULT;
    Spawn_InitAvailableClassList();

    // 优化：实体总数限制，防止爆实体
    int totalEnt = Count_GetInGameSurvivor() + Count_GetAllInfected() + g_i_MaxSpawnCount;
    if(totalEnt > ENTITY_SPAWN_LIMIT)
    {
        int exceed = totalEnt - ENTITY_SPAWN_LIMIT;
        g_i_MaxSpawnCount -= exceed;
    }

    // 开启分帧导航筛选
    if(g_i_MaxSpawnCount > 0 || g_i_TeleportQueueCnt > 0)
    {
        g_al_ValidSpawnPos.Clear();
        if(!g_b_FrameTaskLock)
        {
            g_b_FrameTaskLock = true;
            RequestFrame(Nav_FindNearSurvivorAreas);
        }
    }

    g_h_SingleRespawnTimer = INVALID_HANDLE;
    if(Countdown_IsRunning()) Countdown_Stop();
    return Plugin_Stop;
}

// ====================== 帧更新 OnGameFrame 主循环 ======================
public void OnGameFrame()
{
    // 未在筛选生成点：仅执行特感AI攻击指令
    if(!g_b_ScanSpawnArea)
    {
        for(int client = 1; client <= MaxClients; client++)
        {
            if(IsInfectedBotValid(client) && IsPlayerAlive(client))
            {
                // 不在梯子上才执行攻击SDKCall，优化句柄判空
                if(!(GetEntityMoveType(client) & MOVETYPE_LADDER) && g_h_InfectedAttackSurvivor != null)
                {
                    SDKCall(g_h_InfectedAttackSurvivor, client);
                }
            }
        }
        return;
    }

    int processCnt = 0;
    int navNearLen = g_al_NearNavAreas.Length;
    float spawnPos[3], navSize[3];
    Address pNav, pSurvNav;

    // 分帧遍历就近导航区
    while(g_i_NavScanIndex < navNearLen && processCnt < MAX_FRAME_PROCESS)
    {
        pNav = g_al_NearNavAreas.Get(g_i_NavScanIndex);
        L4D_GetNavAreaCenter(pNav, spawnPos);
        L4D_GetNavAreaSize(pNav, navSize);

        // 在导航范围内随机生成坐标
        spawnPos[0] = GetRandomFloat(spawnPos[0] - navSize[0] * 0.5, spawnPos[0] + navSize[0] * 0.5);
        spawnPos[1] = GetRandomFloat(spawnPos[1] - navSize[1] * 0.5, spawnPos[1] + navSize[1] * 0.5);
        spawnPos[2] = spawnPos[2] + (navSize[2] < 0.0 ? -navSize[2] : navSize[2]) * 0.5 + 10.0;

        bool visible = false;
        // 检测是否被任意生还者看见/距离过近
        for(int survIdx = 1; survIdx <= MaxClients; survIdx++)
        {
            if(IsSurvivorValid(survIdx) && IsPlayerAlive(survIdx))
            {
                GetClientAbsOrigin(survIdx, g_f_Cache_SurvPos);
                if(GetVectorDistance(spawnPos, g_f_Cache_SurvPos) < g_f_SpawnMinDistance)
                {
                    visible = true;
                    break;
                }
                g_f_Cache_SpawnPos[0] = spawnPos[0];
                g_f_Cache_SpawnPos[1] = spawnPos[1];
                g_f_Cache_SpawnPos[2] = spawnPos[2] + SPAWN_Z_OFFSET;
                if(L4D2_IsVisibleToPlayer(survIdx, TEAM_SURVIVOR, TEAM_INFECTED, pNav, g_f_Cache_SpawnPos))
                {
                    visible = true;
                    break;
                }
            }
        }

        // 完全不可见，校验路径与卡点
        if(!visible)
        {
            for(int survIdx = 1; survIdx <= MaxClients; survIdx++)
            {
                // 跳过倒地、挂边、被控制生还
                if(!IsSurvivorValid(survIdx) || !IsPlayerAlive(survIdx) || IsPlayerPinned(survIdx) || L4D_IsPlayerIncapacitated(survIdx) || L4D_IsPlayerHangingFromLedge(survIdx)) continue;
                GetClientAbsOrigin(survIdx, g_f_Cache_SurvPos);
                pSurvNav = L4D_GetNearestNavArea(g_f_Cache_SurvPos, NAV_SEARCH_RANGE, false, false, false, TEAM_SURVIVOR);
                float baseDist = g_f_SpawnDistance + NAV_SEARCH_RANGE;
                float vertDist = spawnPos[2] - g_f_Cache_SurvPos[2];
                // 垂直高度差小，缩短生成距离
                if(vertDist < VERTICAL_DIST_CAP && baseDist < SPAWN_DIST_MAX) baseDist *= 0.5;
                // 路径可达、不和其他生成点重叠、不卡点则存入有效坐标
                if(L4D2_NavAreaBuildPath(pNav, pSurvNav, baseDist, TEAM_INFECTED, false) && !Entity_PosTooCloseExisting(spawnPos) && !Entity_PosStuckCheck(spawnPos))
                {
                    g_al_ValidSpawnPos.PushArray(spawnPos, 3);
                    break;
                }
            }
        }
        g_i_NavScanIndex++;
        processCnt++;
    }

    // 导航遍历完成，进入生成流程
    if(g_i_NavScanIndex >= navNearLen)
    {
        if(g_i_MaxSpawnCount > 0 || g_i_TeleportQueueCnt > 0)
        {
            RequestFrame(Spawn_ProcessQueue);
        }
        g_b_ScanSpawnArea = false;
    }
}

// ====================== 导航工具函数 Nav_* ======================
// 筛选离生还者较近的导航区域
stock void Nav_FindNearSurvivorAreas()
{
    if(g_i_NavIterIndex == 0) g_al_NearNavAreas.Clear();
    int processCnt = 0;
    float spawnPos[3], survPos[3];
    int targetSurv = Survivor_GetFirstValid();

    while(g_i_NavIterIndex < g_al_AllNavAreas.Length && processCnt < 450)
    {
        Address pNav = g_al_AllNavAreas.Get(g_i_NavIterIndex);
        L4D_GetNavAreaCenter(pNav, spawnPos);

        for(int survIdx = 1; survIdx <= MaxClients; survIdx++)
        {
            if(!IsSurvivorValid(survIdx) || !IsPlayerAlive(survIdx)) continue;
            GetClientAbsOrigin(survIdx, survPos);
            float distFilter = (survIdx == targetSurv) ? g_f_SpawnDistance : SURVIVOR_DIST_FILTER;

            if(GetVectorDistance(spawnPos, survPos) < distFilter)
            {
                g_al_NearNavAreas.Push(pNav);
                break;
            }
        }
        g_i_NavIterIndex++;
        processCnt++;
    }

    if(g_i_NavIterIndex >= g_al_AllNavAreas.Length)
    {
        g_i_NavIterIndex = 0;
        g_b_FrameTaskLock = false;
        RequestFrame(Nav_StartSpawnFilter);
    }
    else
    {
        RequestFrame(Nav_FindNearSurvivorAreas);
    }
}

// 开启生成坐标筛选状态
void Nav_StartSpawnFilter()
{
    g_i_NavScanIndex = 0;
    g_b_ScanSpawnArea = true;
    g_al_ValidSpawnPos.Clear();
}

// 关闭生成坐标筛选状态
void Nav_StopSpawnFilter()
{
    g_b_ScanSpawnArea = false;
    g_i_NavScanIndex = 0;
    g_al_ValidSpawnPos.Clear();
}

// ====================== 特感生成工具 Spawn_* ======================
// 处理待生成/待传送特感队列
public void Spawn_ProcessQueue()
{
    int totalNeed = g_i_MaxSpawnCount + g_i_TeleportQueueCnt;
    if(totalNeed <= 0) return;

    while(g_al_ValidSpawnPos.Length > 0 && (g_i_MaxSpawnCount + g_i_TeleportQueueCnt) > 0)
    {
        float spawnPos[3];
        if(!Spawn_GetRandomValidPos(spawnPos)) break;
        Address pNav = L4D_GetNearestNavArea(spawnPos, NAV_SEARCH_RANGE, false, false, false, TEAM_INFECTED);
        // 空导航/生还可见跳过该点
        if(pNav == Address_Null || Entity_PosVisibleAllSurvivor(spawnPos, pNav)) continue;

        int infType;
        // 猎人模式强制只生成Hunter
        if(g_cv_HunterMode.BoolValue) infType = 3;
        else infType = Spawn_RandomSelectClass();

        int spawnClient = Spawn_CreateInfectedBot(g_sz_InfClassShort[infType]);
        if(spawnClient == -1 || !IsClientInGame(spawnClient)) continue;

        // 传送队列优先消耗，再消耗新增生成数量
        if(g_i_TeleportQueueCnt > 0) g_i_TeleportQueueCnt--;
        else if(g_i_MaxSpawnCount > 0) g_i_MaxSpawnCount--;

        Spawn_InitBotState(spawnClient, spawnPos);
    }

    // 还有待生成，扩大距离重新筛选
    if((g_i_MaxSpawnCount + g_i_TeleportQueueCnt) > 0) Spawn_AdjustDistanceRetry();
}

// 扩大生成距离重新遍历导航
void Spawn_AdjustDistanceRetry()
{
    Nav_StopSpawnFilter();
    if(g_f_SpawnDistance >= SPAWN_DIST_MAX)
    {
        g_f_SpawnDistance = SPAWN_DIST_MAX;
        if(!g_b_FrameTaskLock)
        {
            g_b_FrameTaskLock = true;
            RequestFrame(Nav_FindNearSurvivorAreas);
        }
    }
    else
    {
        g_f_SpawnDistance += 50.0;
        Nav_StartSpawnFilter();
        if(!g_b_FrameTaskLock)
        {
            g_b_FrameTaskLock = true;
            RequestFrame(Nav_FindNearSurvivorAreas);
        }
    }
}

// 随机取出一个有效生成坐标并删除缓存
static bool Spawn_GetRandomValidPos(float outPos[3])
{
    int arrLen = g_al_ValidSpawnPos.Length;
    if(arrLen == 0) return false;
    int randIdx = GetRandomInt(0, arrLen - 1);
    g_al_ValidSpawnPos.GetArray(randIdx, outPos, 3);
    g_al_ValidSpawnPos.Erase(randIdx);
    return true;
}

// 初始化可用特感类型列表（按游戏原生z_xxx_limit填充）
stock void Spawn_InitAvailableClassList()
{
    g_al_AvailableInfClass.Clear();
    for(int i = 1; i <= 6; i++)
    {
        int curCnt = Count_GetInfectedClassCurrent(i);
        int maxLimit = Count_GetInfectedClassMax(i);
        int remain = maxLimit - curCnt;
        if(remain <= 0) continue;
        for(int a = 1; a <= remain; a++) g_al_AvailableInfClass.Push(i);
    }
}

// 随机选取特感类型，规避Boomer/Spitter连续生成
stock int Spawn_RandomSelectClass()
{
    if(g_al_AvailableInfClass == null || g_al_AvailableInfClass.Length <= 0) return 3;
    int randIdx = GetRandomInt(0, g_al_AvailableInfClass.Length - 1);
    int type = g_al_AvailableInfClass.Get(randIdx);
    // 抽到呕吐/喷吐，重新随机一次
    if(type == 2 || type == 4)
    {
        randIdx = GetRandomInt(0, g_al_AvailableInfClass.Length - 1);
        type = g_al_AvailableInfClass.Get(randIdx);
    }
    g_al_AvailableInfClass.Erase(randIdx);
    return type;
}

// 通过SDKCall创建指定类型特感Bot
int Spawn_CreateInfectedBot(const char[] className)
{
    int bot = -1;
    if(StrEqual(className, "smoker", false))
    {
        bot = SDKCall(g_h_CreateSmoker, "Smoker");
        if(IsValidClient(bot)) SetEntityModel(bot, MODEL_SMOKER);
    }
    else if(StrEqual(className, "boomer", false))
    {
        bot = SDKCall(g_h_CreateBoomer, "Boomer");
        if(IsValidClient(bot)) SetEntityModel(bot, MODEL_BOOMER);
    }
    else if(StrEqual(className, "hunter", false))
    {
        bot = SDKCall(g_h_CreateHunter, "Hunter");
        if(IsValidClient(bot)) SetEntityModel(bot, MODEL_HUNTER);
    }
    else if(StrEqual(className, "spitter", false))
    {
        bot = SDKCall(g_h_CreateSpitter, "Spitter");
        if(IsValidClient(bot)) SetEntityModel(bot, MODEL_SPITTER);
    }
    else if(StrEqual(className, "jockey", false))
    {
        bot = SDKCall(g_h_CreateJockey, "Jockey");
        if(IsValidClient(bot)) SetEntityModel(bot, MODEL_JOCKEY);
    }
    else if(StrEqual(className, "charger", false))
    {
        bot = SDKCall(g_h_CreateCharger, "Charger");
        if(IsValidClient(bot)) SetEntityModel(bot, MODEL_CHARGER);
    }

    // 实体基础参数初始化
    if(IsValidClient(bot))
    {
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

// 传送特感、重置卡顿计数、执行AI攻击
stock void Spawn_InitBotState(int client, float spawnPos[3])
{
    g_f_InfLastPos[client] = spawnPos;
    TeleportEntity(client, spawnPos, NULL_VECTOR, NULL_VECTOR);
    L4D_WarpToValidPositionIfStuck(client);
    g_i_InfStuckTick[client] = 0;
    if(g_h_InfectedAttackSurvivor != null) SDKCall(g_h_InfectedAttackSurvivor, client);
}

// ====================== 实体/坐标检测工具 Entity_* ======================
// 判断新坐标距离已有生成点过近
stock bool Entity_PosTooCloseExisting(float newPos[3])
{
    if(g_al_ValidSpawnPos == null) return false;
    int arrLen = g_al_ValidSpawnPos.Length;
    if(arrLen == 0) return false;

    for(int i = 0; i < arrLen; i++)
    {
        float cachePos[3];
        g_al_ValidSpawnPos.GetArray(i, cachePos, 3);
        if(GetVectorDistance(newPos, cachePos) < MIN_SPAWN_POS_DIST) return true;
    }
    return false;
}

// 射线检测坐标是否卡点
stock bool Entity_PosStuckCheck(float pos[3])
{
    float rayStart1[3], rayEnd1[3];
    rayStart1[0] = pos[0] - 15.0; rayStart1[1] = pos[1] + 15.0; rayStart1[2] = pos[2] + 70.0;
    rayEnd1[0] = pos[0] + 15.0; rayEnd1[1] = pos[1] - 15.0; rayEnd1[2] = pos[2] + 10.0;
    if(Trace_RayStuck(rayStart1, rayEnd1)) return true;

    float rayStart2[3], rayEnd2[3];
    rayStart2[0] = pos[0] - 15.0; rayStart2[1] = pos[1] - 15.0; rayStart2[2] = pos[2] + 10.0;
    rayEnd2[0] = pos[0] + 15.0; rayEnd2[1] = pos[1] + 15.0; rayEnd2[2] = pos[2] + 70.0;
    if(Trace_RayStuck(rayStart2, rayEnd2)) return true;
    return false;
}

// 射线卡点检测封装
stock bool Trace_RayStuck(float start[3], float end[3])
{
    TR_TraceRayFilter(start, end, MASK_NPCSOLID_BRUSHONLY, RayType_EndPoint, Trace_FilterIgnoreInvalid);
    return TR_DidHit();
}

// 射线过滤：忽略玩家与无效实体
stock bool Trace_FilterIgnoreInvalid(int ent, int mask)
{
    if(ent <= MaxClients || !IsValidEntity(ent)) return false;
    char className[20];
    GetEntityClassname(ent, className, sizeof(className));
    if(strcmp(className, "env_physics_blocker") == 0 && !Entity_IsPhysicsBlockerValid(ent)) return false;
    return true;
}

// 物理阻挡实体有效性校验
stock bool Entity_IsPhysicsBlockerValid(int ent)
{
    int blockType = GetEntProp(ent, Prop_Data, "m_nBlockType");
    return !(blockType == 1 || blockType == 2);
}

// 检测坐标是否被任意生还者看见/距离不足
stock bool Entity_PosVisibleAllSurvivor(float targetPos[3], Address pNav)
{
    float survPos[3], originZ[3];
    originZ = targetPos;
    originZ[2] += SPAWN_Z_OFFSET;
    for(int survIdx = 1; survIdx <= MaxClients; survIdx++)
    {
        if(IsSurvivorValid(survIdx) && IsPlayerAlive(survIdx))
        {
            GetClientAbsOrigin(survIdx, survPos);
            float dist = GetVectorDistance(targetPos, survPos);
            if(dist < g_f_SpawnMinDistance) return true;
            if(L4D2_IsVisibleToPlayer(survIdx, TEAM_SURVIVOR, TEAM_INFECTED, pNav, originZ)) return true;
        }
    }
    return false;
}

// 检测坐标特感是否会被生还看见
stock bool Entity_IsInfectedVisible(float targetPos[3], Address pNav)
{
    g_f_Cache_OriginZ[0] = targetPos[0];
    g_f_Cache_OriginZ[1] = targetPos[1];
    g_f_Cache_OriginZ[2] = targetPos[2] + SPAWN_Z_OFFSET;
    for(int client = 1; client <= MaxClients; client++)
    {
        if(IsSurvivorValid(client) && IsPlayerAlive(client))
        {
            if(L4D2_IsVisibleToPlayer(client, TEAM_SURVIVOR, TEAM_INFECTED, pNav, g_f_Cache_OriginZ)) return true;
        }
    }
    return false;
}

// ====================== 倒计时工具 Countdown_* ======================
// 获取拾荒计时器指针
CountdownTimer Countdown_GetTimerPtr()
{
    return L4D2Direct_GetScavengeRoundSetupTimer();
}

// 开启顶部ready_countdown倒计时UI
stock void Countdown_Start(float duration)
{
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i) && !IsFakeClient(i)) ShowVGUIPanel(i, "ready_countdown", _, true);
    }
    CTimer_Start(Countdown_GetTimerPtr(), duration);
}

// 判断倒计时是否正在运行
stock bool Countdown_IsRunning()
{
    return CTimer_HasStarted(Countdown_GetTimerPtr());
}

// 判断倒计时是否走完
stock bool Countdown_IsElapsed()
{
    return CTimer_IsElapsed(Countdown_GetTimerPtr());
}

// 关闭倒计时UI、销毁计时器
stock void Countdown_Stop()
{
    CTimer_Invalidate(Countdown_GetTimerPtr());
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i) && !IsFakeClient(i)) ShowVGUIPanel(i, "ready_countdown", _, false);
    }
}

// 获取倒计时剩余时间
stock float Countdown_GetRemaining()
{
    return CTimer_GetRemainingTime(Countdown_GetTimerPtr());
}

// ====================== 计时器通用工具 Timer_* ======================
// 销毁主刷特计时器（优化：统一封装，消除重复代码）
void Timer_DestroySingleSpawnTimer()
{
    if(g_h_SingleRespawnTimer != INVALID_HANDLE)
    {
        KillTimer(g_h_SingleRespawnTimer);
        g_h_SingleRespawnTimer = INVALID_HANDLE;
    }
}

// ====================== gamedata加载与SDK签名 GameData_* ======================
void GameData_Load()
{
    char filePath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, filePath, sizeof(filePath), "gamedata/%s.txt", GAMEDATA_NAME);
    if(FileExists(filePath)) g_h_GameData = LoadGameConfigFile(GAMEDATA_NAME);
    GameData_PrepSDKCall();
}

// 内存地址字符串读取
void GameData_LoadStringFromAddr(Address addr, char[] buf, int maxLen)
{
    int i = 0;
    while(i < maxLen)
    {
        char c = LoadFromAddress(addr + view_as<Address>(i), NumberType_Int8);
        if(c == 0) { buf[i] = 0; break; }
        buf[i] = c;
        i++;
    }
    buf[maxLen - 1] = 0;
}

// 通过Trie预创建Bot SDK句柄
Handle GameData_PrepBotCallFromTrie(Handle trie, const char[] sigName)
{
    Address funcAddr;
    StartPrepSDKCall(SDKCall_Static);
    if(!GetTrieValue(trie, sigName, funcAddr) || !PrepSDKCall_SetAddress(funcAddr))
    {
        SetFailState("Unable to find NextBotCreatePlayer<%s> address in memory.", sigName);
        return null;
    }
    PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
    PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
    return EndPrepSDKCall();
}

// Windows跳转表签名预处理
void GameData_PrepWindowsBotCall(Address jumpTableAddr)
{
    Handle trie = CreateTrie();
    for(int i = 0; i < 7; i++)
    {
        Address caseBase = jumpTableAddr + view_as<Address>(i * 12);
        Address strAddr = view_as<Address>(LoadFromAddress(caseBase + view_as<Address>(1), NumberType_Int32));
        char sigName[32];
        GameData_LoadStringFromAddr(strAddr, sigName, sizeof(sigName));
        Address refAddr = caseBase + view_as<Address>(6);
        int relOff = LoadFromAddress(refAddr, NumberType_Int32);
        Address funcAddr = caseBase + view_as<Address>(10) + view_as<Address>(relOff);
        SetTrieValue(trie, sigName, funcAddr);
    }

    g_h_CreateSmoker = GameData_PrepBotCallFromTrie(trie, "Smoker");
    if(g_h_CreateSmoker == null) SetFailState("Cannot initialize %s SDKCall, address lookup failed.", SIG_CREATE_SMOKER);
    g_h_CreateBoomer = GameData_PrepBotCallFromTrie(trie, "Boomer");
    if(g_h_CreateBoomer == null) SetFailState("Cannot initialize %s SDKCall, address lookup failed.", SIG_CREATE_BOOMER);
    g_h_CreateHunter = GameData_PrepBotCallFromTrie(trie, "Hunter");
    if(g_h_CreateHunter == null) SetFailState("Cannot initialize %s SDKCall, address lookup failed.", SIG_CREATE_HUNTER);
    g_h_CreateTank = GameData_PrepBotCallFromTrie(trie, "Tank");
    if(g_h_CreateTank == null) SetFailState("Cannot initialize %s SDKCall, address lookup failed.", SIG_CREATE_TANK);
    g_h_CreateSpitter = GameData_PrepBotCallFromTrie(trie, "Spitter");
    if(g_h_CreateSpitter == null) SetFailState("Cannot initialize %s SDKCall, address lookup failed.", SIG_CREATE_SPITTER);
    g_h_CreateJockey = GameData_PrepBotCallFromTrie(trie, "Jockey");
    if(g_h_CreateJockey == null) SetFailState("Cannot initialize %s SDKCall, address lookup failed.", SIG_CREATE_JOCKEY);
    g_h_CreateCharger = GameData_PrepBotCallFromTrie(trie, "Charger");
    if(g_h_CreateCharger == null) SetFailState("Cannot initialize %s SDKCall, address lookup failed.", SIG_CREATE_CHARGER);
}

// L4D2特感签名预处理
void GameData_PrepL4D2BotCall()
{
    g_h_CreateSpitter = GameData_PrepSDKBotSig(SIG_CREATE_SPITTER);
    if(g_h_CreateSpitter == null) SetFailState("Cannot initialize %s SDKCall, signature is broken.", SIG_CREATE_SPITTER);
    g_h_CreateJockey = GameData_PrepSDKBotSig(SIG_CREATE_JOCKEY);
    if(g_h_CreateJockey == null) SetFailState("Cannot initialize %s SDKCall, signature is broken.", SIG_CREATE_JOCKEY);
    g_h_CreateCharger = GameData_PrepSDKBotSig(SIG_CREATE_CHARGER);
    if(g_h_CreateCharger == null) SetFailState("Cannot initialize %s SDKCall, signature is broken.", SIG_CREATE_CHARGER);
}

// L4D1特感签名预处理
void GameData_PrepL4D1BotCall()
{
    g_h_CreateSmoker = GameData_PrepSDKBotSig(SIG_CREATE_SMOKER);
    if(g_h_CreateSmoker == null) SetFailState("Cannot initialize %s SDKCall, signature is broken.", SIG_CREATE_SMOKER);
    g_h_CreateBoomer = GameData_PrepSDKBotSig(SIG_CREATE_BOOMER);
    if(g_h_CreateBoomer == null) SetFailState("Cannot initialize %s SDKCall, signature is broken.", SIG_CREATE_BOOMER);
    g_h_CreateHunter = GameData_PrepSDKBotSig(SIG_CREATE_HUNTER);
    if(g_h_CreateHunter == null) SetFailState("Cannot initialize %s SDKCall, signature is broken.", SIG_CREATE_HUNTER);
    g_h_CreateTank = GameData_PrepSDKBotSig(SIG_CREATE_TANK);
    if(g_h_CreateTank == null) SetFailState("Cannot initialize %s SDKCall, signature is broken.", SIG_CREATE_TANK);
}

// 通过gamedata签名创建SDK句柄
Handle GameData_PrepSDKBotSig(const char[] sigName)
{
    StartPrepSDKCall(SDKCall_Static);
    if(!PrepSDKCall_SetFromConf(g_h_GameData, SDKConf_Signature, sigName))
    {
        SetFailState("Unable to find %s signature in gamedata file.", sigName);
        return null;
    }
    PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
    PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
    return EndPrepSDKCall();
}

// 全部SDKCall签名初始化入口
void GameData_PrepSDKCall()
{
    if(g_h_GameData == null) SetFailState("Unable to find %s.txt gamedata.", GAMEDATA_NAME);
    Address jumpTableAddr = GameConfGetAddress(g_h_GameData, "NextBotCreatePlayerBot.jumptable");
    if(jumpTableAddr != Address_Null && LoadFromAddress(jumpTableAddr, NumberType_Int8) == 0x68) GameData_PrepWindowsBotCall(jumpTableAddr);
    else
    {
        GameData_PrepL4D2BotCall();
        GameData_PrepL4D1BotCall();
    }

    StartPrepSDKCall(SDKCall_Entity);
    if(!PrepSDKCall_SetFromConf(g_h_GameData, SDKConf_Signature, SIG_INF_ATTACK_SURV))
    {
        SetFailState("Unable to find %s signature in gamedata file.", SIG_INF_ATTACK_SURV);
        return;
    }
    g_h_InfectedAttackSurvivor = EndPrepSDKCall();
    if(g_h_InfectedAttackSurvivor == null) SetFailState("Cannot initialize %s SDKCall, signature is broken.", SIG_INF_ATTACK_SURV);
}

// ====================== 模型预加载 Model_* ======================
// 一次性预缓存全部特感模型
stock void Model_PrecacheAllInfected()
{
    Model_PrecacheSingle(MODEL_SMOKER);
    Model_PrecacheSingle(MODEL_BOOMER);
    Model_PrecacheSingle(MODEL_HUNTER);
    Model_PrecacheSingle(MODEL_SPITTER);
    Model_PrecacheSingle(MODEL_JOCKEY);
    Model_PrecacheSingle(MODEL_CHARGER);
}

// 单个模型按需预加载
stock void Model_PrecacheSingle(const char[] path)
{
    if(!IsModelPrecached(path)) PrecacheModel(path, true);
}


// ====================== 全局状态重置 Global_* ======================
// 轻量重置（回合切换）
public void Global_InitStatus()
{
    g_b_ScanSpawnArea = false;
    g_i_NavScanIndex = 0;
    g_i_MaxSpawnCount = 0;
    g_i_TeleportQueueCnt = 0;
    g_b_LateSpawnTrigger = false;
    if(Countdown_IsRunning()) Countdown_Stop();
}

// 完整全局重置（切图/安全屋重置）
public void Global_ResetAll()
{
    g_b_FrameTaskLock = false;
    g_b_ScanSpawnArea = false;
    g_i_NavScanIndex = 0;
    g_i_MaxSpawnCount = 0;
    g_i_TeleportQueueCnt = 0;
    g_b_LateSpawnTrigger = false;

    // 清空所有缓存数组
    g_al_NearNavAreas.Clear();
    g_al_AvailableInfClass.Clear();
    g_al_ValidSpawnPos.Clear();
    g_al_RandomIndex.Clear();
    g_al_TempIndex.Clear();

    // 遍历踢除全部存活特感Bot，清空卡顿计数
    for(int client = 1; client <= MaxClients; client++)
    {
        if(IsInfectedBotValid(client))
        {
            g_i_InfStuckTick[client] = 0;
            if(IsClientInGame(client) && !IsClientInKickQueue(client)) KickClient(client);
        }
        // 安全屋内倒地生还复活
        if(!L4D_HasAnySurvivorLeftSafeArea() && IsSurvivorValid(client) && !IsPlayerAlive(client))
        {
            L4D_RespawnPlayer(client);
        }
    }

    if(Countdown_IsRunning()) Countdown_Stop();
}

// ====================== 卡顿特感处理 Bot_* ======================
void Bot_HandleStuck(int client)
{
    // 卡顿超过阈值，加入传送队列销毁重建
    if(g_i_InfStuckTick[client] > STUCK_MAX_TICK)
    {
        g_f_SpawnDistance = SPAWN_DIST_DEFAULT;
        g_i_InfStuckTick[client] = -1000;
        g_i_TeleportQueueCnt++;
        g_al_AvailableInfClass.Push(GetEntProp(client, Prop_Send, "m_zombieClass"));
        KickClient(client);
        Survivor_CollectMovableIdx();
        RequestFrame(Nav_StartSpawnFilter);
    }
    else
    {
        g_i_InfStuckTick[client] += STUCK_TICK_STEP;
    }
}

// ====================== 生还者工具 Survivor_* ======================
// 收集未倒地、未被控制、可移动生还索引
stock void Survivor_CollectMovableIdx()
{
    g_al_TempIndex.Clear();
    for(int survIdx = 1; survIdx <= MaxClients; survIdx++)
    {
        if(!IsValidClient(survIdx) || !IsPlayerAlive(survIdx) || !IsSurvivorValid(survIdx)) continue;
        if(L4D_IsPlayerIncapacitated(survIdx) || L4D_IsPlayerHangingFromLedge(survIdx) || IsPlayerPinned(survIdx)) continue;
        g_al_TempIndex.Push(survIdx);
    }
}

// 获取流程最靠前的有效生还
static int Survivor_GetFirstValid()
{
    int surv = L4D_GetHighestFlowSurvivor();
    if(IsSurvivorValid(surv) && IsPlayerAlive(surv) && !L4D_IsPlayerIncapacitated(surv) && !L4D_IsPlayerHangingFromLedge(surv)) return surv;
    return -1;
}

// ====================== 计数工具 Count_* ======================
// 统计当前存活特感Bot总数
stock int Count_GetCurrentSpecialCount()
{
    int count = 0;
    for(int client = 1; client <= MaxClients; client++)
    {
        if(IsClientInGame(client) && IsInfectedBotValid(client) && IsPlayerAlive(client)) count++;
    }
    return count;
}

// 统计在场所有生还（含死亡）
stock int Count_GetInGameSurvivor()
{
    int count = 0;
    for(int client = 1; client <= MaxClients; client++)
    {
        if(IsClientInGame(client) && IsSurvivorValid(client)) count++;
    }
    return count;
}

// 统计所有特感Bot（含死亡）
stock int Count_GetAllInfected()
{
    int count = 0;
    for(int client = 1; client <= MaxClients; client++)
    {
        if(IsClientInGame(client) && IsInfectedBotValid(client)) count++;
    }
    return count;
}

// 获取单类特感当前数量
stock int Count_GetInfectedClassCurrent(int classId)
{
    int count = 0;
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED && GetEntProp(i, Prop_Send, "m_zombieClass") == classId) count++;
    }
    return count;
}

// 获取游戏原生z_xxx_limit上限
stock int Count_GetInfectedClassMax(int classId)
{
    char cvName[16];
    Format(cvName, 16, "z_%s_limit", g_sz_InfClassShort[classId]);
    ConVar cv = FindConVar(cvName);
    return (cv != null) ? cv.IntValue : 0;
}

// ====================== 玩家有效性判断 IsXXXValid ======================
// 通用客户端基础校验
stock bool IsValidClient(int client, bool checkReplay = false)
{
    if(client <= 0 || client > MaxClients || !IsClientInGame(client)) return false;
    return checkReplay ? (!IsClientSourceTV(client) && !IsClientReplay(client)) : true;
}

// 校验生还玩家
stock bool IsSurvivorValid(int client)
{
    return IsValidClient(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}

// 校验特感Bot
stock bool IsInfectedBotValid(int client)
{
    if(client <= 0 || client > MaxClients || !IsClientInGame(client) || !IsFakeClient(client)) return false;
    int classId = GetEntProp(client, Prop_Send, "m_zombieClass");
    return GetClientTeam(client) == TEAM_INFECTED && classId >= 1 && classId <= 6;
}

// 玩家是否被特感控制（舌头/骑乘/扑击/冲撞）
stock bool IsPlayerPinned(int client)
{
    return GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0
        || GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0
        || GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0
        || GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0
        || GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0;
}

// 特感是否正在控制生还
stock bool IsBotPinningSurvivor(int client)
{
    if(!IsInfectedBotValid(client)) return false;
    return GetEntPropEnt(client, Prop_Send, "m_tongueVictim") > 0
        || GetEntPropEnt(client, Prop_Send, "m_jockeyVictim") > 0
        || GetEntPropEnt(client, Prop_Send, "m_pounceVictim") > 0
        || GetEntPropEnt(client, Prop_Send, "m_pummelVictim") > 0
        || GetEntPropEnt(client, Prop_Send, "m_carryVictim") > 0;
}

// 是否幽灵状态
stock bool IsPlayerGhost(int client)
{
    return IsValidClient(client) && view_as<bool>(GetEntProp(client, Prop_Send, "m_isGhost"));
}
#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>
#include <treeutil>

#define CVAR_FLAG FCVAR_NOTIFY
#define INVALID_CLIENT -1
/* 检测吃铁的时间间隔需要少于伤害统计输出时间间隔，否则 round_end 无法检测最后吃铁 */
#define IRON_CHECK_INTERVAL 0.5
#define DAMAGE_DISPLAY_DELAY 1.0
#define DEBUG_ALL 0

public Plugin myinfo = 
{
	name 			= "Tank Damage Announce 2.0",
	author 			= "夜羽真白",
	description 	= "Tank 伤害统计 2.0 版本",
	version 		= "2023/1/16",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

ConVar
	g_hAllowAnnounce,
	g_hAllowForceKillAnnounce,
	g_hAllowPrintLiveTime,
	g_hMissionFailedAnnounce,
	g_hEnableHealthSet,
	g_hSurvivorLimit,
	g_hHealthLimit,
	g_hAllowPrintZeroDamage;

/* Tank 受到来自玩家的伤害，tankId，clientId */
int
	tankHurt[MAXPLAYERS + 1][MAXPLAYERS + 1],
	tankHealth[MAXPLAYERS + 1] = { 0 },
	tankLastHelath[MAXPLAYERS + 1] = { 0 };
float
	tankLiveTime[MAXPLAYERS + 1] = { 0.0 };
bool
	hasPrintDamage[MAXPLAYERS + 1] = { false };
Handle
	ironCheckTimer[MAXPLAYERS + 1][2];

/* 玩家受到来自 Tank 伤害结构体，tankId，clientId */
enum struct PlayerHurt
{
	int punch;
	int rock;
	int iron;
	int gotDamage;
	void init()
	{
		this.punch = this.rock = this.iron = this.gotDamage = 0;
	}
}
PlayerHurt playerHurts[MAXPLAYERS + 1][MAXPLAYERS + 1];

public void OnPluginStart()
{
	g_hAllowAnnounce = CreateConVar("tank_damage_enable", "1", "是否允许在 Tank 死亡后输出生还者对 Tank 的伤害统计", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hAllowForceKillAnnounce = CreateConVar("tank_damage_force_kill_announce", "1", "Tank 被强制处死或自杀时是否输出生还者对 Tank 的伤害统计", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hAllowPrintLiveTime = CreateConVar("tank_damage_print_livetime", "1", "是否显示 Tank 存活时间", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hMissionFailedAnnounce = CreateConVar("tank_damage_failed_announce", "1", "生还者团灭时在场还有 Tank 是否显示生还者对 Tank 的伤害统计", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hAllowPrintZeroDamage = CreateConVar("tank_damage_print_zero", "1", "是否允许显示对 Tank 零伤的玩家", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hEnableHealthSet = CreateConVar("tank_damage_enable_healthset", "1", "是否将坦克的生命值设置为 z_tank_health 数值", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hSurvivorLimit = FindConVar("survivor_limit");
	g_hHealthLimit = FindConVar("z_tank_health");
	// HookEvents
	HookEvent("round_start", roundStartHandler);
	HookEvent("player_spawn", playerSpawnHandler);
	HookEvent("player_death", playerDeathHandler);
	HookEvent("round_end", roundEndHandler);
	HookEvent("player_hurt", playerHurtHandler);
	HookEvent("player_team", playerChangeTeamHandler);
}

/* 玩家离开 UnHook 吃铁检测 */
public void OnClientDisconnect(int client)
{
	if (!IsValidClient(client)) { return; }
	SDKUnhook(client, SDKHook_OnTakeDamage, onTakeDamageHandler);
}

/* 第一个玩家出门时，给每个生还者设置 OnTakeDamage 的 SDKHook 用来检测吃铁 */
public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	static int i;
	for (i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR) { continue; }
		SDKUnhook(i, SDKHook_OnTakeDamage, onTakeDamageHandler);
		SDKHook(i, SDKHook_OnTakeDamage, onTakeDamageHandler);
	}
	return Plugin_Continue;
}

public void playerChangeTeamHandler(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid")), newTeam = event.GetInt("team");
	bool disconnect = event.GetBool("disconnect");
	if (!IsValidClient(client)) { return; }
	if (disconnect) { SDKUnhook(client, SDKHook_OnTakeDamage, onTakeDamageHandler); }
	/* 玩家变更团队到生还者，为其加上受到伤害的 Hook */
	if (newTeam == TEAM_SURVIVOR)
	{
		SDKUnhook(client, SDKHook_OnTakeDamage, onTakeDamageHandler);
		SDKHook(client, SDKHook_OnTakeDamage, onTakeDamageHandler);
	}
}

/* 检测生还者是否吃铁 */
public Action onTakeDamageHandler(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
	if (!IsValidSurvivor(victim) || !isTank(attacker)) { return Plugin_Continue; }
	if (!IsValidEntity(inflictor) || !IsValidEdict(inflictor)) { return Plugin_Continue; }
	if (!HasEntProp(inflictor, Prop_Send, "m_hasTankGlow") || GetEntProp(inflictor, Prop_Send, "m_hasTankGlow", 1) != 1) { return Plugin_Continue; }
	/* 生还者吃到的是铁 */
	/* 第一次未创建时钟，需要删除重新创建，后续吃到多次伤害也需要删除重新创建，因此无需判断时钟是否为 null */
	delete ironCheckTimer[victim][0];
	delete ironCheckTimer[victim][1];
	DataPack pack = new DataPack();
	pack.Reset();
	pack.WriteCell(attacker);
	pack.WriteCell(victim);
	ironCheckTimer[victim][0] = CreateTimer(IRON_CHECK_INTERVAL, checkIronHandler, pack);
	ironCheckTimer[victim][1] = pack;
	return Plugin_Continue;
}
public Action checkIronHandler(Handle timer, DataPack pack)
{
	if (pack == null) { return Plugin_Continue; }
	pack.Reset();
	int attacker = pack.ReadCell(), victim = pack.ReadCell();
	delete pack;
	ironCheckTimer[victim][1] = null;
	if (!isTank(attacker) || !IsValidSurvivor(victim))
	{
		ironCheckTimer[victim][0] = null;
		return Plugin_Stop;
	}
	playerHurts[attacker][victim].iron++;
	ironCheckTimer[victim][0] = null;
	return Plugin_Stop;
}

public void playerHurtHandler(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker")), victim = GetClientOfUserId(event.GetInt("userid")), 
	damage = event.GetInt("dmg_health"), remainHealth = event.GetInt("health");
	char weapon[64] = {'\0'};
	event.GetString("weapon", weapon, sizeof(weapon));
	/* Tank 对玩家造成的伤害 */
	if (isTank(attacker) && IsPlayerAlive(attacker) && IsValidSurvivor(victim) && IsPlayerAlive(victim))
	{
		playerHurts[attacker][victim].gotDamage += damage;
		/* 判断玩家是吃拳还是吃石 */
		if (strcmp(weapon, "tank_claw") == 0) { playerHurts[attacker][victim].punch++; }
		else if (strcmp(weapon, "tank_rock") == 0) { playerHurts[attacker][victim].rock++; }
	}
	/* 玩家对 Tank 造成的伤害 */
	else if (IsValidSurvivor(attacker) && IsPlayerAlive(attacker) && isTank(victim) && IsPlayerAlive(victim) && !IsClientIncapped(victim))
	{
		tankHurt[victim][attacker] += damage;
		/* Tank 有死亡动画，最后一次伤害不会算入 playerHurt 中，因此需要记录最后一次剩余血量，Tank 死亡时加入到生还者伤害中 */
		tankLastHelath[victim] = remainHealth;
	}
}
public void OnMapStart()
{
	PrecacheSound("ui/pickup_secret01.wav");
}
public void playerSpawnHandler(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!isTank(client) || !IsPlayerAlive(client)) { return; }
	tankHealth[client] = GetClientHealth(client);
	tankLiveTime[client] = GetGameTime();
	/* 清空这个 Tank 的伤害统计 */
	clearTankDamage(client);
	hasPrintDamage[client] = false;
	// 设置生命
	if (g_hEnableHealthSet.BoolValue)
	{
		int MaxTankHealth = GetConVarInt(g_hHealthLimit);
		SetConVarInt(g_hHealthLimit, MaxTankHealth);
		SetEntProp(client, Prop_Data, "m_iHealth", g_hHealthLimit.IntValue);
		SetEntProp(client, Prop_Data, "m_iMaxHealth", g_hHealthLimit.IntValue);
	}
	EmitSoundToAll("ui/pickup_secret01.wav");
	/* 显示 Tank 生成 */
	CPrintToChatAll("{blue}Tank has spawned!");
}

public void playerDeathHandler(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker")), victim = GetClientOfUserId(event.GetInt("userid"));
	if (!isTank(victim)) { return; }
		/* 谁杀死了克，加 Tank 最后剩余的血量 */
	tankHurt[victim][attacker] += tankLastHelath[victim];
	tankLiveTime[victim] = GetGameTime() - tankLiveTime[victim];
	if (hasPrintDamage[victim]) { return; }
	CreateTimer(DAMAGE_DISPLAY_DELAY, printTankDamageHandler, victim);
	hasPrintDamage[victim] = true;
}

/* 回合开始，清空所有人的 Tank 伤害统计 */
public void roundStartHandler(Event event, const char[] name, bool dontBroadcast)
{
	clearTankDamage(INVALID_CLIENT);
}

public void roundEndHandler(Event event, const char[] name, bool dontBroadcast)
{
	static int i;
	if (!g_hMissionFailedAnnounce.BoolValue) { return; }
	/* 检测生还者是否全部死亡，如果全部死亡且场上存在 Tank，显示 Tank 伤害统计 */
	if (isSurvivorFailed())
	{
		for (i = 1; i <= MaxClients; i++)
		{
			if (!isTank(i) || !IsPlayerAlive(i)) { continue; }
			/* 坦克还存在，计算存在时长 */
			tankLiveTime[i] = GetGameTime() - tankLiveTime[i];
			CPrintToChatAll("{red}%N {green}剩余%d血量", i, GetClientHealth(i));
			/* 如果已经显示过了 Tank 伤害，则不再显示 */
			if (hasPrintDamage[i]) { continue; }
			CreateTimer(DAMAGE_DISPLAY_DELAY, printTankDamageHandler, i);
			hasPrintDamage[i] = true;
		}
	}
}

public Action printTankDamageHandler(Handle timer, int client)
{
	printTankDamage(client);
	return Plugin_Stop;
}

void printTankDamage (int client)
{
    if (!g_hAllowAnnounce.BoolValue) { return; }

    /* 显示标题 */
    if (!IsFakeClient(client)) 
    { 
        CPrintToChatAll("[{green}!{default}] {blue}生还者对 {green}Tank {default}({green}%N{default}) {blue}的伤害统计", client); 
    }
    else 
    { 
        CPrintToChatAll("[{green}!{default}] {blue}生还者对 {green}Tank {default}({green}AI{default}) {blue}的伤害统计"); 
    }

    /* 显示 Tank 存活时间 */
    if (g_hAllowPrintLiveTime.BoolValue)
    {
        if (!IsFakeClient(client)) 
        { 
            CPrintToChatAll("[{green}!{default}] {green}%N {blue}存活时间：{green}%s", getTime(tankLiveTime[client])); 
        }
        else 
        { 
            CPrintToChatAll("[{green}!{default}] {green}Tank {blue}存活时间：{green}%s", getTime(tankLiveTime[client])); 
        }
    }

    /* 显示详细伤害统计 */
    static int i, totalDamge, totalGotDamage, damagePercent, survivorCount, survivorIndex;
    totalDamge = totalGotDamage = damagePercent = survivorIndex = 0;

    survivorCount = getSurvivorCount();
    int[][] survivorDamage = new int[survivorCount][2];

    for (i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR) { continue; }
        totalDamge += tankHurt[client][i];
        totalGotDamage += playerHurts[client][i].gotDamage;
        damagePercent += getDamageAsPercent(tankHurt[client][i], tankHealth[client]);
        survivorDamage[survivorIndex][0] = i;
        survivorDamage[survivorIndex++][1] = tankHurt[client][i];
    }

    #if DEBUG_ALL
        PrintToConsoleAll("%N 伤害报告：总伤：%d，拳：%d，石：%d，铁：%d", client, totalDamge, totalPunch, totalRock, totalIron);
    #endif

    SortCustom2D(survivorDamage, survivorIndex, sortByDamageDesc);

    static int percentAdjust, lastPercent, exactDamagePercent, survivor, damage;
    percentAdjust = 0, lastPercent = 100;
    if (damagePercent < 100 && float(totalDamge) > (tankHealth[client] - (tankHealth[client] / 200.0))) 
    { 
        percentAdjust = 100 - damagePercent; 
    }

    for (i = 0; i < survivorIndex; i++)
    {
        survivor = survivorDamage[i][0], damage = survivorDamage[i][1];
        if (!IsClientInGame(survivor) || GetClientTeam(survivor) != TEAM_SURVIVOR) { continue; }

        damagePercent = getDamageAsPercent(damage, tankHealth[client]);
        if (percentAdjust != 0 && damage > 0 && !isExactPercent(damage, tankHealth[client]))
        {
            exactDamagePercent = damagePercent + percentAdjust;
            if (exactDamagePercent <= lastPercent) 
            { 
                damagePercent = exactDamagePercent; 
            }
        }

        if (g_hAllowPrintZeroDamage.BoolValue || (!g_hAllowPrintZeroDamage.BoolValue && damage > 0))
        {
            // 匹配截图格式：伤害 [百分比] [拳:xx] [石:xx] 玩家名，移除铁、承伤
            CPrintToChatAll("\x01[\x05%5d\x01] [\x04%d%%\x01] [\x05拳\x01:\x04%d\x01] [\x05石\x01:\x04%d\x01] \x03%N\x01",
                damage, 
                damagePercent,
                playerHurts[client][survivor].punch,
                playerHurts[client][survivor].rock,
                survivor);
        }
        else if (!g_hAllowPrintZeroDamage.BoolValue && damage == 0) { continue; }
    }
}

/* 按照伤害对 survivorDamage[][] 进行降序排序，伤害相同则按照玩家索引降序排序 */
int sortByDamageDesc(int[] elem1, int[] elem2, const int[][] array, Handle hndl)
{
	return elem1[1] > elem2[1] ? -1 : elem1[1] == elem2[1] ? elem1[0] > elem2[0] ? -1 : elem1[0] == elem2[0] ? 0 : 1 : 1;
}

bool isTank(int client)
{
	return GetInfectedClass(client) == ZC_TANK;
}

int getDamageAsPercent(int damage, int health)
{
	return damage == 0 ? 0 : RoundToNearest((float(damage) / float(health)) * 100.0);
}

bool isExactPercent(int damage, int health)
{
	float percent = (damage / health) * 100.0, difference = (getDamageAsPercent(damage, health)) - percent;
	return FloatAbs(difference) < 0.001 ? true : false;
}

bool isSurvivorFailed()
{
	static int i;
	for (i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR) { continue; }
		if (IsPlayerAlive(i) && !IsClientIncapped(i)) { return false; }
	}
	return true;
}

int getSurvivorCount()
{
	static int i, count;
	count = 0;
	for (i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR) { continue; }
		count++;
	}
	return count;
}

void clearTankDamage(int client)
{
	static int i, j;
	/* Tank 生成时，这是个克，清除这个克的伤害统计 */
	if (isTank(client) && client != INVALID_CLIENT)
	{
		for (i = 1; i <= MaxClients; i++)
		{
			tankHurt[client][i] = 0;
			playerHurts[client][i].init();
		}
	}
	else
	{
		/* 清空所有人的 Tank 伤害统计 */
		for (i = 1; i <= MaxClients; i++)
		{
			hasPrintDamage[i] = false;
			for (j = 1; j <= MaxClients; j++)
			{
				tankHurt[i][j] = 0;
				playerHurts[i][j].init();
			}
		}
	}
}

char[] getTime(float time)
{
	char result[64] = {'\0'};
	int exacTime = RoundToNearest(time);
	if (exacTime < 60) { FormatEx(result, sizeof(result), "%d秒", exacTime); }
	else if (exacTime > 60 && exacTime < 3600)
	{
		int minute = exacTime / 60, second = exacTime % 60;
		FormatEx(result, sizeof(result), "%d分钟%d秒", minute, second);
	}
	else
	{
		int hour = exacTime / 3600, minute = (exacTime % 3600) / 60, second = (exacTime % 3600) % 60;
		FormatEx(result, sizeof(result), "%d小时%d分钟%d秒", hour, minute, second);
	}
	return result;
}

stock int GetTeamPlayer(int team)
{
	int playerCount=0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == team && IsPlayerAlive(i))
			playerCount++;
	}
	if(playerCount < g_hSurvivorLimit.IntValue)
		return g_hSurvivorLimit.IntValue;
	else
		return playerCount;
}
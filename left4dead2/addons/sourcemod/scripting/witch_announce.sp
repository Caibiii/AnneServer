#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <colors>

/**
 * Witch Damage Announce (修复版 v1.3.1)
 *
 * 修复内容：
 *  - 核心：回合结束时不再依赖不可靠的 bWitchSpawned 标志，
 *    改为直接扫描地图中是否存在存活的 Witch，修复
 *    "插件重载前已存在的 Witch 存活到回合结束不打印"的问题
 *  - Timer 回调 PrintAnyway 补 public（原为非 public，运行时直接失败）
 *  - 补全全部缺失的分号
 *  - 移除对 survivor_limit cvar 的依赖，统计数组改为定长，杜绝越界
 *  - 伤害封顶增加下限保护，防止负伤害
 *  - Timer 携带回合编号，避免把上一局数据打印进新回合
 *  - 新增 map_transition / finale_win 钩子，确保 Witch 存活时兜底打印
 */

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

int g_iDamageWitch[MAXPLAYERS + 1];	// 每个玩家对 Witch 造成的伤害
int g_iDamageTotal;					// 全队对 Witch 的总伤害
int g_iRoundNumber;					// 回合编号（用于过期 Timer 防护）

bool g_bHasPrinted;					// 本回合是否已打印

float g_fWitchHealth;

ConVar g_cvarWitchHealth;

public Plugin myinfo =
{
	name = "Witch Damage Announce",
	author = "Sir, fix by Kimi",
	description = "Print Witch Damage to chat",
	version = "1.3.1",
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart()
{
	LoadTranslations("l4d_witch_damage_announce.phrases");

	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("finale_win", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("infected_hurt", Event_InfectedHurt);
	HookEvent("witch_killed", Event_WitchKilled);

	g_cvarWitchHealth = FindConVar("z_witch_health");
	g_fWitchHealth = g_cvarWitchHealth.FloatValue;
	g_cvarWitchHealth.AddChangeHook(OnWitchHealthChanged);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	// 新的 Witch 出现，允许再次打印（尽量兼容同回合多只 Witch）
	if (StrContains(classname, "witch", false) != -1)
	{
		g_bHasPrinted = false;
	}
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_iRoundNumber++;
	ClearDamage();
	g_bHasPrinted = false;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	// 核心修复：只要本回合对 Witch 造成过伤害就打印，
	// 不再依赖 bWitchSpawned 标志（该标志对插件加载前已存在的 Witch 永远为 false）
	if (g_iDamageTotal > 0)
	{
		CalculateWitch();
	}
}

public void Event_InfectedHurt(Event event, const char[] name, bool dontBroadcast)
{
	int victimEntId = event.GetInt("entityid");

	if (!IsWitch(victimEntId))
	{
		return;
	}

	int attacker = GetClientOfUserId(event.GetInt("attacker"));

	if (!IsClientAndInGame(attacker) || GetClientTeam(attacker) != TEAM_SURVIVOR)
	{
		return;
	}

	int damage = event.GetInt("amount");

	// 单次伤害封顶到 Witch 剩余血量，并防止出现负伤害
	int health = RoundToFloor(g_fWitchHealth);
	int newTotal = g_iDamageTotal + damage;
	if (newTotal > health)
	{
		damage -= (newTotal - health);
	}
	if (damage < 0)
	{
		damage = 0;
	}

	g_iDamageTotal += damage;
	g_iDamageWitch[attacker] += damage;
}

public void Event_WitchKilled(Event event, const char[] name, bool dontBroadcast)
{
	int killer = GetClientOfUserId(event.GetInt("userid"));

	// Tank 打死 Witch 的播报
	if (IsClientAndInGame(killer) && GetClientTeam(killer) == TEAM_INFECTED && IsTank(killer))
	{
		CPrintToChatAll("%t", "L4DWitchDamageAnnounce_TankKilledWitch", killer);
		ClearDamage();
		return;
	}

	// 伤害统计不足 Witch 总血量时（如燃烧等未计入的伤害），补到击杀者头上，让百分比凑满 100
	if (IsClientAndInGame(killer) && g_iDamageTotal < g_fWitchHealth)
	{
		int missing = RoundToFloor(g_fWitchHealth) - g_iDamageTotal;
		g_iDamageWitch[killer] += missing;
		g_iDamageTotal += missing;
	}

	CalculateWitch();
	ClearDamage();
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = event.GetInt("attackerentid");

	// 生还者被 Witch 杀死：延迟 3 秒打印（若回合已正常打印则自动跳过）
	if (IsClientAndInGame(victim) && GetClientTeam(victim) == TEAM_SURVIVOR && IsWitch(attacker))
	{
		CreateTimer(3.0, Timer_PrintAnyway, g_iRoundNumber);
	}
}

public Action Timer_PrintAnyway(Handle timer, int roundNumber)
{
	// 回合已重开则丢弃，避免把上一局数据打进新回合
	if (roundNumber != g_iRoundNumber)
	{
		return Plugin_Stop;
	}

	CalculateWitch();
	return Plugin_Stop;
}

void CalculateWitch()
{
	if (g_bHasPrinted)
	{
		return;
	}
	g_bHasPrinted = true;

	// 以地图中是否真实存在存活 Witch 为准，而不是任何标志位
	if (IsWitchAlive())
	{
		PrintWitchRemainingHealth();
		PrintWitchDamage(false);
	}
	else
	{
		PrintWitchDamage(true);
	}
}

void PrintWitchRemainingHealth()
{
	CPrintToChatAll("%t", "L4DWitchDamageAnnounce_WitchHealthRemaining",
		RoundToFloor(g_fWitchHealth) - g_iDamageTotal);
}

void PrintWitchDamage(bool witchDead)
{
	if (witchDead)
	{
		CPrintToChatAll("%t", "L4DWitchDamageAnnounce_DamageDealtWitch");
	}

	int totalDamage;
	int totalPercent;
	int percentAdjustment;
	int lastPercent = 100;

	int survivorIndex;
	int survivorClients[MAXPLAYERS + 1];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR || g_iDamageWitch[i] == 0)
		{
			continue;
		}

		survivorClients[survivorIndex++] = i;
		totalDamage += g_iDamageWitch[i];
		totalPercent += GetDamageAsPercent(g_iDamageWitch[i]);
	}

	SortCustom1D(survivorClients, survivorIndex, SortByDamageDesc);

	// 百分比之和不到 100，但实际伤害已超过 Witch 血量 99.5% 时，补齐差值
	if (totalPercent < 100 && float(totalDamage) > (g_fWitchHealth - (g_fWitchHealth / 200.0)))
	{
		percentAdjustment = 100 - totalPercent;
	}

	for (int k = 0; k < survivorIndex; k++)
	{
		int client = survivorClients[k];
		int damage = g_iDamageWitch[client];
		int percentDamage = GetDamageAsPercent(damage);

		if (percentAdjustment != 0 && damage > 0 && !IsExactPercent(damage))
		{
			int adjusted = percentDamage + percentAdjustment;
			if (adjusted <= lastPercent)
			{
				percentDamage = adjusted;
				percentAdjustment = 0;
			}
		}

		lastPercent = percentDamage;

		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				CPrintToChat(i, "%t", "L4DWitchDamageAnnounce_WitchDamageLine",
					damage, percentDamage, client);
			}
		}
	}
}

bool IsWitchAlive()
{
	int entity = INVALID_ENT_REFERENCE;
	while ((entity = FindEntityByClassname(entity, "witch")) != INVALID_ENT_REFERENCE)
	{
		// m_lifeState: 0 = 存活
		if (GetEntProp(entity, Prop_Data, "m_lifeState") == 0)
		{
			return true;
		}
	}
	return false;
}

bool IsWitch(int entity)
{
	if (entity <= 0 || !IsValidEdict(entity))
	{
		return false;
	}

	char classname[64];
	GetEdictClassname(entity, classname, sizeof(classname));
	return StrContains(classname, "witch", false) != -1;
}

bool IsClientAndInGame(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}

bool IsTank(int client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass") == 8;
}

int GetDamageAsPercent(int damage)
{
	return RoundToNearest((damage / g_fWitchHealth) * 100.0);
}

bool IsExactPercent(int damage)
{
	float percent = (damage / g_fWitchHealth) * 100.0;
	return FloatAbs(float(GetDamageAsPercent(damage)) - percent) < 0.001;
}

public int SortByDamageDesc(int elem1, int elem2, const int[] array, Handle hndl)
{
	// 按伤害降序，伤害相同按索引降序
	if (g_iDamageWitch[elem1] > g_iDamageWitch[elem2]) return -1;
	if (g_iDamageWitch[elem1] < g_iDamageWitch[elem2]) return 1;
	return elem1 > elem2 ? -1 : (elem1 < elem2 ? 1 : 0);
}

void ClearDamage()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_iDamageWitch[i] = 0;
	}
	g_iDamageTotal = 0;
}

void OnWitchHealthChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_fWitchHealth = g_cvarWitchHealth.FloatValue;
}

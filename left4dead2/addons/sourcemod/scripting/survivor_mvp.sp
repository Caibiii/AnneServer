#pragma semicolon 1
#pragma newdecls required
#pragma tabsize 0

#include <sourcemod>
#include <left4dhooks>

/**
 * 药役 MVP 统计
 * 指令：sm_mvp / sm_kills
 */

// 小特感类别（m_zombieClass，1~6）
enum
{
	ZC_Smoker = 1,
	ZC_Boomer,
	ZC_Hunter,
	ZC_Spitter,
	ZC_Jockey,
	ZC_Charger
};

#define TEAM_SURVIVOR	2
#define TEAM_INFECTED	3
#define COMMON_BONUS	20	// 每只普尸折算伤害

// 小特感血量上限，用于单次伤害封顶
static const int g_iMaxClassDamage[] = { 0, 250, 50, 250, 100, 325, 600 };

enum struct PlayerStats
{
	int damageDealt;	// 对特感伤害
	int specialKills;	// 小特感击杀
	int commonKills;	// 普尸击杀
	int ffDealt;		// 黑枪伤害
	int ffTaken;		// 被黑伤害
}

PlayerStats g_stats[MAXPLAYERS + 1];
bool g_bPrinted;	// round_end 是否已自动打印

public void OnPluginStart()
{
	RegConsoleCmd("sm_mvp", Command_Mvp);
	RegConsoleCmd("sm_kills", Command_Mvp);

	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("infected_death", Event_InfectedDeath);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
}

void ResetStats()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_stats[i].damageDealt = 0;
		g_stats[i].specialKills = 0;
		g_stats[i].commonKills = 0;
		g_stats[i].ffDealt = 0;
		g_stats[i].ffTaken = 0;
	}

	g_bPrinted = false;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	ResetStats();
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	ResetStats();
	return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bPrinted)
	{
		return Plugin_Handled;
	}
	g_bPrinted = true;

	PrintToChatAll("\x03[MVP统计]");
	PrintMvpStats();

	return Plugin_Continue;
}

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int damage = event.GetInt("dmg_health");

	if (!IsValidClient(victim) || !IsValidClient(attacker))
	{
		return Plugin_Continue;
	}

	// 友伤：双方均为生还者、非自伤、被打者未倒地
	if (attacker != victim
		&& GetClientTeam(attacker) == TEAM_SURVIVOR
		&& GetClientTeam(victim) == TEAM_SURVIVOR
		&& !GetEntProp(victim, Prop_Send, "m_isIncapacitated"))
	{
		g_stats[attacker].ffDealt += damage;
		g_stats[victim].ffTaken += damage;
	}
	// 对特感伤害（不含 Tank / Witch，单次按血量封顶）
	else if (GetClientTeam(attacker) == TEAM_SURVIVOR && GetClientTeam(victim) == TEAM_INFECTED)
	{
		int zclass = GetEntProp(victim, Prop_Send, "m_zombieClass");

		if (zclass >= ZC_Smoker && zclass <= ZC_Charger)
		{
			g_stats[attacker].damageDealt += (damage > g_iMaxClassDamage[zclass])
				? g_iMaxClassDamage[zclass] : damage;
		}
	}

	return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));

	if (IsValidClient(attacker) && IsValidClient(victim)
		&& GetClientTeam(attacker) == TEAM_SURVIVOR && GetClientTeam(victim) == TEAM_INFECTED)
	{
		int zclass = GetEntProp(victim, Prop_Send, "m_zombieClass");

		if (zclass >= ZC_Smoker && zclass <= ZC_Charger)
		{
			g_stats[attacker].specialKills++;
		}
	}

	return Plugin_Continue;
}

public Action Event_InfectedDeath(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));

	if (IsValidClient(attacker) && GetClientTeam(attacker) == TEAM_SURVIVOR)
	{
		g_stats[attacker].commonKills++;
	}

	return Plugin_Continue;
}

public Action Command_Mvp(int client, int args)
{
	PrintToChatAll("\x03[MVP统计] \x05%N", client);
	PrintMvpStats();

	return Plugin_Handled;
}

void PrintMvpStats()
{
	int count = 0;
	int survivors[MAXPLAYERS + 1];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR)
		{
			survivors[count++] = i;
		}
	}

	SortCustom1D(survivors, count, SortByDamageDesc);

	for (int i = 0; i < count; i++)
	{
		int client = survivors[i];

		PrintToChatAll("\x03特感\x04%2d \x03丧尸\x04%3d \x03黑/被黑\x04%2d/%2d \x03伤害\x04%4d \x05%N",
			g_stats[client].specialKills,
			g_stats[client].commonKills,
			g_stats[client].ffDealt,
			g_stats[client].ffTaken,
			GetTotalScore(client),
			client);
	}
}

int GetTotalScore(int client)
{
	return g_stats[client].damageDealt + g_stats[client].commonKills * COMMON_BONUS;
}

public int SortByDamageDesc(int elem1, int elem2, const int[] array, Handle hndl)
{
	int total1 = GetTotalScore(elem1);
	int total2 = GetTotalScore(elem2);

	if (total1 != total2)
	{
		return total1 > total2 ? -1 : 1;
	}

	// 总分相同：特感击杀降序，再按索引升序保证严格弱序
	if (g_stats[elem1].specialKills != g_stats[elem2].specialKills)
	{
		return g_stats[elem1].specialKills > g_stats[elem2].specialKills ? -1 : 1;
	}

	return elem1 < elem2 ? -1 : (elem1 > elem2 ? 1 : 0);
}

stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}

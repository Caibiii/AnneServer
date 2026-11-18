#pragma semicolon 1
#pragma newdecls required
#pragma tabsize 4

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d_CreateSurvivorBot>

#define TEAM_SPECTATOR 1
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

#define DEFAULT_SURVIVOR_LIMIT "4"
#define MIN_SURVIVOR_LIMIT 1
#define MAX_SURVIVOR_LIMIT 8
#define EMPTY_SERVER_RESTART_DELAY 30.0
#define SURVIVOR_SPAWN_DELAY 3.0
#define AWAY_DELAY 2.5
#define WITCH_KILL_HEAL_AMOUNT 15

ConVar g_cvMotdTitle;
ConVar g_cvMotdUrl;
ConVar g_cvSurvivorLimit;
Handle g_hSurvivorAdjustTimer;
bool g_bRestoringSurvivorLimit;
float g_fLastDisconnectTime;

public Plugin myinfo = {
    name = "server.smx",
    author = "Caibiii",
    description = "简简单单的药役服务器设置",
    version = "2026.11.18",
    url = "https://github.com/Caibiii/AnneServer"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_away", CommandMoveToSpectators);
	RegConsoleCmd("sm_s", CommandMoveToSpectators);
	RegConsoleCmd("sm_ammo", CommandGiveClientAmmo);
	RegConsoleCmd("sm_join", CommandJoinSurvivors);
	RegConsoleCmd("sm_jg", CommandJoinSurvivors);

	RegAdminCmd("sm_restartmap", CommandRestartMap, ADMFLAG_ROOT, "重新加载当前地图");
	RegAdminCmd("sm_restart", CommandRestartServer, ADMFLAG_ROOT, "重启服务器");
	RegAdminCmd("sm_hp", CommandGiveHealth, ADMFLAG_ROOT, "恢复所有生还者状态");
	RegAdminCmd("sm_survivor_count", CommandSetSurvivorLimit, ADMFLAG_CONFIG, "设置生还者人数上限");

	AddNormalSoundHook(OnNormalSound);
	AddAmbientSoundHook(OnAmbientSound);

	HookEvent("player_team", EventPlayerTeam);
	HookEvent("witch_killed", EventWitchKilled);
	HookEvent("finale_win", EventResetSurvivors);
	HookEvent("map_transition", EventResetSurvivors);
	HookEvent("round_start", EventRoundStart);

	g_cvMotdTitle = CreateConVar("sm_cfgmotd_title", "AnneHappy", "玩家进入服务器时显示的 MOTD 标题");
	g_cvMotdUrl = CreateConVar("sm_cfgmotd_url", "http://1.12.233.203:777/", "玩家进入服务器时显示的 MOTD 地址");
	g_cvSurvivorLimit = CreateConVar(
		"sm_survivor_limit",
		DEFAULT_SURVIVOR_LIMIT,
		"生还者总人数上限，包含真人与 Bot（1-8）",
		FCVAR_NOTIFY
	);
	g_cvSurvivorLimit.AddChangeHook(OnSurvivorLimitChanged);
}

public void OnMapStart()
{
	ScheduleSurvivorAdjustment();
}

public void OnSurvivorLimitChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (g_bRestoringSurvivorLimit)
	{
		return;
	}

	int limit;
	if (StringToIntEx(newValue, limit) != strlen(newValue) || limit < MIN_SURVIVOR_LIMIT || limit > MAX_SURVIVOR_LIMIT)
	{
		g_bRestoringSurvivorLimit = true;
		convar.SetString(oldValue);
		g_bRestoringSurvivorLimit = false;
		return;
	}

	ServerCommand("exec vote/renshu/%dren.cfg", limit);
	ScheduleSurvivorAdjustment();
}

void ScheduleSurvivorAdjustment()
{
	delete g_hSurvivorAdjustTimer;
	g_hSurvivorAdjustTimer = CreateTimer(SURVIVOR_SPAWN_DELAY, TimerAdjustSurvivors, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action CommandSetSurvivorLimit(int client, int args)
{
	if (args != 1)
	{
		ReplyToCommand(client, "当前上限: %d；用法: sm_survivor_count <%d-%d>", g_cvSurvivorLimit.IntValue, MIN_SURVIVOR_LIMIT, MAX_SURVIVOR_LIMIT);
		return Plugin_Handled;
	}

	char argument[16];
	GetCmdArg(1, argument, sizeof(argument));

	int limit;
	if (StringToIntEx(argument, limit) != strlen(argument) || limit < MIN_SURVIVOR_LIMIT || limit > MAX_SURVIVOR_LIMIT)
	{
		ReplyToCommand(client, "生还者人数上限必须是 %d 到 %d 之间的整数", MIN_SURVIVOR_LIMIT, MAX_SURVIVOR_LIMIT);
		return Plugin_Handled;
	}

	g_cvSurvivorLimit.SetInt(limit);
	ReplyToCommand(client, "生还者人数上限已设置为 %d", limit);
	return Plugin_Handled;
}

public Action TimerAdjustSurvivors(Handle timer)
{
	g_hSurvivorAdjustTimer = null;
	AdjustSurvivorBots();
	return Plugin_Stop;
}

void AdjustSurvivorBots()
{
	int limit = g_cvSurvivorLimit.IntValue;
	int survivorCount = CountSurvivors();
	if (survivorCount > limit)
	{
		int botsToKick = survivorCount - limit;
		for (int client = MaxClients; client >= 1 && botsToKick > 0; client--)
		{
			if (!IsClientInGame(client) || !IsFakeClient(client) || GetClientTeam(client) != TEAM_SURVIVOR)
			{
				continue;
			}

			KickClient(client, "Survivor bot over limit");
			botsToKick--;
		}

		return;
	}

	int botsToCreate = limit - survivorCount;
	for (int i = 0; i < botsToCreate; i++)
	{
		if (limit < 5)
		{
			L4D2Direct_AddSurvivorBot(8);
		}
		else
		{
			CreateSurvivorBot();
		}
	}
}

int CountSurvivors()
{
	int count = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsSurvivor(client))
		{
			count++;
		}
	}

	return count;
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	CreateTimer(0.5, TimerResetSurvivorStatus, _, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}

public Action CommandJoinSurvivors(int client, int args)
{
	ClientCommand(client, "jointeam 2");
	return Plugin_Handled;
}

public Action CommandMoveToSpectators(int client, int args)
{
	if (IsSurvivor(client) && !IsSurvivorPinned(client))
	{
		CreateTimer(AWAY_DELAY, TimerCompleteAway, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}

	return Plugin_Handled;
}

public Action TimerCompleteAway(Handle timer, int userId)
{
	int client = GetClientOfUserId(userId);
	if (IsSurvivor(client) && !IsSurvivorPinned(client))
	{
		ChangeClientTeam(client, TEAM_SPECTATOR);
	}

	return Plugin_Stop;
}

public Action CommandRestartMap(int client, int args)
{
	RestartCurrentMap();
	return Plugin_Handled;
}

void RestartCurrentMap()
{
	char mapName[64];
	GetCurrentMap(mapName, sizeof(mapName));
	ServerCommand("changelevel %s", mapName);
}

public Action CommandRestartServer(int client, int args)
{
	RestartEngine();
	return Plugin_Handled;
}

void RestartEngine()
{
	int flags = GetCommandFlags("crash");
	SetCommandFlags("crash", flags & ~FCVAR_CHEAT);
	ServerCommand("crash");
	SetCommandFlags("crash", flags);
}

public Action CommandGiveClientAmmo(int client, int args)
{
	if (IsSurvivor(client))
	{
		ExecuteCheatCommand(client, "give", "ammo");
	}

	return Plugin_Handled;
}

public Action CommandGiveHealth(int client, int args)
{
	RestoreSurvivorHealth();
	return Plugin_Handled;
}

public void EventRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	CreateTimer(3.0, TimerDelayedRoundStart, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnAutoConfigsBuffered()
{
	ExecuteMapConfig();
}

public Action TimerDelayedRoundStart(Handle timer)
{
	ConVar gameMode = FindConVar("mp_gamemode");
	if (gameMode != null)
	{
		gameMode.SetString("coop");
	}

	ExecuteMapConfig();
	return Plugin_Stop;
}

void ExecuteMapConfig()
{
	char mapName[128];
	char configPath[128];
	GetCurrentMap(mapName, sizeof(mapName));
	Format(configPath, sizeof(configPath), "cfg/sourcemod/map_cvars/%s.cfg", mapName);

	if (FileExists(configPath, true))
	{
		ServerCommand("exec \"sourcemod/map_cvars/%s.cfg\"", mapName);
	}
}

public Action EventResetSurvivors(Handle event, const char[] name, bool dontBroadcast)
{
	RestoreSurvivorHealth();
	ResetSurvivorInventory();
	return Plugin_Continue;
}

void ResetSurvivorInventory()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsSurvivor(client))
		{
			continue;
		}

		for (int slot = 0; slot < 5; slot++)
		{
			RemoveInventoryItem(client, slot);
		}

		ExecuteCheatCommand(client, "give", "pistol");
	}
}

void RemoveInventoryItem(int client, int slot)
{
	int item = GetPlayerWeaponSlot(client, slot);
	if (item > MaxClients && IsValidEntity(item))
	{
		RemovePlayerItem(client, item);
		AcceptEntityInput(item, "Kill");
	}
}

void RestoreSurvivorHealth()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsSurvivor(client))
		{
			continue;
		}

		ExecuteCheatCommand(client, "give", "health");
		ResetSurvivorHealthState(client);
	}
}

void ResetSurvivorHealthState(int client)
{
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
	SetEntProp(client, Prop_Send, "m_currentReviveCount", 0);
	SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", false);
}

public void OnClientPutInServer(int client)
{
	if (!IsFakeClient(client))
	{
		ShowMotdToPlayer(client);
		CreateTimer(3.0, TimerMoveInfectedToSpectators, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
}

void ShowMotdToPlayer(int client)
{
	char title[64];
	char url[192];
	g_cvMotdTitle.GetString(title, sizeof(title));
	g_cvMotdUrl.GetString(url, sizeof(url));
	ShowMOTDPanel(client, title, url, MOTDPANEL_TYPE_URL);
}

public Action EventPlayerTeam(Handle event, const char[] name, bool dontBroadcast)
{
	int userId = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userId);
	int team = GetEventInt(event, "team");

	if (!GetEventBool(event, "disconnect") && team == TEAM_INFECTED && IsValidPlayer(client) && !IsFakeClient(client))
	{
		CreateTimer(0.5, TimerMoveInfectedToSpectators, userId, TIMER_FLAG_NO_MAPCHANGE);
	}

	return Plugin_Continue;
}

public Action TimerMoveInfectedToSpectators(Handle timer, int userId)
{
	int client = GetClientOfUserId(userId);
	if (IsValidPlayer(client) && GetClientTeam(client) == TEAM_INFECTED)
	{
		ChangeClientTeam(client, TEAM_SPECTATOR);
	}

	return Plugin_Stop;
}

public void OnClientDisconnect(int client)
{
	if (IsFakeClient(client))
	{
		return;
	}

	float currentTime = GetGameTime();
	if (g_fLastDisconnectTime == currentTime)
	{
		return;
	}

	g_fLastDisconnectTime = currentTime;
	CreateTimer(EMPTY_SERVER_RESTART_DELAY, TimerRestartEmptyServer, currentTime, TIMER_FLAG_NO_MAPCHANGE);
}

public Action TimerRestartEmptyServer(Handle timer, float disconnectTime)
{
	if (disconnectTime != g_fLastDisconnectTime)
	{
		return Plugin_Stop;
	}

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientConnected(client) && !IsFakeClient(client))
		{
			return Plugin_Stop;
		}
	}

	RestartEngine();
	return Plugin_Stop;
}

public void EventWitchKilled(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsSurvivor(client) || !IsPlayerAlive(client) || IsSurvivorIncapacitated(client))
	{
		return;
	}

	int maxHealth = GetEntProp(client, Prop_Data, "m_iMaxHealth");
	int health = GetEntProp(client, Prop_Send, "m_iHealth") + WITCH_KILL_HEAL_AMOUNT;
	if (health > maxHealth)
	{
		health = maxHealth;
	}

	SetEntProp(client, Prop_Send, "m_iHealth", health);
}

public Action OnNormalSound(int clients[64], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags)
{
	return StrContains(sample, "firewerks", false) != -1 ? Plugin_Stop : Plugin_Continue;
}

public Action OnAmbientSound(char sample[PLATFORM_MAX_PATH], int &entity, float &volume, int &level, int &pitch, float pos[3], int &flags, float &delay)
{
	return StrContains(sample, "firewerks", false) != -1 ? Plugin_Stop : Plugin_Continue;
}

bool IsSurvivor(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}

bool IsValidPlayer(int client)
{
	return client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client);
}

bool IsSurvivorPinned(int client)
{
	if (!IsSurvivor(client))
	{
		return false;
	}

	return GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0
		|| GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0
		|| GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0
		|| GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0
		|| GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0;
}

bool IsSurvivorIncapacitated(int client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated") != 0;
}

void ExecuteCheatCommand(int client, const char[] command, const char[] parameter)
{
	int flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, parameter);
	SetCommandFlags(command, flags);
}

public Action TimerResetSurvivorStatus(Handle timer)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsSurvivor(client))
		{
			continue;
		}

		ExecuteCheatCommand(client, "give", "pain_pills");
		ExecuteCheatCommand(client, "give", "health");
		ResetSurvivorHealthState(client);

		if (IsFakeClient(client))
		{
			RemoveInventoryItem(client, 0);
			ExecuteCheatCommand(client, "give", "smg");
			ExecuteCheatCommand(client, "give", "pistol_magnum");
		}
		else if (GetPlayerWeaponSlot(client, 0) == -1)
		{
			ExecuteCheatCommand(client, "give", "smg");
		}
	}

	return Plugin_Stop;
}

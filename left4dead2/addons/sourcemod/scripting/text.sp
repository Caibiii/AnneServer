#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#define sBuffer	"2021-07-07"
new Handle: g_hCvarInfectedTime = INVALID_HANDLE;
new Handle: g_hCvarInfectedLimit = INVALID_HANDLE;
new Handle: g_hCvarTankBhop = INVALID_HANDLE;
new Handle: g_hCvarReturnBlood = INVALID_HANDLE;
new Handle: g_hTeleHandle = INVALID_HANDLE;
new CommonLimit;
new CommonTime;
new TankBhop;
new ReturnBlood;
new TimeReload;
public OnPluginStart()
{
	g_hCvarInfectedTime = FindConVar("versus_special_respawn_interval");
	g_hCvarInfectedLimit = FindConVar("l4d_infected_limit");
	g_hCvarTankBhop = FindConVar("ai_Tank_Bhop");
	g_hCvarReturnBlood= FindConVar("ReturnBlood");

	HookConVarChange(g_hCvarInfectedTime, Cvar_InfectedTime);
	HookConVarChange(g_hCvarInfectedLimit, Cvar_InfectedLimit);
	HookConVarChange(g_hCvarTankBhop, CvarTankBhop);
	HookConVarChange(g_hCvarReturnBlood, CvarReturnBlood);

	CommonTime = GetConVarInt(g_hCvarInfectedTime);
	CommonLimit = GetConVarInt(g_hCvarInfectedLimit);
	TankBhop = GetConVarInt(g_hCvarTankBhop);
	ReturnBlood = GetConVarInt(g_hCvarReturnBlood);

	RegConsoleCmd("sm_xx", InfectedStatus);
	RegConsoleCmd("sm_zs", ZiSha);
	RegConsoleCmd("sm_kill", ZiSha);

	HookEvent("player_incapacitated_start", Incap_Event);
	HookEvent("player_incapacitated", Incap_Event);
	HookEvent("round_start", event_RoundStart);
	HookEvent("player_death", player_death);
	HookEvent("player_spawn", player_spawn);
	
	HookEvent("map_transition", EventHook:ChangeVersus, EventHookMode_PostNoCopy);
	HookEvent("round_end", EventHook:ChangeVersus, EventHookMode_PostNoCopy);
	HookEvent("finale_win", EventHook:ChangeVersus, EventHookMode_PostNoCopy);
	
}

public Action:ChangeVersus(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_hTeleHandle != INVALID_HANDLE)
	{
		delete g_hTeleHandle;
		g_hTeleHandle = INVALID_HANDLE;
	}
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	ReloadPlugins();
	//g_hTeleHandle = CreateTimer(1.0, Timer_PositionSi, _, TIMER_REPEAT);
}

//传送落后特感
public Action Timer_PositionSi(Handle timer)
{
	TimeReload ++;
	if(TimeReload > CommonTime + 20)
	{
		//ReloadPlugins();
		TimeReload = 0;
		//PrintToChatAll("特感无法刷新，开始重载插件");
	}
	return Plugin_Continue;
}
public Action:player_spawn(Handle: event, const String: name[], bool: dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsInfectedBot(client))
    {
      TimeReload = 0;
    }
    return Plugin_Continue;
}

public Action: player_death(Handle: event, const String: name[], bool: dontBroadcast)
{
	if (IsTeamImmobilised())
    {
        SetConVarString(FindConVar("mp_gamemode"), "realism");
    }
    return Plugin_Continue;
}

public Action: ZiSha(client, args)
{
    ForcePlayerSuicide(client);
    if (IsTeamImmobilised())
    {
        SetConVarString(FindConVar("mp_gamemode"), "realism");
    }
    return Plugin_Handled;
}

public Incap_Event(Handle: event, const String: name[], bool: dontBroadcast)
{
    if (IsTeamImmobilised())
    {
        SetConVarString(FindConVar("mp_gamemode"), "realism");
    }
}

public event_RoundStart(Handle: event, const String: name[], bool: dontBroadcast)
{
    bool isReturnBlood = (ReturnBlood > 0);
    bool isTankBhop = (TankBhop > 0);
    char ReturnBloodType[64], TankBhopType[64];

    Format(ReturnBloodType, sizeof(ReturnBloodType), "%s", (isReturnBlood ? "\x04开启" : "\x04关闭"));
    Format(TankBhopType, sizeof(TankBhopType), "%s", (isTankBhop ? "\x04开启" : "\x04关闭"));

    PrintToChatAll("\x03Tank连跳\x05[%s] \x03回血\x05[%s] \x03特感\x05[\x04%i特%i秒\x05] \x03测试服\x05[\x04%s\x05]", TankBhopType, ReturnBloodType, CommonLimit, CommonTime, sBuffer);
	CreateTimer(3.0, KickFirstSpawn);
}

public Action KickFirstSpawn(Handle timer)
{
	for (new infected = 1; infected <= MaxClients; infected++)
	{
		if (IsInfectedBot(infected))
		{
			KickClient(infected);
		}
	}
	return Plugin_Continue;
}

public Cvar_InfectedTime(Handle: cvar, const String: oldValue[], const String: newValue[])
{
    CommonTime = GetConVarInt(g_hCvarInfectedTime);
	bool isReturnBlood = (ReturnBlood > 0);
    bool isTankBhop = (TankBhop > 0);
    char ReturnBloodType[64], TankBhopType[64];

    Format(ReturnBloodType, sizeof(ReturnBloodType), "%s", (isReturnBlood ? "\x04开启" : "\x04关闭"));
    Format(TankBhopType, sizeof(TankBhopType), "%s", (isTankBhop ? "\x04开启" : "\x04关闭"));

    PrintToChatAll("\x03Tank连跳\x05[%s] \x03回血\x05[%s] \x03特感\x05[\x04%i特%i秒\x05] \x03测试服\x05[\x04%s\x05]", TankBhopType, ReturnBloodType, CommonLimit, CommonTime, sBuffer);
    ReloadPlugins();
}

public Cvar_InfectedLimit(Handle: cvar, const String: oldValue[], const String: newValue[])
{
    CommonLimit = GetConVarInt(g_hCvarInfectedLimit);
	bool isReturnBlood = (ReturnBlood > 0);
    bool isTankBhop = (TankBhop > 0);
    char ReturnBloodType[64], TankBhopType[64];

    Format(ReturnBloodType, sizeof(ReturnBloodType), "%s", (isReturnBlood ? "\x04开启" : "\x04关闭"));
    Format(TankBhopType, sizeof(TankBhopType), "%s", (isTankBhop ? "\x04开启" : "\x04关闭"));

    PrintToChatAll("\x03Tank连跳\x05[%s] \x03回血\x05[%s] \x03特感\x05[\x04%i特%i秒\x05] \x03测试服\x05[\x04%s\x05]", TankBhopType, ReturnBloodType, CommonLimit, CommonTime, sBuffer);
	ReloadPlugins();
}

public CvarTankBhop(Handle: cvar, const String: oldValue[], const String: newValue[])
{
    TankBhop = GetConVarInt(g_hCvarTankBhop);
	
	bool isTankBhop = (TankBhop > 0);
	if(isTankBhop)
	{
		ServerCommand("sm_cvar z_tank_health 6000");
	}
	else
	{
		ServerCommand("sm_cvar z_tank_health 6750");
	}
	
}

public CvarReturnBlood(Handle: cvar, const String: oldValue[], const String: newValue[])
{
    ReturnBlood = GetConVarInt(g_hCvarReturnBlood);
}

public Action: InfectedStatus(Client, args)
{
    bool isReturnBlood = (ReturnBlood > 0);
    bool isTankBhop = (TankBhop > 0);
    char ReturnBloodType[64], TankBhopType[64];

    Format(ReturnBloodType, sizeof(ReturnBloodType), "%s", (isReturnBlood ? "\x04开启" : "\x04关闭"));
    Format(TankBhopType, sizeof(TankBhopType), "%s", (isTankBhop ? "\x04开启" : "\x04关闭"));

    PrintToChatAll("\x03Tank连跳\x05[%s] \x03回血\x05[%s] \x03特感\x05[\x04%i特%i秒\x05] \x03测试服\x05[\x04%s\x05]", TankBhopType, ReturnBloodType, CommonLimit, CommonTime, sBuffer);

    return Plugin_Handled;
}

public OnClientPutInServer(Client)
{
	if (IsValidPlayer(Client, false))
	{
		bool isReturnBlood = (ReturnBlood > 0);
		bool isTankBhop = (TankBhop > 0);
		char ReturnBloodType[64], TankBhopType[64];

		Format(ReturnBloodType, sizeof(ReturnBloodType), "%s", (isReturnBlood ? "\x04开启" : "\x04关闭"));
		Format(TankBhopType, sizeof(TankBhopType), "%s", (isTankBhop ? "\x04开启" : "\x04关闭"));

		PrintToChat(Client,"\x03Tank连跳\x05[%s] \x03回血\x05[%s] \x03特感\x05[\x04%i特%i秒\x05] \x03测试服\x05[\x04%s\x05]", TankBhopType, ReturnBloodType, CommonLimit, CommonTime, sBuffer);
	}
}
stock bool:IsInfectedBot(client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && IsFakeClient(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") <= 6 && GetEntProp(client, Prop_Send, "m_zombieClass") >=1)
	{
		return true;
	}
	else
	{
		return false;
	}
}
stock bool:IsValidPlayer(Client, bool:AllowBot = true, bool:AllowDeath = true)
{
	if (Client < 1 || Client > MaxClients)
		return false;
	if (!IsClientConnected(Client) || !IsClientInGame(Client))
		return false;
	if (!AllowBot)
	{
		if (IsFakeClient(Client))
			return false;
	}

	if (!AllowDeath)
	{
		if (!IsPlayerAlive(Client))
			return false;
	}	
	return true;
}
ReloadPlugins()
{
    ServerCommand("sm plugins load_unlock");
	//ServerCommand("sm plugins unload optional/infected_control.smx");
    ServerCommand("sm plugins reload optional/infected_control.smx");
	//ServerCommand("sm plugins unload optional/hunters.smx");
    ServerCommand("sm plugins reload optional/hunters.smx");
	//ServerCommand("sm plugins unload optional/hunters.smx");
    ServerCommand("sm plugins reload optional/Alone.smx");
    ServerCommand("sm plugins load_lock");
    ServerCommand("sm_startspawn");
}

bool: IsTeamImmobilised()
{
    bool bIsTeamImmobilised = true;

    for (new client = 1; client <= MaxClients; client++)
    {
        if (Survivor(client) && IsPlayerAlive(client) && !Incapacitated(client))
        {
            bIsTeamImmobilised = false;
            break;
        }
    }

    return bIsTeamImmobilised;
}

bool: Survivor(i)
{
    return i > 0 && i <= MaxClients && IsClientInGame(i) && GetClientTeam(i) == 2;
}

bool: Incapacitated(client)
{
    bool bIsIncapped = false;

    if (Survivor(client))
    {
        if (GetEntProp(client, Prop_Send, "m_isIncapacitated") > 0)
            bIsIncapped = true;

        if (!IsPlayerAlive(client))
            bIsIncapped = true;
    }

    return bIsIncapped;
}
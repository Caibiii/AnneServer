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

new CommonLimit;
new CommonTime;
new TankBhop;
new ReturnBlood;

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

	HookEvent("round_start", event_RoundStart);
}
public CvarTankBhop(Handle: cvar, const String: oldValue[], const String: newValue[])
{
    TankBhop = GetConVarInt(g_hCvarTankBhop);
}

public Action: ZiSha(client, args)
{
    ForcePlayerSuicide(client);
    return Plugin_Handled;
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

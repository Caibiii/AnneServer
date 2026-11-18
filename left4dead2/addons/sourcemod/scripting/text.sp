#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

#define STATUS_DATE "2021-07-07"

new Handle:g_hTime = INVALID_HANDLE;
new Handle:g_hLimit = INVALID_HANDLE;
new Handle:g_hBhop = INVALID_HANDLE;
new Handle:g_hBlood = INVALID_HANDLE;

new g_iTime;
new g_iLimit;
new g_iBhop;
new g_iBlood;

public OnPluginStart()
{
	g_hTime = CvarHook("versus_special_respawn_interval", g_iTime);
	g_hLimit = CvarHook("l4d_infected_limit", g_iLimit);
	g_hBhop = CvarHook("ai_Tank_Bhop", g_iBhop);
	g_hBlood = CvarHook("ReturnBlood", g_iBlood);

	RegConsoleCmd("sm_xx", Cmd_Status);
	RegConsoleCmd("sm_zs", Cmd_Kill);
	RegConsoleCmd("sm_kill", Cmd_Kill);

	HookEvent("round_start", Ev_RoundStart);
}

stock Handle:CvarHook(const String:name[], &val)
{
	new Handle:cvar = FindConVar(name);
	if (cvar == INVALID_HANDLE)
	{
		val = 0;
		return INVALID_HANDLE;
	}

	val = GetConVarInt(cvar);
	HookConVarChange(cvar, CvarChanged);
	return cvar;
}

public CvarChanged(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	Refresh();
	SayAll();
}

stock Refresh()
{
	if (g_hTime != INVALID_HANDLE) g_iTime = GetConVarInt(g_hTime);
	if (g_hLimit != INVALID_HANDLE) g_iLimit = GetConVarInt(g_hLimit);
	if (g_hBhop != INVALID_HANDLE) g_iBhop = GetConVarInt(g_hBhop);
	if (g_hBlood != INVALID_HANDLE) g_iBlood = GetConVarInt(g_hBlood);
}

stock StatusText(String:buf[], maxlen)
{
	Format(buf, maxlen, "\x03Tank连跳\x05[\x04%s\x05] \x03回血\x05[\x04%s\x05] \x03特感\x05[\x04%d特%d秒\x05] \x03测试服\x05[\x04%s\x05]",
		g_iBhop > 0 ? "开启" : "关闭",
		g_iBlood > 0 ? "开启" : "关闭",
		g_iLimit,
		g_iTime,
		STATUS_DATE);
}

stock SayAll()
{
	decl String:buf[192];
	StatusText(buf, sizeof(buf));
	PrintToChatAll("%s", buf);
}

stock SayTo(client)
{
	decl String:buf[192];
	StatusText(buf, sizeof(buf));
	PrintToChat(client, "%s", buf);
}

public Action:Cmd_Status(client, args)
{
	if (IsValid(client, false)) SayTo(client);
	return Plugin_Handled;
}

public Action:Cmd_Kill(client, args)
{
	if (IsValid(client, true)) ForcePlayerSuicide(client);
	return Plugin_Handled;
}

public Action:Ev_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	SayAll();
	CreateTimer(3.0, Timer_KickBots);
	return Plugin_Continue;
}

public Action:Timer_KickBots(Handle:timer)
{
	for (new client = 1; client <= MaxClients; client++)
		if (IsInfBot(client)) KickClient(client);

	return Plugin_Continue;
}

public OnClientPutInServer(client)
{
	if (IsValid(client, false)) SayTo(client);
}

stock bool:IsInfBot(client)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client) || !IsFakeClient(client)) return false;
	if (GetClientTeam(client) != 3) return false;

	new cls = GetEntProp(client, Prop_Send, "m_zombieClass");
	return cls >= 1 && cls <= 6;
}

stock bool:IsValid(client, bool:alive)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientConnected(client) || !IsClientInGame(client)) return false;
	if (IsFakeClient(client)) return false;
	if (alive && !IsPlayerAlive(client)) return false;

	return true;
}

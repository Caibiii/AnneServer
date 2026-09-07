#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
new Handle: g_hCvarInfectedTime = INVALID_HANDLE;
new Handle: g_hCvarInfectedLimit = INVALID_HANDLE;
new CommonLimit;
new CommonTime;
public OnPluginStart()
{
	g_hCvarInfectedTime = FindConVar("versus_special_respawn_interval");
	g_hCvarInfectedLimit = FindConVar("l4d_infected_limit");
	HookConVarChange(g_hCvarInfectedTime, Cvar_InfectedTime);
	HookConVarChange(g_hCvarInfectedLimit, Cvar_InfectedLimit);
	CommonTime = GetConVarInt(g_hCvarInfectedTime);
	CommonLimit = GetConVarInt(g_hCvarInfectedLimit);
	HookEvent("round_start", event_RoundStart);
}

public event_RoundStart(Handle: event, const String: name[], bool: dontBroadcast)
{
    //PrintToChatAll("\x03欢迎游玩本服务器，当前难度\x04%i\x03特\x04%i\x03秒，输入!vote进行更改", CommonLimit, CommonTime);
}

public Cvar_InfectedTime(Handle: cvar, const String: oldValue[], const String: newValue[])
{
    CommonTime = GetConVarInt(g_hCvarInfectedTime);
}

public Cvar_InfectedLimit(Handle: cvar, const String: oldValue[], const String: newValue[])
{
    CommonLimit = GetConVarInt(g_hCvarInfectedLimit);
}

public void OnClientPutInServer(int client)
{
	if(!IsFakeClient(client))
	{
		//PrintToChat(client, "\x03欢迎游玩本服务器，当前难度\x04%i\x03特\x04%i\x03秒，输入!vote进行更改", CommonLimit, CommonTime);
	}
}

public Action:L4D_OnFirstSurvivorLeftSafeArea() 
{
	CreateTimer(0.5, ResetSurvivorStatus, _, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Stop;
}
//给予生还者药丸、清除倒地次数、回满血量、清除AI武器并给与机枪和马格南
public Action:ResetSurvivorStatus(Handle:timer) 
{
	for (new client = 1; client <= MaxClients; client++) 
	{
		if (IsSurvivor(client)) 
		{
			if(IsFakeClient(client))
			{
				BypassAndExecuteCommand(client, "give","smg");
				BypassAndExecuteCommand(client, "give","pistol_magnum"); 
			}
			else
			{
				new item = GetPlayerWeaponSlot(client, 0);
				if (item > 0) 
				{
				
				}
				else
				{
					BypassAndExecuteCommand(client, "give","smg");
				}
			}
		}
	}
}

//给予物品函数
BypassAndExecuteCommand(client, String: strCommand[], String: strParam1[])
{
	new flags = GetCommandFlags(strCommand);
	SetCommandFlags(strCommand, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", strCommand, strParam1);
	SetCommandFlags(strCommand, flags);
}
stock bool:IsSurvivor(client) 
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2) 
	{
		return true;
	} 
	else 
	{
		return false;
	}
}

public void OnAutoConfigsBuffered()
{
	 char sMapConfig[128];
	 GetCurrentMap(sMapConfig, sizeof(sMapConfig));
     Format(sMapConfig, sizeof(sMapConfig), "cfg/sourcemod/map_cvars/%s.cfg", sMapConfig);
     if (FileExists(sMapConfig, true))
	 {
        strcopy(sMapConfig, sizeof(sMapConfig), sMapConfig[4]);
        ServerCommand("exec \"%s\"", sMapConfig);
     }
} 
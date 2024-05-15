#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

ConVar g_hCvarSurvivorLimit;
int g_iSurvivorLimit;
bool g_bLateLoad;
float g_fMeleeNerf;

public Plugin myinfo =
{
	name = "L4D2 AntiMelee",
	description = "Nerfes melee damage against tanks by a set amount of %",
	author = "Visor",
	version = "1.0",
	url = "https://github.com/Attano/L4D2-Competitive-Framework"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if(test != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	if(g_bLateLoad)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
				SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	}
	g_hCvarSurvivorLimit = FindConVar("survivor_limit");
	g_iSurvivorLimit = GetConVarInt(g_hCvarSurvivorLimit);
	g_hCvarSurvivorLimit.AddChangeHook(Changed_Cvars);
	GetCvars();
}

public void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}
public void Changed_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	g_iSurvivorLimit = StringToInt(newValue);	
}

void GetCvars()
{
	g_fMeleeNerf = 7.0 * g_iSurvivorLimit;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damageType)
{
	if(g_fMeleeNerf == 1.0 || !IsTank(victim) || !IsMelee(inflictor))
		return Plugin_Continue;
	
	if(IsSurvivor(attacker))
	{
		if(g_fMeleeNerf == 0.0)
			return Plugin_Handled;

		SDKHooks_TakeDamage(victim, inflictor, attacker, damage * g_fMeleeNerf, damageType);
		//damage = 0.0;
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

bool IsMelee(int inflictor)
{
	if(inflictor > MaxClients)
	{
		char classname[32];
		GetEdictClassname(inflictor, classname, 64);
		return strcmp(classname[7], "melee") == 0;
	}

	return false;
}

bool IsSurvivor(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}

bool IsTank(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8;
}

#pragma semicolon 1
#include <sourcemod>
#include <left4dhooks>
public OnPluginStart()
{
	HookEvent("witch_spawn", WitchSpawn_Event);
	//HookEvent("witch_harasser_set", WitchHarasserSet_Event);
}

public WitchSpawn_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new witch = GetEventInt(event, "witchid");
	SetEntProp(witch, Prop_Send, "m_iGlowType", 3);
	SetEntProp(witch, Prop_Send, "m_glowColorOverride", 0xFFFFFF);
}
public Action L4D_OnGetScriptValueInt(const char[] key, int &retVal) 
{
	if (strcmp(key, "ProhibitBosses", false) == 0 || strcmp(key, "DisallowThreatType", false) == 0) 
    {
		retVal = 0;
		return Plugin_Handled;
	}

	return Plugin_Continue;
}
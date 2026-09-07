#pragma semicolon 1
#include <sourcemod>

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
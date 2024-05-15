#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <l4d2_weapon_stocks>

new Float:g_Origin[3];
new Handle:cvarMeleeNames = INVALID_HANDLE;
new bool:g_bMeleeSpawned;

public OnPluginStart() 
{
	cvarMeleeNames = CreateConVar("starting_meleename", "fireaxe", "填写近战武器名称");
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast) 
{
	g_bMeleeSpawned = false;
	CreateTimer(0.1, DisposeItems, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) 
{
	if (!g_bMeleeSpawned) 
	{
		g_bMeleeSpawned = true;
		CreateTimer(1.0, Timer_RoundStart);
	}
}

public Action:Timer_RoundStart(Handle:timer) 
{
	new i = -1;
	do i = GetRandomInt(1, MaxClients);
	while (!IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i));
	if (i > 0) GetClientAbsOrigin(i, g_Origin);
	
	decl String:strGameMode[20];
	GetConVarString((cvarMeleeNames), strGameMode, sizeof(strGameMode));
	SpawnCommonLocation(strGameMode);
}

stock SpawnCommonLocation(String:type[]) 
{
	new entspawn = CreateEntityByName("weapon_melee");
	TeleportEntity(entspawn, g_Origin, NULL_VECTOR, NULL_VECTOR);
	DispatchKeyValue(entspawn, "melee_script_name", type);
	DispatchKeyValue(entspawn, "count", "2");
	DispatchSpawn(entspawn);
	SetEntityMoveType(entspawn, MOVETYPE_NONE);
}

public Action:DisposeItems(Handle:timer)
{
	for (new ent = 1; ent <= GetEntityCount(); ent++)
	{
		if (IsValidEntity(ent) && IsValidEdict(ent))
		{
			decl String:wpname[48];
			GetEdictClassname(ent, wpname, sizeof(wpname));
			
			if (StrEqual(wpname, "weapon_spawn", false))
			{
				new wpid = GetEntProp(ent, Prop_Send, "m_weaponID");
				DisposeItemsLimitFromId(ent, wpid);
			}
			else
			{
				DisposeItemsLimit(ent, wpname);
			}
		}
	}
}
DisposeItemsLimit(entity, String:wpname[])
{
	if (StrEqual(wpname, "weapon_melee_spawn", false)) {RemoveEdict(entity);} //删除近战
}

DisposeItemsLimitFromId(entity, wpid)
{
	if (wpid == 19) {RemoveEdict(entity);} //删除近战
}

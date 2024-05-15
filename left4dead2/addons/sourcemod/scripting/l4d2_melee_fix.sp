#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <sourcescramble>
#define CVAR_FLAGS			FCVAR_NOTIFY
Handle hCvarDmg;
float fCvarDmg;
bool bLateLoad;
ArrayStack gStack;
int lastHealth[MAXPLAYERS+1];
float fLastTempHealth[MAXPLAYERS+1];
float fFrameTempHealth[MAXPLAYERS+1];
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	HookEvent("revive_success", eventReviveSucess);
	gStack = new ArrayStack();
	GameData data = new GameData("l4d2_air_data"); Patch(data); delete data;
	hCvarDmg = CreateConVar("melee_damage_charger", "325.0", "Damage dealt to Chargers per swing, 0.0 to leave in default behaviour");
    fCvarDmg = GetConVarFloat(hCvarDmg);
    HookConVarChange(hCvarDmg, cvarChanged);
    if (bLateLoad)
    {
        for (int i = 1; i < MaxClients + 1; i++) 
        {
            if (IsValidClient(i)) SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
        }
    }
}

public void OnPluginEnd()
{
	MemoryPatch patch;
	
	while (!gStack.Empty)
	{
		patch = gStack.Pop();
		patch.Disable();
	}
}

void Patch (GameData data)
{
	static const char name[][] =
	{
		"vomit",
	};
	
	MemoryPatch patch;
	
	for (int i; i < sizeof name; i++)
	{
		patch = MemoryPatch.CreateFromConf(data, name[i]);
		
		if ( !patch )
		{
			LogMessage("Failed to create patch for \"%s\". Skiping...", name[i]);
			continue;
		}
		else if ( !patch.Validate() ) 
		{
			LogMessage("Failed to verify patch for \"%s\". Skiping...", name[i]);
			continue;
		}
		
		patch.Enable();
		gStack.Push(patch);
	}
}
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon) {
	if (isPlayerAliveSurvivor(client) && !isHangingLedge(client)) {
		lastHealth[client] = GetEntProp(client, Prop_Data, "m_iHealth");
		fLastTempHealth[client] = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
	}
}

public Action eventReviveSucess(Event event, const char[] name, bool dontBroadcast) {
	if (!event.GetBool("ledge_hang")) return;
	
	int client = GetClientOfUserId(event.GetInt("subject"));
	if (lastHealth[client] != 1) return;

	fFrameTempHealth[client] = fLastTempHealth[client];
	CreateTimer(0.0, delayedReviveSuccess, client);
}

public Action delayedReviveSuccess(Handle timer, any client) {
	if (!isPlayerAliveSurvivor(client)) return;

	int health = GetEntProp(client, Prop_Data, "m_iHealth");
	if (health != 1) return;

	float tempHealth = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
	if (fFrameTempHealth[client] > 3.0 && tempHealth <= fFrameTempHealth[client]) return;
	
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
}

bool isPlayerAliveSurvivor(int client) {
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client);
}

bool isHangingLedge(int client) 
{
	return GetEntProp(client, Prop_Send, "m_isHangingFromLedge") == 1;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    if (IsSurvivor(attacker) && IsSi(victim) && GetEntProp(victim, Prop_Send, "m_zombieClass") <= 6 && damage != 0.0)
    {
        char sWeapon[32];
        GetEdictClassname(inflictor, sWeapon, sizeof(sWeapon));
    
        if(StrEqual(sWeapon, "weapon_melee"))
        {
            int class = GetEntProp(victim, Prop_Send, "m_zombieClass");

             // Testing showed that only the L4D1 SI: Hunter, Smoker and Boomer have issues with correct Melee Damage values being applied, check for Spitter and Jockey anyway!
            if (class <= 5)
            { 
                damage = float(GetClientHealth(victim));
                return Plugin_Changed;
            }

            // Are we modifying Melee vs Charger behaviour?
            if (fCvarDmg != 0.0)
            {
                // Take care of low health Chargers to prevent Overkill damage.
                if (float(GetClientHealth(victim)) < fCvarDmg) damage = float(GetClientHealth(victim));

                // Deal requested Damage to Chargers.
                else damage = fCvarDmg;

                return Plugin_Changed;
            }
        }
    }
    return Plugin_Continue;
}

stock bool IsValidClient(int client) 
{ 
    if (client <= 0 || client > MaxClients || !IsClientConnected(client)) return false; 
    return IsClientInGame(client); 
} 

stock bool IsSurvivor(int client) 
{
    return IsValidClient(client) && GetClientTeam(client) == 2;
}

stock bool IsSi(int client) 
{
    return IsValidClient(client) && GetClientTeam(client) == 3;
}

public void cvarChanged(Handle cvar, char[] oldValue, char[] newValue)
{
    fCvarDmg = GetConVarFloat(hCvarDmg);
}
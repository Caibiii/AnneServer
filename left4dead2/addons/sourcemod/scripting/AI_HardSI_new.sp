#pragma semicolon 1
#pragma tabsize 0
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <smlib>
#include "includes/hardcoop_util.sp"
#include "modules/AI_Hunter2.sp"
#include "modules/AI_Hunter.sp"
#include "modules/AI_Spitter.sp"
#include "modules/AI_Jockey.sp"
#include "modules/AI_Tank.sp"
#include "modules/AI_Witch.sp"

Handle g_hTimer;

ConVar g_hAssaultReminderInterval;

bool g_bHasBeenShoved[MAXPLAYERS + 1]; // shoving resets SI movement 
// Enums

public void OnPluginStart() 
{
	g_hAssaultReminderInterval = CreateConVar( "ai_assault_reminder_interval", "0.1", "Frequency(sec) at which the 'nb_assault' command is fired to make SI attack" );
	
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_spawn", InitialiseSpecialInfected);
	HookEvent("ability_use", OnAbilityUse); 
	HookEvent("player_shoved", OnPlayerShoved);
	HookEvent("player_jump", OnPlayerJump);
	Hunter_OnModuleStart2();
	Hunter_OnModuleStart();
	Spitter_OnModuleStart();
	Jockey_OnModuleStart();
	Tank_OnModuleStart();
	Witch_OnModuleStart();
}

public void OnPluginEnd() 
{
	Hunter_OnModuleEnd2();
	Hunter_OnModuleEnd();
	Spitter_OnModuleEnd();
	Jockey_OnModuleEnd();
	Tank_OnModuleEnd();
	Witch_OnModuleEnd();
}

/***********************************************************************************************************************************************************************************

																	KEEP SI AGGRESSIVE
																	
***********************************************************************************************************************************************************************************/
public void OnMapEnd()
{
	delete g_hTimer;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	OnMapEnd();
}

public Action L4D_OnFirstSurvivorLeftSafeArea()
{
	InitStatus();
	delete g_hTimer;
	g_hTimer = CreateTimer(g_hAssaultReminderInterval.FloatValue, Timer_ForceInfectedAssault, _, TIMER_REPEAT);
}

public Action Timer_ForceInfectedAssault(Handle timer)
{
	CheatCommand("nb_assault");
}

/***********************************************************************************************************************************************************************************

																		SI MOVEMENT
																	
***********************************************************************************************************************************************************************************/
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon) 
{
	if(!IsPinningASurvivor(client))
	{
		switch(GetInfectedClass(client)) 
		{
			case L4D2Infected_Hunter:
			{
				if(!g_bHasBeenShoved[client])
				{
					Hunter_OnPlayerRunCmd2(client, buttons, impulse, vel, angles, weapon);
					Hunter_OnPlayerRunCmd(client, buttons, impulse, vel, angles, weapon);
				}
			}
			case L4D2Infected_Spitter:
			{
				Spitter_OnPlayerRunCmd(client, buttons, impulse, vel, angles, weapon);
			}
			case L4D2Infected_Jockey:
			{
				if(!g_bHasBeenShoved[client])
				{
					Jockey_OnPlayerRunCmd(client, buttons, impulse, vel, angles, weapon, g_bHasBeenShoved[client]);
				}
			}
			default :
			{
				
			}
		}
	}
	return Plugin_Continue;
}

/***********************************************************************************************************************************************************************************

																		EVENT HOOKS

***********************************************************************************************************************************************************************************/
public Action InitialiseSpecialInfected(Event event, const char[] name, bool dontBroadcast) 
{
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(IsAiHunter(client)) 
	{
		g_bHasBeenShoved[client] = false;
		g_bHasQueuedLunge[client] = false;
	}
}

public Action OnAbilityUse(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(IsAiJockey(client) || IsAiHunter(client)) 
	{
		g_bHasBeenShoved[client] = false;
		static char sAbilityName[32];
		sAbilityName[0] = 0;
		event.GetString("ability", sAbilityName, sizeof(sAbilityName));
		//if(strcmp(sAbilityName, "ability_charge") == 0) 
			//Charger_OnCharge(client);
		if (strcmp(sAbilityName, "ability_lunge") == 0)
			Hunter_OnPounce(client);
	}
}

public Action OnPlayerShoved(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(IsAiJockey(client)) 
	{
		g_bHasBeenShoved[client] = true;
		Jockey_OnShoved(client);
	}
}

public Action OnPlayerJump(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(IsBotInfected(client) && IsPlayerAlive(client))
	{
		g_bHasBeenShoved[client] = false;
	}
} 

/***********************************************************************************************************************************************************************************

																	TRACKING SURVIVORS' AIM

***********************************************************************************************************************************************************************************/



bool IsTargetWatchingAttacker(int attacker, int offsetThreshold) 
{
	static bool isWatching;
	isWatching = true;
	if(IsBotInfected(attacker) && IsPlayerAlive(attacker)) 
	{
		int target = GetClientAimTarget(attacker);
		if(IsSurvivor(target) && IsPlayerAlive(target)) 
		{
			int aimOffset = RoundToNearest(GetPlayerAimOffset(target, attacker));
			if(aimOffset <= offsetThreshold) 
				isWatching = true;
			else 
				isWatching = false;
		} 
	}	
	return isWatching;
}


float GetPlayerAimOffset(int attacker, int target) 
{
	if(!IsClientInGame(attacker) || !IsPlayerAlive(attacker))
		ThrowError("Client is not Alive."); 
	if(!IsClientInGame(target) || !IsPlayerAlive(target))
		ThrowError("Target is not Alive.");
		
	static float attackerPos[3], targetPos[3];
	static float aimVector[3], directVector[3];

	// Get the unit vector representing the attacker's aim
	GetClientEyeAngles(attacker, aimVector);
	aimVector[0] = aimVector[2] = 0.0; // Restrict pitch and roll, consider yaw only (angles on horizontal plane)
	GetAngleVectors(aimVector, aimVector, NULL_VECTOR, NULL_VECTOR); // extract the forward vector[3]
	NormalizeVector(aimVector, aimVector); // convert into unit vector
	
	// Get the unit vector representing the vector between target and attacker
	GetClientAbsOrigin(target, targetPos); 
	GetClientAbsOrigin(attacker, attackerPos);
	attackerPos[2] = targetPos[2] = 0.0; // Restrict to XY coordinates
	MakeVectorFromPoints(attackerPos, targetPos, directVector);
	NormalizeVector(directVector, directVector);
	
	// Calculate the angle between the two unit vectors
	return RadToDeg(ArcCosine(GetVectorDotProduct(aimVector, directVector)));
}

bool IsPinningASurvivor(int client) 
{
	bool isPinning = false;
	if( IsBotInfected(client) && IsPlayerAlive(client) ) 
	{
		if( GetEntPropEnt(client, Prop_Send, "m_tongueVictim") > 0 ) isPinning = true; // smoker
		if( GetEntPropEnt(client, Prop_Send, "m_pounceVictim") > 0 ) isPinning = true; // hunter
		if( GetEntPropEnt(client, Prop_Send, "m_carryVictim") > 0 ) isPinning = true; // charger carrying
		if( GetEntPropEnt(client, Prop_Send, "m_pummelVictim") > 0 ) isPinning = true; // charger pounding
		if( GetEntPropEnt(client, Prop_Send, "m_jockeyVictim") > 0 ) isPinning = true; // jockey
	}
	return isPinning;
}
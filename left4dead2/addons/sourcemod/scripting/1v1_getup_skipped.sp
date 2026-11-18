/*
	SourcePawn is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	SourceMod is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	Pawn and SMALL are Copyright (C) 1997-2008 ITB CompuPhase.
	Source is Copyright (C) Valve Corporation.
	All trademarks are property of their respective owners.

	This program is free software: you can redistribute it and/or modify it
	under the terms of the GNU General Public License as published by the
	Free Software Foundation, either version 3 of the License, or (at your
	option) any later version.

	This program is distributed in the hope that it will be useful, but
	WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	General Public License for more details.

	You should have received a copy of the GNU General Public License along
	with this program. If not, see <http://www.gnu.org/licenses/>.
*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <colors>

#define CONTROL_DAMAGE 10.0
#define L4D2Team_Survivor 2
#define L4D2Team_Infected 3
#define L4D2Infected_Smoker 1
#define L4D2Infected_Charger 6

stock const char L4D2_InfectedNames[10][] =
{
	"Common", "Smoker", "Boomer", "Hunter", "Spitter",
	"Jockey", "Charger", "Witch", "Tank", "Survivor"
};

ConVar
	g_hCvarDmgThreshold = null;

bool g_bControlPending[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "1v1_getup_skipped",
	author = "红豆、Caibiii",
	description = "单人模式快速起身、拦截部分特感控制效果",
	version = "1.0",
	url = "https://github.com/Caibiii/AnneServer"
};

public void OnPluginStart()
{
	g_hCvarDmgThreshold = CreateConVar("sm_1v1_dmgthreshold", "10", "Amount of damage done (at once) before SI suicides.", _, true, 1.0);

	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
}

public Action L4D_OnPouncedOnSurvivor(int victim, int attacker)
{
	return BlockControl(victim, attacker);
}

public Action L4D_OnGrabWithTongue(int victim, int attacker)
{
	return BlockControl(victim, attacker);
}

public Action L4D2_OnJockeyRide(int victim, int attacker)
{
	return BlockControl(victim, attacker);
}

public Action L4D2_OnStartCarryingVictim(int victim, int attacker)
{
	return BlockControl(victim, attacker);
}

Action BlockControl(int victim, int attacker)
{
	if (!IsClientAndInGame(victim) || GetClientTeam(victim) != L4D2Team_Survivor || !IsPlayerAlive(victim)
		|| !IsClientAndInGame(attacker) || GetClientTeam(attacker) != L4D2Team_Infected || !IsPlayerAlive(attacker))
	{
		return Plugin_Continue;
	}

	int zclass = GetEntProp(attacker, Prop_Send, "m_zombieClass");
	if (zclass == L4D2Infected_Charger)
	{
		return Plugin_Continue;
	}
	if (zclass == L4D2Infected_Smoker)
	{
		if (g_bControlPending[attacker])
		{
			return Plugin_Continue;
		}
		g_bControlPending[attacker] = true;
		DataPack pack = new DataPack();
		pack.WriteCell(GetClientUserId(victim));
		pack.WriteCell(GetClientUserId(attacker));
		CreateTimer(1.0, Timer_BlockControl, pack, TIMER_FLAG_NO_MAPCHANGE | TIMER_DATA_HNDL_CLOSE);
		return Plugin_Continue;
	}

	ApplyControlDamage(victim, attacker);
	return Plugin_Handled;
}

Action Timer_BlockControl(Handle timer, DataPack pack)
{
	pack.Reset();
	int victim = GetClientOfUserId(pack.ReadCell());
	int attacker = GetClientOfUserId(pack.ReadCell());
	if (attacker > 0)
	{
		g_bControlPending[attacker] = false;
	}
	if (IsClientAndInGame(victim) && GetClientTeam(victim) == L4D2Team_Survivor && IsPlayerAlive(victim)
		&& IsClientAndInGame(attacker) && GetClientTeam(attacker) == L4D2Team_Infected && IsPlayerAlive(attacker))
	{
		ApplyControlDamage(victim, attacker);
	}
	return Plugin_Stop;
}

void ApplyControlDamage(int victim, int attacker)
{
	SDKHooks_TakeDamage(victim, attacker, attacker, CONTROL_DAMAGE, DMG_GENERIC);
	RequestFrame(ReleaseSurvivor, GetClientUserId(attacker));
}

void ReleaseSurvivor(int userid)
{
	int attacker = GetClientOfUserId(userid);
	if (IsClientAndInGame(attacker) && GetClientTeam(attacker) == L4D2Team_Infected && IsPlayerAlive(attacker))
	{
		ForcePlayerSuicide(attacker);
	}
}

public void Event_PlayerHurt(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int fDamage = hEvent.GetInt("dmg_health");
	if (fDamage < g_hCvarDmgThreshold.IntValue) {
		return;
	}
	
	int iAttacker = GetClientOfUserId(hEvent.GetInt("attacker"));
	if (!IsClientAndInGame(iAttacker) || GetClientTeam(iAttacker) != L4D2Team_Infected || !IsPlayerAlive(iAttacker)) {
		return;
	}
	
	int iZclass = GetEntProp(iAttacker, Prop_Send, "m_zombieClass");
	
	if (iZclass < L4D2Infected_Smoker || iZclass > L4D2Infected_Charger) {
		return;
	}
	
	int iVictim = GetClientOfUserId(hEvent.GetInt("userid"));
	if (!IsClientAndInGame(iVictim) || GetClientTeam(iVictim) != L4D2Team_Survivor || !IsPlayerAlive(iVictim)) {
		return;
	}
	
	int iRemainingHealth = GetClientHealth(iAttacker);

	// [1v1] Player (Hunter) had 250 health remaining!
	// [1v1] AI (Hunter) had 250 health remaining!
	/*
	char sName[MAX_NAME_LENGTH];
	if (IsFakeClient(iAttacker)) 
	{
		Format(sName, sizeof(sName), "AI");
	} 
	else 
	{
		GetClientName(iAttacker, sName, sizeof(sName));
	}
	*/
	CPrintToChatAll("[{olive}Anne{default}] {green}%s{default} had {olive}%d{default} health remaining!", L4D2_InfectedNames[iZclass], iRemainingHealth);
	ForcePlayerSuicide(iAttacker);
}
public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_PostThinkPost, CancelGetup);
}

public Action CancelGetup(int client)
{
	if (IsClientAndInGame(client))
	{
		SetEntPropFloat(client, Prop_Send, "m_flCycle", 9999.9, 0);
	}
	return Plugin_Continue;
}

stock bool IsClientAndInGame(int iClient)
{
	return (iClient > 0 && IsClientInGame(iClient));
}
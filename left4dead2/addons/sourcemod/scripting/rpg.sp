#pragma semicolon 1
#pragma tabsize 0
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2lib>
#include <left4dhooks>
#include <colors>
#include <smlib>
//常规设定
#define TEAM_SPECTATORS 1		//Team数值
#define TEAM_SURVIVORS 2		//Team数值
#define TEAM_INFECTED 3		//Team数值
#define IsValidClient(%1)		(1 <= %1 <= MaxClients && IsClientInGame(%1))    //定义客户端是否在游戏中

new Handle:ReturnBlood;
#define SCORE_DELAY_EMPTY_SERVER 3.0
#define L4D_MAXHUMANS_LOBBY_OTHER 3
new Float:lastDisconnectTime;


public void OnPluginStart()
{
	HookEvent("player_death", Event_PlayerDeath);
	ReturnBlood = CreateConVar("ReturnBlood", "0");
}

//出门将游戏模式切换为COOP，并回满所有生还者状态
public Action:L4D_OnFirstSurvivorLeftSafeArea() 
{
	CreateTimer(0.5, ResetSurvivorStatus, _, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Stop;
}

//给予物品函数
BypassAndExecuteCommand(client, String: strCommand[], String: strParam1[])
{
	new flags = GetCommandFlags(strCommand);
	SetCommandFlags(strCommand, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", strCommand, strParam1);
	SetCommandFlags(strCommand, flags);
}
public Action:ResetSurvivorStatus(Handle:timer) 
{
	for (new client = 1; client <= MaxClients; client++) 
	{
		if (IsSurvivor(client)) 
		{
			if(IsFakeClient(client))
			{
				new item = GetPlayerWeaponSlot(client, 0);
				if (item > 0) 
				{
					//RemovePlayerItem(client, item);
				}
				else
				{
					BypassAndExecuteCommand(client, "give","smg");
				}
			}
			else
			{
				new item = GetPlayerWeaponSlot(client, 0);
				if (item > 0) 
				{
					//RemovePlayerItem(client, item);
				}
				else
				{
					BypassAndExecuteCommand(client, "give","smg");
				}
			}
		}
	}
}


// 玩家离开游戏 
public OnClientDisconnect(client)
{
	if(!IsFakeClient(client) && IsClientInGame(client))
	{
		new Float:currenttime = GetGameTime();
		if (lastDisconnectTime == currenttime)
		{
			return;
		}
		CreateTimer(SCORE_DELAY_EMPTY_SERVER, IsNobodyConnected, currenttime);
		lastDisconnectTime = currenttime;
	}
}
public Action:IsNobodyConnected(Handle:timer, any:timerDisconnectTime)
{
	if (timerDisconnectTime != lastDisconnectTime)
	{
		return Plugin_Stop;
	}
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i))
		{
			return  Plugin_Stop;
		}
	}
	return Plugin_Stop;
}

// 各种经验值和技能回血效果
public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if(IsValidClient(victim))
	{
		if(GetClientTeam(victim) == TEAM_INFECTED)
		{
			if(IsSurvivor(attacker))	//玩家幸存者杀死特殊感染者
			{
				if(!IsFakeClient(attacker))
				{
					if(bool:GetConVarBool(ReturnBlood))
					{
						new maxhp = GetEntProp(attacker, Prop_Data, "m_iMaxHealth");
						new targetHealth = GetSurvivorPermHealth(attacker);
						targetHealth += 2;
						if(targetHealth > maxhp)
						{
							targetHealth = maxhp;
						}
						if(!IsPlayerIncap(attacker))
						{
							SetSurvivorPermHealth(attacker, targetHealth);
						}
					}
				}
				else
				{
					new targetHealth = GetSurvivorPermHealth(attacker);
					targetHealth += 2;
					if(targetHealth > 100)
					{
						targetHealth = 100;
					}
					if(!IsPlayerIncap(attacker))
					{
						SetSurvivorPermHealth(attacker, targetHealth);
					}
				}
			}
		}
	}
	return Plugin_Continue;
}



//判断是否为生还者
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

//获取实血
stock GetSurvivorPermHealth(client)
{
	return GetEntProp(client, Prop_Send, "m_iHealth");
}
//设置实血
stock SetSurvivorPermHealth(client, health)
{
	SetEntProp(client, Prop_Send, "m_iHealth", health);
}
//判断是否倒地
stock bool:IsPlayerIncap(client)
{
	return bool:GetEntProp(client, Prop_Send, "m_isIncapacitated");
}
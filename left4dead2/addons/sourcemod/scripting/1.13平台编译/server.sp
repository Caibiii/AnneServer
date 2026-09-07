#pragma semicolon 1
#pragma tabsize 0
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
//#include <l4d2lib>
#include <left4dhooks>
#include <colors>
#include <l4d_CreateSurvivorBot>
#define SCORE_DELAY_EMPTY_SERVER 10.0
#define L4D_MAXHUMANS_LOBBY_OTHER 3
#define IsValidClient(%1)		(1 <= %1 <= MaxClients && IsClientInGame(%1))
#define IsValidAliveClient(%1)	(1 <= %1 <= MaxClients && IsClientInGame(%1) && IsPlayerAlive(%1))
new Float:lastDisconnectTime;
new Handle:hCvarMotdTitle;
new Handle:hCvarMotdUrl;
new iNewLimit;
public OnPluginStart()
{
	RegConsoleCmd("sm_away", AFKTurnClientToSpe);
	RegConsoleCmd("sm_s", AFKTurnClientToSpe);
	RegConsoleCmd("sm_ammo", GiveClientAmmo);
	RegAdminCmd("sm_restartmap", RestartMap, ADMFLAG_ROOT, "restarts map");
	//AddCommandListener(Command_Setinfo, "jointeam");
	//AddCommandListener(Command_Setinfo1, "chooseteam");
	AddNormalSoundHook(NormalSHook:OnNormalSound);
	AddAmbientSoundHook(AmbientSHook:OnAmbientSound);
	HookEvent("player_team", Event_PlayerTeam);	
	HookEvent("witch_killed", WitchKilled_Event);
	HookEvent("finale_win", ResetSurvivors);
	HookEvent("map_transition", ResetSurvivors);
	HookEvent("round_start", event_RoundStart);
	RegConsoleCmd("sm_join", AFKTurnClientToSurvivors);
	RegConsoleCmd("sm_jg", AFKTurnClientToSurvivors);
	RegAdminCmd("sm_restart", RestartServer, ADMFLAG_ROOT, "Kicks all clients and restarts server");
	RegAdminCmd("sm_hp", GiveHealth, ADMFLAG_ROOT, "GiveHealth");
	hCvarMotdTitle = CreateConVar("sm_cfgmotd_title", "AnneHappy");
    hCvarMotdUrl = CreateConVar("sm_cfgmotd_url", "http://8.134.115.0:777/");  // 以后更换为数据库控制
	RegAdminCmd("player_limit", Command_SetSurvivorLimit, ADMFLAG_CONFIG, "");
}
// 地图加载初始化
public void OnMapStart() 
{
	ServerCommand("sm plugins load_unlock");
    ServerCommand("sm plugins reload optional/ai_charger3.smx");
    ServerCommand("sm plugins load_lock");
    CreateTimer(3.0, Timer_DoSpawnSurvivors, iNewLimit, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Command_SetSurvivorLimit(int client, int args)
{
    if (args < 1)
    {
        return Plugin_Handled;
    }
    char szArg[16];
    GetCmdArg(1, szArg, sizeof(szArg));
    iNewLimit = StringToInt(szArg);
	
    // 将目标数值传给定时器，延迟1秒执行生成逻辑
    CreateTimer(3.0, Timer_DoSpawnSurvivors, iNewLimit, TIMER_FLAG_NO_MAPCHANGE);
    
    return Plugin_Handled;
}

// 延迟1秒执行生成Bot主体逻辑
public Action Timer_DoSpawnSurvivors(Handle hTimer, int Limit)
{
    int iCurSurvivors = CountSurvivors();

    // 人数超过限制，先踢多余AI Bot
    if (iCurSurvivors > Limit)
    {
        int kickCount = iCurSurvivors - Limit;
        int kicked = 0;
		// 遍历改成从后往前，优先删除新生成Bot
		for (int client = MaxClients; client >= 1; client--)
		{
			if (!IsClientInGame(client)) continue;
			if (GetClientTeam(client) != 2) continue;
			if (!IsFakeClient(client)) continue;
			KickClient(client, "Survivor bot over limit");
			kicked++;
			if (kicked >= kickCount) break;
		}
        return Plugin_Stop;
    }

    // 人数不足，生成补齐
    if(Limit < 5)
    {
        if (Limit <= iCurSurvivors)
        {
            return Plugin_Stop;
        }
        int iNeed = Limit - iCurSurvivors;
        // L4D2Direct原生Bot
        for (int i = 0; i < iNeed; i++)
        {
            L4D2Direct_AddSurvivorBot(8);
        }
    }
    else
    {
        if (Limit <= iCurSurvivors)
        {
            return Plugin_Stop;
        }
        int iNeed = Limit - iCurSurvivors;
        // CreateSurvivorBot假客户端
        for (int i = 0; i < iNeed; i++)
        {
            int fakeclient = CreateSurvivorBot();
            if (fakeclient <= 0)
            {
                continue;
            }
        }
    }
    return Plugin_Stop;
}

// 统计生还者（玩家+AI）
stock int CountSurvivors()
{
    int count = 0;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client) && GetClientTeam(client) == 2)
        {
            count++;
        }
    }
    return count;
}

//出门将游戏模式切换为COOP，并回满所有生还者状态
public Action:L4D_OnFirstSurvivorLeftSafeArea() 
{
	CreateTimer(0.5, ResetSurvivorStatus, _, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Stop;
}
//输入!jg或者!join加入生还者
public Action:AFKTurnClientToSurvivors(client, args)
{ 
	ClientCommand(client, "jointeam 2");
	return Plugin_Handled;
}
//输入!s或者!away延迟2.5秒后切换为旁观
public Action:AFKTurnClientToSpe(client, args) 
{
	if(!IsPinned(client))
	CreateTimer(2.5, Timer_CheckAway, client, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Handled;
}
public Action:Timer_CheckAway(Handle:Timer, any:client)
{
	ChangeClientTeam(client, 1); 
}
//输入!RestartMap重启当前地图
public Action:RestartMap(client,args)
{
	CrashMap();
	return Plugin_Handled;
}
CrashMap()
{
	
	decl String:mapname[64];
	GetCurrentMap(mapname, sizeof(mapname));
	ServerCommand("changelevel %s", mapname);
	
}

// 获取当前所有生还者（真人+Bot）总数量
stock int GetSurvivorCount()
{
    int count = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsSurvivor(i))
        {
            count++;
        }
    }
    return count;
}
//输入!restart重启服务器
public Action: RestartServer(client,args)
{
    CrashServer();
	return Plugin_Handled;
}
CrashServer()
{
    SetCommandFlags("crash", GetCommandFlags("crash")&~FCVAR_CHEAT);
    ServerCommand("crash");
}
//输入!ammo补满子弹
public Action:GiveClientAmmo(client, args) 
{
	if (IsSurvivor(client)) 
	{
		BypassAndExecuteCommand(client, "give","ammo"); 
	}
	return Plugin_Handled;
}
public Action:GiveHealth(client, args) 
{
	RestoreHealth();
	return Plugin_Handled;
}

//地图加载、回合开始3秒后开始加载cfg/sourcemod/map_cvars/%s.cfg下的配置
public event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	CreateTimer(3.0, Timer_DelayedOnRoundStart, _, TIMER_FLAG_NO_MAPCHANGE ); 
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

public Action:Timer_DelayedOnRoundStart(Handle:timer) 
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

//重置生还者为满血以及清除生还者的装备
public Action:ResetSurvivors(Handle:event, const String:name[], bool:dontBroadcast)
{
	RestoreHealth();
	ResetInventory();
}
ResetInventory() 
{
	for (new client = 1; client <= MaxClients; client++) 
	{
		if (IsSurvivor(client)) 
		{
			
			for (new i = 0; i < 5; i++) 
			{ 
				DeleteInventoryItem(client, i);		
			}
			BypassAndExecuteCommand(client, "give", "pistol");
			
		}
	}		
}
DeleteInventoryItem(client, slot) 
{
	new item = GetPlayerWeaponSlot(client, slot);
	if (item > 0) 
	{
		RemovePlayerItem(client, item);
	}	
}
RestoreHealth() 
{
	for (new client = 1; client <= MaxClients; client++) 
	{
		if (IsSurvivor(client)) 
		{
			BypassAndExecuteCommand(client, "give","health");
			SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);		
			SetEntProp(client, Prop_Send, "m_currentReviveCount", 0);
			SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", false);
		}
	}
}

//玩家加入游戏显示motd界面，将特感玩家切换为旁观；将想进入特感方的玩家强制切为旁观
public OnClientPutInServer(client)
{
	if(client > 0 && IsClientConnected(client) && !IsFakeClient(client))
	{
		ShowMotdToPlayer(client);
		CreateTimer(3.0, ChangeClientTeamTo1, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}
ShowMotdToPlayer(client)
{
	decl String:title[64], String:url[192];
    GetConVarString(hCvarMotdTitle, title, sizeof(title));
    GetConVarString(hCvarMotdUrl, url, sizeof(url));
    ShowMOTDPanel(client, title, url, MOTDPANEL_TYPE_URL);
}
public Action:Event_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new Client = GetEventInt(event, "userid");
	new target = GetClientOfUserId(Client);
	new team = GetEventInt(event, "team");
	new bool:disconnect = GetEventBool(event, "disconnect");
	if (IsValidPlayer(target) && !disconnect && team == 3)
	{
		if(!IsFakeClient(target))
		{
			CreateTimer(0.5, ChangeClientTeamTo1, target, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	return Plugin_Continue;
}

public Action:ChangeClientTeamTo1(Handle:Timer, any:client)
{
	if(IsValidPlayerInTeam(client, 3))
	{
		ChangeClientTeam(client, 1); 
	} 
}

//检测控制台输入，如果生还满人、加入特感方、按M选择队伍则阻止
public Action:Command_Setinfo(client, const String:command[], args)
{
    decl String:arg[32];
    GetCmdArg(1, arg, sizeof(arg));
    if (StrEqual(arg, "3") || StrEqual(arg, "infected") || IsSuivivorTeamFull())
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
} 

public Action:Command_Setinfo1(client, const String:command[], args)
{
    return Plugin_Handled;
} 

// 玩家离开显示离开提示，并检测服务器是否还有人，没人则自动重启服务器
public OnClientDisconnect(client)
{
	if (IsClientInGame(client) && IsFakeClient(client)) return;
	new Float:currenttime = GetGameTime();
	if (lastDisconnectTime == currenttime) return;
	CreateTimer(SCORE_DELAY_EMPTY_SERVER, IsNobodyConnected, currenttime);
	lastDisconnectTime = currenttime;
}

public Action:IsNobodyConnected(Handle:timer, any:timerDisconnectTime)
{
	if (timerDisconnectTime != lastDisconnectTime) return Plugin_Stop;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i))
			return  Plugin_Stop;
	}
	CrashServer();
	return Plugin_Stop;
}


//击杀witch回15点实血
public WitchKilled_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !IsPlayerIncap(client))
	{
		new maxhp = GetEntProp(client, Prop_Data, "m_iMaxHealth");
		new targetHealth = GetSurvivorPermHealth(client) + 15;
		if(targetHealth > maxhp)
		{
			targetHealth = maxhp;
		}
		SetSurvivorPermHealth(client, targetHealth);
	}
}
//监听声音，如果是烟花的吵闹声则阻止
public Action:OnNormalSound(int clients[64], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags)
{
	return (StrContains(sample, "firewerks", true) > -1) ? Plugin_Stop : Plugin_Continue;
}
public Action:OnAmbientSound(char sample[PLATFORM_MAX_PATH], int &entity, float &volume, int &level, int &pitch, float pos[3], int &flags, float &delay)
{
	return (StrContains(sample, "firewerks", true) > -1) ? Plugin_Stop : Plugin_Continue;
}

//判断生还是否已经满人
bool:IsSuivivorTeamFull() 
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && IsFakeClient(i))
		{
			return false;
		}
	}
	return true;
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
//判断是否为玩家再队伍里
bool:IsValidPlayerInTeam(client,team)
{
	if(IsValidPlayer(client))
	{
		if(GetClientTeam(client)==team)
		{
			return true;
		}
	}
	return false;
}
bool:IsValidPlayer(Client, bool:AllowBot = true, bool:AllowDeath = true)
{
	if (Client < 1 || Client > MaxClients)
		return false;
	if (!IsClientConnected(Client) || !IsClientInGame(Client))
		return false;
	if (!AllowBot)
	{
		if (IsFakeClient(Client))
			return false;
	}

	if (!AllowDeath)
	{
		if (!IsPlayerAlive(Client))
			return false;
	}	
	
	return true;
}

//判断生还者是否已经被控
stock bool:IsPinned(client) 
{
	new bool:bIsPinned = false;
	if (IsSurvivor(client)) 
	{
		if( GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0 ) bIsPinned = true; // smoker
		if( GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0 ) bIsPinned = true; // hunter
		if( GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0 ) bIsPinned = true; // charger carry
		if( GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0 ) bIsPinned = true; // charger pound
		if( GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0 ) bIsPinned = true; // jockey
	}		
	return bIsPinned;
}
//获取生还者实血
GetSurvivorPermHealth(client)
{
	return GetEntProp(client, Prop_Send, "m_iHealth");
}
//设置生还者实血
SetSurvivorPermHealth(client, health)
{
	SetEntProp(client, Prop_Send, "m_iHealth", health);
}
//判断生还者倒地
bool:IsPlayerIncap(client)
{
	return bool:GetEntProp(client, Prop_Send, "m_isIncapacitated");
}
//给予物品函数
BypassAndExecuteCommand(client, String: strCommand[], String: strParam1[])
{
	new flags = GetCommandFlags(strCommand);
	SetCommandFlags(strCommand, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", strCommand, strParam1);
	SetCommandFlags(strCommand, flags);
}

//给予生还者药丸、清除倒地次数、回满血量、清除AI武器并给与机枪和马格南
public Action:ResetSurvivorStatus(Handle:timer) 
{
	for (new client = 1; client <= MaxClients; client++) 
	{
		if (IsSurvivor(client)) 
		{
			BypassAndExecuteCommand(client, "give","pain_pills"); 
			BypassAndExecuteCommand(client, "give","health"); 
			SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);		
			SetEntProp(client, Prop_Send, "m_currentReviveCount", 0);
			SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", false);
			if(IsFakeClient(client))
			{
				for (new i = 0; i < 1; i++) 
				{ 
					DeleteInventoryItem(client, i);		
				}
				BypassAndExecuteCommand(client, "give","smg");
				BypassAndExecuteCommand(client, "give","pistol_magnum"); 
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


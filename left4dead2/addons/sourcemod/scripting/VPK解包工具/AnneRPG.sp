#pragma semicolon 1
#include <sourcemod>
#include <adminmenu>
#include <sdktools_functions>
#include <sdktools>
#include <left4downtown>
#include <colors>
#include <float>
#include <adt_array> 

//主界面
#define ARMS 			1	//武器
#define	MELEE			2	//近战
#define PROPS 			3	//道具
#define CLASS_TANK		8
//武器
#define	PISTOL			10	//手枪
#define	MAGNUM			11	//马格南手枪

#define	SMG				12	//冲锋枪
#define	SMGSILENCED		13	//消声冲锋枪
#define	MP5				14	

#define PUMPSHOTGUN1	15	//老式单发霰弹
#define PUMPSHOTGUN2	16	//新式单发霰弹
#define	AUTOSHOTGUN1	17	//老式连发霰弹
#define	AUTOSHOTGUN2	18	//新式连发霰弹

#define HUNTING1		19	//猎枪
#define	HUNTING2		20	//G3SG1狙击枪
#define	SNIPERSCOUT		21	//斯太尔小型狙击枪
#define	AWP				22	//麦格农大型狙击枪

#define M16				23
#define	AK47			24
#define	SCAR			25	//三连发


//道具投掷
#define	ADRENALINE		50	//肾上腺素
#define	PAINPILLS		51	//药丸
#define	FIRSTAIDKIT		52	//医疗包
#define	GASCAN		53	//油桶
//武器的点B数价值---------------------------------------------
//武器
new Handle:pistolmoney = INVALID_HANDLE;			//手枪
new Handle:magnummoney = INVALID_HANDLE;			//马格南手枪
new Handle:smgmoney = INVALID_HANDLE;				//冲锋枪
new Handle:smgsilencedmoney = INVALID_HANDLE;		//消声冲锋枪
new Handle:pumpshotgun1money = INVALID_HANDLE;		//老式单发霰弹
new Handle:pumpshotgun2money = INVALID_HANDLE;		//新式单发霰弹
new Handle:autoshotgun1money = INVALID_HANDLE;		//老式连发霰弹
new Handle:autoshotgun2money = INVALID_HANDLE;		//新式连发霰弹
new Handle:hunting1money = INVALID_HANDLE;		//猎枪
new Handle:hunting2money = INVALID_HANDLE;		//G3SG1狙击枪
new Handle:m16money = INVALID_HANDLE;			
new Handle:ak47money = INVALID_HANDLE;			
new Handle:scarmoney = INVALID_HANDLE;				//三连发
//道具投掷
new Handle:adrenalinemoney = INVALID_HANDLE;		//肾上腺素
new Handle:painpillsmoney = INVALID_HANDLE;			//药丸
new Handle:firstaidkitmoney = INVALID_HANDLE;		//医疗包
new Handle:gascanmoney = INVALID_HANDLE;		//油桶
#define IsValidClient(%1)		(1 <= %1 <= MaxClients && IsClientInGame(%1))
//秒妹回血插件
#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))
#define MIN(%0,%1) (((%0) < (%1)) ? (%0) : (%1))
new Handle:hw_max_health;
new Handle:hw_cap_health;
new Handle:hw_perm_gain;
new Handle:hw_temp_gain;
new Handle:pain_pills_decay_rate;
 //秒妹回血插件
#define TEAM_SPECTATORS 1
#define TEAM_SURVIVORS 2
#define TEAM_INFECTED 3
#define CVAR_FLAGS FCVAR_PLUGIN|FCVAR_NOTIFY
#define COMMAND_FILTER COMMAND_FILTER_CONNECTED|COMMAND_FILTER_NO_BOTS
#define PLUGIN_VERSION "1.0"
#define IsValidClient(%1)		(1 <= %1 <= MaxClients && IsClientInGame(%1))
#define IsValidAliveClient(%1)	(1 <= %1 <= MaxClients && IsClientInGame(%1) && IsPlayerAlive(%1))
/* Infected Exp */
// connect--->初始化(读取MYSQL数据，为空则添加)---离开游戏(更新玩家数据UPDATE)
new String:Init[]="INSERT INTO `l4d2`(`steam_id`, `steam_name`, `LV_DATA`, `EXP_DATA`,`Str_DATA`,`Endurance_DATA`,`Intelligence_DATA`, `CASH_DATA`,`STATUS`) VALUES (?,?,0,0,0,0,0,0,1)"; 
new String:Select[]="select * from l4d2 l where l.steam_id=?";
new String:Update[]="update l4d2 l set l.steam_name=?,l.LV_DATA=?,l.EXP_DATA=?,l.Str_DATA=?,l.Endurance_DATA=?,l.Intelligence_DATA=?,l.CASH_DATA=?,l.STATUS=1 where l.steam_id=?"; //这个是过图或者重启关卡的时候更新一次，不更新游戏时间
new String:Update_Disconnect[]="update l4d2 l set l.steam_name=?,l.LV_DATA=?,l.EXP_DATA=?,l.Str_DATA=?,l.Endurance_DATA=?,l.Intelligence_DATA=?,l.CASH_DATA=?,l.STATUS=0,l.HP_DATA=? where l.steam_id=?";//这个是离开游戏，然后更新一下所有数据以及游戏时间
/* Survivor Exp */
#define MSG_EXP_KILL_WITCH				"{lightgreen}击杀 {olive}Witch{lightgreen} 获得 {green}%d{olive}EXP"
#define MSG_EXP_KILL_SMOKER				"{lightgreen}击杀 {olive}Smoker{lightgreen} 获得 {green}%d{olive}EXP"
#define MSG_EXP_KILL_BOOMER				"{lightgreen}击杀 {olive}Boomer{lightgreen} 获得 {green}%d{olive}EXP"
#define MSG_EXP_KILL_HUNTER				"{lightgreen}击杀 {olive}Hunter{lightgreen} 获得 {green}%d{olive}EXP"
#define MSG_EXP_KILL_SPITTER			"{lightgreen}击杀 {olive}Spitter{lightgreen} 获得 {green}%d{olive}EXP"
#define MSG_EXP_KILL_JOCKEY				"{lightgreen}击杀 {olive}Jockey{lightgreen} 获得 {green}%d{olive}EXP"
#define MSG_EXP_KILL_CHARGER			"{lightgreen}击杀 {olive}Charger{lightgreen} 获得 {green}%d{olive}EXP"
#define MSG_EXP_KILL_TANK_ALL			"{lightgreen}由于你在这场与 {olive}Tank{lightgreen} 的搏斗中得以幸存奖励 {green}%d{olive}EXP"
#define MSG_EXP_KILL_ZOMBIES			"{lightgreen}击杀 {green}%d{lightgreen} 丧尸获得 {green}%d{olive}EXP"
#define MSG_EXP_REVIVE					"{olive}拉起队友{lightgreen} 获得 {green}%d{olive}EXP"
#define MSG_EXP_REVIVE_JOB4				"{olive}拉起队友{lightgreen} 获得 {green}%d{lightgreen}EXP{green}(额外+%d){lightgreen}{green}(额外+%d)"
#define MSG_EXP_DEFIBRILLATOR			"{olive}复活队友{lightgreen} 获得 {green}%d{olive}EXP"
#define MSG_EXP_DEFIBRILLATOR_JOB4		"{olive}复活队友{lightgreen} 获得 {green}%d{lightgreen}EXP{green}(额外+%d){lightgreen}{green}(额外+%d)"
#define MSG_EXP_HEAL_SUCCESS			"{olive}治疗队友{lightgreen} 获得 {green}%d{olive}EXP"
#define MSG_EXP_HEAL_SUCCESS_JOB4		"{olive}治疗队友{lightgreen} 获得 {green}%d{lightgreen}EXP{green}(额外+%d){lightgreen}{green}(额外+%d)"

/*** 玩家基本资料 ***/
enum data
{
	LV,
	EXP,
	Str,
	Endurance,
	Intelligence,
	CASH
};
int player_data[MAXPLAYERS+1][data];
/** 属性上限 **/
#define Limit_Str 100
/* 幸存者经验值 */
new Handle:JockeyKilledExp;
new Handle:HunterKilledExp;
new Handle:ChargerKilledExp;
new Handle:SmokerKilledExp;
new Handle:SpitterKilledExp;
new Handle:BoomerKilledExp;
new Handle:WitchKilledExp;
new Handle:ZombieKilledExp;
/* 幸存者金钱 */
new Handle:JockeyKilledCash;
new Handle:HunterKilledCash;
new Handle:ChargerKilledCash;
new Handle:SmokerKilledCash;
new Handle:SpitterKilledCash;
new Handle:BoomerKilledCash;
new Handle:WitchKilledCash;
new Handle:ZombieKilledCash;
/* 升级成本 */
new Handle:LvUpExpRate;
/* 攻击/击杀/召唤尸消失被击杀次数计算 */
new ZombiesKillCount[MAXPLAYERS+1];
/* 其他 */
/* 存档和排名 */
/* Timers设置 */
new Handle:ZombiesKillCountTimer[MAXPLAYERS+1]			= {	INVALID_HANDLE, ...};
new Handle:CheckExpTimer[MAXPLAYERS+1]					= {	INVALID_HANDLE, ...};
public OnPluginStart()
{
	RegisterCvars();
	RegisterCmds();
	HookEvents();
}
RegisterCvars()
{
	/* 幸存者经验值 */
	JockeyKilledExp					= CreateConVar("rpg_GainExp_Kill_Jockey",				"10",	"击杀Jockey获得的经验值", CVAR_FLAGS, true, 0.0);
	HunterKilledExp					= CreateConVar("rpg_GainExp_Kill_hunter",				"10",	"击杀Hunter获得的经验值", CVAR_FLAGS, true, 0.0);
	ChargerKilledExp				= CreateConVar("rpg_GainExp_Kill_Charger",				"10",	"击杀Charger获得的经验值", CVAR_FLAGS, true, 0.0);
	SmokerKilledExp					= CreateConVar("rpg_GainExp_Kill_Smoker",				"10",	"击杀Smoker获得的经验值", CVAR_FLAGS, true, 0.0);
	SpitterKilledExp				= CreateConVar("rpg_GainExp_Kill_Spitter",				"10",	"击杀Spitter获得的经验值", CVAR_FLAGS, true, 0.0);
	BoomerKilledExp					= CreateConVar("rpg_GainExp_Kill_Boomer",				"10",	"击杀Boomer获得的经验值", CVAR_FLAGS, true, 0.0);
	WitchKilledExp					= CreateConVar("rpg_GainExp_Kill_Witch",				"30",	"击杀Witch获得的经验值", CVAR_FLAGS, true, 0.0);
	ZombieKilledExp					= CreateConVar("rpg_GainExp_Kill_Zombie",				"1",	"击杀普通丧尸获得的经验值", CVAR_FLAGS, true, 0.0);
	/* 幸存者金钱 */
	JockeyKilledCash				= CreateConVar("rpg_GainCash_Kill_Jockey",				"10",	"击杀Jockey获得的金钱", CVAR_FLAGS, true, 0.0);
	HunterKilledCash				= CreateConVar("rpg_GainCash_Kill_hunter",				"10",	"击杀Hunter获得的金钱", CVAR_FLAGS, true, 0.0);
	ChargerKilledCash				= CreateConVar("rpg_GainCash_Kill_Charger",				"10",	"击杀Charger获得的金钱", CVAR_FLAGS, true, 0.0);
	SmokerKilledCash				= CreateConVar("rpg_GainCash_Kill_Smoker",				"10",	"击杀Smoker获得的金钱", CVAR_FLAGS, true, 0.0);
	SpitterKilledCash				= CreateConVar("rpg_GainCash_Kill_Spitter",				"10",	"击杀Spitter获得的金钱", CVAR_FLAGS, true, 0.0);
	BoomerKilledCash				= CreateConVar("rpg_GainCash_Kill_Boomer",				"10",	"击杀Boomer获得的金钱", CVAR_FLAGS, true, 0.0);
	WitchKilledCash					= CreateConVar("rpg_GainCash_Kill_Witch",				"30",	"击杀Witch获得的金钱", CVAR_FLAGS, true, 0.0);
	ZombieKilledCash				= CreateConVar("rpg_GainCash_Kill_Zombie",				"1",	"击杀普通丧尸获得的金钱", CVAR_FLAGS, true, 0.0);
	
	
	
	pistolmoney	=	CreateConVar("sm_Cashshop_pistolmoney","350","小刀的价格.",CVAR_FLAGS);
	magnummoney	=	CreateConVar("sm_Cashshop_magnummoney","60","马格南手枪的价格.",CVAR_FLAGS);
	smgmoney	=	CreateConVar("sm_Cashshop_smgmoney","60","冲锋枪的价格.",CVAR_FLAGS);
	smgsilencedmoney	=	CreateConVar("sm_Cashshop_smgsilencedmoney","60","消声冲锋枪的价格.",CVAR_FLAGS);
	pumpshotgun1money	=	CreateConVar("sm_Cashshop_pumpshotgun1money","60","老式单发霰弹枪的价格.",CVAR_FLAGS);
	pumpshotgun2money	=	CreateConVar("sm_Cashshop_pumpshotgun2money","60","新式单发霰弹枪的价格.",CVAR_FLAGS);
	autoshotgun1money	=	CreateConVar("sm_Cashshop_autoshotgun1money","300","老式连发霰弹枪的价格.",CVAR_FLAGS);
	autoshotgun2money	=	CreateConVar("sm_Cashshop_autoshotgun2money","300","新式连发霰弹枪的价格.",CVAR_FLAGS);
	hunting1money	=	CreateConVar("sm_Cashshop_hunting1money","300","猎枪的价格.",CVAR_FLAGS);
	hunting2money	=	CreateConVar("sm_Cashshop_hunting2money","300","G3SG1狙击枪的价格.",CVAR_FLAGS);
	m16money	=	CreateConVar("sm_Cashshop_m16money","300","M16步枪的价格.",CVAR_FLAGS);
	ak47money	=	CreateConVar("sm_Cashshop_ak47money","300","AK47步枪的价格.",CVAR_FLAGS);
	scarmoney	=	CreateConVar("sm_Cashshop_scarmoney","300","三连发步枪的价格.",CVAR_FLAGS);
	adrenalinemoney	=	CreateConVar("sm_Cashshop_adrenalinemoney","250","肾上腺素的价格.",CVAR_FLAGS);
	painpillsmoney	=	CreateConVar("sm_Cashshop_painpillsmoney","350","止痛药的价格.",CVAR_FLAGS);
	firstaidkitmoney	=	CreateConVar("sm_Cashshop_firstaidkitmoney","500","医疗包的价格.",CVAR_FLAGS);
	gascanmoney	=	CreateConVar("sm_Cashshop_gascanmoney","250","油桶的价格.",CVAR_FLAGS);
	HookEvent("witch_killed",			Event_WitchKilled);
	pain_pills_decay_rate = FindConVar("pain_pills_decay_rate");
	hw_max_health = CreateConVar("hw_max_health", "100", "多少hp以下的幸存者秒妹可以回血？", FCVAR_PLUGIN, true, 100.0);
	hw_cap_health = CreateConVar("hw_cap_health", "0", "是否限制健康的幸存者可以获得秒妹回血的效果", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	hw_perm_gain = CreateConVar("hw_perm_gain", "15", "秒妹会回多少实血", FCVAR_PLUGIN, true, 0.0);
	hw_temp_gain = CreateConVar("hw_temp_gain", "0", "秒妹会回多少虚血", FCVAR_PLUGIN, true, 0.0);
	/* 关于升级 */
	LvUpExpRate	= CreateConVar("rpg_LvUp_Exp_Rate",	"300",	"升级Exp系数: 升级经验=升级系Exp数*(当前等级+1)", CVAR_FLAGS, true, 1.0);
}
RegisterCmds()
{
	/* 技能 */
	RegConsoleCmd("sm_rpg",			Menu_RPG);
	RegConsoleCmd("sm_buy",			Menu_RPG);
	RegConsoleCmd("sm_lv",			Menu_STATUS);
	RegConsoleCmd("sm_pw",			Menu_STATUS);
}

HookEvents()
{
	HookEvent("player_death",			Event_PlayerDeath); 
	HookEvent("round_end", EvtRoundStart);
	HookEvent("map_transition",EvtRoundStart);
	HookEvent("finale_win",EvtRoundStart);
}
static Initialization(i)
{
	KillAllClientSkillTimer(i);
}
KillAllClientSkillTimer(Client)
{
	/* 停止击杀丧尸Timer */
	if(ZombiesKillCountTimer[Client] != INVALID_HANDLE)
	{
		ZombiesKillCount[Client] = 0;
		KillTimer(ZombiesKillCountTimer[Client]);
		ZombiesKillCountTimer[Client] = INVALID_HANDLE;
	}
}
public Action:L4D_OnFirstSurvivorLeftSafeArea() 
{
	RPGGiveitems();
	return Plugin_Stop;
}
public RPGGiveitems() 
{
	// iterate though all clients
	for (new client = 1; client <= MaxClients; client++) 
	{ 
		//check player is a survivor
		if (IsSurvivor(client) ) 
		{
			// check pills slot is empty
			if (player_data[client][Str] == 100) 
			{ 
				GiveItem(client, "knife"); 
			}
			if (player_data[client][Str] == 101) 
			{ 
				GiveItem(client, "fireaxe"); 
			}
		}
	}
}
GiveItem(client, String:Item[22]) {
	new flags = GetCommandFlags("give");
	SetCommandFlags("give", flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "give %s", Item);
	SetCommandFlags("give", flags|FCVAR_CHEAT);
} 
bool:IsSurvivor(client) { 
    if (client <= 0 || client > MaxClients || !IsClientConnected(client)) return false; // not a valid client
    else return IsClientInGame(client) && GetClientTeam(client) == 2; 
}  
public Action:EvtRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl String:id[30];
	for (new i=1;i<=MaxClients;i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i))
		{
	
			GetClientAuthId(i,AuthId_Steam2,id,sizeof(id));
			if (!StrEqual(id, "BOT"))
			{
				if(!Update_DATA(i,false)) return;
			}
		}
	}
}
public OnClientConnected(Client)
{
	if(!IsFakeClient(Client))
	{
		CheckExpTimer[Client] = CreateTimer(1.0, PlayerLevelAndMPUp, Client, TIMER_REPEAT);
		Initialization(Client);
	}
	
}
/* 玩家离开游戏 */
public OnClientDisconnect(Client)
{
	if(!IsFakeClient(Client))
	{
		Initialization(Client);
	}	
	
}
public OnClientPostAdminCheck(client)
{
	decl String:id[32];
	if (IsClientConnected(client))
	GetClientAuthId(client,AuthId_Steam2,id,sizeof(id));
	if ((StrEqual(id, "BOT")))	 return ;
	if(MYSQL_INIT(client,id))
	{
	}
}

public Action:PlayerLevelAndMPUp(Handle:timer, any:target)
{
	if(IsClientInGame(target))
	{
		if(player_data[target][EXP] >= GetConVarInt(LvUpExpRate))
		{
			player_data[target][EXP] -= GetConVarInt(LvUpExpRate);
			player_data[target][LV] += 1;
			//PrintToChatAll("\x04%N \x05当前等级为\x04Lv.%d  \x05输入!rpg有惊喜哦", target, Lv[target]);
		}
	}
	
	return Plugin_Continue;
}
/* 各种经验值 */
public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	decl String:WeaponUsed[256];
	GetEventString(event, "weapon", WeaponUsed, sizeof(WeaponUsed));
	if(IsValidClient(victim))
	{
		
		if(GetClientTeam(victim) == TEAM_INFECTED)
		{
			new iClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
			
			if(IsValidClient(attacker))
			{
				if(GetClientTeam(attacker) == TEAM_SURVIVORS)	//玩家幸存者杀死特殊感染者
				{
					if(!IsFakeClient(attacker))
					{
						switch (iClass)
						{
							case 1: //smoker
							{
								new EXPGain = GetConVarInt(SmokerKilledExp);
								new CashGain = GetConVarInt(SmokerKilledCash);
								player_data[attacker][EXP] += EXPGain;
								player_data[attacker][CASH] += CashGain;
								if(player_data[attacker][Endurance] > 29)
								{
									new targetHealth = GetSurvivorPermHealth(attacker) + 1;
									SetSurvivorPermHealth(attacker, targetHealth);
								}
							}
							case 2: //boomer
							{
								new EXPGain = GetConVarInt(BoomerKilledExp);
								new CashGain = GetConVarInt(BoomerKilledCash);
								
								player_data[attacker][EXP] += EXPGain;
								player_data[attacker][CASH] += CashGain;
								if(player_data[attacker][Endurance] > 29)
								{
									new targetHealth = GetSurvivorPermHealth(attacker) + 1;
									if(player_data[attacker][Endurance] > 99)
									{
										targetHealth += 1;
									}
									SetSurvivorPermHealth(attacker, targetHealth);
								}
							
							}
							case 3: //hunter
							{
								new EXPGain = GetConVarInt(HunterKilledExp);
								new CashGain = GetConVarInt(HunterKilledCash);
								
								player_data[attacker][EXP] += EXPGain;
								player_data[attacker][CASH] += CashGain;
								if(player_data[attacker][Endurance] > 29)
								{
									new targetHealth = GetSurvivorPermHealth(attacker) + 1;
									SetSurvivorPermHealth(attacker, targetHealth);
								}
							
							}
							case 4: //spitter
							{
								new EXPGain = GetConVarInt(SpitterKilledExp);
								new CashGain = GetConVarInt(SpitterKilledCash);
								
								player_data[attacker][EXP] += EXPGain;
								player_data[attacker][CASH] += CashGain;
								if(player_data[attacker][Endurance] > 29)
								{
									new targetHealth = GetSurvivorPermHealth(attacker) + 1;
									SetSurvivorPermHealth(attacker, targetHealth);
								}
								
							}
							case 5: //jockey
							{
								new EXPGain = GetConVarInt(JockeyKilledExp);
								new CashGain = GetConVarInt(JockeyKilledCash);
								
								player_data[attacker][EXP] += EXPGain;
								player_data[attacker][CASH] += CashGain;
								if(player_data[attacker][Endurance] > 29)
								{
									new targetHealth = GetSurvivorPermHealth(attacker) + 1;
									SetSurvivorPermHealth(attacker, targetHealth);
								}
						
							}
							case 6: //charger
							{
								new EXPGain = GetConVarInt(ChargerKilledExp);
								new CashGain = GetConVarInt(ChargerKilledCash);
								
								player_data[attacker][EXP] += EXPGain;
								player_data[attacker][CASH] += CashGain;
								if(player_data[attacker][Endurance] > 29)
								{
									new targetHealth = GetSurvivorPermHealth(attacker) + 1;
									SetSurvivorPermHealth(attacker, targetHealth);
								}
					
							}
						}
					}
				}
			}
		}
		else if(GetClientTeam(victim) == TEAM_SURVIVORS)
		{
			if(!IsValidClient(attacker))
			{
				new attackerentid = GetEventInt(event, "attackerentid");
				for(new i=1; i<=MaxClients; i++)
				{
					if(GetEntPropEnt(attackerentid, Prop_Data, "m_hOwnerEntity") == i)
					{
						new Handle:event_death = CreateEvent("player_death");
						SetEventInt(event_death, "userid", GetClientUserId(victim));
						SetEventInt(event_death, "attacker", GetClientUserId(i));
						SetEventString(event_death, "weapon", "summon_killed");
						FireEvent(event_death);
						break;
					}
				}
			}
			
		}
	} 
	else if (!IsValidClient(victim))
	{
		if(IsValidClient(attacker))
		{
			if(GetClientTeam(attacker) == TEAM_SURVIVORS && !IsFakeClient(attacker))	//玩家幸存者杀死普通感染者
			{
				if(ZombiesKillCountTimer[attacker] == INVALID_HANDLE)	ZombiesKillCountTimer[attacker] = CreateTimer(5.0, ZombiesKillCountFunction, attacker);
				ZombiesKillCount[attacker] ++;
			}
		}
	}

	return Plugin_Continue;
}
/* Witch死亡 */
public Action:Event_WitchKilled(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new killer = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsValidClient(killer))
	{
		if(GetClientTeam(killer) == TEAM_SURVIVORS && !IsFakeClient(killer))
		{
			player_data[killer][EXP] += GetConVarInt(WitchKilledExp);
			player_data[killer][CASH] += GetConVarInt(WitchKilledCash);
			new bool:capped = GetConVarBool(hw_cap_health);
			new targetHealth = GetSurvivorPermHealth(killer) + GetConVarInt(hw_perm_gain);
			new Float:targetTemp = GetSurvivorTempHealth(killer) + GetConVarInt(hw_temp_gain);

			if (capped)
			{
				new maxHealth = GetConVarInt(hw_max_health);
				targetHealth = MIN(targetHealth, maxHealth);
				new Float:totalHealth = targetHealth + targetTemp;
				totalHealth = MIN(totalHealth, float(maxHealth));
				targetTemp = totalHealth - targetHealth;
			}
			SetSurvivorPermHealth(killer, targetHealth);
			SetSurvivorTempHealth(killer, targetTemp);
		}
	}
	return Plugin_Continue;
}

public Action:ZombiesKillCountFunction(Handle:timer, any:attacker)
{
	KillTimer(timer);
	ZombiesKillCountTimer[attacker] = INVALID_HANDLE;
	if (IsValidClient(attacker))
	{
		if (ZombiesKillCount[attacker] > 0)
		{
			player_data[attacker][EXP] += GetConVarInt(ZombieKilledExp)*ZombiesKillCount[attacker];
			player_data[attacker][CASH] += GetConVarInt(ZombieKilledCash)*ZombiesKillCount[attacker];
		}
		ZombiesKillCount[attacker]=0;
	}
}
/******************************************************
*	United RPG选单
*******************************************************/

/******************************************************
*	United RPG选单
*******************************************************/

/* 玩家受伤 */
/* 快捷指令 */
public Action:AddStrength(Client, args) //力量
{
	if(player_data[Client][CASH] > 300)
	{
		if (args < 1)
		{
			if(player_data[Client][Str] + 1 > Limit_Str)
			{
				return Plugin_Handled;
			}
			else
			{
				player_data[Client][Str] += 1;
				player_data[Client][CASH] -= 300;
				return Plugin_Handled;
			}
		}

		decl String:arg[8];
		GetCmdArg(1, arg, sizeof(arg));

		if (StringToInt(arg) <= 0)
		{
			return Plugin_Handled;
		}

		if (player_data[Client][CASH] >= StringToInt(arg))
		{
			if(player_data[Client][Str] + StringToInt(arg) > Limit_Str)
			{
				return Plugin_Handled;
			}
			else
			{
				player_data[Client][Str] += StringToInt(arg);
				player_data[Client][CASH] -= StringToInt(arg);
			}
		}
	}

	return Plugin_Handled;
}
public Action:AddEndurance(Client, args) //防御
{
	if(player_data[Client][CASH] > 1000)
	{
		if (args < 1)
		{

			
				player_data[Client][Endurance] += 1;
				player_data[Client][CASH] -= 1000;
				return Plugin_Handled;
			
		}

		decl String:arg[8];
		GetCmdArg(1, arg, sizeof(arg));

		if ( 0 >= StringToInt(arg))
		{
			return Plugin_Handled;
		}

		if (player_data[Client][CASH] >= StringToInt(arg))
		{
			player_data[Client][Endurance] += StringToInt(arg);
			player_data[Client][CASH] -= StringToInt(arg);
			
		}
	}

	return Plugin_Handled;
}
public Action:AddIntelligence(Client, args) //暴击伤害
{
	if(player_data[Client][CASH] > 30000)
	{
		if (args < 1)
		{
			player_data[Client][Intelligence] += 1;
			player_data[Client][CASH] -= 30000;
			return Plugin_Handled;
		}

		decl String:arg[8];
		GetCmdArg(1, arg, sizeof(arg));

		if ( 0 >= StringToInt(arg))
		{
			return Plugin_Handled;
		}

		if (player_data[Client][CASH] >= StringToInt(arg))
		{
			
			player_data[Client][Intelligence] += StringToInt(arg);
			player_data[Client][CASH] -= StringToInt(arg);
			
		}
	}

	return Plugin_Handled;
}

public Action:ResetBshu(Client, args) //重置技能
{
	if(player_data[Client][CASH] > 0)
	{
		if (args < 1)
		{
			player_data[Client][CASH] -= 0;
			player_data[Client][CASH] += (player_data[Client][Intelligence] * 28500 +player_data[Client][Endurance] * 950 +player_data[Client][Str] * 285);
			player_data[Client][Intelligence] = 0;
			player_data[Client][Endurance] = 0;
			player_data[Client][Str] = 0;
			return Plugin_Handled;	
		}

		decl String:arg[8];
		GetCmdArg(1, arg, sizeof(arg));

		if (StringToInt(arg) <= 0)
		{
			return Plugin_Handled;
		}

		if (player_data[Client][CASH] >= StringToInt(arg))
		{
			player_data[Client][CASH] -= StringToInt(arg);
			player_data[Client][CASH] += (player_data[Client][Intelligence] * 28500 +player_data[Client][Endurance] * 950 +player_data[Client][Str] * 285);
			player_data[Client][Intelligence] = 0;
			player_data[Client][Endurance] = 0;
			player_data[Client][Str] = 0;
		}
	}

	return Plugin_Handled;
}

/******************************************************
*	United RPG选单
*******************************************************/
public Action:Menu_RPG(Client,args)
{
	MenuFunc_Xsbz(Client);
	return Plugin_Handled;
}
public Action:Menu_STATUS(Client,args)
{
	displaykillinfected();
	return Plugin_Handled;
}
displaykillinfected()
{
	new client;
	new players;
	new players_clients[MAXPLAYERS+1];
	for (client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) != 3 && !IsFakeClient(client)) 
			players_clients[players++] = client;
	}
	SortCustom1D(players_clients, 8, SortByDamageDesc);
	for (new i; i <= 8; i++)
	{
		client = players_clients[i];
		if (IsValidClient(client) && GetClientTeam(client) != 3 && !IsFakeClient(client)) 
		{
			PrintToChatAll("\x03等级:Lv\x04%2d  \x03B数:\x04%2d   \x05%N",player_data[client][LV],player_data[client][CASH],client);
		}
	}
}
public SortByDamageDesc(elem1, elem2, const array[], Handle:hndl)
{
	if (player_data[elem1][LV] > player_data[elem2][LV]) return -1;
	else if (player_data[elem2][LV] > player_data[elem1][LV]) return 1;
	else if (elem1 > elem2) return -1;
	else if (elem2 > elem1) return 1;
	return 0;
}
/* 分配面板*/
public Action:MenuFunc_Xsbz(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();

	Format(line, sizeof(line), "AnneHappy");			
	SetPanelTitle(menu, line);
    
	Format(line, sizeof(line), "技能商店");
	DrawPanelItem(menu, line);
	
	Format(line, sizeof(line), "技能商店");
	DrawPanelItem(menu, line);
	
	Format(line, sizeof(line), "个人信息");
	DrawPanelItem(menu, line);
	
	Format(line, sizeof(line), "关闭菜单");
	DrawPanelItem(menu, line);
	SendPanelToClient(menu, Client, MenuHandler_Xsbz, MENU_TIME_FOREVER);
}

public MenuHandler_Xsbz(Handle:menu, MenuAction:action, Client, param)//基础菜单	
{
	if (action == MenuAction_Select) 
	{
		switch (param)
		{
			case 1: MenuFunc_AddStatus(Client);
			case 2: MenuFunc_AddStatus(Client);
			case 3: MenuFunc_tongji(Client);
		}
	}
}
/* 属性点菜单 */
public Action:MenuFunc_AddStatus(Client)
{
	new Handle:menu = CreatePanel();
	decl String:line[256];
	Format(line, sizeof(line), "B数: %d", player_data[Client][CASH]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "尽梨了 (%d/%d) 每级300点B数", player_data[Client][Str], Limit_Str);
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "技能满级后出门时给予一把小刀");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "莓良心 (%d/∞) 每级1000点B数", player_data[Client][Endurance]);
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "技能30级时附加杀特回血效果");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "重置技能  免费(返还百分之95)");
	DrawPanelItem(menu, line);
	DrawPanelItem(menu, "Exit", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddStatus, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddStatus(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		switch(param)
			{
				case 1:	AddStrength(Client, 0);
				case 2:	AddEndurance(Client, 0);
				case 3:	ResetBshu(Client, 0);
			}
		MenuFunc_AddStatus(Client);
	}
}

public Action:MenuFunc_tongji(Client)
{ 
	new Handle:menu = CreatePanel();
	decl String:line[256];
	
	Format(line, sizeof(line), "%N\n等级Lv.%d \n经验值:%d/%d \nB数:%d", Client, player_data[Client][LV], player_data[Client][EXP], GetConVarInt(LvUpExpRate),player_data[Client][CASH]);
	SetPanelTitle(menu, line);	
	Format(line, sizeof(line), "刷新");  
	DrawPanelItem(menu, line);
	
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
    
	SendPanelToClient(menu, Client, MenuHandler_tongji, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_tongji(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select)
	{
		switch (param)
		{
			case 1: MenuFunc_tongji(Client);
		}
	}
}
/*-----------------------------------------方法区--------------------------------------------------*/
//给武器
stock BypassAndExecuteCommand(client, String: strCommand[], String: strParam1[])
{
	new flags = GetCommandFlags(strCommand);
	SetCommandFlags(strCommand, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", strCommand, strParam1);
	SetCommandFlags(strCommand, flags);
}

//这是主界面

public CharMenu(Handle:menu, MenuAction:action, param1, param2) 
{
	switch (action) 
	{
		case MenuAction_Select: 
		{
			decl String:item[8];
			GetMenuItem(menu, param2, item, sizeof(item));
			
			switch(StringToInt(item)) 
			{
				case ARMS:		{	ShowTypeMenu(param1,ARMS);	}
				case PROPS:		{	ShowTypeMenu(param1,PROPS);	}
			}
		}
		case MenuAction_Cancel:
		{
			
		}
		case MenuAction_End: 
		{
			CloseHandle(menu);
		}
	}
}

public Action:ShowMenu(Client)
{	
	decl String:sMenuEntry[8];
	new Handle:menu = CreateMenu(CharMenu);
	SetMenuTitle(menu, "B数:%i",player_data[Client][CASH]);
	IntToString(ARMS, sMenuEntry, sizeof(sMenuEntry));
	AddMenuItem(menu, sMenuEntry, "购买枪械");
	IntToString(PROPS, sMenuEntry, sizeof(sMenuEntry));
	AddMenuItem(menu, sMenuEntry, "购买补给");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);
}

//这是购买武器

public CharArmsMenu(Handle:menu, MenuAction:action, param1, param2) 
{
	switch (action) 
	{
		case MenuAction_Select: 
		{
			decl String:item[8];
			GetMenuItem(menu, param2, item, sizeof(item));
			
			switch(StringToInt(item)) 
			{
				case PISTOL:
				{
					new money = GetConVarInt(pistolmoney);
					if(player_data[param1][CASH] < money){ PrintToChat(param1,"\x03你自己心里没有点B数吗?");}
					else{BypassAndExecuteCommand(param1, "give", "knife");player_data[param1][CASH] -= money;PrintToChatAll("\x04%N\x03花了%i点B数购买了近战小刀",param1,money);}
				}
				case MAGNUM:	
				{	
					new money = GetConVarInt(magnummoney);
					if(player_data[param1][CASH] < money){ PrintToChat(param1,"\x03你自己心里没有点B数吗?");} 
					else{BypassAndExecuteCommand(param1, "give", "pistol_magnum");player_data[param1][CASH] -= money;PrintToChatAll("\x04%N\x03花了%i点B数购买了马格南手枪",param1,money);}
				}
				case SMG:	
				{	
					new money = GetConVarInt(smgmoney);
					if(player_data[param1][CASH] < money){ PrintToChat(param1,"\x03你自己心里没有点B数吗?");} 
					else{BypassAndExecuteCommand(param1, "give", "smg");player_data[param1][CASH] -= money;PrintToChatAll("\x04%N\x03花了%i点B数购买了UZI冲锋枪",param1,money);}
				}
				case SMGSILENCED:	
				{	
					new money = GetConVarInt(smgsilencedmoney);
					if(player_data[param1][CASH] < money){ PrintToChat(param1,"\x03你自己心里没有点B数吗?");} 
					else{BypassAndExecuteCommand(param1, "give", "smg_silenced");player_data[param1][CASH] -= money;PrintToChatAll("\x04%N\x03花了%i点B数购买了SMG冲锋枪",param1,money);}
				}
				case PUMPSHOTGUN1:
				{
					new money = GetConVarInt(pumpshotgun1money);
					if(player_data[param1][CASH] < money){ PrintToChat(param1,"\x03你自己心里没有点B数吗?");} 
					else{BypassAndExecuteCommand(param1, "give", "pumpshotgun");player_data[param1][CASH] -= money;PrintToChatAll("\x04%N\x03花了%i点B数购买了一代单发霰弹枪",param1,money);}
				}
				case PUMPSHOTGUN2:
				{
					new money = GetConVarInt(pumpshotgun2money);
					if(player_data[param1][CASH] < money){ PrintToChat(param1,"\x03你自己心里没有点B数吗?");} 
					else{BypassAndExecuteCommand(param1, "give", "shotgun_chrome");player_data[param1][CASH] -= money;PrintToChatAll("\x04%N\x03花了%i点B数购买了二代单发霰弹枪",param1,money);}
				}
				case AUTOSHOTGUN1:
				{
					new money = GetConVarInt(autoshotgun1money);
					if(player_data[param1][CASH] < money){ PrintToChat(param1,"\x03你自己心里没有点B数吗?");} 
					else{BypassAndExecuteCommand(param1, "give", "autoshotgun");player_data[param1][CASH] -= money;PrintToChatAll("\x04%N\x03花了%i点B数购买了一代连发霰弹枪",param1,money);}
				}
				case AUTOSHOTGUN2:
				{
					new money = GetConVarInt(autoshotgun2money);
					if(player_data[param1][CASH] < money){ PrintToChat(param1,"\x03你自己心里没有点B数吗?");} 
					else{BypassAndExecuteCommand(param1, "give", "shotgun_spas");player_data[param1][CASH] -= money;PrintToChatAll("\x04%N\x03花了%i点B数购买了二代连发霰弹枪",param1,money);}
				}
				case HUNTING1:
				{
					new money = GetConVarInt(hunting1money);
					if(player_data[param1][CASH] < money){ PrintToChat(param1,"\x03你自己心里没有点B数吗?");} 
					else{BypassAndExecuteCommand(param1, "give", "hunting_rifle");player_data[param1][CASH] -= money;PrintToChatAll("\x04%N\x03花了%i点B数购买了一代狙击枪",param1,money);}
				}
				case HUNTING2:
				{
					new money = GetConVarInt(hunting2money);
					if(player_data[param1][CASH] < money){ PrintToChat(param1,"\x03你自己心里没有点B数吗?");} 
					else{BypassAndExecuteCommand(param1, "give", "sniper_military");player_data[param1][CASH] -= money;PrintToChatAll("\x04%N\x03花了%i点B数购买了二代狙击枪",param1,money);}
				}
				
				case M16:
				{
					new money = GetConVarInt(m16money);
					if(player_data[param1][CASH] < money){ PrintToChat(param1,"\x03你自己心里没有点B数吗?");} 
					else{BypassAndExecuteCommand(param1, "give", "rifle");player_data[param1][CASH] -= money;PrintToChatAll("\x04%N\x03花了%i点B数购买了M16步枪",param1,money);}
				}
				case AK47:
				{
					new money = GetConVarInt(ak47money);
					if(player_data[param1][CASH] < money){ PrintToChat(param1,"\x03你自己心里没有点B数吗?");} 
					else{BypassAndExecuteCommand(param1, "give", "rifle_ak47");player_data[param1][CASH] -= money;PrintToChatAll("\x04%N\x03花了%i点B数购买了AK47步枪",param1,money);}
				}
				case SCAR:
				{
					new money = GetConVarInt(scarmoney);
					if(player_data[param1][CASH] < money){ PrintToChat(param1,"\x03你自己心里没有点B数吗?");} 
					else{BypassAndExecuteCommand(param1, "give", "rifle_desert");player_data[param1][CASH] -= money;PrintToChatAll("\x04%N\x03花了%i点B数购买了SCAR步枪",param1,money);}
				}
				
				case ADRENALINE:
				{
					new money = GetConVarInt(adrenalinemoney);
					if(player_data[param1][CASH] < money){ PrintToChat(param1,"\x03你自己心里没有点B数吗?");} 
					else{BypassAndExecuteCommand(param1, "give", "adrenaline");player_data[param1][CASH] -= money;PrintToChatAll("\x04%N\x03花了%i点B数购买了肾上腺素",param1,money);}
				}
				case PAINPILLS:
				{
					new money = GetConVarInt(painpillsmoney);
					if(player_data[param1][CASH] < money){ PrintToChat(param1,"\x03你自己心里没有点B数吗?");} 
					else{BypassAndExecuteCommand(param1, "give", "pain_pills");player_data[param1][CASH] -= money;PrintToChatAll("\x04%N\x03花了%i点B数购买了止痛药",param1,money);}
				}
				case FIRSTAIDKIT:
				{
					new money = GetConVarInt(firstaidkitmoney);
					if(player_data[param1][CASH] < money){ PrintToChat(param1,"\x03你自己心里没有点B数吗?");} 
					else{BypassAndExecuteCommand(param1, "give", "first_aid_kit");player_data[param1][CASH] -= money;PrintToChatAll("\x04%N\x03花了%i点B数购买了急救包",param1,money);}
				}
				case GASCAN:
				{
					new money = GetConVarInt(gascanmoney);
					if(player_data[param1][CASH] < money){ PrintToChat(param1,"\x03你自己心里没有点B数吗?");} 
					else{BypassAndExecuteCommand(param1, "give", "gascan");player_data[param1][CASH] -= money;PrintToChatAll("\x04%N\x03花了%i点B数购买了油桶",param1,money);}
				}
			}
		}
		case MenuAction_Cancel:
		{
			
		}
		case MenuAction_End: 
		
		{
			CloseHandle(menu);
		}
	}
}

public ShowTypeMenu(Client,type)
{	
	decl String:sMenuEntry[8];
	new String:money[64];
	new Handle:menu = CreateMenu(CharArmsMenu);
	switch(type)
	{
		case ARMS:
		{
			SetMenuTitle(menu, "B数:%i",player_data[Client][CASH]);
			
			Format(money,sizeof(money),"近战小刀(%d点B数)",GetConVarInt(pistolmoney));
			IntToString(PISTOL, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
					
			Format(money,sizeof(money),"马格南手枪(%d点B数)",GetConVarInt(magnummoney));
			IntToString(MAGNUM, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
				
			Format(money,sizeof(money),"UZI冲锋枪(%d点B数)",GetConVarInt(smgmoney));
			IntToString(SMG, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
					
			Format(money,sizeof(money),"SMG冲锋枪(%d点B数)",GetConVarInt(smgsilencedmoney));
			IntToString(SMGSILENCED, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
					
			Format(money,sizeof(money),"一代单发霰弹枪(%d点B数)",GetConVarInt(pumpshotgun1money));
			IntToString(PUMPSHOTGUN1, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
					
			Format(money,sizeof(money),"二代单发霰弹枪(%d点B数)",GetConVarInt(pumpshotgun2money));
			IntToString(PUMPSHOTGUN2, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
					
			Format(money,sizeof(money),"一代连发霰弹枪(%d点B数)",GetConVarInt(autoshotgun1money));
			IntToString(AUTOSHOTGUN1, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
					
			Format(money,sizeof(money),"二代连发霰弹枪(%d点B数)",GetConVarInt(autoshotgun2money));
			IntToString(AUTOSHOTGUN2, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
					
			Format(money,sizeof(money),"一代狙击枪(%d点B数)",GetConVarInt(hunting1money));
			IntToString(HUNTING1, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
					
			Format(money,sizeof(money),"二代狙击枪(%d点B数)",GetConVarInt(hunting2money));
			IntToString(HUNTING2, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
			
			Format(money,sizeof(money),"M16步枪(%d点B数)",GetConVarInt(m16money));
			IntToString(M16, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
			
			Format(money,sizeof(money),"AK47步枪(%d点B数)",GetConVarInt(ak47money));
			IntToString(AK47, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
			
			Format(money,sizeof(money),"SCAR步枪(%d点B数)",GetConVarInt(scarmoney));
			IntToString(SCAR, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
			
		}
		
		case PROPS:
		{
			SetMenuTitle(menu, "B数:%i",player_data[Client][CASH]);
			
			Format(money,sizeof(money),"肾上腺素(%d点B数)",GetConVarInt(adrenalinemoney));
			IntToString(ADRENALINE, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
			
			Format(money,sizeof(money),"止痛药(%d点B数)",GetConVarInt(painpillsmoney));
			IntToString(PAINPILLS, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
			
			Format(money,sizeof(money),"医疗包(%d点B数)",GetConVarInt(firstaidkitmoney));
			IntToString(FIRSTAIDKIT, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
			
			Format(money,sizeof(money),"油桶(%d点B数)",GetConVarInt(gascanmoney));
			IntToString(GASCAN, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);

		}
		
	}
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);
}



stock GetSurvivorPermHealth(client)
{
	return GetEntProp(client, Prop_Send, "m_iHealth");
}

stock SetSurvivorPermHealth(client, health)
{
	SetEntProp(client, Prop_Send, "m_iHealth", health);
}

stock Float:GetSurvivorTempHealth(client)
{
	new Float:tmp = GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(pain_pills_decay_rate));
	return tmp > 0 ? tmp : 0.0;
}

stock SetSurvivorTempHealth(client, Float:newOverheal)
{
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", newOverheal);
}

stock bool:IsPlayerIncap(client)
{
	return bool:GetEntProp(client, Prop_Send, "m_isIncapacitated");
}

bool Update_DATA(client,bool:IsDisconnect=false,bool:IsMapStart=false) 
{
	decl String:id[40];
	new String:error[256];
	new String:NAMES[256];
	GetClientName(client,NAMES,sizeof(NAMES));
	GetClientAuthId(client,AuthId_Steam2,id,sizeof(id));
	if ((StrEqual(id, "BOT"))) return false;
	// kill,
	// hurt,
	// time,
	// res
	// steam_id steam_name KILL_DATA hurt_DATA time_DATA res_DATA

	new Database:db = SQL_DefConnect(error, sizeof(error));
	if (db == null) {
		PrintToServer("【严重错误】:无法连接到MySQL数据库，错误信息：%s", error);
		CPrintToChatAll("{red}【严重错误】:无法连接到MySQL数据库，错误信息：%s", error);
		return false;
	}
	if(!SQL_FastQuery(db, "SET NAMES 'UTF8'"))
	{
		if(SQL_GetError(db,error,sizeof(error)))
			CPrintToChatAll("{red}【严重错误】:无法更改为UTF-8编码，错误信息：%s", error);
		else
			CPrintToChatAll("{red}【严重错误】:无法更改为UTF-8编码，错误信息：未知");
	}	
	if(IsMapStart)
	{
		SQL_FastQuery(db, "update l4d2 l set l.STATUS=0");	
	}	
	DBStatement hAddQuery;
	if(IsDisconnect){
		if ((hAddQuery = SQL_PrepareQuery(db, Update_Disconnect, error, sizeof(error))) == null)
		{
			PrintToServer("SQL_PrepareQuery出现错误");
			//delete db;
			return false;
		}
	}else{
		if ((hAddQuery = SQL_PrepareQuery(db, Update, error, sizeof(error))) == null)
		{
			PrintToServer("SQL_PrepareQuery出现错误");
			//delete db;
			return false;
		}
	}
	//下面是参数绑定
	//行数sizeof(args)/sizeof(args[0])
	//SQL_BindParamInt
	SQL_BindParamString(hAddQuery,0,NAMES,true);
	SQL_BindParamInt(hAddQuery,1,player_data[client][LV]);
	SQL_BindParamInt(hAddQuery,2,player_data[client][EXP]);
	SQL_BindParamInt(hAddQuery,3,player_data[client][Str]);
	SQL_BindParamInt(hAddQuery,4,player_data[client][Endurance]);
	SQL_BindParamInt(hAddQuery,5,player_data[client][Intelligence]);
	if(IsDisconnect)
	{
		SQL_BindParamInt(hAddQuery,6,player_data[client][CASH]);
		SQL_BindParamString(hAddQuery,7,id,true);
	}
	else
	{
		SQL_BindParamInt(hAddQuery,6,player_data[client][CASH]);
		SQL_BindParamString(hAddQuery,7,id,true);
	}
	if (!SQL_Execute(hAddQuery))
	{
		PrintToServer("SQL_Execute出现错误");
		if(SQL_GetError(db,error,sizeof(error)))
			CPrintToChatAll("{red}【严重错误】:无法提交信息，错误信息：%s", error);
		else
			CPrintToChatAll("{red}【严重错误】:无法提交信息，错误信息：未知");		
	}
	db.Close();
	return true; 
}
public bool MYSQL_INIT(client,String:id[])
{
//全插件只有这个地方是查询
	new String:error[256];
	new String:NAMES[256];
	ArrayList array=CreateArray(40,1);
	//if(GetClientTime(client)>0.0) return true; //已经在游戏则不用查询了
	new Database:db = SQL_DefConnect(error, sizeof(error));
	if (db == null) {
		PrintToServer("【严重错误】:无法连接到MySQL数据库，错误信息：%s", error);
		CPrintToChatAll("{red}【严重错误】:无法连接到MySQL数据库，错误信息：%s", error);
		return false;
	}
	DBStatement hAddQuery;
	if ((hAddQuery = SQL_PrepareQuery(db, Select, error, sizeof(error))) == null)
	{
		PrintToServer("SQL_PrepareQuery出现错误%s",error);
		CPrintToChatAll("SQL_PrepareQuery出现错误%s",error);
		delete db;
		return false;
	}
	//下面是参数绑定
	//行数sizeof(args)/sizeof(args[0])
	SQL_BindParamString(hAddQuery,0,id,true);
	if (!SQL_Execute(hAddQuery))
	{
		PrintToServer("SQL_Execute出现错误");
	}
	if(!SQL_FetchRow(hAddQuery))
	{
		CPrintToChat(client,"{red}[注意]:您初次登录本服务器，即将为您初始化数据");
	// enum data
	// {
	// kill,
	// hurt,
	// time,
	// res
	// };
		CloseHandle(hAddQuery);
		db.Close();
		player_data[client][LV]=0;
		player_data[client][EXP]=0;
		player_data[client][Str]=0;
		player_data[client][Endurance]=0;
		player_data[client][Intelligence]=0;
		player_data[client][CASH]=0;
		GetClientName(client,NAMES,sizeof(NAMES));
		SetArrayString(array,0,id);
		ResizeArray(array,GetArraySize(array)+1);
		// 每增加一条数据都要进行ResizeArray(array,GetArraySize(array)+1)操作
		SetArrayString(array,1,NAMES);
		MySQLTransaction(Init,array);		
		return true;
	}else{
	//查询到数据了
	//SQL_FetchInt(hQuery, 1);
	//SQL_FetchString
	player_data[client][LV]=SQL_FetchInt(hAddQuery, 2);
	player_data[client][EXP]=SQL_FetchInt(hAddQuery, 3);
	player_data[client][Str]=SQL_FetchInt(hAddQuery, 4);
	player_data[client][Endurance]=SQL_FetchInt(hAddQuery, 5);
	player_data[client][Intelligence]=SQL_FetchInt(hAddQuery, 6);
	player_data[client][CASH]=SQL_FetchInt(hAddQuery, 7);
	}
	db.Close();
	return true;	
}
public bool MySQLTransaction(char[] query,ArrayList  array)
{
	
	new String:error[256];
	new String:buffer[256];
	new Database:db = SQL_DefConnect(error, sizeof(error));
	if (db == null) {
		PrintToServer("【严重错误】:无法连接到MySQL数据库，错误信息：%s", error);
		CPrintToChatAll("{red}【严重错误】:无法连接到MySQL数据库，错误信息：%s", error);
		return false;
	}
	if(!SQL_FastQuery(db, "SET NAMES 'UTF8'"))
	{
		if(SQL_GetError(db,error,sizeof(error)))
			CPrintToChatAll("{red}【严重错误】:无法更改为UTF-8编码，错误信息：%s", error);
		else
			CPrintToChatAll("{red}【严重错误】:无法更改为UTF-8编码，错误信息：未知");
	}	
	DBStatement hAddQuery;
	if ((hAddQuery = SQL_PrepareQuery(db, query, error, sizeof(error))) == null)
	{
		PrintToServer("SQL_PrepareQuery出现错误");
		delete db;
		return false;
	}
	//下面是参数绑定
	//行数sizeof(args)/sizeof(args[0])
	for(int i=0;i<GetArraySize(array);i++)
	{
		GetArrayString(array,i,buffer,sizeof(buffer));
		SQL_BindParamString(hAddQuery,i,buffer,true);
		//PrintToServer("位置%d绑定值为%s\n",i,buffer);
	}
	if (!SQL_Execute(hAddQuery))
	{
		PrintToServer("SQL_Execute出现错误");
		if(SQL_GetError(db,error,sizeof(error)))
			CPrintToChatAll("{red}【严重错误】:无法提交信息，错误信息：%s", error);
		else
			CPrintToChatAll("{red}【严重错误】:无法提交信息，错误信息：未知");		
	}
	db.Close();
	return true;
}
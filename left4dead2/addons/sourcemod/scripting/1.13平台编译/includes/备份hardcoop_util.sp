// Thanks to L4D2Util for many stock functions and enumerations

#pragma semicolon 1
#include <sourcemod>
#include <smlib>

#if defined HARDCOOP_UTIL_included
#endinput
#endif

#define HARDCOOP_UTIL_included

#define DEBUG_FLOW 0

#define TEAM_CLASS(%1) (%1 == ZC_SMOKER ? "smoker" : (%1 == ZC_BOOMER ? "boomer" : (%1 == ZC_HUNTER ? "hunter" :(%1 == ZC_SPITTER ? "spitter" : (%1 == ZC_JOCKEY ? "jockey" : (%1 == ZC_CHARGER ? "charger" : (%1 == ZC_WITCH ? "witch" : (%1 == ZC_TANK ? "tank" : "None"))))))))
#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))


#define VEL_MAX	450.0

// Velocity
enum VelocityOverride 
{
	VelocityOvr_None = 0,
	VelocityOvr_Velocity,
	VelocityOvr_OnlyWhenNegative,
	VelocityOvr_InvertReuseVelocity
};

enum L4D2_Team 
{
	L4D2Team_Spectator = 1,
	L4D2Team_Survivor,
	L4D2Team_Infected
};

enum L4D2_Infected 
{
	L4D2Infected_Smoker = 1,
	L4D2Infected_Boomer,
	L4D2Infected_Hunter,
	L4D2Infected_Spitter,
	L4D2Infected_Jockey,
	L4D2Infected_Charger,
	L4D2Infected_Witch,
	L4D2Infected_Tank
};

// alternative enumeration
// Special infected classes
enum ZombieClass 
{
	ZC_NONE = 0, 
	ZC_SMOKER, 
	ZC_BOOMER, 
	ZC_HUNTER, 
	ZC_SPITTER, 
	ZC_JOCKEY, 
	ZC_CHARGER, 
	ZC_WITCH, 
	ZC_TANK, 
	ZC_NOTINFECTED
};

// 0=Anywhere, 1=Behind, 2=IT, 3=Specials in front, 4=Specials anywhere, 5=Far Away, 6=Above
enum SpawnDirection 
{
	ANYWHERE = 0,
	BEHIND,
	IT,
	SPECIALS_IN_FRONT,
	SPECIALS_ANYWHERE,
	FAR_AWAY,
	ABOVE   
};

enum AimTarget
{
	AimTarget_Eye,
	AimTarget_Body,
	AimTarget_Chest
};

/***********************************************************************************************************************************************************************************

																  		SURVIVORS
																	
***********************************************************************************************************************************************************************************/

/**
 * Returns true if the player is currently on the survivor team. 
 *
 * @param client: client ID
 * @return bool
 */
stock bool IsSurvivor(int client) 
{
	return IsValidClient(client) && view_as<L4D2_Team>(GetClientTeam(client)) == L4D2Team_Survivor;
}

stock bool IsPinned(int client) 
{
	if(GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0)	   // charger pound
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0)		// charger carry
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0)	   // hunter
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0)	   //jockey
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0)		  //smoker
		return true;
	return false;
}

//true = 挂边, false = 未挂边
stock bool IsHanging(int client)
{
	return GetEntProp(client, Prop_Send, "m_isHangingFromLedge") != 0;
}

/**
 * Returns true if the player is incapacitated. 
 *
 * @param client client ID
 * @return bool
 */
stock bool IsIncapacitated(int client) 
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}


/**
 * @return: The highest %map completion held by a survivor at the current point in time
 */
stock int GetMaxSurvivorCompletion() 
{
	float flow = 0.0;
	float tmp_flow;
	float origin[3];
	static Address pNavArea;
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
		{
			GetClientAbsOrigin(client, origin);
			tmp_flow = GetFlow(origin);
			flow = MAX(flow, tmp_flow);
		}
	}
	
	int current = RoundToNearest(flow * 100 / L4D2Direct_GetMapMaxFlowDistance());
		
		#if DEBUG_FLOW
			Client_PrintToChatAll(true, "Current: {G}%d%%", current);
		#endif
		
	return current;
}

/**
 * @return: the farthest flow distance currently held by a survivor
 */
stock float GetFarthestSurvivorFlow() 
{
	float farthest_flow = 0.0;
	float origin[3];
	float flow;
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client)) 
		{
			GetClientAbsOrigin(client, origin);
			flow = GetFlow(origin);
			if(flow > farthest_flow) 
				farthest_flow = flow;
		}
	}
	return farthestFlow;
}

/**
 * Returns the average flow distance covered by each survivor
 */
stock float GetAverageSurvivorFlow() 
{
	int survivor_count;
	float total_flow;
	float origin[3];
	float client_flow;
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client)) 
		{
			survivor_count++;
			GetClientAbsOrigin(client, origin);
			client_flow = GetFlow(origin);
			if(GetFlow(origin) != -1.0) 
				total_flow++;
		}
	}
	return FloatDiv(totalFlow, float(survivor_count));
}

/**
 * Returns the flow distance of a given point
 */
 stock float GetFlow(const float o[3]) 
 {
 	float origin[3]; //non constant var
 	origin[0] = o[0];
 	origin[1] = o[1];
 	origin[2] = o[2];

 	Address pNavArea = L4D2Direct_GetTerrorNavArea(origin);
 	if(pNavArea != Address_Null) 
 		return L4D2Direct_GetTerrorNavAreaFlow(pNavArea);

 	return 0.0;
}

/**
 * Finds the closest survivor excluding a given survivor 
 * @param referenceClient: compares survivor distances to this client
 * @param excludeSurvivor: ignores this survivor
 * @return: the entity index of the closest survivor
**/
stock int GetClosestSurvivor(float vPos[3], int excludeSurvivor = -1) 
{
	int[] targets = new int[MaxClients];
	static int numClients;
	numClients = 0;
	static int i;

	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !IsPinned(i) && i != excludeSurvivor)
			targets[numClients++] = i;
	}
	
	if(numClients == 0)
		return -1;

	static ArrayList aTargets;
	aTargets = new ArrayList(2);
	static float vTarg[3];
	static float dist;
	static int index;
	static int victim;
	
	for(i = 0; i < numClients; i++)
	{
		victim = targets[i];

		GetClientAbsOrigin(victim, vTarg);
		dist = GetVectorDistance(vPos, vTarg);
		index = aTargets.Push(dist);
		aTargets.Set(index, victim, 1);
	}
	
	// Sort by nearest
	if(aTargets.Length == 0)
	{
		delete aTargets;
		return -1;
	}
		
	SortADTArray(aTargets, Sort_Ascending, Sort_Float);
	
	victim = aTargets.Get(0, 1);
	delete aTargets;
	return victim;
}

stock int GetClosestActiveSurvivor(float vPos[3]) 
{
	int[] targets = new int[MaxClients];
	static int numClients;
	numClients = 0;
	static int i;

	for(i = 1; i <= MaxClients; i++) 
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !IsIncapacitated(i))
			targets[numClients++] = i;
	}
	
	if(numClients == 0)
		return -1;

	static ArrayList aTargets;
	aTargets = new ArrayList(2);
	static float vTarg[3];
	static float dist;
	static int index;
	static int victim;
	
	for(i = 0; i < numClients; i++)
	{
		victim = targets[i];

		GetClientAbsOrigin(victim, vTarg);
		dist = GetVectorDistance(vPos, vTarg);
		index = aTargets.Push(dist);
		aTargets.Set(index, victim, 1);
	}
	
	// Sort by nearest
	if(aTargets.Length == 0)
	{
		delete aTargets;
		return -1;
	}
		
	SortADTArray(aTargets, Sort_Ascending, Sort_Float);
	
	victim = aTargets.Get(0, 1);
	delete aTargets;
	return victim;
}

/**
 * Returns the distance of the closest survivor or a specified survivor
 * @param referenceClient: the client from which to measure distance to survivor
 * @param specificSurvivor: the index of the survivor to be measured, -1 to search for distance to closest survivor
 * @return: the distance
 */
stock int GetSurvivorProximity(const float rp[3], int specificSurvivor = -1) 
{
	static int targetSurvivor;
	static float targetSurvivorPos[3];
	static float referencePos[3]; // non constant var
	referencePos[0] = rp[0];
	referencePos[1] = rp[1];
	referencePos[2] = rp[2];
	

	if(IsSurvivor(specificSurvivor)) 
		targetSurvivor = specificSurvivor; // specified survivor	
	else 	
		targetSurvivor = GetClosestSurvivor(referencePos); // closest survivor	

	if(targetSurvivor == -1)
		return -1;

	GetEntPropVector(targetSurvivor, Prop_Send, "m_vecOrigin", targetSurvivorPos);
	return RoundToNearest(GetVectorDistance(referencePos, targetSurvivorPos));
}

/** @return: the index to a random survivor */
/***********************************************************************************************************************************************************************************

																   	SPECIAL INFECTED 
																	
***********************************************************************************************************************************************************************************/

/**
 * @return: the special infected class of the client
 */
stock L4D2_Infected GetInfectedClass(int client) 
{
	return view_as<L4D2_Infected>(GetEntProp(client, Prop_Send, "m_zombieClass"));
}

/**
 * @return: true if client is a special infected bot
 */
stock bool IsBotInfected(int client) 
{
	return IsValidClient(client) && view_as<L4D2_Team>(GetClientTeam(client)) == L4D2Team_Infected && IsFakeClient(client);
}

stock bool IsBotBoomer(int client) 
{
	return IsBotInfected(client) && GetInfectedClass(client) == L4D2Infected_Boomer;
}

stock bool IsBotHunter(int client) 
{
	return IsBotInfected(client) && GetInfectedClass(client) == L4D2Infected_Hunter;
}

stock bool IsBotJockey(int client) 
{
	return IsBotInfected(client) && GetInfectedClass(client) == L4D2Infected_Jockey;
}

stock bool IsBotCharger(int client) 
{
	return IsBotInfected(client) && GetInfectedClass(client) == L4D2Infected_Charger;
}

// @return: the number of a particular special infected class alive in the game
stock int CountSpecialInfectedClass(ZombieClass targetClass) 
{
	int count;
	int playerClass;
	for(int i = 1; i <= MaxClients; i++) 
	{
		if(IsClientInGame(i) && view_as<L4D2_Team>(GetClientTeam(i)) == L4D2Team_Infected && IsFakeClient(i) && IsPlayerAlive(i) && !IsClientInKickQueue(i)) 
		{
			playerClass = GetEntProp(i, Prop_Send, "m_zombieClass");
			if(playerClass == view_as<int>(targetClass)) 
				count++;
		}
	}
	return count;
}

// @return: the total special infected bots alive in the game
stock int CountSpecialInfectedBots() 
{
	int count;
	for(int i = 1; i <= MaxClients; i++) 
	{
		if(IsClientInGame(i) && view_as<L4D2_Team>(GetClientTeam(i)) == L4D2Team_Infected && IsFakeClient(i) && IsPlayerAlive(i)) 
			count++;
	}
	return count;
}

/***********************************************************************************************************************************************************************************

																	   		TANK
																	
***********************************************************************************************************************************************************************************/

/**
 *@return: true if client is a tank
 */
stock bool IsTank(int client) 
{
	return IsClientInGame(client) && view_as<L4D2_Team>(GetClientTeam(client)) == L4D2Team_Infected && GetInfectedClass(client) == L4D2Infected_Tank;
}

/**
 * Searches for a player who is in control of a tank.
 *
 * @param iTankClient client index to begin searching from
 * @return client ID or -1 if not found
 */
stock int FindTankClient(int iTankClient) 
{
	for(int i = iTankClient < 0 ? 1 : iTankClient + 1; i <= MaxClients; i++) 
	{
		if(IsTank(i)) 
			return i;
	}

	return -1;
}

/**
 * Is there a tank currently in play?
 *
 * @return bool
 */
stock bool IsTankInPlay() 
{
	return view_as<bool>(FindTankClient(-1) != -1);
}

stock bool IsBotTank(int client) 
{
	// Check the input is valid
	if(!IsValidClient(client)) return false;
	// Check if player is on the infected team, a hunter, and a bot
	if(view_as<L4D2_Team>(GetClientTeam(client)) == L4D2Team_Infected) 
	{
		L4D2_Infected zombieClass = view_as<L4D2_Infected>(GetEntProp(client, Prop_Send, "m_zombieClass"));
		if(zombieClass == L4D2Infected_Tank) 
		{
			if(IsFakeClient(client)) 
				return true;
		}
	}
	return false; // otherwise
}

/***********************************************************************************************************************************************************************************

																   			MISC
																	
***********************************************************************************************************************************************************************************/

/**
 * Executes a cheat command through a dummy client
 *
 * @param command: The command to execute
 * @param argument1: Optional argument for command
 * @param argument2: Optional argument for command
 * @param dummyName: The name to use for the dummy client 
 *
**/
stock void CheatCommand(const char[] sCommand, const char[] argument1 = "", const char[] argument2 = "") 
{
	if(GetCommandFlags(sCommand) != INVALID_FCVAR_FLAGS) 
	{
		bool temp = false;
		int DummyBot = GetAnyValidClient();
		if(DummyBot == -1) 
		{
			DummyBot = CreateFakeClient("DummyBot");
			if(DummyBot > 0)
				temp = true;
		}

		// Execute command
		if(DummyBot > 0) 
		{
			int bits = GetUserFlagBits(DummyBot);			
			SetUserFlagBits(DummyBot, ADMFLAG_ROOT);
			int flags = GetCommandFlags(sCommand);
			SetCommandFlags(sCommand, flags & ~FCVAR_CHEAT);			   
			FakeClientCommand(DummyBot, "%s %s %s", sCommand, argument1, argument2);
			SetCommandFlags(sCommand, flags);
			SetUserFlagBits(DummyBot, bits);	
			if(temp) 
				KickClient(DummyBot);
		} 
		else 
		{
			char pluginName[128];
			GetPluginFilename(INVALID_HANDLE, pluginName, sizeof(pluginName));		
			LogError("%s could not find or create a client through which to execute cheat command %s", pluginName, sCommand);
		}
	}
}

stock int GetAnyValidClient() 
{
	for(int i = 1; i <= MaxClients; i++) 
	{
		if(IsClientInGame(i)) 
			return i;
	}
	return -1;
}

// Sets the spawn direction for SI, relative to the survivors
// Yet to test whether map specific scripts override this option, and if so, how to rewrite this script line
stock void SetSpawnDirection(SpawnDirection direction) 
{
	L4D2_RunScript("g_ModeScript.DirectorOptions.PreferredSpecialDirection <- %i", view_as<int>(direction));   
}
/*
stock void L4D2_RunScript(const char[] sCode, any ...)
{
	static int iScriptLogic = INVALID_ENT_REFERENCE;
	if(!IsValidEnt(EntRefToEntIndex(iScriptLogic))) 
		iScriptLogic = EntIndexToEntRef(FindEntityByClassname(MaxClients + 1, "info_director"));	
	
	if(!IsValidEnt(EntRefToEntIndex(iScriptLogic)))
	{
		iScriptLogic = EntIndexToEntRef(CreateEntityByName("logic_script"));
		if(!IsValidEnt(EntRefToEntIndex(iScriptLogic)))
			SetFailState("Could not create 'logic_script'");
		
		DispatchSpawn(iScriptLogic);
	}
	char sBuffer[512];
	VFormat(sBuffer, sizeof(sBuffer), sCode, 2);
	SetVariantString(sBuffer);
	AcceptEntityInput(iScriptLogic, "RunScriptCode");
}

stock bool IsValidEnt(int entity)
{
	return entity > MaxClients && IsValidEntity(entity) && entity != INVALID_ENT_REFERENCE;
}
*/
stock void L4D2_RunScript(const char[] sCode, any ...) 
{
	static int iScriptLogic = INVALID_ENT_REFERENCE;
	if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic)) 
	{
		iScriptLogic = EntIndexToEntRef(CreateEntityByName("logic_script"));
		if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic)) 
			SetFailState("Could not create 'logic_script'");

		DispatchSpawn(iScriptLogic);
	}

	char sBuffer[512];
	VFormat(sBuffer, sizeof(sBuffer), sCode, 2);
	SetVariantString(sBuffer);
	AcceptEntityInput(iScriptLogic, "RunScriptCode");
}

stock bool IsValidClient(int client) 
{
	return client > 0 && client <= MaxClients && IsClientInGame(client); 
}

stock bool IsGenericAdmin(int client) 
{
	return CheckCommandAccess(client, "", ADMFLAG_GENERIC); 
}

// Kick dummy bot 
public Action Timer_KickBot(Handle timer, any client) 
{
	if(IsClientInGame(client) && !IsClientInKickQueue(client) && IsFakeClient(client) && !IsPlayerAlive(client)) 
		KickClient(client);
}

// clientの一番近くにいる生存者の距離を取得
//
// 今はトレースしていないので1階と2階とか隣の部屋とか
// 遮るものがあっても近くになってしまう
stock float NearestSurvivorDistance(int client)
{
	float[] dists = new float[MaxClients];
	static int numClients;
	numClients = 0;
	static int i;
	float dist;
	static float self[3];

	GetClientAbsOrigin(client, self);

	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i)) 
		{
			static float target[3];
			GetClientAbsOrigin(i, target);

			dist = GetVectorDistance(self, target);
			dists[numClients++] = dist;
		}
	}

	SortFloats(dists, numClients, Sort_Ascending);
	return dists[0];
}

stock float NearestActiveSurvivorDistance(int client)
{
	float[] dists = new float[MaxClients];
	static int numClients;
	numClients = 0;
	static int i;
	float dist;
	static float self[3];

	GetClientAbsOrigin(client, self);

	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !IsIncapacitated(i))
		{
			static float target[3];
			GetClientAbsOrigin(i, target);

			dist = GetVectorDistance(self, target);
			dists[numClients++] = dist;
		}
	}

	SortFloats(dists, numClients, Sort_Ascending);
	return dists[0];
}

// clientから見える範囲で一番近い生存者を取得
stock float NearestVisibleDistance(int client)
{
	static float vPos[3];
	int targets[MAXPLAYERS+1];
	static int numClients;
	numClients = 0;
	static int i;
	
	GetClientEyePosition(attacker, vPos);
	
	numClients = GetClientsInRange(vPos, RangeType_Visibility, targets, MAXPLAYERS);

	if(numClients == 0)
		return -1.0;

	float[] dists = new float[MaxClients];
	static int counts;
	counts = 0;
	static float vTarg[3];
	float dist;
	int victim;
	
	for(i = 0; i < numClients; i++)
	{
		victim = targets[i];
		if(victim && GetClientTeam(victim) == 2 && IsPlayerAlive(victim))
		{
			GetClientAbsOrigin(victim, vTarg);
			dist = GetVectorDistance(vPos, vTarg);
			dists[counts++] = dist;
		}
	}

	SortFloats(dists, counts, Sort_Ascending);
	return dists[0];
}

// clientから見える範囲で一番近い生存者を取得
stock int NearestVisibleSurvivor(int client)
{
	static float vPos[3];
	int targets[MAXPLAYERS+1];
	static int numClients;
	numClients = 0;
	static int i;
	
	GetClientEyePosition(client, vPos);
	
	numClients = GetClientsInRange(vPos, RangeType_Visibility, targets, MAXPLAYERS);

	if(numClients == 0)
		return -1;

	static ArrayList aTargets;
	aTargets = new ArrayList(2);
	static float vTarg[3];
	static float dist;
	static int index;
	static int victim;
	
	for(i = 0; i < numClients; i++)
	{
		victim = targets[i];
		if(victim && GetClientTeam(victim) == 2 && IsPlayerAlive(victim) && !IsPinned(victim) && !IsIncapacitated(victim))
		{
			GetClientAbsOrigin(victim, vTarg);
			dist = GetVectorDistance(vPos, vTarg);
			index = aTargets.Push(dist);
			aTargets.Set(index, victim, 1);
		}
	}

	// Sort by nearest
	if(aTargets.Length == 0)
	{
		delete aTargets;
		return -1;
	}
	
	SortADTArray(aTargets, Sort_Ascending, Sort_Float);
	
	victim = aTargets.Get(0, 1);
	delete aTargets;
	return victim;
}

// ゴーストか
stock bool IsGhost(int i)
{
	return view_as<bool>(GetEntProp(i, Prop_Send, "m_isGhost"));
}
// 特殊感染者ボットか
stock bool IsSpecialInfectedBot(int i)
{
	return i > 0 && i <= MaxClients && IsClientInGame(i) && GetClientTeam(i) == 3 && IsFakeClient(i);
}
// 感染者の種類を取得
stock int GetZombieClass(int client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass");
}

/**
 * キー入力処理内でビジーループと状態維持に使っている変数
 *
 * 死んだときにクリアしないと前の情報が残ってるけど
 * あまり気にならないような作りにしてる
 */
// 1 client 8delayを持っとく
float g_fDelay[MAXPLAYERS + 1][8];
stock void DelayStart(int client, int no)
{
	g_fDelay[client][no] = GetGameTime();
}

stock bool DelayExpired(int client, int no, float delay)
{
	return GetGameTime() - g_fDelay[client][no] > delay;
}
// 1 player 8state を持っとく
int g_iState[MAXPLAYERS + 1][8];
stock void SetState(int client, int no, int value)
{
	g_iState[client][no] = value;
}

stock int GetState(int client, int no)
{
	return g_iState[client][no];
}

stock void InitStatus()
{
	float time = GetGameTime();
	for(int i; i < MAXPLAYERS + 1; ++i) 
	{
		for(int j; j < 8; ++j) 
		{
			g_fDelay[i][j] = time;
			g_iState[i][j] = 0;
		}
	}
}

// 特殊がメイン攻撃した時間
float g_fSiAttackTime;
stock float getSIAttackTime()
{
	return g_fSiAttackTime;
}

stock void UpdateSIAttackTime()
{
	g_fSiAttackTime = GetGameTime();
}

/**
 * TODO: 主攻撃の準備ができているか（リジャージ中じゃないか）調べたいけど
 *	   どうすればいいのか分からない
 */
stock bool ReadyAbility(int client)
{
	int ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");

	if(ability > 0 && IsValidEntity(ability)) 
	{
		float time = GetEntPropFloat(ability, Prop_Send, "m_timestamp");
		//int used = GetEntProp(ability, Prop_Send, "m_hasBeenUsed");
		//float duration = GetEntPropFloat(ability, Prop_Send, "m_duration");
		return time < GetGameTime();
	} 
	else 
	{
		// なぜかここにくることがある
	}
	return true;
}

/* clientからtargetの頭あたりが見えているか判定 MASK_SOLID*/
stock bool IsOldVisibleTo(int client, int target)
{
	static float angles[3];
	static float self_pos[3];

	GetClientEyePosition(client, self_pos);
	ComputeAimAngles(client, target, angles);
	
	static Handle trace;
	trace = TR_TraceRayFilterEx(self_pos, angles, MASK_SOLID, RayType_Infinite, TraceFilter_Old, client);

	static bool ret;
	ret = false;
	if(TR_DidHit(trace)) 
	{
		int hit = TR_GetEntityIndex(trace);
		if(hit == target) 
			ret = true;
	}
	delete trace;
	return ret;
}

stock bool TraceFilter_Old(int entity, int mask, any self)
{
	return entity != self;
}

stock bool TraceFilter(int impactEntity, int contentMask, any self) 
{
	if(impactEntity == self)
		return false;
	else
	{
		static char sClassName[11];
		GetEntityClassname(impactEntity, sClassName, sizeof(sClassName));
		if(strcmp(sClassName, "infected") == 0)
			return false;
		else if(strcmp(sClassName, "witch") == 0)
			return false;
		return true;
	}
}

stock bool IsVisibleTo(int Client, int Target)
{
	float position[3];
	GetClientAbsOrigin(Client, position);
	position[2] += 45.0;
	if(L4D2_IsVisibleToPlayer(Target, 2, 3, L4D_GetLastKnownArea(Client), position))
	{
		return true;
	}
	return false;
}

// clientからtargetへのアングルを計算
stock void ComputeAimAngles(int client, int target, float angles[3], AimTarget type = AimTarget_Eye)
{
	static float target_pos[3];
	static float self_pos[3];
	static float lookat[3];

	GetClientEyePosition(client, self_pos);
	switch(type) 
	{
		case AimTarget_Eye:
			GetClientEyePosition(target, target_pos);

		case AimTarget_Body:
			GetClientAbsOrigin(target, target_pos);

		case AimTarget_Chest:
		{
			GetClientAbsOrigin(target, target_pos);
			target_pos[2] += 45.0; // このくらい
		}
	}
	MakeVectorFromPoints(self_pos, target_pos, lookat);
	GetVectorAngles(lookat, angles);
}


stock void Client_Push(int client, float clientEyeAngle[3], float power, VelocityOverride override[3] = VelocityOvr_None) 
{
	static float forwardVector[3], newVel[3];
	
	GetAngleVectors(clientEyeAngle, forwardVector, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(forwardVector, forwardVector);
	ScaleVector(forwardVector, power);

	Entity_GetAbsVelocity(client, newVel);
	
	static int i;
	for(i = 0; i < 3; i++) 
	{
		switch(override[i]) 
		{
			case VelocityOvr_Velocity: 
			{
				newVel[i] = 0.0;
			}
			case VelocityOvr_OnlyWhenNegative: 
			{				
				if(newVel[i] < 0.0) 
					newVel[i] = 0.0;
			}
			case VelocityOvr_InvertReuseVelocity: 
			{				
				if(newVel[i] < 0.0) 
					newVel[i] *= -1.0;
			}
		}
		
		newVel[i] += forwardVector[i];
	}
	
	Entity_SetAbsVelocity(client, newVel);
}

//https://forums.alliedmods.net/showthread.php?p=1542365
stock void ResetInfectedAbility(int client, float time)
{
	int ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
	if(ability > 0)
	{
		SetEntPropFloat(ability, Prop_Send, "m_duration", time);
		SetEntPropFloat(ability, Prop_Send, "m_timestamp", GetGameTime() + time);
	}
}


// 牛连跳
bool Do_Bhop(int client, int &buttons, float vec[3])
{
	if (buttons & IN_FORWARD || buttons & IN_BACK || buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT)
	{
		if (ClientPush(client, vec))
		{
			return true;
		}
	}
	return false;
}
bool ClientPush(int client, float vec[3])
{
	float curvel[3] = {0.0};
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", curvel);
	AddVectors(curvel, vec, curvel);
	if (GetVectorLength(curvel) <= 250.0)
	{
		NormalizeVector(curvel, curvel);
		ScaleVector(curvel, 251.0);
	}
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, curvel);
	return true;
}
// 计算与目标之间的向量
float[] CalculateVel(float self_pos[3], float target_pos[3], float force)
{
	float vecbuffer[3] = {0.0};
	SubtractVectors(target_pos, self_pos, vecbuffer);
	NormalizeVector(vecbuffer, vecbuffer);
	ScaleVector(vecbuffer, force);
	return vecbuffer;
}

bool IsValidSurvivor(int client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2)
	{
		return true;
	}
	else
	{
		return false;
	}
}

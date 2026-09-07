#pragma semicolon 1

// ConVars
ConVar g_hSpitterTarget, g_hInstantKill;
// Ints
int g_iSpitterTarget;
// Bools
bool g_bInstantKill;
#define SpitterBoostForward 60.0 // Bhop
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define ZC_SPITTER 4
#define FL_JUMPING 65922

public void Spitter_OnModuleStart() 
{
	g_hSpitterTarget = CreateConVar("ai_SpitterTarget", "3", "Spitter的目标选择：1=默认目标选择，2=多人的地方优先，3=被扑，撞，拉者优先（无3则2）", FCVAR_NOTIFY, true, 1.0, true, 3.0);
	g_hInstantKill = CreateConVar("ai_SpitterInstantKill", "0", "Spitter吐完痰之后是否处死", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hSpitterTarget.AddChangeHook(SpitterConVarChanged_Cvars);
	g_hInstantKill.AddChangeHook(SpitterConVarChanged_Cvars);
	GetSpitterCvars();
}
public void Spitter_OnModuleEnd() 
{

}

void SpitterConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetSpitterCvars();
}

void GetSpitterCvars()
{
	g_iSpitterTarget = g_hSpitterTarget.IntValue;
	g_bInstantKill = g_hInstantKill.BoolValue;
}

public Action Spitter_OnPlayerRunCmd(int spitter, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon) 
{
	if (IsAiSpitter(spitter))
	{
		// 跳着吐痰
		if (buttons & IN_ATTACK)
		{
			buttons |= IN_JUMP;
			if (g_bInstantKill)
			{
				// 延迟10秒处死，防止无声痰
				CreateTimer(10.0, Timer_ForceSuicide, spitter);
			}
			return Plugin_Changed;
		}
		/*
		static float Velocity[3];
		GetEntPropVector(spitter, Prop_Data, "m_vecVelocity", Velocity);
		float currentspeed = SquareRoot(Pow(Velocity[0], 2.0) + Pow(Velocity[1], 2.0));

		float dist = NearestSurvivorDistance(spitter);
		if(dist < 1000.0 && currentspeed > 150.0) 
		{
			if(GetEntityFlags(spitter) & FL_ONGROUND)
			{
				static float clientEyeAngles[3];
				GetClientEyeAngles(spitter, clientEyeAngles);
				buttons |= IN_DUCK;
				buttons |= IN_JUMP;
				if(buttons & IN_FORWARD)
				{
					Client_Push(spitter, clientEyeAngles, SpitterBoostForward, view_as<VelocityOverride>({VelocityOvr_None, VelocityOvr_None, VelocityOvr_None}));
				}
					
				if(buttons & IN_BACK)
				{
					clientEyeAngles[1] += 180.0;
					Client_Push(spitter, clientEyeAngles, SpitterBoostForward, view_as<VelocityOverride>({VelocityOvr_None, VelocityOvr_None, VelocityOvr_None}));
				}
							
				if(buttons & IN_MOVELEFT) 
				{
					clientEyeAngles[1] += 90.0;
					Client_Push(spitter, clientEyeAngles, SpitterBoostForward, view_as<VelocityOverride>({VelocityOvr_None, VelocityOvr_None, VelocityOvr_None}));
				}
							
				if(buttons & IN_MOVERIGHT) 
				{
					clientEyeAngles[1] += -90.0;
					Client_Push(spitter, clientEyeAngles, SpitterBoostForward, view_as<VelocityOverride>({VelocityOvr_None, VelocityOvr_None, VelocityOvr_None}));
				}
			}

			if(GetEntityMoveType(spitter) & MOVETYPE_LADDER) 
			{
				buttons &= ~IN_JUMP;
				buttons &= ~IN_DUCK;
			}
		}
		*/
	}
	return Plugin_Continue;
}

public Action Timer_ForceSuicide(Handle timer, int client)
{
	ForcePlayerSuicide(client);
}


// ***** 方法 *****
bool IsAiSpitter(int client)
{
	if(IsFakeClient(client) && GetClientTeam(client) == TEAM_INFECTED && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_SPITTER && GetEntProp(client, Prop_Send, "m_isGhost") != 1)
	{
		return true;
	}
	else
	{
		return false;
	}
}

int GetSurvivorCount()
{
	int iCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && GetClientTeam(i) == TEAM_SURVIVOR)
		{
			iCount++;
		}
	}
	return iCount;
}

// From：http://github.com/PaimonQwQ/L4D2-Plugins/smartspitter.sp
int GetCrowdPlace()
{
	int iCount = GetSurvivorCount();
	if (iCount > 0)
	{
		int index = 0, iTarget = 0;
		int[] iSurvivors = new int[iCount];
		float fDistance[MAXPLAYERS + 1] = -1.0;
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsValidClient(client) && GetClientTeam(client) == TEAM_SURVIVOR)
			{
				iSurvivors[index++] = client;
			}
		}
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsValidClient(client) && IsPlayerAlive(client) && GetClientTeam(client) == TEAM_SURVIVOR)
			{
				fDistance[client] = 0.0;
				float fClientPos[3] = 0.0;
				GetClientAbsOrigin(client, fClientPos);
				for (int i = 0; i < iCount; i++)
				{
					float fPos[3] = 0.0;
					GetClientAbsOrigin(iSurvivors[i], fPos);
					fDistance[client] += GetVectorDistance(fClientPos, fPos, true);
				}
			}
		}
		for (int i = 0; i < iCount; i++)
		{
			if (fDistance[iSurvivors[iTarget]] > fDistance[iSurvivors[i]])
			{
				if (fDistance[iSurvivors[i]] != -1.0)
				{
					iTarget = i;
				}
			}
		}
		return iSurvivors[iTarget];
	}
	else
	{
		return -1;
	}
}



bool IsSpitterPinned(int client)
{
	bool bIsPinned = false;
	if (IsSurvivor(client))
	{
		if(GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0) bIsPinned = true;
		if(GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0) bIsPinned = true;
		// if(GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0) bIsPinned = true;
		if(GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0) bIsPinned = true;
		if(GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0) bIsPinned = true;
	}		
	return bIsPinned;
}

bool HasPinnedClient()
{
	bool bHasPinnedClient = false;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsSpitterPinned(client))
		{
			bHasPinnedClient = true;
		}
	}
	return bHasPinnedClient;
}
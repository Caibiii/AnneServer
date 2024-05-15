#pragma semicolon 1
#define BoomerBoostForward 120.0 // Bhop
public void Boomer_OnModuleStart() 
{
	FindConVar("z_vomit_range").SetInt(200);
	FindConVar("z_boomer_near_dist").SetInt(1);
	FindConVar("z_vomit_fatigue").SetInt(1500);
}

public void Boomer_OnModuleEnd() 
{

}

/***********************************************************************************************************************************************************************************

																KEEP CHARGE ON COOLDOWN UNTIL WITHIN PROXIMITY

***********************************************************************************************************************************************************************************/


public Action Boomer_OnPlayerRunCmd(int boomer, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon) 
{

	int flags = GetEntityFlags(boomer);
	// Get Angle of boomer
	// LOS and survivor proximity
	float boomerPos[3];
	GetClientAbsOrigin(boomer, boomerPos);
	int iSurvivorsProximity = GetSurvivorProximity(boomerPos);
	// Near survivors
	float fVelocity[3];
	GetEntPropVector(boomer, Prop_Data, "m_vecVelocity", fVelocity);
	float currentspeed = SquareRoot(Pow(fVelocity[0],2.0)+Pow(fVelocity[1],2.0));
	float clientEyeAngles[3];
	GetClientEyeAngles(boomer,clientEyeAngles);
	if(GetEntProp(boomer, Prop_Send, "m_hasVisibleThreats") && 700 > iSurvivorsProximity > 200 && currentspeed > 25.0) 
	{ 
		if (flags & FL_ONGROUND) 
		{
			buttons |= IN_DUCK;
			buttons |= IN_JUMP;
			
			if(buttons & IN_FORWARD)
			{
				Client_Push(boomer, clientEyeAngles, BoomerBoostForward, view_as<VelocityOverride>({VelocityOvr_None, VelocityOvr_None, VelocityOvr_None}));
			}
				
			if(buttons & IN_BACK)
			{
				clientEyeAngles[1] += 180.0;
				Client_Push(boomer, clientEyeAngles, BoomerBoostForward, view_as<VelocityOverride>({VelocityOvr_None, VelocityOvr_None, VelocityOvr_None}));
			}
						
			if(buttons & IN_MOVELEFT) 
			{
				clientEyeAngles[1] += 90.0;
				Client_Push(boomer, clientEyeAngles, BoomerBoostForward, view_as<VelocityOverride>({VelocityOvr_None, VelocityOvr_None, VelocityOvr_None}));
			}
						
			if(buttons & IN_MOVERIGHT) 
			{
				clientEyeAngles[1] += -90.0;
				Client_Push(boomer, clientEyeAngles, BoomerBoostForward, view_as<VelocityOverride>({VelocityOvr_None, VelocityOvr_None, VelocityOvr_None}));
			}
		}
		//Block Jumping and Crouching when on ladder
		if (GetEntityMoveType(boomer) & MOVETYPE_LADDER)
		{
			buttons &= ~IN_JUMP;
			buttons &= ~IN_DUCK;
		}
	}
	
	return Plugin_Continue;
}

bool IsAiBoomer(int client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client) && IsFakeClient(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 2 && GetEntProp(client, Prop_Send, "m_isGhost") != 1)
	{
		return true;
	}
	else
	{
		return false;
	}
}


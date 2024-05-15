#pragma semicolon 1

#define JockeyBoostForward 80.0 // Bhop

ConVar g_hJockeyLeapRange;
ConVar g_hHopActivationProximity;
ConVar g_hJockeyLeapAgain;

//Bibliography: "hunter pounce push" by "Pan XiaoHai & Marcus101RR & AtomicStryker"
public void Jockey_OnModuleStart() 
{
	g_hHopActivationProximity = CreateConVar("ai_hop_activation_proximity", "800", "How close a jockey will approach before it starts hopping");
	g_hJockeyLeapRange = FindConVar("z_jockey_leap_range");
	g_hJockeyLeapRange.SetInt(1000); 
	g_hJockeyLeapAgain = FindConVar("z_jockey_leap_again_timer");
	g_hJockeyLeapAgain.SetFloat(0.1);
	FindConVar("z_leap_attach_distance").SetFloat(250.0);
	FindConVar("z_leap_force_attach_distance").SetFloat(250.0);
	FindConVar("z_leap_far_attach_delay").SetFloat(0.0);
	FindConVar("z_leap_max_distance").SetFloat(600.0);
	FindConVar("z_leap_power").SetFloat(450.0);
}

public void Jockey_OnModuleEnd() 
{
	g_hJockeyLeapRange.RestoreDefault();
	g_hJockeyLeapAgain.RestoreDefault();
	FindConVar("z_leap_attach_distance").RestoreDefault();
	FindConVar("z_leap_force_attach_distance").RestoreDefault();
	FindConVar("z_leap_far_attach_delay").RestoreDefault();
	FindConVar("z_leap_max_distance").RestoreDefault();
	FindConVar("z_leap_power").RestoreDefault();
}

/***********************************************************************************************************************************************************************************

																	HOPS: ALTERNATING LEAP AND JUMP

***********************************************************************************************************************************************************************************/

public Action Jockey_OnPlayerRunCmd(int jockey, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, bool hasBeenShoved) 
{
	static float LeftGroundMaxSpeed[MAXPLAYERS + 1];
	int target = GetClientAimTarget(jockey, true);
	float Velocity[3];
	GetEntPropVector(jockey, Prop_Data, "m_vecVelocity", Velocity);
	float currentspeed = SquareRoot(Pow(Velocity[0], 2.0) + Pow(Velocity[1], 2.0));

	int flags = GetEntityFlags(jockey);
	if(flags & FL_ONGROUND)
	{
		
	}
	else if(LeftGroundMaxSpeed[jockey] == -1.0)
		LeftGroundMaxSpeed[jockey] = GetEntPropFloat(jockey, Prop_Data, "m_flMaxspeed");

	if(GetEntProp(jockey, Prop_Send, "m_hasVisibleThreats") == 0 || hasBeenShoved)
		return Plugin_Continue;

	float dist = NearestSurvivorDistance(jockey);
	if(currentspeed > 130.0)
	{
		if(dist < g_hHopActivationProximity.FloatValue) 
		{
			if(flags & FL_ONGROUND)
			{
				if(dist < 250.0 && DelayExpired(jockey, 0, g_hJockeyLeapAgain.FloatValue))
				{
					if(LeftGroundMaxSpeed[jockey] != -1.0 && currentspeed > 250.0)
					{
						float CurVelVec[3];
						GetEntPropVector(jockey, Prop_Data, "m_vecAbsVelocity", CurVelVec);
						if(GetVectorLength(CurVelVec) > LeftGroundMaxSpeed[jockey])
						{
							NormalizeVector(CurVelVec, CurVelVec);
							ScaleVector(CurVelVec, LeftGroundMaxSpeed[jockey]);
							TeleportEntity(jockey, NULL_VECTOR, NULL_VECTOR, CurVelVec);
						}
						LeftGroundMaxSpeed[jockey] = -1.0;
					}

					if(GetState(jockey, 0) == IN_JUMP)
					{
						bool IsWatchingJockey = IsTargetWatchingAttacker(jockey, 20);
						if(angles[2] == 0.0 && IsWatchingJockey) 
						{
							angles = angles;
							angles[0] = GetRandomFloat(-50.0,-10.0);
							TeleportEntity(jockey, NULL_VECTOR, angles, NULL_VECTOR);
						}

						buttons |= IN_ATTACK;
						SetState(jockey, 0, IN_ATTACK);
					}
					else 
					{
						if(angles[2] == 0.0) 
						{
							angles[0] = GetRandomFloat(-10.0, 0.0);
							TeleportEntity(jockey, NULL_VECTOR, angles, NULL_VECTOR);
						}

						buttons |= IN_JUMP;
						switch(GetRandomInt(0, 2)) 
						{
							case 0:
								buttons |= IN_DUCK;
							case 1:
								buttons |= IN_ATTACK2;
						}
						SetState(jockey, 0, IN_JUMP);
					}
				}
				
				else if(IsValidSurvivor(target))
				{
					float target_pos[3] = {0.0}, vel_buffer[3] = {0.0};
					GetClientAbsOrigin(target, target_pos);
					vel_buffer = CalculateVel(Velocity, target_pos, 90.0);
					buttons |= IN_JUMP;
					//buttons |= IN_DUCK;
					if (Do_Bhop(jockey, buttons, vel_buffer))
					{
						return Plugin_Changed;
					}
				}
			}

			if(GetEntityMoveType(jockey) & MOVETYPE_LADDER) 
			{
				buttons &= ~IN_JUMP;
				buttons &= ~IN_DUCK;
			}
		}
	}

	return Plugin_Continue;
}

/***********************************************************************************************************************************************************************************

																	DEACTIVATING HOP DURING SHOVES

***********************************************************************************************************************************************************************************/
// Disable hopping when shoved
public void Jockey_OnShoved(int botJockey) 
{
	DelayStart(botJockey, 0);
}

/***********************************************************************************************************************************************************************************

																		JOCKEY STUMBLE

***********************************************************************************************************************************************************************************/

stock float modulus(float a, float b) 
{
	while(a > b)
		a -= b;
	return a;
}

bool IsAiJockey(int client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client) && IsFakeClient(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 5 && GetEntProp(client, Prop_Send, "m_isGhost") != 1)
	{
		return true;
	}
	else
	{
		return false;
	}
}
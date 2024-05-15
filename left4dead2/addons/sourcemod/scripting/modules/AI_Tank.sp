#pragma semicolon 1
// RockThrowSequence
#define SEQUENCE_ONEHAND 49
#define SEQUENCE_UNDERHAND 50
#define SEQUENCE_TWOHAND 51

#pragma semicolon 1

#define BoostForward 60.0 // Bhop

#define VelocityOvr_None 0
#define VelocityOvr_Velocity 1
#define VelocityOvr_OnlyWhenNegative 2
#define VelocityOvr_InvertReuseVelocity 3

static ConVar g_hCvarEnable, g_hCvarTankBhop, g_hCvarTankRock; 
static bool g_bCvarEnable, g_bCvarTankBhop, g_bCvarTankRock;

public void Tank_OnModuleStart() 
{
	g_hCvarEnable 		= CreateConVar( "AI_HardSI_Tank_enable",   	"1",   	"0=Improves the Tank behaviour off, 1=Improves the Tank behaviour on.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarTankBhop 	= CreateConVar("ai_tank_bhop", 				"1", 	"Flag to enable bhop facsimile on AI tanks", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarTankRock 	= CreateConVar("ai_tank_rock", 				"1", 	"Flag to enable rocks on AI tanks", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	GetCvars();
	g_hCvarEnable.AddChangeHook(ConVarChanged_EnableCvars);
	g_hCvarTankBhop.AddChangeHook(CvarChanged);
	g_hCvarTankRock.AddChangeHook(CvarChanged);
	HookEvent("tank_spawn", evt_TankSpawn);

}

static void ConVarChanged_EnableCvars(ConVar hCvar, const char[] sOldVal, const char[] sNewVal)
{
    GetCvars();
}

static void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) 
{
	GetCvars();
}

static void GetCvars()
{
	g_bCvarEnable = g_hCvarEnable.BoolValue;
	g_bCvarTankBhop = g_hCvarTankBhop.BoolValue;
	g_bCvarTankRock = g_hCvarTankRock.BoolValue;
}

public void Tank_OnModuleEnd() 
{

}
// **************
//		事件
// *************
public void evt_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsAiTank(client))
	{
		SDKHook(client, SDKHook_PostThinkPost, UpdateThink);
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

//Tank障碍攀爬速度增加
// 动画序列：9=正常走路，49=单手举过头顶投掷，50=低抛，51=双手举过头顶投掷
// 25=爬梯子，16=上低矮障碍物，19/20/21=爬墙/空调机/正常围栏，15=落地或上低矮障碍物，17=爬灌木/低矮围栏，22=爬房车，23=爬大货车，梯子由于有ladderboost不用加了
public void UpdateThink(int client)
{
	switch (GetEntProp(client, Prop_Send, "m_nSequence"))
	{
		case 15, 16, 17:
		{
			SetEntPropFloat(client, Prop_Send, "m_flPlaybackRate", 2.0);
		}
		case 18, 19, 20, 21, 22, 23:
		{
			SetEntPropFloat(client, Prop_Send, "m_flPlaybackRate", 4.0);
		}
		case 54, 55, 56, 57, 58, 59, 60:
		{
			SetEntPropFloat(client, Prop_Send, "m_flPlaybackRate", 999.0);
		}
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (IsAiTank(victim))
	{
		damage = damage * 0.9;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

// 禁止Tank低抛石头
public Action L4D2_OnSelectTankAttack(int client, int &sequence)
{
	if (sequence == SEQUENCE_UNDERHAND)
	{
		sequence = GetRandomInt(0, 1) ? SEQUENCE_ONEHAND : SEQUENCE_TWOHAND;
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

// 坦克挥拳时设定减少拳头力度
public void L4D_TankClaw_DoSwing_Pre(int tank, int claw)
{
	SetConVarString(FindConVar("z_tank_throw_force"), "500");
}

//Tank跳砖设置
public Action L4D_OnCThrowActivate(int ability)
{
	SetConVarString(FindConVar("z_tank_throw_force"), "950");
	int tankclient = GetEntPropEnt(ability, Prop_Data, "m_hOwnerEntity");
	if (IsAiTank(tankclient))
	{
		RequestFrame(NextFrame_JumpRock, tankclient);
	}
	return Plugin_Continue;
}
void NextFrame_JumpRock(int tankclient)
{
	if (IsAiTank(tankclient))
	{
		float tankpos[3] = {0.0};
		GetClientAbsOrigin(tankclient, tankpos);
		int target = GetClosestSurvivor(tankpos);
		if (IsSurvivor(target))
		{
			int flags = GetEntityFlags(tankclient);
			if (flags & FL_ONGROUND)
			{
				float eyeangles[3] = 0.0, lookat[3] = 0.0;
				GetClientEyeAngles(tankclient, eyeangles);
				GetAngleVectors(eyeangles, lookat, NULL_VECTOR, NULL_VECTOR);
				NormalizeVector(lookat, lookat);
				ScaleVector(lookat, 200.0);
				lookat[2] = 200.0;
				TeleportEntity(tankclient, NULL_VECTOR, NULL_VECTOR, lookat);
			}
		}
	}
}

bool IsAiTank(int client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client) && IsFakeClient(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8 && GetEntProp(client, Prop_Send, "m_isGhost") != 1)
	{
		return true;
	}
	else
	{
		return false;
	}
}


// Tank bhop and blocking rock throw
stock Action Tank_OnPlayerRunCmd( int tank, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon ) {
	if(!g_bCvarEnable) return Plugin_Continue;

	// block rock throws
	if( g_bCvarTankRock == false ) 
	{
		buttons &= ~IN_ATTACK2;
	}
	
	if( g_bCvarTankBhop ) 
	{
		int flags = GetEntityFlags(tank);
		
		// Get the player velocity:
		float fVelocity[3];
		GetEntPropVector(tank, Prop_Data, "m_vecVelocity", fVelocity);
		float currentspeed = SquareRoot(Pow(fVelocity[0],2.0)+Pow(fVelocity[1],2.0));
		//PrintCenterTextAll("Tank Speed: %.1f", currentspeed);
		
		// Get Angle of Tank
		float clientEyeAngles[3];
		GetClientEyeAngles(tank,clientEyeAngles);
		
		// LOS and survivor proximity
		float tankPos[3];
		GetClientAbsOrigin(tank, tankPos);
		int iSurvivorsProximity = GetSurvivorProximity(tankPos);
		if (iSurvivorsProximity == -1) return Plugin_Continue;
		
		bool bHasSight = view_as<bool>(GetEntProp(tank, Prop_Send, "m_hasVisibleThreats")); //Line of sight to survivors
		
		// Near survivors
		if( bHasSight && (1500 > iSurvivorsProximity > 100) && currentspeed > 190.0 ) 
		{ // Random number to make bhop?
			if (flags & FL_ONGROUND) 
			{
				buttons |= IN_DUCK;
				buttons |= IN_JUMP;
				
				if(buttons & IN_FORWARD) 
				{
					Client_Push( tank, clientEyeAngles, BoostForward, {VelocityOvr_None,VelocityOvr_None,VelocityOvr_None} );
				}	
				
				if(buttons & IN_BACK) 
				{
					clientEyeAngles[1] += 180.0;
					Client_Push( tank, clientEyeAngles, BoostForward, {VelocityOvr_None,VelocityOvr_None,VelocityOvr_None} );
				}
						
				if(buttons & IN_MOVELEFT) 
				{
					clientEyeAngles[1] += 90.0;
					Client_Push( tank, clientEyeAngles, BoostForward, {VelocityOvr_None,VelocityOvr_None,VelocityOvr_None} );
				}
						
				if(buttons & IN_MOVERIGHT) 
				{
					clientEyeAngles[1] += -90.0;
					Client_Push( tank, clientEyeAngles, BoostForward, {VelocityOvr_None,VelocityOvr_None,VelocityOvr_None} );
				}
			}
			//Block Jumping and Crouching when on ladder
			if (GetEntityMoveType(tank) & MOVETYPE_LADDER) 
			{
				buttons &= ~IN_JUMP;
				buttons &= ~IN_DUCK;
			}

			if(buttons & IN_JUMP)
			{
				int Activity = PlayerAnimState.FromPlayer(tank).GetMainActivity();
				if(Activity == L4D2_ACT_HULK_THROW || Activity == L4D2_ACT_TANK_OVERHEAD_THROW || Activity == L4D2_ACT_HULK_ATTACK_LOW)
				{
					GetEntPropVector(tank, Prop_Data, "m_vecVelocity", vel);
					vel[2] = 280.0;
					TeleportEntity(tank, NULL_VECTOR, NULL_VECTOR, vel);  
					//buttons &= ~IN_JUMP;
				}
			}
		}
	}
	return Plugin_Continue;	
}

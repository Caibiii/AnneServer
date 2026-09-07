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

public void Tank_OnModuleStart() 
{

	HookEvent("tank_spawn", evt_TankSpawn);

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
		//SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
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
	SetConVarString(FindConVar("z_tank_throw_force"), "500");
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

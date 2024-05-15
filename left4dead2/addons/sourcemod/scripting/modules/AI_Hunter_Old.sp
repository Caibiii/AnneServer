#pragma semicolon 1
public void Hunter_OnModuleStart() 
{

}

public void Hunter_OnModuleEnd() 
{

}


/***********************************************************************************************************************************************************************************

																		FAST POUNCING

***********************************************************************************************************************************************************************************/
// HUNTER
#define HUNTERATTACKTIME 5.0
#define HUNTERREPEATSPEED 4
#define HUNTERONGTOUNDSTATE 1
#define HUNTERFLYSTATE 2
#define HUNTERCOOLDOWNTIME 0.5
#define VEM_MAX 450.0
public Action Hunter_OnPlayerRunCmd(int hunter, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon) 
{
	if (GetEntityMoveType(hunter) != MOVETYPE_LADDER) 
	{
		Action react = Plugin_Continue;
		bool internaltrigger = false;
		if (!DelayExpired(hunter, 1, HUNTERATTACKTIME) && GetEntityMoveType(hunter) != MOVETYPE_LADDER)
		{
			buttons |= IN_DUCK;
			if (!(GetRandomInt(0, HUNTERREPEATSPEED)))
			{
				buttons |= IN_ATTACK;
				internaltrigger = true;
			}
			react = Plugin_Changed;
		}
		if (!(GetEntityFlags(hunter) & FL_ONGROUND) && GetState(hunter, HUNTERFLYSTATE) == 0)
		{
			DelayStart(hunter, 2);
			SetState(hunter, HUNTERONGTOUNDSTATE, 0);
			SetState(hunter, HUNTERFLYSTATE, 1);
		}
		else if (!(GetEntityFlags(hunter) & FL_ONGROUND))
		{
			if (GetState(hunter, 0) == IN_FORWARD)
			{
				buttons |= IN_FORWARD;
				vel[0] = VEM_MAX;
				if (GetState(hunter, HUNTERONGTOUNDSTATE) == 0 && DelayExpired(hunter, 2, 0.2))
				{
					if (angles[2] == 0.0)
					{
						angles[0] = GetRandomFloat(-30.0, 30.0);
						TeleportEntity(hunter, NULL_VECTOR, angles, NULL_VECTOR);
					}
					SetState(hunter, HUNTERONGTOUNDSTATE, 1);
				}
				react = Plugin_Changed;
			}
			else if (!(GetState(hunter, 2) == 1))
			{
				SetState(hunter, HUNTERFLYSTATE, 0);
			}
		}
		if (DelayExpired(hunter, 0, 0.1) && (buttons & IN_ATTACK) && (GetEntityFlags(hunter) & FL_ONGROUND))
		{
			float dist = NearestSurvivorDistance(hunter);
			DelayStart(hunter, 0);
			if (!internaltrigger && !(buttons & IN_BACK) && dist < 1000.0 && DelayExpired(hunter, 1, HUNTERATTACKTIME + HUNTERCOOLDOWNTIME))
			{
				DelayStart(hunter, 1);
			}
			if (GetRandomInt(0, 1) == 0)
			{
				if (dist < 1000.0)
				{
					if (angles[2] == 0.0)
					{
						// 4 / 5 的概率向 10 - 30 度的 x 轴角度突袭，向右， 1 / 5 的概率向 -30 -10 度的 x 轴角度突袭，向左
						if (GetRandomInt(0, 4))
						{
							angles[0] = GetRandomFloat(10.0, 30.0);
						}
						else
						{
							angles[0] = GetRandomFloat(-30.0, -10.0);
						}
						TeleportEntity(hunter, NULL_VECTOR, angles, NULL_VECTOR);
					}
					SetState(hunter, 0, IN_FORWARD);
				}
				else
				{
					SetState(hunter, 0, 0);
				}
			}
			else
			{
				SetState(hunter, 0, 0);
			}
			react = Plugin_Changed;
		}
		return react;
	}
	return Plugin_Continue;
	
}
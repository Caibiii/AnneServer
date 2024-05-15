//TANK转弯石头
//TANK丢石头姿势
//TANK拳头和石头力度控制
//特感加强插件
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#pragma tabsize 0
#define CMD_ATTACK 0
#include "includes/hardcoop_util.sp"
#define CHARGER_MELEE_DELAY     0.2
#define CHARGER_MELEE_RANGE 750.0

#define DEBUG_SPEED 0
#define DEBUG_EYE   0
#define DEBUG_KEY   0
#define DEBUG_ANGLE 0
#define DEBUG_VEL   0
#define DEBUG_AIM       0
#define DEBUG_POS       0

#define ZC_SMOKER       1
#define ZC_BOOMER       2
#define ZC_HUNTER       3
#define ZC_SPITTER      4
#define ZC_JOCKEY       5
#define ZC_CHARGER      6
#define ZC_WITCH        7
#define ZC_TANK         8

#define MAXPLAYERS1     (MAXPLAYERS+1)

#define VEL_MAX          450.0
#define MOVESPEED_TICK     1.0
#define EYEANGLE_TICK      0.2
#define TEST_TICK          2.0
#define MOVESPEED_MAX     1000
enum AimTarget
{
        AimTarget_Eye,
        AimTarget_Body,
        AimTarget_Chest
};

public OnPluginStart()
{
        HookEvent("round_start", onRoundStart);
        HookEvent("player_spawn", onPlayerSpawn);
		HookEvent("tank_spawn", Event_TankSpawn, EventHookMode_PostNoCopy);
}
public OnMapStart()
{
     CreateTimer(MOVESPEED_TICK, timerMoveSpeed, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}
new bool:g_ai_enable[MAXPLAYERS1];
public Action:onRoundStart(Handle:event, String:event_name[], bool:dontBroadcast)
{
        for (new i = 0; i < MAXPLAYERS1; ++i) {
                g_ai_enable[i] = false;
        }
        initStatus();
}

public Action:onPlayerSpawn(Handle:event, String:event_name[], bool:dontBroadcast)
{
        new client = GetClientOfUserId(GetEventInt(event, "userid"));
        if (isSpecialInfectedBot(client)) 
		{
                // AI適用の有効無効を切り替える（タンクはこのフラグを無視する）
                 g_ai_enable[client] = true;
        }
}


/* クライアントのキー入力処理
 *
 * ここでbotのキー入力を監視して書き換えることでbotをコントロールする
 *
 * buttons: 入力されたキー (enumはinclude/entity_prop_stock.inc参照)
 * vel: プレーヤーの速度？
 *      実プレーヤーだと
 *      [0]が↑↓入力で-450～+450.
 *      [1]が←→入力で-450～+450.
 *      botだと230
 *
 * angles: 視線の方向(マウスカーソルを向けている方向)？
 *      [0]がpitch(上下) -89～+89
 *      [1]がyaw(自分を中心に360度回転) -180～+180
 *
 *      これを変更しても視線は変わらないがIN_FORWARDに対する移動方向が変わる
 *
 * impulse: impules command なぞ
 *
 * buttons, vel, anglesは書き換えてPlugin_Changedを返せば操作に反映される.
 * ただ処理順の問題があってたとえばIN_USEのビットを落としてUSE Keyが使えないようにすると
 * 武器は取れないけどドアは開くみたいな事が起こりえる.
 *
 * ゲームフレームから呼ばれるようなのでできるだけ軽い処理にする.
 */
public Action:OnPlayerRunCmd(client, &buttons, &impulse,
                                                         Float:vel[3], Float:angles[3], &weapon)
{
        // 確認用...
#if (DEBUG_SPEED || DEBUG_KEY || DEBUG_EYE || DEBUG_ANGLE || DEBUG_VEL || DEBUG_AIM || DEBUG_POS)
        debugPrint(client, buttons, vel, angles);
#endif
        // 特殊のBOTのみ処理
        if (isSpecialInfectedBot(client)) {
                // versusだとゴースト状態のBotがいるけど
                // Coopだとゴーストなしでいきなり沸いてる?
                // 今回ゴーストは考慮しない
                if (!isGhost(client)) {
                        // 種類ごとの処理
                        new zombie_class = getZombieClass(client);
                        new Action:ret = Plugin_Continue;

                        if (zombie_class == ZC_TANK) {
                                ret = onTankRunCmd(client,  buttons, vel, angles);
                        } else if (g_ai_enable[client]) {
                                switch (zombie_class) {
                                case ZC_SMOKER: { ret = onSmokerRunCmd(client, buttons, vel, angles); }
								case ZC_JOCKEY: { ret = onJockeyRunCmd(client, buttons, vel, angles); }
								case ZC_BOOMER: { ret = onBoomerRunCmd(client, buttons, vel, angles); }
                                case ZC_HUNTER: { ret = onHunterRunCmd(client, buttons, vel, angles); }
								case ZC_CHARGER: { ret = onChargerRunCmd(client, buttons, vel, angles); }
                                case ZC_SPITTER: { ret = onSpitterRunCmd(client, buttons, vel, angles); }
                                }
                        }
                        // 最近のメイン攻撃時間を保存
                        if (buttons & IN_ATTACK) {
                                updateSIAttackTime();
                        }
                        return ret;
                }
        }
        return Plugin_Continue;
}
stock Action:onSmokerRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
	if (GetEntityMoveType(client) != MOVETYPE_LADDER) 
	{
		new target = GetClientAimTarget(client, true);
		if (target > 0 && isVisibleTo(client,target) && !hasPinned(target) && !isIncapacitated(target)) 
		{
			new Float:aim_angles[3];
			computeAimAngles(client, target, aim_angles, AimTarget_Chest);
			aim_angles[2] = 0.0;
			TeleportEntity(client, NULL_VECTOR, aim_angles, NULL_VECTOR);
			return Plugin_Changed;		
		} 
		else
		{
			new new_target = -1;
			new Float:min_dist = 100000.0;
			new Float:self_pos[3], Float:target_pos[3];
			GetClientAbsOrigin(client, self_pos);
			for (new i = 1; i <= MaxClients; ++i) 
			{
				if (isSurvivor(i)&& IsPlayerAlive(i) && !isIncapacitated(i) && isVisibleTo(client,i) && !hasPinned(i))
				{
					new Float:dist;
					GetClientAbsOrigin(i, target_pos);
					dist = GetVectorDistance(self_pos, target_pos);
					if (dist < min_dist) 
					{
						min_dist = dist;
						new_target = i;
					}
				}
			}
			if (new_target > 0) 
			{
				if (angles[2] == 0.0) 
				{
					new Float:aim_angles[3];
					computeAimAngles(client, new_target, aim_angles, AimTarget_Chest);
					aim_angles[2] = 0.0;
					TeleportEntity(client, NULL_VECTOR, aim_angles, NULL_VECTOR);
					return Plugin_Changed;
				}
			}
		}
	}
	return Plugin_Continue;
}
stock Action:onBoomerRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
	if (GetEntityMoveType(client) != MOVETYPE_LADDER) 
	{
		new target = GetClientAimTarget(client, true);
		if (target > 0 && isVisibleTo(client,target) && !hasPinned(target)) 
		{
			new Float:aim_angles[3];
			computeAimAngles(client, target, aim_angles, AimTarget_Chest);
			aim_angles[2] = 0.0;
			TeleportEntity(client, NULL_VECTOR, aim_angles, NULL_VECTOR);
			return Plugin_Changed;		
		} 
		else
		{
			new new_target = -1;
			new Float:min_dist = 100000.0;
			new Float:self_pos[3], Float:target_pos[3];
			GetClientAbsOrigin(client, self_pos);
			for (new i = 1; i <= MaxClients; ++i) 
			{
				if (isSurvivor(i) && IsPlayerAlive(i) && isVisibleTo(client,i) && !hasPinned(i))
				{
					new Float:dist;
					GetClientAbsOrigin(i, target_pos);
					dist = GetVectorDistance(self_pos, target_pos);
					if (dist < min_dist) 
					{
						min_dist = dist;
						new_target = i;
					}
				}
			}
			if (new_target > 0) 
			{
				if (angles[2] == 0.0) 
				{
					new Float:aim_angles[3];
					computeAimAngles(client, new_target, aim_angles, AimTarget_Chest);
					aim_angles[2] = 0.0;
					TeleportEntity(client, NULL_VECTOR, aim_angles, NULL_VECTOR);
					return Plugin_Changed;
				}
			}
		}
	}
	return Plugin_Continue;
}
stock Action:onJockeyRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
	if (GetEntityMoveType(client) != MOVETYPE_LADDER) 
	{
		new target = GetClientAimTarget(client, true);
		if (target > 0 && isVisibleTo(client,target) && !hasPinned(target) && !isIncapacitated(target)) 
		{
			new Float:aim_angles[3];
			computeAimAngles(client, target, aim_angles, AimTarget_Chest);
			aim_angles[2] = 0.0;
			TeleportEntity(client, NULL_VECTOR, aim_angles, NULL_VECTOR);
			return Plugin_Changed;		
		} 
		else
		{
			new new_target = -1;
			new Float:min_dist = 100000.0;
			new Float:self_pos[3], Float:target_pos[3];
			GetClientAbsOrigin(client, self_pos);
			for (new i = 1; i <= MaxClients; ++i) 
			{
				if (isSurvivor(i)&& IsPlayerAlive(i) && !isIncapacitated(i) && isVisibleTo(client,i) && !hasPinned(i))
				{
					new Float:dist;
					GetClientAbsOrigin(i, target_pos);
					dist = GetVectorDistance(self_pos, target_pos);
					if (dist < min_dist) 
					{
						min_dist = dist;
						new_target = i;
					}
				}
			}
			if (new_target > 0) 
			{
				if (angles[2] == 0.0) 
				{
					new Float:aim_angles[3];
					computeAimAngles(client, new_target, aim_angles, AimTarget_Chest);
					aim_angles[2] = 0.0;
					TeleportEntity(client, NULL_VECTOR, aim_angles, NULL_VECTOR);
					return Plugin_Changed;
				}
			}
		}
	}
	return Plugin_Continue;
}
stock Action:onSpitterRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
	if (GetEntityMoveType(client) != MOVETYPE_LADDER) 
	{
		new target = GetClientAimTarget(client, true);
		if (target > 0 && isVisibleTo(client,target) && hasPinned(target)) 
		{
			new Float:aim_angles[3];
			computeAimAngles(client, target, aim_angles, AimTarget_Chest);
			aim_angles[2] = 0.0;
			TeleportEntity(client, NULL_VECTOR, aim_angles, NULL_VECTOR);
			return Plugin_Changed;		
		} 
		else
		{
			new new_target = -1;
			new Float:min_dist = 100000.0;
			new Float:self_pos[3], Float:target_pos[3];
			GetClientAbsOrigin(client, self_pos);
			for (new i = 1; i <= MaxClients; ++i) 
			{
				if (isSurvivor(i)&& IsPlayerAlive(i) && isVisibleTo(client,i) && hasPinned(i))
				{
					new Float:dist;
					GetClientAbsOrigin(i, target_pos);
					dist = GetVectorDistance(self_pos, target_pos);
					if (dist < min_dist) 
					{
						min_dist = dist;
						new_target = i;
					}
				}
			}
			if (new_target > 0) 
			{
				if (angles[2] == 0.0) 
				{
					new Float:aim_angles[3];
					computeAimAngles(client, new_target, aim_angles, AimTarget_Chest);
					aim_angles[2] = 0.0;
					TeleportEntity(client, NULL_VECTOR, aim_angles, NULL_VECTOR);
					return Plugin_Changed;
				}
			}
		}
	}
	return Plugin_Continue;
}

stock Action:onChargerRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
    if (GetEntityMoveType(client) != MOVETYPE_LADDER) 
	{
		new target = GetClientAimTarget(client, true);
		new abilityEnt = 0;
		if (target > 0 && isVisibleTo(client,target) && !hasPinned(target) && !isIncapacitated(target)) 
		{
			abilityEnt = GetEntPropEnt(client, Prop_Send, "m_customAbility");
			new bool:isCharging = false;
			if (abilityEnt > 0) 
			{
				isCharging = (GetEntProp(abilityEnt, Prop_Send, "m_isCharging") > 0) ? true : false;
			}
			if (!isCharging && GetEntPropEnt(client, Prop_Send, "m_carryAttacker") == 0)
			{
				new Float:aim_angles[3];
				computeAimAngles(client, target, aim_angles, AimTarget_Chest);
				aim_angles[2] = 0.0;
				TeleportEntity(client, NULL_VECTOR, aim_angles, NULL_VECTOR);
				return Plugin_Changed;
			}	
		} 
		else
		{
			new new_target = -1;
			new Float:min_dist = 100000.0;
			new Float:self_pos[3], Float:target_pos[3];
			GetClientAbsOrigin(client, self_pos);
			for (new i = 1; i <= MaxClients; ++i) 
			{
				if (isSurvivor(i)&& IsPlayerAlive(i) && !isIncapacitated(i) && isVisibleTo(client,i) && !hasPinned(i))
				{
					new Float:dist;
					GetClientAbsOrigin(i, target_pos);
					dist = GetVectorDistance(self_pos, target_pos);
					if (dist < min_dist) 
					{
						min_dist = dist;
						new_target = i;
					}
				}
			}
			if (new_target > 0) 
			{
				if(angles[2] == 0.0)
				{
					abilityEnt = GetEntPropEnt(client, Prop_Send, "m_customAbility");
					new bool:isCharging = false;
					if (abilityEnt > 0) 
					{
						isCharging = (GetEntProp(abilityEnt, Prop_Send, "m_isCharging") > 0) ? true : false;
					}
					if (!isCharging && GetEntPropEnt(client, Prop_Send, "m_carryAttacker") == 0)
					{
						new Float:aim_angles[3];
						computeAimAngles(client, new_target, aim_angles, AimTarget_Chest);
						aim_angles[2] = 0.0;
						TeleportEntity(client, NULL_VECTOR, aim_angles, NULL_VECTOR);
						return Plugin_Changed;
					}
				}
			}
		}
	}
    return Plugin_Continue;
}
/**
 * スモーカーの処理
 *
 * チャンスがあれば舌を飛ばす
 */

/**
 * ハンターの処理
 *
 * 次のようにする
 * - 最初の飛び掛りのトリガーはBOTが自発的に行う
 * - BOTが飛び掛ったら一定の間攻撃モードをONにする
 * - 攻撃モードがONの場合さまざまな角度で連続的に飛びまくる動きと
 *   ターゲットを狙った飛びかかり（デフォルトの動き）を混ぜて飛び回る
 *
 * あと hunter_pounce_ready_range というCVARをを2000くらいに変更すると
 * 遠くにいるときでもしゃがむようになるの変更するとよい
 *
 * あと撃たれたときに後ろに飛んで逃げるっぽい動きに移行するのをやめさせたい
 */
stock Action:onHunterRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
	if (GetEntityMoveType(client) != MOVETYPE_LADDER) 
	{
		new target = GetClientAimTarget(client, true);
		if (target > 0 && isVisibleTo(client,target) && !hasPinned(target) && !isIncapacitated(target)) 
		{
			new Float:aim_angles[3];
			computeAimAngles(client, target, aim_angles, AimTarget_Chest);
			aim_angles[2] = 0.0;
			TeleportEntity(client, NULL_VECTOR, aim_angles, NULL_VECTOR);
			return Plugin_Changed;		
		} 
		else
		{
			new new_target = -1;
			new Float:min_dist = 100000.0;
			new Float:self_pos[3], Float:target_pos[3];
			GetClientAbsOrigin(client, self_pos);
			for (new i = 1; i <= MaxClients; ++i) 
			{
				if (isSurvivor(i)&& IsPlayerAlive(i) && !isIncapacitated(i) && isVisibleTo(client,i) && !hasPinned(i))
				{
					new Float:dist;
					GetClientAbsOrigin(i, target_pos);
					dist = GetVectorDistance(self_pos, target_pos);
					if (dist < min_dist) 
					{
						min_dist = dist;
						new_target = i;
					}
				}
			}
			if (new_target > 0) 
			{
				if (angles[2] == 0.0) 
				{
					new Float:aim_angles[3];
					computeAimAngles(client, new_target, aim_angles, AimTarget_Chest);
					aim_angles[2] = 0.0;
					TeleportEntity(client, NULL_VECTOR, aim_angles, NULL_VECTOR);
					return Plugin_Changed;
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action:L4D2_OnSelectTankAttack(client, &sequence) 
{
	if (IsFakeClient(client) && sequence == 50) {
		sequence = GetRandomInt(0, 1) ? 49 : 51;
		return Plugin_Handled;
	}
	return Plugin_Changed;
}
public Action:L4D_OnCThrowActivate(ability)
{
	SetConVarString(FindConVar("z_tank_throw_force"), "900");
}

#define TANK_MELEE_SCAN_DELAY 0.5
#define TANK_ROCK_AIM_TIME    4.0
#define TANK_ROCK_AIM_DELAY   0.25
stock Action:onTankRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
        static Float:s_tank_attack_range = -1.0;
        static Float:s_tank_speed = -1.0;

        if (s_tank_attack_range < 0.0) {
                // 殴りの範囲
                s_tank_attack_range = GetConVarFloat(FindConVar("tank_attack_range"));
        }
        if (s_tank_speed < 0.0) {
                // タンクの速さ
                s_tank_speed = GetConVarFloat(FindConVar("z_tank_speed"));
        }
        // 岩投げ
        if ((buttons & IN_ATTACK2)) 
		{
                // BOTが岩投げ開始
                // この時間が切れるまでターゲットを探してAutoAimする
                delayStart(client, 3);
                delayStart(client, 4);
        }
        // 岩投げ中
        if (delayExpired(client, 4, TANK_ROCK_AIM_DELAY)
                && !delayExpired(client, 3, TANK_ROCK_AIM_TIME))
        {
                new target = GetClientAimTarget(client, true);
                if (target > 0 && isVisibleTo(client, target)) {
                        // BOTが狙っているターゲットが見えている場合
                } else {
                        // 見えて無い場合はタンクから見える範囲で一番近い生存者を検索
                        new new_target = -1;
                        new Float:min_dist = 100000.0;
                        new Float:self_pos[3], Float:target_pos[3];

                        GetClientAbsOrigin(client, self_pos);
                        for (new i = 1; i <= MaxClients; ++i) {
                                if (isSurvivor(i)
                                        && IsPlayerAlive(i)
                                        && !isIncapacitated(i)
                                        && isVisibleTo(client, i))
                                {
                                        new Float:dist;

                                        GetClientAbsOrigin(i, target_pos);
                                        dist = GetVectorDistance(self_pos, target_pos);
                                        if (dist < min_dist) {
                                                min_dist = dist;
                                                new_target = i;
                                        }
                                }
                        }
                        if (new_target > 0) {
                                // 新たなターゲットに照準を合わせる
                                if (angles[2] == 0.0) {
                                        new Float:aim_angles[3];
                                        computeAimAngles(client, new_target, aim_angles, AimTarget_Chest);
                                        aim_angles[2] = 0.0;
                                        TeleportEntity(client, NULL_VECTOR, aim_angles, NULL_VECTOR);
                                        return Plugin_Changed;
                                }
                        }
                }
        }

        // 殴り
        if (GetEntityMoveType(client) != MOVETYPE_LADDER
                && (GetEntityFlags(client) & FL_ONGROUND)
                && IsPlayerAlive(client))
        {
                if (delayExpired(client, 0, TANK_MELEE_SCAN_DELAY)) 
				{
                        // 殴りの当たる範囲に立っている生存者がいたら方向は関係なく殴る
                        delayStart(client, 0);
                        if (nearestActiveSurvivorDistance(client) < s_tank_attack_range * 0.95) 
						{
                                buttons |= IN_ATTACK;
                                return Plugin_Changed;
                        }
                }
        }
        return Plugin_Continue;
}
/**
 * タンクの処理
 *
 * - 近くに生存者がいればとにかく殴る
 * - 走っているときに直線的なジャンプで加速する
 * - 岩投げ中にターゲットしている人が見えなくなったらターゲットを変更する
 *   （投げる瞬間にターゲットが変わるとモーションと違う軌道に投げる）
 */
public void Event_TankSpawn(Event event, const char[] name, bool dont_broadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsBotInfected(client) &&  IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == 8)
	{
		SDKHook(client, SDKHook_PostThinkPost, UpdateThink);
	}
}
public void UpdateThink(int client)
{
	switch(GetEntProp(client, Prop_Send, "m_nSequence", 2))
	{
		case 54, 55, 56, 57, 58, 59, 60: //拍胸/咆哮
			SetEntPropFloat(client, Prop_Send, "m_flPlaybackRate", 999.0);

		case 17, 18, 19, 20, 21, 22, 23: //爬围栏/障碍
			SetEntPropFloat(client, Prop_Send, "m_flPlaybackRate", 2.5); //不能设置太高否则无法爬上去
	}
}
// clientの一番近くにいる生存者の距離を取得
//
// 今はトレースしていないので1階と2階とか隣の部屋とか
// 遮るものがあっても近くになってしまう
stock any:nearestSurvivorDistance(client)
{
        new Float:self[3];
        new Float:min_dist = 100000.0;

        GetClientAbsOrigin(client, self);
        for (new i = 1; i <= MaxClients; ++i) {
                if (IsClientInGame(i) && isSurvivor(i) && IsPlayerAlive(i) && !isIncapacitated(i) && !hasPinned(i)) {
                        new Float:target[3];
                        GetClientAbsOrigin(i, target);
                        new Float:dist = GetVectorDistance(self, target);
                        if (dist < min_dist) {
                                min_dist = dist;
                        }
                }
        }
        return min_dist;
}
stock any:nearestActiveSurvivorDistance(client)
{
        new Float:self[3];
        new Float:min_dist = 100000.0;

        GetClientAbsOrigin(client, self);
        for (new i = 1; i <= MaxClients; ++i) {
                if (IsClientInGame(i)
                        && isSurvivor(i)
                        && IsPlayerAlive(i)
                        && !isIncapacitated(i)
						&& !IsPinned(i))
                {
                        new Float:target[3];
                        GetClientAbsOrigin(i, target);
                        new Float:dist = GetVectorDistance(self, target);
                        if (dist < min_dist) {
                                min_dist = dist;
                        }
                }
        }
        return min_dist;
}

// clientから見える範囲で一番近い生存者を取得
stock any:nearestVisibleSurvivor(client)
{
    new Float:self[3];
	new target = 0;
    new Float:min_dist = 1000.0;
    GetClientAbsOrigin(client, self);
    for (new i = 1; i <= MaxClients; ++i) 
	{
        if (IsClientInGame(i) && isSurvivor(i) && IsPlayerAlive(i) && isVisibleTo(client, i) && !isIncapacitated(i) && !hasPinned(i)) 
		{
			new Float:targetpos[3];
			GetClientAbsOrigin(i, targetpos);
			new Float:dist = L4D2_NavAreaTravelDistance(self, targetpos, false);
			if (dist != -1.0 && dist < min_dist) 
			{
				min_dist = dist;
				target = i ;
			}
		}
	}
	return target;
}

// 感染者か
stock bool:isInfected(i)
{
    return GetClientTeam(i) == 3;
}
// ゴーストか
stock bool:isGhost(i)
{
    return isInfected(i) && GetEntProp(i, Prop_Send, "m_isGhost");
}
// 特殊感染者ボットか
stock bool:isSpecialInfectedBot(i)
{
    return i > 0 && i <= MaxClients && IsClientInGame(i) && IsFakeClient(i) && isInfected(i);
}
// 生存者か
// 死んでるとかダウンしてるとか拘束されてるとかも見たほうがいいでしょう..
stock bool:isSurvivor(i)
{
    return i > 0 && i <= MaxClients && IsClientInGame(i) && GetClientTeam(i) == 2;
}
// 感染者の種類を取得
stock any:getZombieClass(client)
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
new Float:g_delay[MAXPLAYERS1][8];
stock delayStart(client, no)
{
    g_delay[client][no] = GetGameTime();
}
stock bool:delayExpired(client, no, Float:delay)
{
    return GetGameTime() - g_delay[client][no] > delay;
}
// 1 player 8state を持っとく
new g_state[MAXPLAYERS1][8];
stock setState(client, no, value)
{
    g_state[client][no] = value;
}
stock any:getState(client, no)
{
    return g_state[client][no];
}
stock initStatus()
{
    new Float:time = GetGameTime();
    for (new i = 0; i < MAXPLAYERS+1; ++i) 
	{
        for (new j = 0; j < 8; ++j) 
		{
            g_delay[i][j] = time;
            g_state[i][j] = 0;
        }
    }
}

// 特殊がメイン攻撃した時間
new Float:g_si_attack_time;
stock any:getSIAttackTime()
{
        return g_si_attack_time;
}
stock updateSIAttackTime()
{
        g_si_attack_time = GetGameTime();
}

/**
 * TODO: 主攻撃の準備ができているか（リジャージ中じゃないか）調べたいけど
 *       どうすればいいのか分からない
 */
stock bool:readyAbility(client)
{
        /*
        new ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
        new String:name[256];
        GetClientName(client, name, 256);

        if (ability > 0) {
            //new Float:time = GetEntPropFloat(ability, Prop_Send, "m_timestamp");
                //new used = GetEntProp(ability, Prop_Send, "m_hasBeenUsed");
                //new Float:duration = GetEntPropFloat(ability, Prop_Send, "m_duration");
                return time < GetGameTime();
        } else {
                // なぜかここにくることがある
        }
        */
        return true;
}

// 入力がどうなっているの確認に使ってるやつ
stock debugPrint(client, buttons, Float:vel[3], Float:angles[3])
{
        // 条件でフィルタしないと出すぎてやばいので適当に書き換えてデバッグしてる
        if (IsFakeClient(client)) {
                return; // 自分だけ表示
        }

        new String:name[256];
        GetClientName(client, name, 256);

#if DEBUG_KEY
        // キー入力
        new String:command[1024];
        if (buttons & IN_DUCK) {
                StrCat(command, sizeof(command), "DUCK ");
        }
        if (buttons & IN_ATTACK) {
                StrCat(command, sizeof(command), "ATTACK ");
        }
        if (buttons & IN_ATTACK2) {
                StrCat(command, sizeof(command), "ATTACK2 ");
        }
        if (buttons & IN_MOVELEFT) {
                StrCat(command, sizeof(command), "MOVELEFT ");
        }
        if (buttons & IN_MOVERIGHT) {
                StrCat(command, sizeof(command), "MOVERIGHT ");
        }
        if (buttons & IN_FORWARD) {
                StrCat(command, sizeof(command), "FORWARD ");
        }
        if (buttons & IN_BACK) {
                StrCat(command, sizeof(command), "BACK ");
        }
        if (buttons & IN_USE) {
                StrCat(command, sizeof(command), "USE ");
        }
        if (buttons & IN_JUMP) {
                StrCat(command, sizeof(command), "JUMP ");
        }
        if (buttons != 0) {PrintToChatAll("%s: %s", name, command);}
#endif
#if DEBUG_ANGLE
        // angles
        PrintToChatAll("%s: angles(%f,%f,%f)", name, angles[0], angles[1], angles[2]);
#endif
#if DEBUG_VEL
        // vel
        if (vel[0] != 0.0 || vel[1] != 0.0) {
                PrintToChatAll("%s: vel(%f,%f,%f)", name, vel[0], vel[1], vel[2]);
        }
#endif
#if DEBUG_AIM
    // GetClientAimTargetで
        // AIMが向いてる方向にあるクライアントを取得後に
        // 見えてるか判定
        new entity = GetClientAimTarget(client, true);
        if (entity > 0) {
                new String:target[256];
                new visible = isVisibleTo(client, entity);
                // クライアントのエンティティ
                GetClientName(entity, target, 256);
                PrintToChatAll("%s aimed to %s (%s)", name, target, (visible ? "visible" : "invisible"));
        }
#endif
#if DEBUG_POS
        new Float:org[3], Float:eye[3];
        GetClientAbsOrigin(client, org);
        GetClientEyePosition(client, eye);
        PrintToChatAll("----");
        PrintToChatAll("AbsOrigin: (%f,%f,%f)", org[0], org[1], org[2]);
        PrintToChatAll("EyePosition: (%f,%f,%f)", eye[0], eye[1], eye[2]);
#endif
}

/**
 * 各クライアントの現在の移動速度を計算する
 *
 * g_move_speedは生存者が直線に走ったときが220くらい
 * 走っているとか止まっている判定できる
 */
new Float:g_move_grad[MAXPLAYERS1][3];
new Float:g_move_speed[MAXPLAYERS1];
new Float:g_pos[MAXPLAYERS1][3];
public Action:timerMoveSpeed(Handle:timer)
{
        for (new i = 1; i <= MaxClients; ++i) {
                if (IsClientInGame(i) && IsPlayerAlive(i)) {
                        new team = GetClientTeam(i);
                        if (team == 2 || team == 3) { // survivor or infected
                                new Float:pos[3];

                                GetClientAbsOrigin(i, pos);
                                g_move_grad[i][0] = pos[0] - g_pos[i][0];
                                 // yジャンプしてるときにおかしくなる..
                                g_move_grad[i][1] = pos[1] - g_pos[i][1];
                                g_move_grad[i][2] = pos[2] - g_pos[i][2];
                                // スピードに高さ方向は考慮しない
                                g_move_speed[i] =
                                        SquareRoot(g_move_grad[i][0] * g_move_grad[i][0] +
                                                           g_move_grad[i][1] * g_move_grad[i][1]);
                                if (g_move_speed[i] > MOVESPEED_MAX) {
                                        // ワープやリスポンしたっぽいときはクリア
                                        g_move_speed[i] = 0.0;
                                        g_move_grad[i][0] = 0.0;
                                        g_move_grad[i][1] = 0.0;
                                        g_move_grad[i][2] = 0.0;
                                }
                                g_pos[i] = pos;
#if DEBUG_SPEED
                                if (!IsFakeClient(i)) {
                                        // 俺
                                        PrintToChat(i, "speed: %f(%f,%f,%f)",
                                                                g_move_speed[i],
                                                                g_move_grad[i][0], g_move_grad[i][1], g_move_grad[i][2]
                                                );
                                }
#endif
                        }
                }
        }
        return Plugin_Continue;
}

stock Float:getMoveSpeed(client)
{
        return g_move_speed[client];
}
stock Float:getMoveGradient(client, ax)
{
        return g_move_grad[client][ax];
}

public bool:traceFilter(entity, mask, any:self)
{
        return entity != self;
}

/* clientからtargetの頭あたりが見えているか判定 */
stock bool:isVisibleTo(client, target)
{
        new bool:ret = false;
        new Float:angles[3];
        new Float:self_pos[3];

        GetClientEyePosition(client, self_pos);
        computeAimAngles(client, target, angles);
        new Handle:trace = TR_TraceRayFilterEx(self_pos, angles, MASK_SOLID, RayType_Infinite, traceFilter, client);
        if (TR_DidHit(trace)) {
                new hit = TR_GetEntityIndex(trace);
                if (hit == target) {
                        ret = true;
                }
        }
        CloseHandle(trace);
        return ret;
}
// clientからtargetへのアングルを計算
stock computeAimAngles(client, target, Float:angles[3], AimTarget:type = AimTarget_Eye)
{
        new Float:target_pos[3];
        new Float:self_pos[3];
        new Float:lookat[3];

        GetClientEyePosition(client, self_pos);
        switch (type) {
        case AimTarget_Eye: {
                GetClientEyePosition(target, target_pos);
        }
        case AimTarget_Body: {
                GetClientAbsOrigin(target, target_pos);
        }
        case AimTarget_Chest: {
                GetClientAbsOrigin(target, target_pos);
                target_pos[2] += 45.0; // このくらい
        }
        }
        MakeVectorFromPoints(self_pos, target_pos, lookat);
        GetVectorAngles(lookat, angles);
}
// 生存者の場合ダウンしてるか？
stock bool:isIncapacitated(client)
{
    new bool:bIsIncapped = false;
	if ( IsSurvivor(client) ) {
		if (GetEntProp(client, Prop_Send, "m_isIncapacitated") > 0) bIsIncapped = true;
		if (!IsPlayerAlive(client)) bIsIncapped = true;
	}
	return bIsIncapped;
}
stock bool:hasPinned(client) {
	new bool:bhasPinned = false;
	if (IsSurvivor(client)) {
		// check if held by:
		if( GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0 ) bhasPinned = true; // hunter
		if( GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0 ) bhasPinned = true; // charger pound
		if( GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0 ) bhasPinned = true; // charger carry
	}		
	return bhasPinned;
}
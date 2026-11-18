#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>
#include <treeutil>
#include <logger2>
#include <actions>

// For debug print vector direction, positon
#include <vector_show>


// ======== Included from: ./setup.inc ========

#include <sdkhooks>
#include <dhooks>

// =========================================================================
// Public Defines
// =========================================================================
#define CVAR_FLAGS							FCVAR_NOTIFY

#define GAMEDATA 							"l4d2_ai_charger3"
#define SIG_GET_RUN_TOP_SPEED 				"CTerrorPlayer::GetRunTopSpeed"
#define SIG_IS_CHARGE_BLOCKED 				"Charger::IsChargeBlocked"
#define SIG_PATH_FOLLOWER_UPDATE			"PathFollower::Update"
#define SIG_NEXTBOT_GET_COMBAT_CHARACTER 	"INextBot::GetNextBotCombatCharacter"
#define OFFSET_PATH_FOLLOWER_GOAL			"PathFollower::m_goal"
#define SIG_PATH_GET_CUR_GOAL				"Path::GetCurrentGoal"
#define SIG_PATH_INVALIDATE					"Path::Invalidate"
#define SIG_PATH_NEXT_SEGMENT				"Path::NextSegment"
#define SIG_PATH_PRIOR_SEGMENT				"Path::PriorSegment"
#define SIG_PATH_LAST_SEGMENT 				"Path::LastSegment"
#define	SIG_MY_NEXTBOT_POINTER				"CBaseEntity::MyNextBotPointer"
#define SIG_NEXTBOT_GET_LOCOMOTION			"INextBot::GetLocomotionInterface"
#define SIG_LOCOMOTION_APPROACH				"ILocomotion::Approach"
#define SIG_LOCOMOTION_FACE_TO				"ILocomotion::FaceTowards"
#define SIG_LOCOMOTION_HAS_POTENTIAL_GAP	"ILocomotion::HasPotentialGap"

#define PLAYER_HEIGHT 						72.0
#define JUMP_HEIGHT							57.0	// PlayerLocomotion::GetMaxJumpHeight 返回 57.0

#define DEFAULT_CHARGE_SPEED 				500.0
#define DEFAULT_MELEE_RANGE 				70.0
#define DEFAULT_MELEE_DMG_CHARGER 			390
#define DEFAULT_GRAVITY 					800.0
#define DEFAULT_SURVIVOR_SPEED 				220.0
#define DROP_DOWN_THRESHOLD					200.0
#define TARGET_VULNERABLE_ADV_CHECK_DIST	250.0
#define UNAVOIDABLE_TARGET_DIST_BUFFER		120.0
#define EVADE_MOVETO_REFRESH_MIN_DIST		50.0		// 目标至少移动该距离才重建 BehaviorMoveTo, 避免微小位置抖动反复寻路
#define STATE_TOLERANCE_DIST                50.0		// 状态转换容差距离
#define CHARGE_Z_THRESHOLD                  57.0    	// charger 冲锋时, 如果与目标的高度差超过该值, 则取消冲锋
#define PI									3.14159265

// 空中速度修正插值系数
#define AIR_CHARGE_LINE_CORR_LERP           0.85
#define AIR_CHARGE_LINE_CORR_LOCK_LERP      0.95
#define AIR_CHARGE_LINE_CORR_CHARGE_LERP    0.90
#define AIR_CHARGE_LINE_MIN_PREDICT_TIME    0.05
#define AIR_CHARGE_LINE_MAX_PREDICT_TIME    0.25

// =========================================================================
// ConVars
// =========================================================================
ConVar
	g_cvBhop,					// 是否允许普通连跳 (STATE APPROACH 时的连跳)
	g_cvBhopMinDist,			// 禁止连跳的最小距离
	g_cvDirectBhopDist,			// 朝着目标直线连跳的最小距离
	g_cvBhopMaxDist,			// 允许连跳的最大距离
	g_cvBhopMinSpeed,			// 允许连跳的最小速度
	g_cvBhopMaxSpeed,			// 连跳的最大速度
	g_cvBhopMaxHeight,			// 连跳相对起跳地面的最大高度
	g_cvBhopBeforeCharge,		// 冲锋前是否允许进行接近连跳
	g_cvBhopImpulse,			// 连跳加速度
	g_cvBhopNoVision,			// 是否允许无视野连跳
	g_cvBhopNoVisionMaxAng,		// 无视野时自身速度方向与视角方向夹角小于这个值允许连跳
	g_cvTargetWatchMaxDeg,		// 目标视角向量与到 charger 的位置向量夹角小于这个值时认为目标正在看着 charger, 用于控制侧向连跳等
	g_cvBhopStrafeMinDist,		// 禁止侧向连跳的最小距离 (距离目标小于这个距离, 禁止侧向连跳)
	g_cvBhopStrafeMinDeg,		// 目标看着 charger 时, 连跳方向向基准方向左右偏移的最小角度
	g_cvBhopStrafeMaxDeg,		// 目标看着 charger 时, 连跳方向向基准方向左右偏移的最大角度
	g_cvBhopStrafeOnceDist,		// 左右侧向连跳一次的最小距离限制 (距离 Goal Pos 小于这个值时不允许侧向连跳)
	g_cvBhopStrafeTwiceDist,	// 左右侧向连跳两次的最小距离限制 (距离 Goal Pos 大于这个值且以当前速度一跳可达才允许左右侧向连跳两次)
	g_cvMeleeBaitZoneMinRange,	// 目标拿着近战时, 近战博弈区的最小范围, melee_range + 这个值
	g_cvMeleeBaitZoneMaxRange,	// 目标拿着近战时, 近战博弈区的最大范围, melee_range + 这个值
	g_cvAirVecModifyMinDegree,	// 在空中 charger 到目标方向向量与速度向量夹角超过这个值进行速度修正
	g_cvAirVecModifyMaxDegree,	// 在空中 charger 到目标方向向量与速度向量夹角超过这个值放弃修正
	g_cvAirVecModifyInterval,	// 空中速度修正间隔
	g_cvAirVecModifyLerp,		// 空中速度修正转向插值因子
	g_cvBaitMaxDuration,		// charger 进入博弈状态的最长时间
	g_cvProbChargeChkDur,		// 概率冲锋时的检测间隔
	g_cvProbChargeProb,			// 概率冲锋的概率到达这个数值可冲锋
	g_cvAntiRetreat,			// 是否阻止 charger 逃跑
	g_cvEvadeMoveToRefreshInterval,	// ChargerEvade 生成的 BehaviorMoveTo 目标坐标刷新间隔
	g_cvPathLookAheadMaxDepth,	// 向前搜索 PathSegment 的最大深度
	g_cvEarlyChargeHealth,		// 提前冲锋的血量阈值
	g_cvEarlyChargeDist;		// 提前冲锋的距离阈值

// ai_charger_2 兼容配置。旧配置继续使用原名称，内部转换为 3.0 的行为参数。
ConVar
	g_cvLegacyBhop,
	g_cvLegacyBhopSpeed,
	g_cvLegacyChargeDistance,
	g_cvLegacyExtraTargetDistance,
	g_cvLegacyAimOffset,
	g_cvLegacyMeleeAvoid,
	g_cvLegacyMeleeDamage,
	g_cvLegacyTarget,
	g_cvLegacyChargeHeightDiff;

float g_fLegacyExtraTargetMin;
float g_fLegacyExtraTargetMax;

// =========================================================================
// AI Charger Data
// =========================================================================

enum SegmentType {
	SegType_OnGround,
	SegType_DropDown,
	SegType_ClimbUp,
	SegType_JumpOverGap,
	SegType_LadderUp,
	SegType_LadderDown,
	SegType_Size
}

enum struct PathSegment {
	Address m_pPathSegment;			// 指向该 PathSegment 结构体的指针
	Address m_pNavArea;				// 指向该 NavArea 的指针
	int m_iNavTraverseType;			// 如何从上一个 PathSegment 到该 PathSegment 的移动方式
	float m_vecGoalPos[3];			// 目标点
	SegmentType m_SegmentType;		// 如何移动到该 PathSegment
	float m_vecForward[3];			// 路径前进方向
	float m_flLength;				// 路径长度
	float m_flDistFromStart;		// 当前 PathSegment 到起始点的距离

	void init() {
		this.m_pPathSegment = Address_Null;
		this.m_pNavArea = Address_Null;
		ZeroVector(this.m_vecGoalPos);
		ZeroVector(this.m_vecForward);
	}
}

enum StrafeDir {
	StrafeDir_None = 0,
	StrafeDir_Left = 1,
	StrafeDir_Right = -1,
	StrafeDir_Size
}

enum StrafeType {
	StrafeType_None = -1,
	StrafeType_Once,
	StrafeType_Twice,
	StrafeType_Size
}

enum struct AirStrafe {
	float m_flStrafeStartDist;	// 准备执行侧向连跳时, 计算的 Charger 当前位置到 Goal Pos 的距离
	float m_flStrafeAmp;		// 侧向连跳的振幅
	StrafeDir m_StrafeDir;		// 侧向连跳的方向
	StrafeType m_StrafeType;	// 侧向连跳的类型
	
	void init() {
		this.m_flStrafeStartDist = 0.0;
		this.m_flStrafeAmp = 0.0;
		this.m_StrafeDir = StrafeDir_None;
		this.m_StrafeType = StrafeType_None;
	}
}

enum BhopType {
	BhopType_None,
	BhopType_Path,				// 沿着 Path 进行连跳
	BhopType_DirectCandidate,	// 距离目标小于直线连跳阈值, 但还在验证路径是否安全
	BhopType_Normal,			// 朝着目标直线连跳
	BhopType_BaitRetreat,		// 近战 Bait 状态中正在执行向后跳
	BhopType_Repathing,			// 已经到达当前 Path 末尾, 正在重新找一条新的 Path (c4m2 楼梯口, 当前 Path 末端在楼梯口, 但是 Charger 应该从旁边绕过来)
	BhopType_Size
}

enum struct AiCharger {
	int m_iTarget;						// 当前目标 userId
	int m_iBetterTarget;				// 更好的目标 userId
	bool m_bChargeDelayed;				// 目前冲撞能力是否被人为延时
	bool m_bHasAirBreaked;				// 在空中时是否急停过了
	bool m_bBhopBeforeCharge;			// 冲锋之前是否进行了最后一次连跳
	bool m_bEvadeMoveCommandActive;	// ChargerEvade 是否已经下发 BOT_CMD_MOVE 追击命令
	bool m_bBhopHeightValid;			// 是否已记录本次连跳的起跳地面高度
	
	float m_flLastHopSpeed;				// 上次起跳的速度
	float m_flBhopGroundZ;				// 本次连跳起跳点的地面高度
	float m_flFinalBhopStartTime;		// 冲锋前最后一次连跳开始时间, 用于短暂等待落地/进入 commit range
	float m_flLastLookAheadTime;		// 上次节点前向遍历时间
	float m_flLastAirVecModifyTime;		// 上次目标修正时间
	float m_flLastProbChargeChkTime;	// 上次概率冲锋的检测时间
	float m_flLastVisibleTime;			// 当前状态中上次看到目标的时间
	float m_flLastEvadeMoveToCheckTime;	// 上次检查 BehaviorMoveTo 目标坐标是否过期的时间
	float m_vecEvadeMoveToPos[3];		// 当前 BehaviorMoveTo 创建时使用的目标坐标
	Address m_pPathFollower;			// Path Follower 的指针, 用于前瞻 Goal Pos
	PathSegment m_PathSegment;			// Charger 当前 NextBot 寻路的 PathSegment
	PathSegment m_NextPathSegment;		// 当前 PathSegment 的下一个 PathSegment
	PathSegment m_LastPathSegment;		// Charger 当前 NextBot 寻路的当前路径最后一个 PathSegment
	float m_vecAirCorrGoal[3];			// 空中速度修正的前瞻目标点 (一跳内最远且无障碍的 segment goal)
	AirStrafe m_AirStrafe;				// 连跳空中侧向偏移数据
	BhopType m_BhopType;				// 连跳类型 (基于 PATH 或基于目标)

	float m_flPathWaitStart;			// Charger 开始等待下一次 RePath 的时间
	float m_flLastPathInvalidateTime;	// Charger 上次 Path 人为失效时间

	void init() {
		this.m_iTarget = -1;
		this.m_iBetterTarget = -1;
		this.m_bChargeDelayed = false;
		this.m_bHasAirBreaked = false;
		this.m_bBhopBeforeCharge = false;
		this.m_BhopType = BhopType_None;
		this.m_flLastHopSpeed = 0.0;
		this.m_flBhopGroundZ = 0.0;
		this.m_bBhopHeightValid = false;
		this.m_flFinalBhopStartTime = 0.0;
		this.m_flLastLookAheadTime = 0.0;
		this.m_flLastAirVecModifyTime = 0.0;
		this.m_flLastProbChargeChkTime = 0.0;
		this.m_flLastVisibleTime = 0.0;
		this.m_bEvadeMoveCommandActive = false;
		this.m_flLastEvadeMoveToCheckTime = 0.0;
		ZeroVector(this.m_vecEvadeMoveToPos);
		this.m_flPathWaitStart = -1.0;
		this.m_flLastPathInvalidateTime = -1.0;
		this.m_pPathFollower = Address_Null;
		this.m_PathSegment.init();
		this.m_NextPathSegment.init();
		this.m_LastPathSegment.init();
		ZeroVector(this.m_vecAirCorrGoal);
		this.m_AirStrafe.init();
	}
}
AiCharger g_AiChargers[MAXPLAYERS + 1];

// 定义状态函数原型 Funcion Properties
typedef StateFunc_Enter = function void(int client);
typedef StateFunc_Update = function Action(int client, int& buttons, float vel[3], float ang[3]);
typedef StateFunc_Exit = function void(int client);

// Charger 状态枚举
enum {
	CH_STATE_NONE = -1,
	CH_STATE_APPROACH = 0,	// 接近目标中
	CH_STATE_BAIT,			// 与目标博弈
	CH_STATE_LOCKED, 		// 锁定目标, 准备冲撞
	CH_STATE_CHARGING, 		// 冲锋中
	CH_STATE_COUNT,			// 状态计数
}

// =========================================================================
// 每个状态的描述数组
// =========================================================================
enum struct ChargerState {
	char name[64];				// 状态名称
	StateFunc_Enter OnEnter;	// 进入状态函数指针
	StateFunc_Update OnUpdate;	// 状态更新函数指针
	StateFunc_Exit OnExit;		// 退出状态函数指针
}

ArrayList g_ChargerStates;

// =========================================================================
// Charger 状态管理器 (持有一个当前状态 ID, 负责状态转换与执行)
// 1. TransitionTo(int newStateId) 用于进行状态转换
// 2. update(int& buttons, float vel[3], float ang[3]) 由 OnPlayerRunCmd 调用, 用于每帧执行当前状态
// =========================================================================   
enum struct ChargerStateContext {
	int userId;
	int currentStateId;	// 状态 ID
	float startTime;	// 持续时间

	// 状态管理器初始化
	void init(int client) {
		if (!IsValidInfected(client) || GetInfectedClass(client) != ZC_CHARGER
			|| !IsPlayerAlive(client) || !IsFakeClient(client) || IsInGhostState(client))
			return;
		
		this.userId = GetClientUserId(client);
		this.currentStateId = CH_STATE_NONE;
		this.startTime = GetGameTime();
	}

	// 状态转移
	void transitionTo(int newStateId) {
		if (newStateId == this.currentStateId)
			return;
		if (!IsValidClient(GetClientOfUserId(this.userId)))
			return;

		// 执行旧状态的退出逻辑。必须先读取当前状态，再检查 OnExit，
		// 否则静态 oldState 会一直保留初始空值，导致所有状态的清理函数都被跳过。
		static ChargerState oldState;
		if (this.currentStateId != CH_STATE_NONE) {
			g_ChargerStates.GetArray(this.currentStateId, oldState, sizeof(oldState));
			if (oldState.OnExit != INVALID_FUNCTION) {
				Call_StartFunction(INVALID_HANDLE, oldState.OnExit);
				Call_PushCell(GetClientOfUserId(this.userId));
				Call_Finish();
			}
		}

		// 设置状态管理器的当前状态 ID 和开始时间
		this.currentStateId = newStateId;
		this.startTime = GetGameTime();

		// 执行新状态的进入逻辑
		static ChargerState newState;
		g_ChargerStates.GetArray(this.currentStateId, newState, sizeof(newState));
		if (newState.OnEnter != INVALID_FUNCTION) {
			Call_StartFunction(INVALID_FUNCTION, newState.OnEnter);
			Call_PushCell(GetClientOfUserId(this.userId));
			Call_Finish();
		}
	}

	// 状态的每帧更新操作
	Action update(int& buttons, float vel[3], float ang[3]) {
		// 默认返回值, 如果没有状态或者没有 update 函数, 返回 Plugin_Continue
		Action res = Plugin_Continue;
		if (this.currentStateId == CH_STATE_NONE || g_ChargerStates == null)
			return res;

		// 获取当前状态
		static ChargerState curState;
		g_ChargerStates.GetArray(this.currentStateId, curState, sizeof(curState));

		if (curState.OnUpdate != INVALID_FUNCTION) {
			Call_StartFunction(INVALID_HANDLE, curState.OnUpdate);
			Call_PushCell(GetClientOfUserId(this.userId));
			Call_PushCellRef(buttons);
			Call_PushArrayEx(vel, 3, SM_PARAM_COPYBACK);
			Call_PushArrayEx(ang, 3, SM_PARAM_COPYBACK);
			Call_Finish(res);
		}

		return res;
	}

	// 获取当前状态执行时间
	float getStateDuration() {
		return GetGameTime() - this.startTime;
	}
}

ChargerStateContext g_ChargerStateContext[MAXPLAYERS + 1];

// =========================================================================
// 目标持有武器类型枚举
// =========================================================================
enum TargetThreatType{
	Threat_None,
	Threat_Shotgun,		// 目标正在拿着霰弹枪
	Threat_Melee,		// 目标正在拿着近战武器
	Threat_Normal,		// 正常的持枪玩家
}

// =========================================================================
// Setup 模块初始化与销毁
// =========================================================================
ConVar
	cvChargeSpeed,
	cvMeleeRange,
	cvMeleeDamageCharger,
	cvGravity;

Handle
	g_hSdkGetRunTopSpeed,
	g_hSdkIsChargeBlocked,
	g_hSdkNextBotGetCombatCharacter,
	g_hSdkPathGetCurGoal,
	g_hSdkPathInvalidate,
	g_hSdkPathNextSegment,
	g_hSdkPathPriorSegment,
	g_hSdkPathLastSegment,
	g_hSdkMyNextBotPointer,
	g_hSdkGetLocomotionInterface,
	g_hSdkLocomotionApproach,
	g_hSdkLocomotionFaceTo,
	g_hSdkHasPotentialGap;

Handle
	g_hPathFollowerDetour;

int
	g_iPathFollowerGoalOffset;

stock void SetUp_OnModuleStart() {
	// 初始化状态描述列表
	g_ChargerStates = new ArrayList(sizeof(ChargerState));
}

stock void SetUp_OnConfigsExecuted() {
	cvChargeSpeed = FindConVar("z_charge_max_speed");
	cvMeleeRange = FindConVar("melee_range");
	cvMeleeDamageCharger = FindConVar("melee_damage_charger");
	cvGravity = FindConVar("sv_gravity");
}

stock void SetUp_OnAllPluginsLoaded() {
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(path))
		SetFailState("Missing required gamedata file: %s", path);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load gamedata file: %s", path);

	// 读取 PathFollower::m_goal 成员的偏移量 (4 * 4566)
	g_iPathFollowerGoalOffset = hGameData.GetOffset(OFFSET_PATH_FOLLOWER_GOAL);
	if (g_iPathFollowerGoalOffset < 0)
		SetFailState("Failed to load offset: %s in gamedata file: %s.", OFFSET_PATH_FOLLOWER_GOAL, GAMEDATA);

	// ============================================================
	// Read SDK function 'CTerrorPlayer::GetRunTopSpeed'
	// ============================================================
	StartPrepSDKCall(SDKCall_Entity);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, SIG_GET_RUN_TOP_SPEED))
		SetFailState("Failed to load signature: %s in gamedata file: %s.", SIG_GET_RUN_TOP_SPEED, GAMEDATA);
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
	g_hSdkGetRunTopSpeed = EndPrepSDKCall();
	if (!g_hSdkGetRunTopSpeed)
		SetFailState("Could not prep the %s function.", SIG_GET_RUN_TOP_SPEED);

	// =========================================================================
	// Read SDK function 'Charger::IsChargeBlocked'
	// =========================================================================
	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, SIG_IS_CHARGE_BLOCKED))
		SetFailState("Failed to load signature: %s in gamedata file: %s.", SIG_IS_CHARGE_BLOCKED, GAMEDATA);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSdkIsChargeBlocked = EndPrepSDKCall();
	if (!g_hSdkIsChargeBlocked)
		SetFailState("Could not prep the %s function.", SIG_IS_CHARGE_BLOCKED);

	// ============================================================
	// PathFollower::Update Detour
	// ============================================================
	g_hPathFollowerDetour = DHookCreateFromConf(hGameData, SIG_PATH_FOLLOWER_UPDATE);
	if (!g_hPathFollowerDetour)
		SetFailState("Failed to create detour for signature: %s in gamedata file: %s.", SIG_PATH_FOLLOWER_UPDATE, GAMEDATA);
	if (!DHookEnableDetour(g_hPathFollowerDetour, false, Detour_PathFollower_Update))
		SetFailState("Failed to enable detour for signature: %s in gamedata file: %s.", SIG_PATH_FOLLOWER_UPDATE, GAMEDATA);

	// ============================================================
	// CBaseCombatCharacter* GetEntity( void ) const
	// ============================================================
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, SIG_NEXTBOT_GET_COMBAT_CHARACTER))
		SetFailState("Failed to load signature: %s in gamedata file: %s.", SIG_NEXTBOT_GET_COMBAT_CHARACTER, GAMEDATA);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSdkNextBotGetCombatCharacter = EndPrepSDKCall();
	if (!g_hSdkNextBotGetCombatCharacter)
		SetFailState("Failed to prep sdk call for signature %s", SIG_NEXTBOT_GET_COMBAT_CHARACTER);

	// ============================================================
	// int __cdecl PathFollower::GetCurrentGoal(PathFollower *this)
	// ============================================================
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, SIG_PATH_GET_CUR_GOAL))
		SetFailState("Failed to load offset for signature %s", SIG_PATH_GET_CUR_GOAL);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSdkPathGetCurGoal = EndPrepSDKCall();
	if (!g_hSdkPathGetCurGoal)
		SetFailState("Failed to prep sdk call for signature %s", SIG_PATH_GET_CUR_GOAL);

	// ============================================================
	// void Path::Invalidate()
	// ============================================================
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, SIG_PATH_INVALIDATE))
		SetFailState("Failed to load offset for signature %s", SIG_PATH_INVALIDATE);
	g_hSdkPathInvalidate = EndPrepSDKCall();
	if (!g_hSdkPathInvalidate)
		SetFailState("Failed to prep sdk call for signature %s", SIG_PATH_INVALIDATE);

	// ============================================================
	// Path::Segment* NextSegment( const Path::Segment* currentSegment )
	// given current segment, return next segment
	// ============================================================
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, SIG_PATH_NEXT_SEGMENT))
		SetFailState("Failed to load offset for signature %s", SIG_PATH_NEXT_SEGMENT);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_hSdkPathNextSegment = EndPrepSDKCall();
	if (!g_hSdkPathNextSegment)
		SetFailState("Failed to prep sdk call for signature %s", SIG_PATH_NEXT_SEGMENT);

	// ============================================================
	// Path::PriorSegment(Path::Segment const*) const
	// ============================================================
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, SIG_PATH_PRIOR_SEGMENT))
		SetFailState("Failed to load offset for signature %s", SIG_PATH_PRIOR_SEGMENT);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_hSdkPathPriorSegment = EndPrepSDKCall();
	if (!g_hSdkPathPriorSegment)
		SetFailState("Failed to prep sdk call for signature %s", SIG_PATH_PRIOR_SEGMENT);

	// ============================================================
	// Path::Segment* Path::LastSegment(void)
	// ============================================================
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, SIG_PATH_LAST_SEGMENT))
		SetFailState("Failed to load offset for signature %s", SIG_PATH_LAST_SEGMENT);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSdkPathLastSegment = EndPrepSDKCall();
	if (!g_hSdkPathLastSegment)
		SetFailState("Failed to prep sdk call for signature %s", SIG_PATH_LAST_SEGMENT);

	// ============================================================
	// int CBaseEntity::MyNextBotPointer()
	// ============================================================
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, SIG_MY_NEXTBOT_POINTER))
		SetFailState("Failed to load offset for signature %s", SIG_MY_NEXTBOT_POINTER);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSdkMyNextBotPointer = EndPrepSDKCall();
	if (!g_hSdkMyNextBotPointer)
		SetFailState("Failed to prep sdk call for signature %s", SIG_MY_NEXTBOT_POINTER);

	// ============================================================
	// INextBot::GetLocomotionInterface() const
	// ============================================================
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, SIG_NEXTBOT_GET_LOCOMOTION))
		SetFailState("Failed to load offset for signature %s", SIG_NEXTBOT_GET_LOCOMOTION);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSdkGetLocomotionInterface = EndPrepSDKCall();
	if (!g_hSdkGetLocomotionInterface)
		SetFailState("Failed to prep sdk call for signature %s", SIG_NEXTBOT_GET_LOCOMOTION);

	// ============================================================
	// ILocomotion::Approach(Vector const&, float)
	// ============================================================
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, SIG_LOCOMOTION_APPROACH))
		SetFailState("Failed to load offset for signature %s", SIG_LOCOMOTION_APPROACH);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	g_hSdkLocomotionApproach = EndPrepSDKCall();
	if (!g_hSdkLocomotionApproach)
		SetFailState("Failed to prep sdk call for signature %s", SIG_LOCOMOTION_APPROACH);

	// ============================================================
	// ILocomotion::FaceTowards(Vector const&)
	// ============================================================
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, SIG_LOCOMOTION_FACE_TO))
		SetFailState("Failed to load offset for signature %s", SIG_LOCOMOTION_FACE_TO);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	g_hSdkLocomotionFaceTo = EndPrepSDKCall();
	if (!g_hSdkLocomotionFaceTo)
		SetFailState("Failed to prep sdk call for signature %s", SIG_LOCOMOTION_FACE_TO);

	// ============================================================
	// ILocomotion::HasPotentialGap(Vector const&, Vector const&, float*) const
	// ============================================================
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, SIG_LOCOMOTION_HAS_POTENTIAL_GAP))
		SetFailState("Failed to load offset for signature %s", SIG_LOCOMOTION_HAS_POTENTIAL_GAP);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_ByRef);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSdkHasPotentialGap = EndPrepSDKCall();
	if (!g_hSdkHasPotentialGap)
		SetFailState("Failed to find signature %s", SIG_LOCOMOTION_HAS_POTENTIAL_GAP);

	delete hGameData;
}

stock void SetUp_OnModuleEnd() {
	delete g_ChargerStates;
}

// ======== End of: ./setup.inc ========

// ======== Included from: ./stocks.inc ========



// ======== Included from: ./setup.inc ========

// ======== End of: ./setup.inc ========

#define STOCK_LOG_PREFIX "AI-ChargerStock"

Logger
    stockLog;

ConVar
    g_cvStockLogLevel;

stock void Stock_OnModuleStart(ConVar& cvPluginName) {
    if (!cvPluginName) {
        g_cvStockLogLevel = CreateConVar("_ai_charger3_stock_log_level", "38", "工具模块的日志记录级别, 1=关闭, 2=控制台输出, 4=log文件输出, 8=聊天框输出, 16=服务器控制台输出, 32=error文件输出, 数字相加", CVAR_FLAGS);
    } else {
        char cvName[64], stockLogCvName[64];
        cvPluginName.GetString(cvName, sizeof(cvName));
        FormatEx(stockLogCvName, sizeof(stockLogCvName), "_%s_stock_log_level", cvName);
        g_cvStockLogLevel = CreateConVar(stockLogCvName, "38", "状态模块的日志记录级别, 1=关闭, 2=控制台输出, 4=log文件输出, 8=聊天框输出, 16=服务器控制台输出, 32=error文件输出, 33=所有输出", CVAR_FLAGS);
    }

    stockLog = new Logger(STOCK_LOG_PREFIX, g_cvStockLogLevel.IntValue);
}

stock void Stock_OnModuleEnd() {
    delete stockLog;
}

stock bool isAiCharger(int client) {
    return IsValidInfected(client) && GetInfectedClass(client) == ZC_CHARGER &&
            IsFakeClient(client) && IsPlayerAlive(client) && !IsInGhostState(client);
}

/**
* 限制 Charger 连跳相对起跳地面的最大高度。
* 正常跳跃不会受到影响；异常向上速度会被削减，已经越界时直接压回上限。
* 只修改垂直速度，保留连跳的水平移动与空中方向修正。
**/
stock void limitBhopJumpHeight(int client) {
    // 冲锋、控人、梯子等非连跳移动不干预，并废弃旧基准，避免之后误用
    if (isChargerCharging(client) || IsPinningSurvivor(client) ||
        GetEntityMoveType(client) != MOVETYPE_WALK) {
        g_AiChargers[client].m_bBhopHeightValid = false;
        return;
    }

    static float pos[3];
    GetClientAbsOrigin(client, pos);

    // 每次接触地面都刷新基准，因此上下坡后的下一次连跳仍从实际地面计算
    if (IsClientOnGround(client)) {
        g_AiChargers[client].m_flBhopGroundZ = pos[2];
        g_AiChargers[client].m_bBhopHeightValid = true;
        return;
    }

    // 插件接管时已经在空中，则以当前位置建立安全基准，避免错误传送
    if (!g_AiChargers[client].m_bBhopHeightValid) {
        g_AiChargers[client].m_flBhopGroundZ = pos[2];
        g_AiChargers[client].m_bBhopHeightValid = true;
        return;
    }

    static float maxHeight;
    maxHeight = g_cvBhopMaxHeight.FloatValue;
    if (maxHeight <= 0.0)
        return;

    static float height, remainingHeight, gravity, maxUpSpeed;
    static float velocity[3];
    GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", velocity);
    height = pos[2] - g_AiChargers[client].m_flBhopGroundZ;

    // 已经高于上限时压回上限，并清除仍向上的速度；水平速度保持不变
    if (height >= maxHeight && (height > maxHeight || velocity[2] > 0.0)) {
        pos[2] = g_AiChargers[client].m_flBhopGroundZ + maxHeight;
        if (velocity[2] > 0.0)
            velocity[2] = 0.0;
        TeleportEntity(client, pos, NULL_VECTOR, velocity);
        return;
    }

    gravity = !cvGravity ? DEFAULT_GRAVITY : cvGravity.FloatValue;
    if (gravity <= 0.0)
        return;

    // 按 v² / (2g) 预先限制本帧上升速度，使本次跳跃的抛物线顶点不超过上限
    remainingHeight = maxHeight - height;
    maxUpSpeed = SquareRoot(2.0 * gravity * remainingHeight);
    if (velocity[2] > maxUpSpeed) {
        velocity[2] = maxUpSpeed;
        TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
    }
}

stock bool allowToBhop(int client) {
    if (!isAiCharger(client))
        return false;
    
    // 处于 APPROACH STATE 且不允许接近状态时连跳或处于 CHARGING STATE 时不允许冲锋前连跳
    if (
        (g_ChargerStateContext[client].currentStateId == CH_STATE_APPROACH && !g_cvBhop.BoolValue) ||
        (g_ChargerStateContext[client].currentStateId == CH_STATE_CHARGING && !g_cvBhopBeforeCharge.BoolValue)
    ) {
        return false;
    }

    if (L4D_IsPlayerStaggering(client))
        return false;
    
    if (GetEntityMoveType(client) == MOVETYPE_LADDER || GetEntProp(client, Prop_Data, "m_nWaterLevel") > 1)
        return false;
    
    // 当前需要上下梯子或者爬上障碍物, 不允许连跳
    static PathSegment curSeg;
    curSeg = g_AiChargers[client].m_PathSegment;
    if (
        curSeg.m_pPathSegment && curSeg.m_SegmentType == SegType_ClimbUp ||
        curSeg.m_pPathSegment && curSeg.m_SegmentType == SegType_LadderUp ||
        curSeg.m_pPathSegment && curSeg.m_SegmentType == SegType_LadderDown
    ) {
        return false;
    }

    return true;
}

stock bool isNearLadder(int client, const float checkDist) {
    static int entity;
    entity = -1;
    static float pos[3], origin[3], mins[3], maxs[3], nearest[3];
    L4D_GetEntityWorldSpaceCenter(client, pos);
    while ((entity = FindEntityByClassname(entity, "func_simpleladder")) != -1) {
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
        GetEntPropVector(entity, Prop_Send, "m_vecMins", mins);
        GetEntPropVector(entity, Prop_Send, "m_vecMaxs", maxs);

        AddVectors(origin, mins, mins);
        AddVectors(origin, maxs, maxs);

        nearest[0] = (pos[0] < mins[0]) ? mins[0] : ((pos[0] > maxs[0]) ? maxs[0] : pos[0]);
        nearest[1] = (pos[1] < mins[1]) ? mins[1] : ((pos[1] > maxs[1]) ? maxs[1] : pos[1]);
        nearest[2] = (pos[2] < mins[2]) ? mins[2] : ((pos[2] > maxs[2]) ? maxs[2] : pos[2]);

        if (GetVectorDistance(pos, nearest) <= checkDist) {
            return true;
        }
    }
    return false;
}

stock int getChargeAbilityEnt(int client) {
    if (!isAiCharger(client))
        return -1;

    static int ability;
    static char clsName[32];
    ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
    if (!IsValidEdict(ability))
        return -1;
    GetEntityClassname(ability, clsName, sizeof(clsName));
    if (strcmp(clsName, "ability_charge", false) != 0)
        return -1;

    return ability;
}

stock bool isChargerCharging(int client) {
    if (!isAiCharger(client))
        return false;
    
    static int ability;
    ability = getChargeAbilityEnt(client);
    if (!IsValidEdict(ability))
        return false;
    
    return view_as<bool>(GetEntProp(ability, Prop_Send, "m_isCharging"));
}

/**
* 检查 Charger 冲撞能力是否就绪
* @param client 客户端索引
* @return bool, true 就绪, false 未就绪
**/
stock bool isChargeAbilityReady(int client) {
    if (!isAiCharger(client))
        return false;

    static int ability;
    ability = getChargeAbilityEnt(client);
    if (!IsValidEdict(ability))
        return false;
    
    static float timestamp;
    timestamp = GetEntPropFloat(ability, Prop_Send, "m_timestamp");
    // ============================================================
    // 1. 如果技能就绪时刻大于当前时刻, 且是人为延时, 则说明技能其实可以准备就绪, 允许冲锋
    // 2. 如果技能就绪时刻小于当前时刻, 允许冲锋
    // ============================================================
    if (timestamp > GetGameTime() && g_AiChargers[client].m_bChargeDelayed)
        return true;
    if (timestamp <= GetGameTime())
        return true;
    
    return false;
}

/**
* 检查目标是否处在 Charger 可以冲锋的高度范围内
* @param pos Charger 位置
* @param targetPos 目标位置
* @param threshold 最大允许高度差
* @return bool, true 表示高度可冲锋, false 表示高度差过大
**/
stock float getChargeHeightLimit(float threshold = -1.0) {
	if (threshold > 0.0)
		return threshold;
	if (g_cvLegacyChargeHeightDiff != null && g_cvLegacyChargeHeightDiff.FloatValue > 0.0)
		return g_cvLegacyChargeHeightDiff.FloatValue;
	return CHARGE_Z_THRESHOLD;
}

stock bool isChargeHeightReachable(const float pos[3], const float targetPos[3], float threshold = -1.0) {
	return FloatAbs(pos[2] - targetPos[2]) <= getChargeHeightLimit(threshold);
}

/**
* 检查目标实体是否处在 Charger 可以冲锋的高度范围内
* @param client Charger 客户端索引
* @param target 目标客户端索引
* @param threshold 最大允许高度差
* @return bool, true 表示高度可冲锋, false 表示高度差过大
**/
stock bool isChargeTargetHeightReachable(int client, int target, float threshold = -1.0) {
    if (!isAiCharger(client))
        return false;
    if (!IsValidSurvivor(target) || !IsPlayerAlive(target))
        return false;

    static float pos[3], targetPos[3];
    GetClientAbsOrigin(client, pos);
    GetClientAbsOrigin(target, targetPos);

    return isChargeHeightReachable(pos, targetPos, threshold);
}

/**
* 设置 Charger 冲锋技能的冷却时间
* @param client 客户端索引
* @param duration 冷却剩余时间 (0.0 = 立刻就绪, 0.5 = 锁定)
* @return void
**/
stock void setChargerAbilityCooldown(int client, float duration) {
    if (!isAiCharger(client))
        return;
    
    static int ability;
    ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
    if (!IsValidEntity(ability))
        return;
    
    static char clsName[32];
    GetEntityClassname(ability, clsName, sizeof(clsName));
    if (strcmp(clsName, "ability_charge", false) != 0)
        return;
    
    // =========================================================================
    // 检查能力冷却时间, 若能力就绪时间大于当前时间, 且无论 duration > 0.0 还是小于 0.0
    // 则说明还在冷却, 不处理, 避免能力还没就绪就直接设置为 GetGameTime() ± 0.1 导致能力立即就绪
    // =========================================================================
    static float timestamp, gameTime;
    timestamp = GetEntPropFloat(ability, Prop_Send, "m_timestamp");
    gameTime = GetGameTime();
    if (duration > 0.0) {
        // 如果当前已经处在自然冷却时间, 且 timestamp 远大于 gametime + duration, 返回
        if (timestamp > gameTime + duration && !g_AiChargers[client].m_bChargeDelayed)
            return;
        // 可以进行人为延迟, 进行标记
        SetEntPropFloat(ability, Prop_Send, "m_timestamp", gameTime + duration);
        g_AiChargers[client].m_bChargeDelayed = true;
    } else {
        // 如果是自然冷却, 不能重置
        if (timestamp > gameTime && !g_AiChargers[client].m_bChargeDelayed)
            return;
        // 只有是人为延迟的，或者已经就绪的，才允许重置, 并重置标记
        SetEntPropFloat(ability, Prop_Send, "m_timestamp", gameTime + duration);
        g_AiChargers[client].m_bChargeDelayed = false;
    }
}

/**
* 检查 Charger 冲锋路径 start 和 end 坐标中会不会被实体阻挡
* @param client 客户端索引
* @param start 起点坐标 (使用 GetWorldSpaceCenter 获得)
* @param end 终点坐标
* @return bool, false 表示无障碍, true 存在障碍
**/
stock bool isChargePathBlocked(int client, int target) {
    if (!isAiCharger(client))
        return false;
    if (!IsValidSurvivor(target) || !IsPlayerAlive(target))
        return false;

    static float start[3], end[3];
    L4D_GetEntityWorldSpaceCenter(client, start);
    L4D_GetEntityWorldSpaceCenter(target, end);
    return SDKCall(g_hSdkIsChargeBlocked, client, start, end);
}

/**
* 检查 charger 当前目标是否处在易受攻击状态
* @param client 客户端索引
* @param target 目标索引
* @return bool, true 表示易受攻击, false 表示非易受攻击
**/
stock bool isTargetVulnerable(int client, int target) {
    if (!isAiCharger(client))
        return false;
    if (!IsValidSurvivor(target) || !IsPlayerAlive(target))
        return false;
    
    static int weapon;
    weapon = GetEntPropEnt(target, Prop_Send, "m_hActiveWeapon");
    // 没有武器, 可以直接冲撞
    if (!IsValidEntity(weapon)) {
        //stockLog.debugAll("Charger (%N)'s target (%N) has no weaopn, can charge", client, target);
        return true;
    }

    static char weaponName[32];
    GetEntityClassname(weapon, weaponName, sizeof(weaponName));

    // 正在换弹中, 可以直接冲撞
    if (HasEntProp(weapon, Prop_Send, "m_bInReload") &&
        view_as<bool>(GetEntProp(weapon, Prop_Send, "m_bInReload"))) {
        //stockLog.debugAll("Charger (%N)'s target (%N) is reloading, weapon %s, can charge", client, target, weaponName);
        return true;
    }

    // 正在攻击间隔中, 可以直接冲撞
    static float nextPrimaryAttack;
    nextPrimaryAttack = GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack");
    if (nextPrimaryAttack > GetGameTime() + 0.5) {
        //stockLog.debugAll("Charger (%N)'s target (%N) is in primary attack cooldown, weapon %s, can charge", client, target, weaponName);
        return true;
    }

    // 正在推的间隔中, 可以直接冲撞
    static float nextShoveTime;
    nextShoveTime = GetEntPropFloat(target, Prop_Send, "m_flNextShoveTime");
    if (nextShoveTime > GetGameTime() + 0.5) {
        //stockLog.debugAll("Charger (%N)'s target (%N) is in shove cooldown, can charge", client, target);
        return true;
    }

    // 如果除了目标以外, 有另外的生还者正在看着 charger, 可以直接冲撞
    if (isAnySurvivorWatchingCharger(client, target) >= 1) {
        //stockLog.debugAll("Charger (%N)'s target (%N) is being watched by another survivor, can charge", client, target);
        return true;
    }
    
    // 如果目标手持近战武器, 且 charger 生命值高于近战斩杀线, 可以直接冲撞
    if (L4D2_GetMeleeWeaponIndex(weaponName) > -1) {
        static int health;
        static int meleeDamageCharger;
        health = GetEntProp(client, Prop_Data, "m_iHealth");
		meleeDamageCharger = getLegacyMeleeDamage();
        if (health > meleeDamageCharger) {
            //stockLog.debugAll("Charger (%N)'s target (%N) is holding melee weapon %s, charger health %d is greater than melee damage charger %.2f, can charge",
                //client, target, weaponName, health, meleeDamageCharger);
            return true;
        }
    }

    // 如果当前 charger 的博弈时间超过了最大允许的博弈时间, 直接冲撞
    if (g_ChargerStateContext[client].getStateDuration() > g_cvBaitMaxDuration.FloatValue) {
        //stockLog.debugAll("Charger (%N)'s bait time is up, can charge to its target (%N)", client, target);
        return true;
    }

    // 进阶检查, 检查朝着目标方向冲撞位置后若干距离是否有墙体或向下是否有足够高差或必杀
    static float eyeAng[3];
	GetClientEyeAngles(target, eyeAng);
    if (isDirectionBlockedOrFall(target, eyeAng, TARGET_VULNERABLE_ADV_CHECK_DIST)) {
        //stockLog.debugAll("Ahead charger (%N)'s target (%N)'s direction %.2f distance, will hit wall or fall down, can charge",
            //client, target, TARGET_VULNERABLE_ADV_CHECK_DIST);
        return true;
    }

    return false;
}

/**
* 检查 charger 当前目标 ang 方向 checkDist 距离内是否有障碍物
* @param target 目标索引
* @param ang 检测方向
* @param checkDist 检测距离
* @return book, true 存在障碍, false 无障碍
**/
stock bool isDirectionBlockedOrFall(int target, float ang[3], float checkDist) {
    if (!IsValidSurvivor(target) || !IsPlayerAlive(target))
        return false;
    
    static float targetPos[3], eyePos[3], dir[3];
    GetClientAbsOrigin(target, targetPos);
    GetClientEyePosition(target, eyePos);
    // 计算方向向量
    GetAngleVectors(ang, dir, NULL_VECTOR, NULL_VECTOR);
    dir[2] = 0.0;
    NormalizeVector(dir, dir);
    // 计算终点
    ScaleVector(dir, checkDist);
    AddVectors(eyePos, dir, dir);

    static Handle hTrace;
    static bool blocked;
    hTrace = TR_TraceHullFilterEx(eyePos, dir, {-16.0, -16.0, -16.0}, {16.0, 16.0, 16.0}, MASK_PLAYERSOLID, _TraceWallFilter, target);
    blocked = TR_DidHit(hTrace);
    delete hTrace;
    if (blocked)
        return true;

    // 如果没有障碍物阻挡, 那么向下检测是否有很高的高差或者可以直接摔死
    static float vDown[3];
    vDown = dir;
    vDown[2] -= 9999.0;
    hTrace = TR_TraceRayFilterEx(dir, vDown, MASK_PLAYERSOLID, RayType_EndPoint, _TraceWallFilter, target);
    blocked = TR_DidHit(hTrace);
    if (!blocked) {
        // 如果连向下的射线都没有阻挡, 直接允许冲锋
        delete hTrace;
        return true;
    }
    static int hitEnt;
    static float endPos[3];
    hitEnt = TR_GetEntityIndex(hTrace);
    TR_GetEndPosition(endPos, hTrace);
    delete hTrace;

    // 检查落点高度, 若距离目标当前位置高差大于阈值, 则允许冲锋
    if (targetPos[2] - endPos[2] > DROP_DOWN_THRESHOLD)
        return true;
    // 检查落点是否有危险
    static char clsName[64];
    if (IsValidEntity(hitEnt)) {
        GetEntityClassname(hitEnt, clsName, sizeof(clsName));
        if (strcmp(clsName, "trigger_hurt", false) == 0)
            return true;
    }

    return false;
}

stock int getLegacyMeleeDamage() {
	if (g_cvLegacyMeleeDamage != null)
		return g_cvLegacyMeleeDamage.IntValue;
	if (cvMeleeDamageCharger != null)
		return cvMeleeDamageCharger.IntValue;
	return DEFAULT_MELEE_DMG_CHARGER;
}

/**
* 计算 charger 是否允许概率冲锋
* @param client 客户端索引
* @return bool, true 允许概率冲锋, false 不允许
**/
stock bool isChargerProbCharge(int client) {
    if (!isAiCharger(client))
        return false;

    // 没到检测时间
    if (GetGameTime() - g_AiChargers[client].m_flLastProbChargeChkTime <= g_cvProbChargeChkDur.FloatValue)
        return false;

    // 重新计算此次冲锋概率
    g_AiChargers[client].m_flLastProbChargeChkTime = GetGameTime();
    // 计算概率
    static float chargeProb;
    chargeProb = GetRandomFloatInRange(0.0, 1.0);
    if (chargeProb <= g_cvProbChargeProb.FloatValue)
        return true;
    
    return false;
}

/**
* 计算在平地上正常跳跃的滞空时间, Client 起跳高度为 56.0
* @param 
* @return float
**/
stock float getJumpAirTime() {
    static float gravity;
    gravity = !cvGravity ? DEFAULT_GRAVITY : cvGravity.FloatValue;
    return SquareRoot(112 / gravity) * 2.0;
}

/**
* 下一帧连跳落点位置检测
* @param client 客户端索引
* @param visible 是否有目标的视野
* @return bool, true 表示下一帧位置没有威胁, 允许连跳, false 反之
**/
stock bool nextTickPosCheck(int client, float vFwd[3], bool visible) {
	if (!isAiCharger(client))
		return false;

	static float vMins[3], vMaxs[3];
	GetClientMins(client, vMins);
	GetClientMaxs(client, vMaxs);

	static float pos[3], endPos[3], velVec[3], vel;
	L4D_GetEntityWorldSpaceCenter(client, pos);
    velVec = vFwd;
    // 根据跳跃滞空时间对 velVec 进行缩放
    ScaleVector(velVec, getJumpAirTime());

	vel = GetVectorLength(velVec);
	NormalizeVector(velVec, velVec);
	// 为下一帧检测的位置留出一些余量 (bbox 宽度 + 3), endPos 为下一帧位置
	ScaleVector(velVec, vel + FloatAbs(vMaxs[0] - vMins[0]) + 3.0);
	AddVectors(pos, velVec, endPos);

    // For debug print next tick position
    /* ShowPos(COLOR_GREEN, pos, endPos); */

	// 射线检测
	static Handle hTrace;
	hTrace = TR_TraceHullFilterEx(pos, endPos, {-36.0, -36.0, 10.0}, {36.0, 36.0, 72.0}, MASK_PLAYERSOLID, _TraceWallFilter, client);
	if (TR_DidHit(hTrace)) {
		// 防止下次连跳速度方向撞墙 (速度方向与墙的法向量垂直为 180 度)
		static float rayEndPos[3], hitNormal[3];
		TR_GetEndPosition(rayEndPos, hTrace);
		TR_GetPlaneNormal(hTrace, hitNormal);
		NormalizeVector(hitNormal, hitNormal);
		NormalizeVector(velVec, velVec);
		if (RadToDeg(ArcCosine(GetVectorDotProduct(hitNormal, velVec))) > 165.0) {
			delete hTrace;
			return false;
		}
	}

	if (!visible) {
		// 无视野情况, 计算视角与速度向量夹角, 若太大则禁止连跳
		static float eyeAng[3], dir[3], dot, angle;
		GetClientEyeAngles(client, eyeAng);
		GetAngleVectors(eyeAng, dir, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(dir, dir);
		NormalizeVector(velVec, velVec);
		dir[2] = velVec[2] = 0.0;

        dot = GetVectorDotProduct(dir, velVec);
        if (dot > 1.0) dot = 1.0;
        else if (dot < -1.0) dot = -1.0;
		angle = RadToDeg(ArcCosine(dot));

		if (angle > g_cvBhopNoVisionMaxAng.FloatValue) {
			delete hTrace;
			return false;
		}
	}

	delete hTrace;
	// 检测下一帧向下的位置是否会死亡
	static float downPos[3], landPos[3];
	downPos = endPos;
	downPos[2] -= 99999.0;
	hTrace = TR_TraceHullFilterEx(endPos, downPos, {-16.0, -16.0, 0.0}, {16.0, 16.0, 0.0}, MASK_PLAYERSOLID, _TraceWallFilter, client);
	// 太高了, 返回 false
	if (!TR_DidHit(hTrace)) {
		delete hTrace;
		return false;
	}

    // 获取实际落地点
    TR_GetEndPosition(landPos, hTrace);

	static int hitEnt;
	hitEnt = TR_GetEntityIndex(hTrace);
	if (IsValidEntity(hitEnt)) {
		static char className[32];
		GetEntityClassname(hitEnt, className, sizeof(className));
		if (strcmp(className, "trigger_hurt", false) == 0) {
			delete hTrace;
			return false;
		}
	}
	delete hTrace;
	return true;
}

stock float navAreaGetCenterZ(Address navArea) {
    if (navArea == Address_Null)
        return 0.0;
    
    static float center[3];
    L4D_GetNavAreaCenter(navArea, center);
    return center[2];
}

stock bool _TraceWallFilter(int entity, int contentsMask, any data) {
    // worldspawn
    if (entity == 0)
        return true;
    // 忽略自身
    if (entity == data)
        return false;
    // 忽略所有玩家 (生还和特感)
    if (entity > 0 && entity <= MaxClients)
        return false;

    // 忽略普通感染者和 witch
    static char clsName[32];
    if (IsValidEntity(data)) {
        GetEntityClassname(entity, clsName, sizeof(clsName));
        if (strcmp(clsName, "infected", false) == 0 ||
            strcmp(clsName, "witch", false) == 0)
            return false;
    }

    static char className[64];
    GetEntityClassname(entity, className, sizeof(className));
    if (StrContains(className, "trigger_", false) >= 0)
        return false;
    if (strcmp(className, "func_illusionary", false) == 0)
        return false;
    // 忽略玻璃
    static int solidType, effects;
    solidType = GetEntProp(entity, Prop_Data, "m_nSolidType");
    if (strcmp(className, "func_breakable", false) == 0 && solidType == 1)
        return false;
    // 忽略阻挡玩家或特感的空气墙
    if (strcmp(className, "func_playerclip", false) == 0 ||
        strcmp(className, "player_infected_clip", false) == 0 ||
        strcmp(className, "func_playerinfected_clip", false) == 0)
        return false;
    // 忽略效果包含 EF_NODRAW 的实体
    effects = GetEntProp(entity, Prop_Send, "m_fEffects");
    if (effects & 32)
        return false;

    return true;
}

/**
* 获取 charger 目标的威胁类型
* @param client 客户端索引
* @param target 目标索引
* @return TargetThreatType, 威胁类型
**/
stock TargetThreatType getTargetThreatType(int client, int target) {
    if (!isAiCharger(client))
        return Threat_None;
    if (!IsValidSurvivor(target) || !IsPlayerAlive(target))
        return Threat_None;

    static int weapon;
    weapon = GetEntPropEnt(target, Prop_Send, "m_hActiveWeapon");
    if (!IsValidEntity(weapon))
        return Threat_None;
    
    char clsName[64];
    GetEntityClassname(weapon, clsName, sizeof(clsName));
    if (StrContains(clsName, "shotgun", false) >= 0)
        return Threat_Shotgun;
	else if (StrContains(clsName, "melee", false) >= 0 || StrContains(clsName, "chainsaw", false) >= 0)
	{
		if (g_cvLegacyMeleeAvoid != null && !g_cvLegacyMeleeAvoid.BoolValue)
			return Threat_Normal;
		return Threat_Melee;
	}
    
    return Threat_Normal;
}

stock float angleNormalize(float angle) {
    while (angle > 180.0) angle -= 360.0;
    while (angle < -180.0) angle += 360.0;
    return angle;
}

/**
* 判断目标是否正在看着 charger
* @param client 客户端索引
* @param target 目标索引
* @param fovDeg 视野角度 (默认 60 度, 即目标的视角方向与目标到 charger 的位置向量方向夹角小于 fovDeg 即为正在看着)
* @return bool
**/
stock bool isTargetWatchingCharger(int client, int target, float fovDeg = 60.0) {
    if (!isAiCharger(client))
        return false;
    if (!IsValidSurvivor(target) || !IsPlayerAlive(target))
        return false;
    
    static float eyePos[3], vDir[3];
    GetClientEyePosition(client, eyePos);
    
    static float targetEyePos[3], targetEyeAng[3], vFwd[3];
    GetClientEyePosition(target, targetEyePos);
    GetClientEyeAngles(target, targetEyeAng);
    GetAngleVectors(targetEyeAng, vFwd, NULL_VECTOR, NULL_VECTOR);
    NormalizeVector(vFwd, vFwd);
    
    MakeVectorFromPoints(targetEyePos, eyePos, vDir);
    NormalizeVector(vDir, vDir);

    float dot = GetVectorDotProduct(vFwd, vDir);
    if (dot > 1.0) dot = 1.0;
    else if (dot < -1.0) dot = -1.0;
    float deg = RadToDeg(ArcCosine(dot));
    
    if (deg > fovDeg)
        return false;

    /**
    // 检测是否能够直视 charger (没有被障碍物挡住)
    static Handle hTrace;
    static bool visible;
    hTrace = TR_TraceRayFilterEx(targetEyePos, eyePos, MASK_VISIBLE, RayType_EndPoint, _TraceRayFilterNoPlayer, target);
    visible = !TR_DidHit(hTrace);
    delete hTrace;
    return visible;
    **/

    return L4D2_IsVisibleToPlayer(client, TEAM_INFECTED, TEAM_SURVIVOR, 0, targetEyePos);
}

/**
* 检查当前有几个生还者正在看着 Charger
* @param client 客户端索引
* @param target Charger 的目标索引, 一般是把它排除的, 如果需要检查目标, target 传递 INVALID_CLIENT_INDEX 即可
* @param fovDeg 视野角度 (默认 60 度)
* @return int 正在看着 Charger 的生还者数量
**/
stock int isAnySurvivorWatchingCharger(int client, int target, float fovDeg = 60.0) {
    if (!isAiCharger(client))
        return 0;

    int count = 0;
    static float pos[3], targetPos[3], dist, weaponRange, rangeModifier;
    static int weapon;
    static char clsName[32];

    for (int i = 1; i <= MaxClients; i++) {
        if (i == client || i == target)
            continue;
        if (!IsValidSurvivor(i) || !IsPlayerAlive(i))
            continue;
        if (IsClientIncapped(i) || IsClientHanging(i) || IsClientPinned(i))
            continue;
        if (!isTargetWatchingCharger(client, i, fovDeg))
            continue;
        // =========================================================================
        // 对不同的武器类型进行判断
        // 1. 如果生还者拿着近战武器但是距离 charger 的距离大于 melee_range + _ai_charger3_melee_bait_maxrange.FloatValue, 那么没有威胁
        // 2. 如果生还者拿着枪械, 如果距离大于射程范围, 没有威胁
        // =========================================================================
        GetClientAbsOrigin(client, pos);
        GetClientAbsOrigin(i, targetPos);
        pos[2] = targetPos[2] = 0.0;
        dist = GetVectorDistance(pos, targetPos);

        weapon = GetEntPropEnt(i, Prop_Send, "m_hActiveWeapon");
        if (!IsValidEntity(weapon))
            continue;
        GetEntityClassname(weapon, clsName, sizeof(clsName));
        // 近战武器的情况
        if (L4D2_GetMeleeWeaponIndex(clsName) > -1 || strcmp(clsName[7], "chainsaw", false) == 0) {
		float meleeRange = cvMeleeRange != null ? cvMeleeRange.FloatValue : DEFAULT_MELEE_RANGE;
		if (dist > meleeRange + g_cvMeleeBaitZoneMaxRange.FloatValue)
                continue;
        }
        // 非近战武器的情况
        weaponRange = L4D2_GetFloatWeaponAttribute(clsName, L4D2FWA_Range);
        rangeModifier = L4D2_GetFloatWeaponAttribute(clsName, L4D2FWA_RangeModifier);
        if (dist > (weaponRange * rangeModifier))
            continue;
        
        count += 1;
    }
    return count;
}

stock int getClosestSurvivorAndValid(int charger, int excludeTar = -1) {
	if (!isAiCharger(charger))
		return -1;
	
	static int target;
	static float pos[3], targetPos[3];
	static ArrayList targets;
	if (!targets)
		targets = new ArrayList(2);

	GetClientAbsOrigin(charger, pos);
	for (int i = 1; i <= MaxClients; i++) {
		if (i == charger || i == excludeTar)
			continue;
		if (!IsValidSurvivor(i) || !IsPlayerAlive(i) || IsClientPinned(i) || IsClientIncapped(i) || IsClientHanging(i))
			continue;

		GetClientAbsOrigin(i, targetPos);
		targets.Set(targets.Push(GetVectorDistance(pos, targetPos)), i, 1);
	}

	if (targets.Length < 1) {
		delete targets;
		return -1;
	}

	SortADTArray(targets, Sort_Ascending, Sort_Float);
	target = targets.Get(0, 1);
	delete targets;
	return target;
}

stock bool vectorsEqual(const float vec1[3], const float vec2[3]) {
    return (vec1[0] == vec2[0] &&
            vec1[1] == vec2[1] &&
            vec1[2] == vec2[2]);
}

stock float getVectorLength2D(const float vec[3]) {
    return SquareRoot(vec[0] * vec[0] + vec[1] * vec[1]);
}

stock float getVectorDistance2D(const float vec1[3], const float vec2[3]) {
    return SquareRoot(Pow(vec1[0] - vec2[0], 2.0) + Pow(vec1[1] - vec2[1], 2.0));
}

stock bool isSurvivorPinned(int client) {
    if (!IsValidSurvivor(client) || !IsPlayerAlive(client))
        return false;

    // 检查是否被 Hunter 扑倒
    if (GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0) return true;
    // 检查是否被其他 Charger 携带着冲锋
    if (GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0) return true;
    // 检查是否被其他 Charger 按在地上捶打
    if (GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0) return true;

    return false;
}

/* struct Segment
{
    CNavArea *area;									// the area along the path
    NavTraverseType how;							// how to enter this area from the previous one
    Vector pos;										// our movement goal position at this point in the path
    const CNavLadder *ladder;						// if "how" refers to a ladder, this is it
    
    SegmentType type;								// how to traverse this segment of the path
    Vector forward;									// unit vector along segment
    float length;									// length of this segment
    float distanceFromStart;						// distance of this node from the start of the path
    float curvature;								// how much the path 'curves' at this point in the XY plane (0 = none, 1 = 180 degree doubleback)

    Vector m_portalCenter;							// position of center of 'portal' between previous area and this area
    float m_portalHalfWidth;						// half width of 'portal'
}; */
void constructPathSegment(Address pPathSegment, PathSegment segment) {
    if (!pPathSegment) {
        LogError("Stocks.sp::ConstructPathSegment: pPathSegment pointer is null");
        segment.init();
        return;
    }

    segment.m_pPathSegment = pPathSegment;

    static Address pArea;
	pArea = view_as<Address>(LoadFromAddress(pPathSegment, NumberType_Int32));
    segment.m_pNavArea = pArea;

    static int traverseType, segmentType;
	traverseType = view_as<int>(LoadFromAddress(pPathSegment + view_as<Address>(4), NumberType_Int32));
    segmentType = view_as<int>(LoadFromAddress(pPathSegment + view_as<Address>(24), NumberType_Int32));
    segment.m_iNavTraverseType = traverseType;
	segment.m_SegmentType = view_as<SegmentType>(segmentType);

    // 从 pPathSegment 结构体中获取 x, y, z 坐标
	// v99 = *(float *)(v37 + 8);
	// v38 = *(float *)(v37 + 12);
	// v39 = *(float *)(v37 + 16);
    static float x, y, z;
	x = view_as<float>(LoadFromAddress(pPathSegment + view_as<Address>(8), NumberType_Int32));
	y = view_as<float>(LoadFromAddress(pPathSegment + view_as<Address>(12), NumberType_Int32));
	z = view_as<float>(LoadFromAddress(pPathSegment + view_as<Address>(16), NumberType_Int32));
	segment.m_vecGoalPos[0] = x;
    segment.m_vecGoalPos[1] = y;
    segment.m_vecGoalPos[2] = z;

    x = view_as<float>(LoadFromAddress(pPathSegment + view_as<Address>(28), NumberType_Int32));
	y = view_as<float>(LoadFromAddress(pPathSegment + view_as<Address>(32), NumberType_Int32));
	z = view_as<float>(LoadFromAddress(pPathSegment + view_as<Address>(36), NumberType_Int32));
	segment.m_vecForward[0] = x;
    segment.m_vecForward[1] = y;
    segment.m_vecForward[2] = z;

    static float length, dist;
	length = view_as<float>(LoadFromAddress(pPathSegment + view_as<Address>(40), NumberType_Int32));
	dist = view_as<float>(LoadFromAddress(pPathSegment + view_as<Address>(44), NumberType_Int32));
	segment.m_flLength = length;
    segment.m_flDistFromStart = dist;
}

stock bool getNextPathSegment(Address pPath, Address pCurSeg, PathSegment segemnt) {
    if (!pPath || !pCurSeg)
        return false;
    
    Address pNextSeg = view_as<Address>(SDKCall(g_hSdkPathNextSegment, pPath, pCurSeg));
    if (!pNextSeg)
        return false;
    constructPathSegment(pNextSeg, segemnt);
    return true;
}

stock int getLookAheadGoalPos(int client, const float pos[3], float maxDist, float outPos[3], int maxDepth = 10) {
	// A: iterSeg, B: nextSeg
    static PathSegment A, B;
    A = g_AiChargers[client].m_PathSegment;
    
    // 如果 current path segment 无效, 返回 false
    if (!A.m_pPathSegment) {
		return false;
	}

	static float vPos2D[3];
	vPos2D = pos;
	vPos2D[2] = 0.0;

	// ============================================================
	// 使用几何投影法, 找到真正的前向节点
	// ============================================================
	for (int i = 0; i < maxDepth; i++) {
		// 先尝试获取下一个节点, 如果没有下一个节点, 说明 iterSeg 为当前路径的终点, 跳出循环
		if (!getNextPathSegment(g_AiChargers[client].m_pPathFollower, A.m_pPathSegment, B)) {
			break;
		}

		// 获取 2D 节点坐标, 用于计算投影
		static float curGoal2D[3], nextGoal2D[3];
		curGoal2D = A.m_vecGoalPos;
		nextGoal2D = B.m_vecGoalPos;
		curGoal2D[2] = 0.0;
		nextGoal2D[2] = 0.0;

		// 获取 current goal pos 到 next goal pos 的向量 x
		// 获取 current goal pos 到 client pos 的向量 y
		static float vCur2Next[3], vCur2Client[3], lenSqrAB;
		MakeVectorFromPoints(curGoal2D, nextGoal2D, vCur2Next);
		MakeVectorFromPoints(curGoal2D, vPos2D, vCur2Client);
		lenSqrAB = GetVectorDotProduct(vCur2Next, vCur2Next);
		
		if (lenSqrAB <= 0.0) {
			A = B;
			continue;
		}

		// 计算 y 到 x 向量的投影
		static float proj;
		proj = GetVectorDotProduct(vCur2Next, vCur2Client) / lenSqrAB;

		// 如果 y 向量在 x 向量上的投影长过 x 向量, 说明当前 path segment 完全在 client 身后, 继续推进检测下一段 path segment
		if (proj >= 1.0) {
			A = B;
			continue;
		} else if (proj >= 0.5) {
			// 若 y 向量在 x 向量上的投影超过 x 向量长度一半, 说明 client 已经走了当前 path segment 的一半, 找一个以当前 client 速度一次可达的最远节点
			A = B;
			break;
		} else {
			// 若投影小于等于 0, 说明当前节点依旧是有效的起步点, 找一个以当前 client 速度一次可达的最远节点
			break;
		}
	}

	// ============================================================
	// 以上一步的起点为基础, 外推, 找一个以当前 client 速度一次
	// 可达且可见 (client pos 到目标节点中间没有障碍物遮挡, 不会阻止连跳) 的最远节点
	// ============================================================
	static float lastVisPos[3];
	lastVisPos = A.m_vecGoalPos;

	static float vStart[3];
	L4D_GetEntityWorldSpaceCenter(client, vStart);

	static int fwdCount;
	fwdCount = 0;

	for (int i = 0; i < maxDepth; i++) { 
		static float vGoal[3], vEnd[3];
		vGoal = A.m_vecGoalPos;

		vEnd = vGoal;
		vEnd[2] += 36.0;
		
		static Handle hTrace;
        static bool isHit;
		hTrace = TR_TraceHullFilterEx(vStart, vEnd, {-16.0, -16.0, -16.0}, {16.0, 16.0, 16.0}, MASK_PLAYERSOLID, _TraceWallFilter);
        isHit = TR_DidHit(hTrace);
        delete hTrace;

        // 如果视线被墙挡住, 前面的路无法直接一次连跳过去, 跳出循环, 返回最远的可见节点
        if (isHit) {
            break;
        }

		// 该节点并没有被遮挡, 立即记录为最优节点, 增加检查节点数量
		lastVisPos = vGoal;
		fwdCount += 1;

		static float dist2CurGoal;
		dist2CurGoal = getVectorDistance2D(vStart, vGoal);
		// 到达以当前速度最远可达的距离, 这个节点以当前速度一次连跳不可达, 跳出循环
		if (dist2CurGoal >= maxDist) {
			break;
		}

        // 如果当前节点的高度大于 client pos + MaxJumpHeight, 说明一跳上不去, 跳出循环
        if (vGoal[2] - pos[2] > JUMP_HEIGHT) {
            break;
        }

		// 如果这个节点以当前速度可达, 继续遍历下一个节点
		// 如果下一个节点没有了, 说明当前节点就是路径的最后一个节点, 跳出循环
		if (!getNextPathSegment(g_AiChargers[client].m_pPathFollower, A.m_pPathSegment, A)) {
			break;
		}
	}

	// 如果前向检查节点没有任何一个以当前速度一次跳跃可达的节点, 说明 client 当前位置到下一个节点中间存在障碍物, 不允许连跳
	if (fwdCount < 1) {
		return false;
	}

	outPos = lastVisPos;
	return true;
}

/**
* 从 PathFollower 对象中读出 m_minLookAheadDistance 成员
* @param pPathFollower 指向 PathFollower 对象的指针
* @return float
**/
stock float getMinLookAheadDist(Address pPathFollower) {
    if (!pPathFollower)
        return -1.0;

    // *((float *)this + 4567) = a2;
    return view_as<float>(LoadFromAddress(pPathFollower + view_as<Address>(4 * 4567), NumberType_Int32));
}

/**
 * 计算客户端的剩余滞空时间
 * @param client  客户端索引
 * @param pos     客户端当前坐标
 * @param vVel    m_vecAbsVelocity
 * @return float
 */
stock float calcRemainingAirTime(const float pos[3], const float vVel[3]) {
    float vEnd[3];
    vEnd = pos;
    vEnd[2] -= 9999.0;

    Handle hTrace = TR_TraceRayFilterEx(pos, vEnd, MASK_PLAYERSOLID, RayType_Infinite, _TraceWallFilter);

    float H = JUMP_HEIGHT;
    if (TR_DidHit(hTrace)) {
        float vHitPos[3];
        TR_GetEndPosition(vHitPos, hTrace);
        H = pos[2] - vHitPos[2];
    }
    delete hTrace;

    /*
        如果射线没有打到任何东西, 说明下面是深渊, 使用什么 H 都无所谓了
    */
    if (H < 0.0) {
        H = 0.0;
    }

    float gravity = !cvGravity ? DEFAULT_GRAVITY : cvGravity.FloatValue;

    float root = (vVel[2] * vVel[2]) + (2.0 * gravity * H);
    if (root < 0.0) {
        root = 0.0;
    }

    // 计算落地时间, 设置最小值和最大值
    float t = (vVel[2] + SquareRoot(root)) / gravity;
    if (t < 0.1) {
        t = 0.1;
    }
    if (t > 3.0) {
        t = 3.0;
    }

    return t;
}

#define DIRECT_GROUND_SAMPLE_STEP   50.0    // hasPotentialGap2 函数的从 start 到 end 路线上的采样步长
#define DIRECT_MAX_LOCAL_STEP_UP    56.0    // 后续采样点以第一个采样点的地面高度向上或者向下 (STEP_UP + margin) 开始向下射线
#define DIRECT_GROUND_TRACE_MARGIN  10.0
#define DIRECT_MIN_GROUND_NORMAL_Z  0.20

stock bool hasPotentialGap2(int client, const float start[3], const float end[3], float maxLocalDrop) {
    if (maxLocalDrop <= 0.0)
        return true;
    
    // 从 start 到 end 只计算水平路线
    static float routeDir[3];
    MakeVectorFromPoints(start, end, routeDir);
    routeDir[2] = 0.0;

    // NormalizeVector 返回归一化之前的向量长度, 同时将 routeDir 转化为单位方向向量
    static float routeDist;
    routeDist = NormalizeVector(routeDir, routeDir);

    if (routeDist <= 0.0)
        return false;

    int sampleCount = RoundToCeil(routeDist / DIRECT_GROUND_SAMPLE_STEP);
    if (sampleCount < 1) {
        sampleCount = 1;
    }

    static float previousGroundZ;
    bool hasPreviousGround;

    previousGroundZ = start[2];
    hasPreviousGround = false;

    for (int sampleIndex = 0; sampleIndex <= sampleCount; sampleIndex++) {
        static float sampleFraction;
        sampleFraction = float(sampleIndex) / float(sampleCount);

        static float samplePos[3];
        samplePos[0] = start[0] + routeDir[0] * routeDist * sampleFraction;
        samplePos[1] = start[1] + routeDir[1] * routeDist * sampleFraction;
        samplePos[2] = start[2];

        /*
        * 第一个采样点以 start[2] 高度为基准, 后续采样点以上一个真实地面高度为基准
        * 这样可以允许长斜坡之间存在很大的累计高度差, 比如中间有个坑这种, 但不允许相邻采样点之间高度差断崖式下降或者上升
        */
        static float referenceGroundZ;
        referenceGroundZ = hasPreviousGround ? previousGroundZ : start[2];

        static float currentGroundZ;
        if (!tryFindGroundAtRouteSample(client, samplePos, referenceGroundZ, hasPreviousGround, maxLocalDrop, currentGroundZ)) {
            return true;
        }

        if (hasPreviousGround) {
            if (isLocalGroundHeightDiscontinuous(previousGroundZ, currentGroundZ, maxLocalDrop)) {
                return true;
            }
        }

        previousGroundZ = currentGroundZ;
        hasPreviousGround = true;
    }

    return false;
}

stock bool tryFindGroundAtRouteSample(int client, const float samplePos[3], float referenceGroundZ, bool hasPreviousGround, float maxLocalDrop, float& outGroundZ) {
    static float traceStart[3], traceEnd[3];

    traceStart[0] = samplePos[0];
    traceStart[1] = samplePos[1];

    traceEnd[0] = samplePos[0];
    traceEnd[1] = samplePos[1];

    /*
    * 第一个采样点, Charger 通常已经在地面上, 只需要从 start 上方向下寻找地面
    * 后续采样点, 允许当前地面比上一个地面高 DIRECT_MAX_LOCAL_STEP_UP, 如果上升超过这个范围, 要么 trace 失败, 要么后续的高度差检查会拒绝
    */
    if (hasPreviousGround) {
        traceStart[2] = referenceGroundZ + (DIRECT_MAX_LOCAL_STEP_UP + DIRECT_GROUND_TRACE_MARGIN);
    } else {
        traceStart[2] = referenceGroundZ + DIRECT_GROUND_TRACE_MARGIN;
    }

    /*
    * 最低只允许下降 max local drop, 如果这个范围内找不到地面, 认为存在 Gap 或者断崖
    */
    traceEnd[2] = referenceGroundZ - maxLocalDrop;

    static Handle hTrace;
    hTrace = TR_TraceRayFilterEx(traceStart, traceEnd, MASK_PLAYERSOLID, RayType_EndPoint, _TraceWallFilter, client);

    if (!TR_DidHit(hTrace) || TR_StartSolid(hTrace)) {
        delete hTrace;
        return false;
    }

    static float groundPos[3], groundNormal[3];
    TR_GetEndPosition(groundPos, hTrace);
    TR_GetPlaneNormal(hTrace, groundNormal);

    delete hTrace;

    /*
    * GroundNormal 越接近于 1, 说明越接近水平地面, 如果 GroundNormal 接近于 0, 则说明地面倾斜严重, 无法站立
    */
    if (groundNormal[2] < DIRECT_MIN_GROUND_NORMAL_Z) {
        return false;
    }

    outGroundZ = groundPos[2];
    return true;
}

stock bool isLocalGroundHeightDiscontinuous(float previousGroundZ, float currentGroundZ, float maxLocalDrop) {
    static float deltaZ;
    deltaZ = currentGroundZ - previousGroundZ;

    if (deltaZ > DIRECT_MAX_LOCAL_STEP_UP + 1.0) {
        return true;
    }

    if (deltaZ < -maxLocalDrop - 1.0) {
        return true;
    }

    return false;
}

stock float calcVectorAngle(const float v1[3], const float v2[3], bool ignoreZ = true) {
    if ((v1[0] == 0.0 && v1[1] == 0.0 && v1[2] == 0.0) ||
        (v2[0] == 0.0 && v2[1] == 0.0 && v2[2] == 0.0))
        return 0.0;
    
    static float v1_cpy[3], v2_cpy[3];
    v1_cpy = v1;
    v2_cpy = v2;

    if (ignoreZ) {
        v1_cpy[2] = 0.0;
        v2_cpy[2] = 0.0;
    }

    NormalizeVector(v1_cpy, v1_cpy);
    NormalizeVector(v2_cpy, v2_cpy);
    static float dot;
    dot = GetVectorDotProduct(v1_cpy, v2_cpy);
    if (dot > 1.0) dot = 1.0;
    else if (dot < -1.0) dot = -1.0;
    return RadToDeg(ArcCosine(dot));
}

/**
* 从 Client Index 获取该 Bot 的 ILocomotion 指针
* @param client 客户端索引
* @return Address ILocomotion 指针地址, 无效返回 Address Null
**/
stock Address clientGetLocomotionInterface(int client) {
    if (!IsValidClient(client))
        return Address_Null;
    
    Address pEntity = GetEntityAddress(client);
    if (!pEntity)
        return Address_Null;
    
    Address pNextBot = view_as<Address>(SDKCall(g_hSdkMyNextBotPointer, pEntity));
    if (!pNextBot)
        return Address_Null;
    
    Address pLocomotion = view_as<Address>(SDKCall(g_hSdkGetLocomotionInterface, pNextBot));
    if (!pLocomotion)
        return Address_Null;
    
    return pLocomotion;
}

/**
* 检查 start 坐标和 end 坐标中间有没有纵向高差超过 MaxJumpHeight 的下坠, 有则返回 true, 无返回 false
* 底层采用从 start 到 end 进行步进然后向下作射线检测, 检测是否有超过 MaxJumpHeight 的高差
* @param start 起点坐标
* @param end 终点坐标
* @return bool
**/
stock bool hasPotentialGap(Address pLocomotion, const float start[3], const float end[3]) {
    if (!pLocomotion)
        return false;

    /*
        bool ILocomotion::HasPotentialGap( const Vector &from, const Vector &desiredTo, float *fraction ) const
        最后一个参数 fraction 表示射线检测的进度, 射线检测到 has gap, 这个 fraction 表示从 start 到高度差的距离占 start 到 end 的距离的百分比
    */
    float fraction = 0.0;

    return SDKCall(g_hSdkHasPotentialGap, pLocomotion, start, end, fraction);
}

/**
* 调试输出 PathSegment 结构体信息
* @param segment PathSegment 结构体
* @return void
**/
stock void debugPrintPathSegment(PathSegment segment) {
    PrintToConsoleAll("\n===== PathSegment Info =====");
    PrintToConsoleAll("\tthis pointer: 0x%X", segment.m_pPathSegment);
    PrintToConsoleAll("\tNavArea: 0x%X", segment.m_pNavArea);
    PrintToConsoleAll("\tNavTraverseType: %d", segment.m_iNavTraverseType);
    PrintToConsoleAll("\tSegmentType: %d", segment.m_SegmentType);
    PrintToConsoleAll("\tGoal Pos: (%f, %f, %f)", segment.m_vecGoalPos[0], segment.m_vecGoalPos[1], segment.m_vecGoalPos[2]);
    PrintToConsoleAll("\tForward: (%f, %f, %f)", segment.m_vecForward[0], segment.m_vecForward[1], segment.m_vecForward[2]);
    PrintToConsoleAll("\tLength: %f", segment.m_flLength);
    PrintToConsoleAll("\tDistFromStart: %f", segment.m_flDistFromStart);
    PrintToConsoleAll("\n");
}

// ======== End of: ./stocks.inc ========

// ======== Included from: ./state/state.inc ========


#define STATE_LOG_PREFIX "AI-ChargerState"

Logger
    stateLog;

ConVar
    g_cvStateLogLevel;

// =========================================================================
// State 状态模块初始化
// =========================================================================
stock void State_OnModuleStart(ConVar& cvPluginName) {
    if (!cvPluginName) {
        g_cvStateLogLevel = CreateConVar("_ai_charger3_state_log_level", "1", "状态模块的日志记录级别, 1=关闭, 2=控制台输出, 4=log文件输出, 8=聊天框输出, 16=服务器控制台输出, 32=error文件输出, 数字相加", CVAR_FLAGS);
    } else {
        char cvName[64], stateLogCvName[64];
        cvPluginName.GetString(cvName, sizeof(cvName));
        FormatEx(stateLogCvName, sizeof(stateLogCvName), "_%s_state_log_level", cvName);
        g_cvStateLogLevel = CreateConVar(stateLogCvName, "1", "状态模块的日志记录级别, 1=关闭, 2=控制台输出, 4=log文件输出, 8=聊天框输出, 16=服务器控制台输出, 32=error文件输出, 33=所有输出", CVAR_FLAGS);
    }

    stateLog = new Logger(STATE_LOG_PREFIX, g_cvStateLogLevel.IntValue);

    // 注册状态
    registerStates();
}

stock void State_OnModuleEnd() {
    delete stateLog;
}


// ======== Included from: ./state_charging.inc ========



// ======== Included from: ../setup.inc ========

// ======== End of: ../setup.inc ========

// ======== Included from: ../stocks.inc ========

// ======== End of: ../stocks.inc ========

// ======== Included from: ./state.inc ========

// ======== End of: ./state.inc ========

#define STATE_CHARGING_NAME                     "STATE_CHARGING"
#define PREDICT_MAX_LATERAL_OFFSET              45.0    // 冲锋位置横向预测最大值
#define PREDICT_MAX_TIME                        0.5     // charger 冲锋时预测目标位置的最大预测时间
#define CHARGE_DIST_TOLERANCE                   10.0    // 开始冲锋距离容差, 500 速度冲锋目标无法躲避距离大概是 36 左右, 有点小, 导致 charger 一直连跳无法冲锋, 增加一点容差

#define CHARGE_COMMIT_MIN_DIST                   36.0   // 按照 500 速度冲锋时, 允许冲锋的最小距离
#define CHARGE_COMMIT_MAX_DIST                   95.0   // 按照 500 速度冲锋时, 允许冲锋的最大距离
#define CHARGE_HIT_WIDTH                         16.0   // 冲锋命中宽度, 目标左右水平移动不超过这个范围可以被冲锋命中
#define CHARGE_SIDE_SPEED_MIN                    80.0   // 生还者横向移动速度假设的最小值 (由于计算 commitDist 时需要使用横向速度做除法, 防止除零异常, 设置一个最小值)
#define CHARGE_SPEED_EFFECTIVE_FACTOR            0.75   // 计算有效冲锋速度的因子 effective charge speed = max charge speed * factor
#define CHARGE_DIR_EPSILON                       50.0   // XY 距离小于该值时认为水平冲锋方向退化
#define CHARGE_COMMIT_GRACE_DIST                 10.0   // 最后一跳后落在 (commit range + 这个值) 的范围内时, 允许冲锋, 避免因为落在 commit range 外一点然后下一帧直接退回 Approach
#define CHARGE_FINAL_HOP_GRACE_TIME              0.50   // 最后一跳预计落地时间后的额外等待时间, 然后再判断 dist > commit range
#define CHARGING_LOST_SIGHT_GRACE                3.0    // 连续丢失目标视野超过该时间才退出 Charging

enum struct ChargeMotion {
    float m_flDist;                     // Charger 到目标的水平距离
    float m_vecForward[3];              // Charger -> target 的方向向量
    float m_vecSide[3];                 // 根据 vecForward 计算的水平侧向向量, 用于计算目标横向移动向量
    float m_vecTargetVel2D[3];          // 目标的水平速度, z 轴分量清零
    float m_flTargetSpeed;              // 目标水平速度大小
    float m_flForwardSpeed;             // 目标速度在冲锋方向上的投影分量, >0 表示目标正在远离 Charger, <0 表示正在靠近 Charger
    float m_flSideSpeed;                // 目标速度在横向方向上的投影分量, 有符号, 表示左右
    float m_flAbsSideSpeed;             // 横向速度绝对值, 只关心目标横向位移大小
    float m_flEffectiveChargeSpeed;     // 有效冲锋速度
    float m_flClosingSpeed;             // Charger 与目标沿冲锋方向的相对接近速度
    float m_flTimeToImpact;             // 按当前距离和接近速度估计的命中时间

    void init() {
        this.m_flDist = 0.0;
        ZeroVector(this.m_vecForward);
        ZeroVector(this.m_vecSide);
        ZeroVector(this.m_vecTargetVel2D);
        this.m_flTargetSpeed = 0.0;
        this.m_flForwardSpeed = 0.0;
        this.m_flSideSpeed = 0.0;
        this.m_flAbsSideSpeed = 0.0;
        this.m_flEffectiveChargeSpeed = 0.0;
        this.m_flClosingSpeed = 0.0;
        this.m_flTimeToImpact = 0.0;
    }
}

// =========================================================================
// State Charging 冲锋状态, Charger 以 500 速度冲锋目标无法躲避的距离大概在 36.0 左右
// 但是连跳到这个距离之内再冲撞是十分困难的, 大多时候都是在空中达到这个距离, 由于目标
// 持续的移动, Charger 落地时可能已经大于这个距离, 因此无法 100% 冲锋命中, 建议安装 air_ability patch
// 注册状态函数
// =========================================================================
stock void RegisterState_Charging() {
    ChargerState stateCharging;
    strcopy(stateCharging.name, sizeof(stateCharging.name), "State_Charging");
    stateCharging.OnEnter = StateCharging_OnEnter;
    stateCharging.OnUpdate = StateCharging_OnUpdate;
    stateCharging.OnExit = StateCharging_OnExit;
    g_ChargerStates.PushArray(stateCharging);
}

// ============================================================
// OnEnter 函数
// ============================================================
stock void StateCharging_OnEnter(int client) {
    g_AiChargers[client].m_flLastVisibleTime = GetGameTime();
    stateLog.debugAll("\n========== Charger (%N) State Charging On Enter ===========", client);
    // 确保每次进入冲锋决策逻辑时, 都有机会执行一次最后的连跳
    g_AiChargers[client].m_bBhopBeforeCharge = false;
    g_AiChargers[client].m_flFinalBhopStartTime = 0.0;
}

// ============================================================
// OnUpdate 函数
// ============================================================
stock Action StateCharging_OnUpdate(int client, int& buttons, float vel[3], float ang[3]) {
    if (!isAiCharger(client))
        return Plugin_Continue;
    
    static int target, betterTarget;
    target = GetClientOfUserId(g_AiChargers[client].m_iTarget);
    betterTarget = GetClientOfUserId(g_AiChargers[client].m_iBetterTarget);
    // 检查更好的目标是否有效
    target = (IsValidSurvivor(betterTarget) && IsPlayerAlive(betterTarget)) ? betterTarget : target;
    if (!IsValidSurvivor(target) || !IsPlayerAlive(target)) {
        stateLog.debugAll("(%s) Charger (%N)'s target %d is invalid, transition to APPROACH STATE", STATE_CHARGING_NAME, client, target);
        g_ChargerStateContext[client].transitionTo(CH_STATE_APPROACH);
        return Plugin_Continue;
    }

    // 获取当前速度
    static float vVel[3], speed;
    GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
    speed = getVectorLength2D(vVel);
    GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);
    // 是否在地上
    static bool isOnGround;
    isOnGround = IsClientOnGround(client);
    // 计算 charger 当前到目标的距离
    static float pos[3], eyePos[3], targetPos[3], targetEyePos[3], dist;
    L4D_GetEntityWorldSpaceCenter(client, pos);
    L4D_GetEntityWorldSpaceCenter(target, targetPos);
    GetClientEyePosition(client, eyePos);
    GetClientEyePosition(target, targetEyePos);
    dist = getVectorDistance2D(pos, targetPos);
    // 是否可视目标
    static bool visible;
    visible = L4D2_IsVisibleToPlayer(client, TEAM_INFECTED, TEAM_SURVIVOR, 0, targetEyePos);
    if (visible) {
        g_AiChargers[client].m_flLastVisibleTime = GetGameTime();
    }
    static bool recentlyVisible;
    recentlyVisible = visible || GetGameTime() - g_AiChargers[client].m_flLastVisibleTime < CHARGING_LOST_SIGHT_GRACE;
    // 目标威胁类型
    static TargetThreatType threatType;
    threatType = getTargetThreatType(client, target);
    // 是否正在冲锋
    static bool isCharging, isPinning;
    isCharging = isChargerCharging(client);
    isPinning = (IsValidSurvivor(L4D2_GetQueuedPummelVictim(client)) || IsValidSurvivor(L4D_GetVictimCharger(client)) || IsValidSurvivor(L4D_GetVictimCarry(client)));

    // ============================================================
    // 冲锋中或者正在控人, 不处理后续逻辑
    // ============================================================
    if (isCharging || isPinning)
        return Plugin_Continue;

    /*
    * Charging 空中阶段只负责空中速度修正, 不做状态退出和真正冲锋
    * 有些情况下 Charger 飞到目标背后会导致 visible=false, 但二者之间其实没有障碍
    * 如果此时先执行 shouldExitChargingState(), Charger 会过早切回 Approach
    * 然后重新走 Path/Direct 连跳, 可能朝错误的 goal 加速
    */
    if (!isOnGround) {
        /*
        * 是否允许进行空中速度方向修正
        * 有时候 Charger 飞到目标背后会导致 visible=false, 但二者之间其实没有障碍, 因此 visible 不是硬条件
        * 只要冲锋路径没有被阻挡就可以进行速度方向修正
        */
        static bool canPreserveAirLine;
        canPreserveAirLine = (
            visible ||
            !isChargePathBlocked(client, target)
        );

        if (canPreserveAirLine &&
            preserveAirChargeLine(client, target, true, AIR_CHARGE_LINE_CORR_CHARGE_LERP)
        ) {
            return Plugin_Changed;
        }

        return Plugin_Continue;
    }

    // ============================================================
    // 检查是否需要切换到其他状态
    // ============================================================
    if (shouldExitChargingState(client, target, dist, visible, threatType)) {
        g_ChargerStateContext[client].transitionTo(CH_STATE_APPROACH);
        return Plugin_Continue;
    }

    // 处理冲锋结束或控人结束时的能力未就绪的情况, 切换到其他状态
    if (!isChargeAbilityReady(client)) {
        handleAbilityNotReady(client, target, dist, threatType);
        return Plugin_Continue;
    }

    // ============================================================
    // 能力准备就绪, 发起冲锋
    // ============================================================

    // 获取目标当前速度
    static float chargeSpeed, targetAbsVel[3];
    chargeSpeed = !cvChargeSpeed ? DEFAULT_CHARGE_SPEED : cvChargeSpeed.FloatValue;
    GetEntPropVector(target, Prop_Data, "m_vecAbsVelocity", targetAbsVel);

    static int health;
    health = GetEntProp(client, Prop_Data, "m_iHealth");
    static bool earlyCharge;
    earlyCharge = health < g_cvEarlyChargeHealth.IntValue || dist <= g_cvEarlyChargeDist.FloatValue;

    /*
    * 常规冲锋需要可靠的运动学模型；提前冲锋不依赖该模型，避免近距离方向退化或目标高速移动时反复延迟技能。
    */
    static float commitDist;
    if (!getChargeCommitDist(pos, targetPos, targetAbsVel, chargeSpeed, commitDist)) {
        if (!earlyCharge) {
            stateLog.debugAll("Charger (%N) failed to calculate reliable charge commit distance for target (%N), wait in CHARGING STATE", client, target);
            setChargerAbilityCooldown(client, 1.0);
            return Plugin_Continue;
        }
        commitDist = g_cvEarlyChargeDist.FloatValue;
    }

    if (earlyCharge) {
        commitDist = g_cvEarlyChargeDist.FloatValue;
        stateLog.debugAll("Charger (%N) early charge in CHARGING: health %d < %d or dist %.2f <= %.2f, commitDist overridden to %.2f",
            client, health, g_cvEarlyChargeHealth.IntValue, dist, g_cvEarlyChargeDist.FloatValue, commitDist);
    }

    /*
    * 最后一跳已经发出后, 不要因为和 commit range 只差几个单位距离的预测误差立刻退回 Approach, 放弃这次冲锋
    * 这段逻辑只处理最后一跳后的短暂待决窗口:
    * 1. 已经接近 commit range, 直接冲锋
    * 2. 仍在最后一跳预计落地窗口内, 继续保持 Charging, 等待下一帧/落地后的距离更新
    * 3. 超过窗口仍然没有进入 commit range, 才退回 Approach 重新接近
    */
    static bool forceChargeNow;
    forceChargeNow = false;

    if (g_AiChargers[client].m_bBhopBeforeCharge) {
        static float now, finalHopWaitTime;
        now = GetGameTime();
        finalHopWaitTime = getJumpAirTime() + CHARGE_FINAL_HOP_GRACE_TIME;

        if (dist <= commitDist + CHARGE_COMMIT_GRACE_DIST) {
            // 最后一跳已经落在 commitDist + grace range 之内了, 可以直接冲锋
            g_AiChargers[client].m_bBhopBeforeCharge = false;
            g_AiChargers[client].m_flFinalBhopStartTime = 0.0;
            forceChargeNow = true;
        } else if (now - g_AiChargers[client].m_flFinalBhopStartTime <= finalHopWaitTime) {
            /*
            * 最后一跳刚发出的下一帧, 还没到落地结算查看 dist > commit dist 的时候, 应该继续保持 Charging 状态, 等待落地后查看是否进入 commit range
            * 在空中时禁止打拳和冲锋
            */
            //buttons &= ~IN_ATTACK;
            //buttons &= ~IN_ATTACK2;

            stateLog.debugAll("Charger (%N) waiting final bhop commit window, dist %.2f, commitDist %.2f, grace %.2f",
                client, dist, commitDist, CHARGE_COMMIT_GRACE_DIST);

            return Plugin_Changed;
        } else {
            // 最后一跳的 grace time 窗口已经结束, 但是仍然没有进入 (commit range + grace range), 说明最后一跳真的失败, 只能返回 Approach 重新接近目标
            stateLog.debugAll("Charger (%N) final bhop commit window expired, dist %.2f > commitDist %.2f, transition to APPROACH STATE",
                client, dist, commitDist
            );

            g_AiChargers[client].m_bBhopBeforeCharge = false;
            g_AiChargers[client].m_flFinalBhopStartTime = 0.0;
            g_AiChargers[client].m_iBetterTarget = 0;
            g_ChargerStateContext[client].transitionTo(CH_STATE_APPROACH);
            return Plugin_Continue;
        }
    }

    /*
    * 如果 Charger 已经进入 commit range, 那么可以直接冲锋 (dist < commit range + grace range) 时 forceChargeNow 为 true
    * 未进入 commit range 时, 只有当最后一跳可以进入 commit range 时才执行最后一跳
    * 如果最后一跳都无法进入 commit range, 说明当前不适合冲锋, 退回 Approach 重新接近目标
    */
    if (!forceChargeNow && dist > commitDist) {
        static Action finalBhopRes;
        // performFinalBhopBeforeCharge 成功返回 Plugin_Changed 然后立即结束这一帧的处理, 失败返回 Plugin_Continue
        finalBhopRes = performFinalBhopBeforeCharge(client, pos, targetPos, targetAbsVel, dist, commitDist, speed, recentlyVisible, buttons);
        if (finalBhopRes != Plugin_Continue)
            return finalBhopRes;

        stateLog.debugAll("Charger (%N) cannot enter charge commit range in one final bhop, dist %.2f > commitDist %.2f, transition to APPROACH STATE",
            client, dist, commitDist);
        
        g_AiChargers[client].m_iBetterTarget = 0;
        g_AiChargers[client].m_bBhopBeforeCharge = false;
        g_AiChargers[client].m_flFinalBhopStartTime = 0.0;
        g_ChargerStateContext[client].transitionTo(CH_STATE_APPROACH);
        return Plugin_Continue;
    }

    if (!isCharging && !isPinning) {
        static float aimPos[3];
        if (!calculateChargeAimPosition(pos, targetPos, targetAbsVel, chargeSpeed, aimPos))
            aimPos = targetPos;

        // 设置视角方向
        static float dir[3];
        MakeVectorFromPoints(pos, aimPos, dir);
        dir[2] = 0.0;

        // 设置立即冲锋
        setChargerAbilityCooldown(client, -1.0);
        GetVectorAngles(dir, dir);
        TeleportEntity(client, NULL_VECTOR, dir, NULL_VECTOR);

        // 发起冲锋
        buttons |= IN_ATTACK2;
        buttons |= IN_ATTACK;

        stateLog.debugAll("Charger (%N) initiated charge towards target (%N), dist %.2f, commitDist %.2f", client, target, dist, commitDist);

        return Plugin_Changed;
    }
    return Plugin_Continue;
}

bool shouldExitChargingState(int client, int target, float dist, bool visible, TargetThreatType threatType) {
    if (!isAiCharger(client) || !IsValidSurvivor(target) || !IsPlayerAlive(target))
        return true;
    if (IsClientIncapped(target) || IsClientHanging(target))
        return true;

    /*
    * Hunter 和其他 Charger 已经占有不可抢占的控制权, 此时不能抢夺目标
    * isSurvivorPinned 不包含 Smoker/Jockey, 所以这两种控制仍允许 Charger 抢夺
    */
    if (isSurvivorPinned(target)) {
        stateLog.debugAll("Charger (%N), target (%N) is controlled by Hunter/Charger, transition to APPROACH STATE", client, target);
        return true;
    }

    static float pos[3], targetPos[3];
    GetClientAbsOrigin(client, pos);
    GetClientAbsOrigin(target, targetPos);

    // 冲锋路径上面存在障碍物和高度差过大的 Gap 属于独立的硬退出理由, 不受距离、视野或最后一跳宽限窗口影响
    if (isChargePathBlocked(client, target)) {
        stateLog.debugAll("Charger (%N), charge path to target (%N) is blocked, transition to APPROACH STATE", client, target);
        return true;
    }

    /*
    * 常规冲锋沿实际地面逐段采样，相邻地面不连续时退出。
    * 提前冲锋保留实体阻挡检测，但跳过容易受台阶和斜坡接缝影响的 Gap 采样。
    */
    static int health;
    health = GetEntProp(client, Prop_Data, "m_iHealth");
    static bool earlyCharge;
    earlyCharge = health < g_cvEarlyChargeHealth.IntValue || dist <= g_cvEarlyChargeDist.FloatValue;
    if (!earlyCharge && hasPotentialGap2(client, pos, targetPos, JUMP_HEIGHT)) {
        stateLog.debugAll("Charger (%N), route to target (%N) has a gap, transition to APPROACH STATE", client, target);
        return true;
    }

    /*
    * 最后一跳待决期间只忽略软退出条件, 上面的目标状态、阻挡和 Gap 仍然立即生效
    */
    static bool finalHopPending;
    finalHopPending = (
        g_AiChargers[client].m_bBhopBeforeCharge &&
        g_AiChargers[client].m_flFinalBhopStartTime > 0.0 &&
        GetGameTime() - g_AiChargers[client].m_flFinalBhopStartTime <= getJumpAirTime() + CHARGE_FINAL_HOP_GRACE_TIME
    );

    if (finalHopPending)
        return false;

    static float minDist;
    minDist = g_cvBhopMinDist.FloatValue + STATE_TOLERANCE_DIST;

    // 连续丢失目标视野超过宽限期才转换为 APPROACH STATE
    if (!visible && GetGameTime() - g_AiChargers[client].m_flLastVisibleTime >= CHARGING_LOST_SIGHT_GRACE) {
        stateLog.debugAll("Charger (%N) lost sight of target (%N) for %.1f seconds, transition to APPROACH STATE", client, target, CHARGING_LOST_SIGHT_GRACE);
        return true;
    }
    // 目标非手持近战, 且到目标距离大于 g_cvBhopMinDist.FloatValue + 容差距离, 转换为 APPROACH STATE
    if (
        threatType != Threat_Melee &&
        dist > minDist
    ) {
        stateLog.debugAll("Charger (%N), target (%N), distance %.2f > min dist %.2f, transition to APPROACH STATE", client, target, dist, minDist);
        return true;
    }
    // 目标手持近战, 且到目标距离大于 meleeRange + g_cvMeleeBaitZoneMaxRange.FloatValue, 转换为 APPROACH STATE
    static float meleeRange;
    meleeRange = !cvMeleeRange ? DEFAULT_MELEE_RANGE : cvMeleeRange.FloatValue;
    minDist = meleeRange + g_cvMeleeBaitZoneMaxRange.FloatValue + STATE_TOLERANCE_DIST;
    if (
        threatType == Threat_Melee &&
        dist > minDist
    ) {
        stateLog.debugAll("Charger (%N), target (%N) holding melee, dist %.2f > baitZoneMax %.2f, transition to APPROACH STATE", client, target, dist, minDist);
        return true;
    }
    return false;
}

/**
* 处理冲锋后能力未就绪时的状态转换
* @param client 客户端索引
* @param target 目标索引
* @param dist 到目标距离
* @param threatType 目标威胁类型
* @return void
**/
void handleAbilityNotReady(int client, int target, float dist, TargetThreatType threatType) {
    static float meleeRange, baitZoneMax;
    meleeRange = !cvMeleeRange ? DEFAULT_MELEE_RANGE : cvMeleeRange.FloatValue;
    baitZoneMax = meleeRange + g_cvMeleeBaitZoneMaxRange.FloatValue;

    if (threatType == Threat_Melee) {
        if (dist <= baitZoneMax) {
            stateLog.debugAll("Charger (%N) ability not ready, melee threat (%N), dist %.2f < baitZoneMax %.2f, transition to BAIT STATE", client, target, dist, baitZoneMax);
            g_ChargerStateContext[client].transitionTo(CH_STATE_BAIT);
        } else if (dist > baitZoneMax + STATE_TOLERANCE_DIST) {
            stateLog.debugAll("Charger (%N) ability not ready, melee threat (%N), dist %.2f > baitZoneMax + tolerance, transition to APPROACH STATE", client, target, dist);
            g_ChargerStateContext[client].transitionTo(CH_STATE_APPROACH);
        }
    } else {
        if (dist <= g_cvBhopMinDist.FloatValue) {
            stateLog.debugAll("Charger (%N) ability not ready, non melee threat (%N), dist %.2f < bhopMinDist, transition to BAIT STATE", client, target, dist);
            g_ChargerStateContext[client].transitionTo(CH_STATE_BAIT);
        } else if (dist > g_cvBhopMinDist.FloatValue + STATE_TOLERANCE_DIST) {
            stateLog.debugAll("Charger (%N) ability not ready, non melee threat (%N), dist %.2f > bhopMinDist + tolerance, transition to APPROACH STATE", client, target, dist);
            g_ChargerStateContext[client].transitionTo(CH_STATE_APPROACH);
        }
    }
}

/**
* 构造目标运动学模型
* @param pos Charger 位置
* @param targetPos 目标位置
* @param targetVel 目标速度
* @param chargeSpeed 冲锋速度
* @param motion 返回的冲锋运动学模型
* @return 运动学模型构建成功返回 true
    1. 当前 Charger 和 target 距离过近, 小于 CHARGE_DIR_EPSILON, 表示冲锋方向退化, 直接判断高度差满足允许冲锋
    2. 目标水平速度已经超过了当前最大冲锋速度, 并且目标正在横向移动或者逃逸, 说明这次冲锋大概率无法命中, 返回 false, 模型构建失败
    3. Charger 冲锋时接近目标的相对速度太小, 小于 120.0, 大概率无法命中, 返回 false, 模型构建失败
* @error 
**/
stock bool buildChargeMotion(const float pos[3], const float targetPos[3], const float targetVel[3], float chargeSpeed, ChargeMotion motion) {
    motion.init();

    /*
    * 计算 Charger -> target 冲锋的水平方向
    * 如果方向向量长度小于 CHARGE_DIR_EPSILON, 不代表不能冲锋, 而是代表 Charger 和 target 过于近了, 说明 forward 方向退化
    * 但是如果满足高度差范围的话, 还是能够直接冲锋的
    */
    MakeVectorFromPoints(pos, targetPos, motion.m_vecForward);
    motion.m_vecForward[2] = 0.0;

    motion.m_flDist = NormalizeVector(motion.m_vecForward, motion.m_vecForward);
    if (motion.m_flDist <= CHARGE_DIR_EPSILON)
        return false;

    // 计算沿着冲锋方向的侧向方向向量
    GetVectorCrossProduct(motion.m_vecForward, {0.0, 0.0, 1.0}, motion.m_vecSide);
    NormalizeVector(motion.m_vecSide, motion.m_vecSide);

    // 提取目标的水平速度
    motion.m_vecTargetVel2D[0] = targetVel[0];
    motion.m_vecTargetVel2D[1] = targetVel[1];
    motion.m_vecTargetVel2D[2] = 0.0;

    motion.m_flTargetSpeed = getVectorLength2D(motion.m_vecTargetVel2D);

    // 目标水平速度已经超过当前最大冲锋速度时, 认为这次冲锋大概率无法命中, 不允许冲锋
    if (motion.m_flTargetSpeed > chargeSpeed)
        return false;

    /*
    * 分解目标当前速度
    * m_flForwardSpeed 表示目标沿着冲锋方向的速度分量, >0 说明目标远离 Charger, <0 说明目标靠近 Charger
    * m_flSideSpeed 表示目标沿着冲锋方向的侧向速度分量, >0 说明目标向右移动, <0 说明目标向左移动
    * m_flAbsSideSpeed 表示目标横向速度绝对值大小, 用于 getCommitDist, 因为 getCommitDist 只需要计算目标多久能够离开命中宽度
    */
    motion.m_flForwardSpeed = GetVectorDotProduct(motion.m_vecTargetVel2D, motion.m_vecForward);
    motion.m_flSideSpeed = GetVectorDotProduct(motion.m_vecTargetVel2D, motion.m_vecSide);
    motion.m_flAbsSideSpeed = FloatAbs(motion.m_flSideSpeed);

    /*
    * 计算有效冲锋速度和接近速度
    * 考虑到 Charger 冲锋的启动时间, 不是直接从 runTopSpeed 直接到 max charge speed 的, 但是不知道启动时间是多少
    * 因此保守估计 max charge speed, 宁愿慢一些, 也不要过早冲锋
    */
    motion.m_flEffectiveChargeSpeed = chargeSpeed * CHARGE_SPEED_EFFECTIVE_FACTOR;
    motion.m_flClosingSpeed = motion.m_flEffectiveChargeSpeed - motion.m_flForwardSpeed;

    if (motion.m_flClosingSpeed < 120.0)
        return false;

    // 估计冲锋命中时间
    motion.m_flTimeToImpact = motion.m_flDist / motion.m_flClosingSpeed;
    return true;
}

/**
* 动态计算 Charger 冲锋目标无法躲避冲锋的距离, 尤其是考虑了目标横向位移, 如果目标横向位移大, 那么允许冲锋距离 commit dist 就要小一点, 否则可以大一点
* @param pos Charger 位置
* @param targetPos 目标位置
* @param targetVel 目标速度
* @param chargeSpeed 冲锋速度
* @param commitDist 返回冲锋允许的最小距离
* @return bool, 返回 true 表示最小冲锋允许距离预测成功
* @error 
**/
stock bool getChargeCommitDist(const float pos[3], const float targetPos[3], const float targetVel[3], float chargeSpeed, float& commitDist) {
    commitDist = CHARGE_COMMIT_MIN_DIST;

    static ChargeMotion motion;
    if (!buildChargeMotion(pos, targetPos, targetVel, chargeSpeed, motion)) {
        /*
        * XY 基本重合时方向退化, 但高度可达就可以用最小 charge commit 距离来进行冲锋, 只要 charger 到达最小 charge commit 距离, 那么允许冲锋
        * 如果不是方向退化, buildChargeMotion 失败代表目标速度或接近速度不可靠, 不允许冲锋, 维持 Charging 状态等待一个合适的冲锋时机
        */
        if (motion.m_flDist <= CHARGE_DIR_EPSILON)
            return isChargeHeightReachable(pos, targetPos);

        return false;
    }

    static float sideSpeed;
    sideSpeed = motion.m_flAbsSideSpeed;

    /*
    * 即使目标当前纯直线后退, 也给横向逃逸一个最小估计值
    * 这是为了防止 commitDist 被除法放大到过远, 让 Charger 太早冲锋
    */
    if (sideSpeed < CHARGE_SIDE_SPEED_MIN)
        sideSpeed = CHARGE_SIDE_SPEED_MIN;

    /*
    * timeToHit = dist / closingSpeed
    * sideEscape = sideSpeed * timeToHit
    * 命中条件: sideEscape <= hitWidth
    * 推导: sideSpeed * (dist / closingSpeed) <= hitWidth
    * 所以: dist <= (hitWidth * closingSpeed) / sideSpeed
    */
    commitDist = (CHARGE_HIT_WIDTH * motion.m_flClosingSpeed) / sideSpeed;
    commitDist += CHARGE_DIST_TOLERANCE;

    if (commitDist < CHARGE_COMMIT_MIN_DIST) {
        commitDist = CHARGE_COMMIT_MIN_DIST;
    } else if (commitDist > CHARGE_COMMIT_MAX_DIST) {
        commitDist = CHARGE_COMMIT_MAX_DIST;
    }

    return true;
}

/**
* 计算 Charger 冲锋前瞄准的位置, 通过 build charge motion 中分解的目标速度, 预测目标在 timeToImpact 时间后的位置
* @param pos Charger 位置
* @param targetPos 目标位置
* @param targetVel 目标速度
* @param chargeSpeed 冲锋速度
* @param aimPos 瞄准位置
* @return bool, 返回 true 表示位置预测成功
* @error 
**/
stock bool calculateChargeAimPosition(const float pos[3], const float targetPos[3], const float targetVel[3], float chargeSpeed, float aimPos[3]) {
    // 运动学模型构建失败, 不进行冲锋位置预测
    static ChargeMotion motion;
    if (!buildChargeMotion(pos, targetPos, targetVel, chargeSpeed, motion))
        return false;

    // 如果冲锋时间太长, 那么就限制到最大预测 PREDICT_MAX_TIME
    static float predictTime;
    predictTime = motion.m_flTimeToImpact;
    if (predictTime > PREDICT_MAX_TIME)
        predictTime = PREDICT_MAX_TIME;

    static float offsetFwd, offsetSide;
    offsetFwd = motion.m_flForwardSpeed * predictTime;
    offsetSide = motion.m_flSideSpeed * predictTime;

    // 限制侧向偏移, 侧向偏移太多会导致 Charger 撞空
    if (offsetSide > PREDICT_MAX_LATERAL_OFFSET) {
        offsetSide = PREDICT_MAX_LATERAL_OFFSET;
    } else if (offsetSide < -PREDICT_MAX_LATERAL_OFFSET) {
        offsetSide = -PREDICT_MAX_LATERAL_OFFSET;
    }

    aimPos[0] = targetPos[0] + (motion.m_vecForward[0] * offsetFwd) + (motion.m_vecSide[0] * offsetSide);
    aimPos[1] = targetPos[1] + (motion.m_vecForward[1] * offsetFwd) + (motion.m_vecSide[1] * offsetSide);
    aimPos[2] = targetPos[2];

    return true;
}

stock Action performFinalBhopBeforeCharge(int client, const float pos[3], const float targetPos[3], const float targetVel[3],
    float dist, float commitDist, float speed, bool visible, int& buttons
) {
    if (!visible || !allowToBhop(client))
        return Plugin_Continue;

    // 距离已经到 commit dist 之内了, 直接冲锋
    if (dist <= commitDist)
        return Plugin_Continue;

    static float airTime;
    airTime = getJumpAirTime();
    if (airTime <= 0.0)
        return Plugin_Continue;

    static float targetVel2D[3];
    targetVel2D = targetVel;
    targetVel2D[2] = 0.0;
    
    static float predictPos[3];
    predictPos[0] = targetPos[0] + (targetVel2D[0] * airTime);
    predictPos[1] = targetPos[1] + (targetVel2D[1] * airTime);
    predictPos[2] = targetPos[2];

    static float dir[3], predictDist;
    MakeVectorFromPoints(pos, predictPos, dir);
    dir[2] = 0.0;

    predictDist = NormalizeVector(dir, dir);
    if (predictDist <= commitDist) {
        return Plugin_Continue;
    }

    static float desiredRemainDist;
    desiredRemainDist = commitDist * 0.60;

    // Charger 实际需要从当前位置一次连跳到 commitDist * 0.60 的距离
    static float travelDist;
    travelDist = predictDist - desiredRemainDist;

    if (travelDist <= 0.0)
        return Plugin_Continue;

    static float requiredSpeed;
    requiredSpeed = travelDist / airTime;
    if (requiredSpeed <= 0.0)
        return Plugin_Continue;

    // 计算最后一跳的连跳速度, 最小不能小于 runTopSpeed, 最大不能大于 g_cvBhopMaxSpeed.FloatValue
    static float baseSpeed, maxHopSpeed;
    baseSpeed = SDKCall(g_hSdkGetRunTopSpeed, client);
    maxHopSpeed = speed;

    if (maxHopSpeed < baseSpeed)
        maxHopSpeed = baseSpeed;

    maxHopSpeed += g_cvBhopImpulse.FloatValue;

    if (maxHopSpeed > g_cvBhopMaxSpeed.FloatValue)
        maxHopSpeed = g_cvBhopMaxSpeed.FloatValue;

    if (requiredSpeed > maxHopSpeed)
        return Plugin_Continue;

    // 缩放最后一跳的速度向量
    ScaleVector(dir, requiredSpeed);

    static float landPos[3];
    landPos[0] = pos[0] + (dir[0] * airTime);
    landPos[1] = pos[1] + (dir[1] * airTime);
    landPos[2] = pos[2];

    if (hasPotentialGap2(client, pos, landPos, JUMP_HEIGHT))
        return Plugin_Continue;

    if (!nextTickPosCheck(client, dir, visible))
        return Plugin_Continue;

    // 如果最后一跳的落点安全, 执行连跳
    buttons |= IN_DUCK;
    buttons |= IN_JUMP;

    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, dir);
    g_AiChargers[client].m_bBhopBeforeCharge = true;
    g_AiChargers[client].m_flFinalBhopStartTime = GetGameTime();
    g_AiChargers[client].m_flLastHopSpeed = getVectorLength2D(dir);

    stateLog.debugAll(
        "Charger (%N) performed final bunnyhop before charge, dist %.2f, commitDist %.2f, requiredSpeed %.2f, maxHopSpeed %.2f",
        client,
        dist,
        commitDist,
        getVectorLength2D(dir),
        maxHopSpeed
    );

    return Plugin_Changed;
}

// ============================================================
// OnExit 函数
// ============================================================
stock void StateCharging_OnExit(int client) {
    stateLog.debugAll("\n========== Charger (%N) State Charging On Exit ===========", client);
    // 再次重置人为冲锋延迟标记
    g_AiChargers[client].m_bChargeDelayed = false;
    g_AiChargers[client].m_bBhopBeforeCharge = false;
    g_AiChargers[client].m_flFinalBhopStartTime = 0.0;
    g_AiChargers[client].m_iBetterTarget = 0;
}

// ======== End of: ./state_charging.inc ========

// ======== Included from: ./state_approach.inc ========



// ======== Included from: ../setup.inc ========

// ======== End of: ../setup.inc ========

// ======== Included from: ../stocks.inc ========

// ======== End of: ../stocks.inc ========

// ======== Included from: ./state.inc ========

// ======== End of: ./state.inc ========

#define STATE_APPROACH_NAME             "STATE_APPROACH"
#define PATH_LOOKAHEAD_MIN_DIST         150.0           // 在地面时连跳前瞻目标点的最小距离
#define GOAL_POS_TOLERANCE_DIST         25.0            // Charger 与目标 Goal Pos 距离小于这个值时, 放弃速度修正
#define DEFAULT_PATH_LOOKAHEAD_DIST     300.0           // 默认的触发节点前向遍历距离

#define DIRECT_BHOP_TOLERANCE_BUFFER    150.0           // 朝着目标方向直线连跳状态切换到 Path 连跳的缓冲距离

#define GOAL_REACHED_DIST               100.0            // Charger 位置距离当前 GoalPos 位置在这个范围之内, 认为到达 GoalPos
#define PATH_REPATH_COOLDOWN            0.75             // Repath 之前的冷却时间
#define PATH_REPATH_DELAY               1.0              // 没有 Path, 尝试 Repath 到直接切成直线连跳的延迟时间

// =========================================================================
// State Approach 接近目标状态 (连跳等)
// 注册状态函数
// =========================================================================
stock void RegisterState_Approach() {
    ChargerState stateApproach;
    strcopy(stateApproach.name, sizeof(stateApproach.name), "State_Approach");
    stateApproach.OnEnter = StateApproach_OnEnter;
    stateApproach.OnUpdate = StateApproach_OnUpdate;
    stateApproach.OnExit = StateApproach_OnExit;
    g_ChargerStates.PushArray(stateApproach);
}

// ============================================================
// OnEnter 函数
// ============================================================
stock void StateApproach_OnEnter(int client) {
	g_AiChargers[client].m_flLastVisibleTime = GetGameTime();
    stateLog.debugAll("\n========== Charger (%N) State Approach On Enter ===========", client);
}

// ============================================================
// OnUpdate 函数
// ============================================================
stock Action StateApproach_OnUpdate(int client, int& buttons, float vel[3], float ang[3]) {
    if (!isAiCharger(client) || IsPinningSurvivor(client))
        return Plugin_Continue;

    // ============================================================
    // 数据收集 (Data Collection)
    // ============================================================
    static int target;
    target = GetClientOfUserId(g_AiChargers[client].m_iTarget);
    if (!IsValidSurvivor(target) || !IsPlayerAlive(target)) {
        stateLog.debugAll("(%s) Charger (%N)'s target %d is invalid", STATE_APPROACH_NAME, client, target);
        return Plugin_Continue;
    }
    
    // 计算 charger 当前速度
    static float vVel[3], speed;
    GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
    speed = getVectorLength2D(vVel);
    GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);
    // 计算 charger 当前到目标的距离
    static float pos[3], targetPos[3], targetEyePos[3], dist;
    GetClientAbsOrigin(client, pos);
    GetClientAbsOrigin(target, targetPos);
    GetClientEyePosition(target, targetEyePos);
    dist = getVectorDistance2D(pos, targetPos);
    // 是否可视目标
    static bool visible;
    visible = L4D2_IsVisibleToPlayer(client, TEAM_INFECTED, TEAM_SURVIVOR, 0, targetEyePos);
    if (visible) {
        g_AiChargers[client].m_flLastVisibleTime = GetGameTime();
    }
    // 是否在地上
    static bool isOnGround;
    isOnGround = IsClientOnGround(client);
    // 高度差过大时不进入 Bait/Locked, 避免不可冲锋目标导致状态抖动
    static bool chargeHeightReachable;
    chargeHeightReachable = isChargeHeightReachable(pos, targetPos);

    // ============================================================
    // 状态决策 (State Decision)
    // ============================================================

    // 1. 优先行动检查, 检测是否有更好的可以直接冲锋的目标, 如果有, 直接转换为冲锋状态
    if (isOnGround) {
        static int betterTarget;
        betterTarget = getChargeUnavoidableTarget(client, target, pos, dist, g_cvBhopMinDist.FloatValue);
        if (IsValidSurvivor(betterTarget) && IsPlayerAlive(betterTarget) &&
            isChargeAbilityReady(client) &&
            isChargeTargetHeightReachable(client, betterTarget) &&
            !isChargePathBlocked(client, betterTarget)
        ) {
            stateLog.debugAll("Charger (%N) find a better charge target %N, transition to LOCKED STATE", client, betterTarget);
            // 设置新目标, 转换为冲锋状态
            g_AiChargers[client].m_iBetterTarget = GetClientUserId(betterTarget);
            g_ChargerStateContext[client].transitionTo(CH_STATE_LOCKED);
            return Plugin_Changed;
        }
    }
    // 2. 紧急/近距离提前冲锋判断
    // 当血量低于阈值或距离小于阈值时, 跳过 BAIT 博弈和常规瞄准计算直接转入 LOCKED 状态
    if (visible && chargeHeightReachable &&
        !isChargePathBlocked(client, target) && isChargeAbilityReady(client)) {

        static int health;
        health = GetEntProp(client, Prop_Data, "m_iHealth");

        if (health < g_cvEarlyChargeHealth.IntValue || dist <= g_cvEarlyChargeDist.FloatValue) {
            stateLog.debugAll("Charger (%N) early charge trigger: health %d < %d or dist %.2f <= %.2f, transition to LOCKED STATE",
                client, health, g_cvEarlyChargeHealth.IntValue, dist, g_cvEarlyChargeDist.FloatValue);
            g_ChargerStateContext[client].transitionTo(CH_STATE_LOCKED);
            return Plugin_Changed;
        }
    }

    // 3. 面对近战威胁的博弈 (切换到 BAIT 博弈逻辑)
    // 若 charger 目标手持近战武器, 设置一个博弈区为 melee_range + g_cvMeleeBaitZoneMaxRange.FloatValue
    // charger 在空中进入该区域时, 急停, 进入博弈状态, 若在地上, 直接进入博弈状态, 避免 g_cvBhopMinDist.FloatValue 设置的太小, 连跳到目标脸上被砍
    static TargetThreatType threatType;
    threatType = getTargetThreatType(client, target);
    if (threatType == Threat_Melee) {
        static float meleeRange, baitZoneMax;
        meleeRange = !cvMeleeRange ? DEFAULT_MELEE_RANGE : cvMeleeRange.FloatValue;
        baitZoneMax = meleeRange + g_cvMeleeBaitZoneMaxRange.FloatValue;

        if (visible && chargeHeightReachable && dist <= baitZoneMax) {
            // 增加 airBreak 标记, 如果是空中急停, 修正了速度之后返回 Plugin_Changed 让速度修改返回 OnPlyaerRunCmd
            static bool airBreaked;
            airBreaked = false;

            if (!isOnGround && !g_AiChargers[client].m_bHasAirBreaked) {
                // 如果 charger 此时在空中, 将水平方向上的速度设置为 0, 仅保留垂直方向的速度
                vVel[0] = vVel[1] = 0.0;
                TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
                g_AiChargers[client].m_bHasAirBreaked = true;
                airBreaked = true;
            }
            // 转换为博弈状态
            stateLog.debugAll("Charger (%N) melee threat (%N) dist %.2f < %.2f, transition to BAIT", client, target, dist, baitZoneMax);
            g_ChargerStateContext[client].transitionTo(CH_STATE_BAIT);
            return airBreaked ? Plugin_Changed : Plugin_Continue;
        }
    }
    // 4. 常规距离达标后的博弈 or 准备冲锋 (转换到 BAIT 博弈逻辑)
    if (visible && chargeHeightReachable && dist <= g_cvBhopMinDist.FloatValue) {
        /**
         * charger 面对持枪生还者, 连跳到 g_cvBhopMinDist.FloatValue 时空中急停
         * 急停可能会出现的问题: charger 下落时间内, 目标又跑出去一段路, 此时 charger 冲锋无法准确命中目标
         * if (!isOnGround && !g_AiChargers[client].m_bHasAirBreaked) {
                // 如果 charger 此时在空中, 将水平方向上的速度设置为 0, 仅保留垂直方向的速度
                vVel[0] = vVel[1] = 0.0;
                TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
                g_AiChargers[client].m_bHasAirBreaked = true;
            }
         */
        // 到目标距离小于允许连跳的最小距离, 转换为博弈状态
        stateLog.debugAll("Charger (%N) to target (%N) dist %.2f <= %.2f, transition to BAIT", client, target, dist, g_cvBhopMinDist.FloatValue);
        g_ChargerStateContext[client].transitionTo(CH_STATE_BAIT);
        return Plugin_Continue;
    }

    // ============================================================
    // 动作干预 (Default Actions)
    // ============================================================

    // 移除原生攻击键, 特别是 IN_ATTACK2, 避免多个 Charger 生成在远处互相打拳
    //buttons &= ~IN_ATTACK;
    //buttons &= ~IN_ATTACK2;
    setChargerAbilityCooldown(client, 1.0);

    // ============================================================
    // 连跳行为 (Bhop Execution)
    // ============================================================
    static Action bhopRes;
    bhopRes = checkShouldBhop(client, buttons, target, vVel, speed, dist, visible, pos, targetPos);
    if (bhopRes != Plugin_Continue)
        return bhopRes;

    return Plugin_Continue;
}

stock Action checkShouldBhop(
    int client, int& buttons, int target, float vVel[3], float speed,
    float dist, bool visible, float pos[3], float targetPos[3]
) {
    if (!isAiCharger(client))
        return Plugin_Continue;
    if (!IsValidSurvivor(target) || !IsPlayerAlive(target))
        return Plugin_Continue;
    if (!allowToBhop(client))
        return Plugin_Continue;

    // 是否在地上
    static bool isOnGround;
    isOnGround = IsClientOnGround(client);
    if (isOnGround) {
        g_AiChargers[client].m_bHasAirBreaked = false;
    }

    // 连跳距离限制
    if (dist > g_cvBhopMaxDist.FloatValue)
        return Plugin_Continue;

    // 连跳空速限制
    if (speed < g_cvBhopMinSpeed.FloatValue)
        return Plugin_Continue;

    if (isOnGround)
        return executeGroundBhop(client, target, dist, speed, visible, pos, targetPos, vVel, buttons);
    else
        return executeAirCorrection(client, dist, speed, visible, pos, targetPos, vVel, buttons);
}

/**
* 检查当前 Charger 的 Path 是否通向目标, 也就是目标所在的 NavArea 是否在 Charger 的 Path 上
* @param client 客户端索引
* @param targetNavArea 目标所在的 NavArea
* @param hasSpecialMove 如果目标所在的 NavArea 在 Charger 的 Path 上, 从 Charger 当前的 PathSegment 到目标所在的 PathSegment 是否存在 SetmentType != ON_GROUND 的 Segment
* @return bool 目标是否在 Charger 当前 Path 上
* @error 
**/
stock bool isRemainingPathSupportsTarget(int client, Address targetNavArea, bool& hasSpecialMove) {
    if (!isAiCharger(client))
        return false;
    if (!targetNavArea)
        return false;
    
    hasSpecialMove = false;

    static Address pPathFollower;
    pPathFollower = g_AiChargers[client].m_pPathFollower;

    static Address pCurrentSeg, pLastSegment;
    pCurrentSeg = g_AiChargers[client].m_PathSegment.m_pPathSegment;
    pLastSegment = g_AiChargers[client].m_LastPathSegment.m_pPathSegment;

    if (!pPathFollower || !pCurrentSeg || !pLastSegment)
        return false;
    
    static bool scannedAny;
    scannedAny = false;

    static PathSegment curSeg, lastScannedSeg;
    while (pCurrentSeg != Address_Null) {
        constructPathSegment(pCurrentSeg, curSeg);

        lastScannedSeg = curSeg;
        scannedAny = true;

        // 查看当前遍历的 PathSegment 的 SegmentType 查看是否需要特殊移动
        if (curSeg.m_SegmentType != SegType_OnGround)
            hasSpecialMove = true;

        // 如果当前 Path 的某一个 Segment 对应的 NavArea 等于目标所在的 NavArea, 则返回 true
        if (curSeg.m_pNavArea == targetNavArea)
            return true;
        
        if (pCurrentSeg == pLastSegment)
            break;

        pCurrentSeg = view_as<Address>(SDKCall(g_hSdkPathNextSegment, pPathFollower, pCurrentSeg));

        if (!pCurrentSeg)
            break;
    }

    if (!scannedAny || !lastScannedSeg.m_pNavArea)
        return false;
    
    // 目标移动到 Path 终点相邻的 NavArea 也视为当前 Path 可以通向目标
    return (
        L4D_NavArea_IsConnected(lastScannedSeg.m_pNavArea, targetNavArea, NAV_ALL) ||
        L4D_NavArea_IsConnected(targetNavArea, lastScannedSeg.m_pNavArea, NAV_ALL)
    );
}

/**
* 检查 Charger 是否已经到达了当前 Path 最后一个节点的 GoalPos, 判断当前 Charger 位置是否已经接近 GoalPos 或者已经越过了 GoalPos
* @param pos 当前 Charger 坐标
* @param vel 当前 Charger 速度向量
* @param goalPos 需要检测的 GoalPos 坐标
* @return bool 如果靠近或者越过, 返回 true
* @error 
**/
stock bool isFinalGoalReached(const float pos[3], const float vel[3], const float goalPos[3]) {
    // Charger 已经足够接近 GoalPos, 直接认为已到达
    static float dist2D;
    dist2D = getVectorDistance2D(pos, goalPos);
    if (dist2D <= GOAL_REACHED_DIST) {
        return true;
    }

    /*
    * 判断 GoalPos 是否已经落在 Charger 水平移动方向的后方
    * toGoal 表示当前 Charger 到 GoalPos 的方向向量
    * moveDir 表示 Charger 水平方向的速度向量
    */
    static float toGoal[3], moveDir[3];
    MakeVectorFromPoints(pos, goalPos, toGoal);
    toGoal[2] = 0.0;

    moveDir = vel;
    moveDir[2] = 0.0;

    // 如果 Charger 当前位置到 GoalPos 的水平距离几乎为 0, 那么认为已经到达
    if (NormalizeVector(toGoal, toGoal) <= 0.0)
        return true;
    
    // 如果 Charger 当前没有水平速度, 那么直接返回 false
    if (NormalizeVector(moveDir, moveDir) <= 0.0)
        return false;

    /*
    * 如果 GoalPos 处在移动方向背后, 认为是已经到达终点
    * dot < -0.20 表示 ArcCosine(Dot(·)), 约为 101.5 度, 也就是说 GoalPos 已经明显处于当前速度方向的后方, 而不是刚好 dot = 0.0 表示侧方 90 度位置
    */
    return GetVectorDotProduct(moveDir, toGoal) < -0.20;
}

stock void buildDirectBhopVelocity(const float pos[3], const float targetPos[3], float speed, float outputVelVec[3]) {
    MakeVectorFromPoints(pos, targetPos, outputVelVec);
    outputVelVec[2] = 0.0;

    if (NormalizeVector(outputVelVec, outputVelVec) <= 0.0) {
        ZeroVector(outputVelVec);
        return;
    }

    ScaleVector(outputVelVec, speed + g_cvBhopImpulse.FloatValue);

    limitGroundBhopVel(outputVelVec);
}

/**
* 检查朝着目标方向直线连跳是否安全
* @param client 客户端索引
* @param pos 当前 Charger 位置
* @param targetPos 目标位置
* @param velVec 当前 Charger 速度向量
* @return bool, 如果安全, 返回 true
* @error 
**/
stock bool isDirectBhopSafe(int client, const float pos[3], const float targetPos[3], const float velVec[3]) {
    // 获取 ILocomotion 指针用于 HasPotentialGap 的检查
    /* static Address pLocomotion;
    pLocomotion = clientGetLocomotionInterface(client);
    if (!pLocomotion)
        return false; */
    
    // 计算当前位置到目标点的水平 2D 方向
    static float vDir[3];
    MakeVectorFromPoints(pos, targetPos, vDir);
    vDir[2] = 0.0;

    static float targetDist2D;
    targetDist2D = NormalizeVector(vDir, vDir);
    if (targetDist2D <= 0.0) {
        return false;
    }

    /*
    * 预测 Charger 在一次空中连跳可能飞出的水平距离, 如果当前速度很快 Charger 可能不会停在 targetPos 而是继续向前飞, 飞到目标后面之类的
    * 因此实际落点要使用 routeEnd 也就是根据算出来的水平距离的落点而不是 targetPos
    */
    static float curSpeed2D, predictedAirDist;
    curSpeed2D = getVectorLength2D(velVec);
    predictedAirDist = curSpeed2D * getJumpAirTime();

    // 先把 routeCheckDist 设置成为 targetDist, 在判断和实际飞行距离的关系, 取较大值
    static float routeCheckDist;
    routeCheckDist = targetDist2D;
    if (predictedAirDist > targetDist2D) {
        routeCheckDist = predictedAirDist;
    }
    
    /*
    * 构造本次直线连跳可能到达的终点坐标 routeEnd
    * z 高度沿着 pos -> targetPos 的高度斜率外推, 如果 routeCheckDist > targetDist2D, 表示 Charger 会飞过头, 因此 routeEnd 的 z 高度也同样按照斜率外推
    */
    static float heightDelta, heightSlopePerUnit;
    heightDelta = targetPos[2] - pos[2];
    heightSlopePerUnit = heightDelta / targetDist2D;

    static float routeEnd[3];
    routeEnd[0] = pos[0] + vDir[0] * routeCheckDist;
    routeEnd[1] = pos[1] + vDir[1] * routeCheckDist;
    routeEnd[2] = pos[2] + (heightSlopePerUnit * routeCheckDist);
    
    // 原生 hasPotentialGap 检查 Charger 位置到目标位置的路线是否存在 Gap, 但不作为最终判断条件, 因为最终判断条件是需要 Charger 位置到 routeEnd 位置的判断
    /* static bool hasGap;
    hasGap = hasPotentialGap(pLocomotion, pos, targetPos);
    stateLog.debugAll("[IsDirectBhopSafe]: hasPotentialGap: %b, routeDist: %.2f", hasGap, routeDist); */

    // 检查整段实际路线, 包括速度太快可能跳到目标后方
    if (hasPotentialGap2(client, pos, routeEnd, JUMP_HEIGHT)) {
        return false;
    }
    
    // 检查到目标的方向是否被障碍物阻挡, 如果有阻挡继续沿着 Path 连跳
    static float traceStart[3], traceEnd[3];
    L4D_GetEntityWorldSpaceCenter(client, traceStart);

    traceEnd = routeEnd;
    traceEnd[2] += PLAYER_HEIGHT * 0.5;

    static Handle hTrace;
    hTrace = TR_TraceHullFilterEx(traceStart, traceEnd, {-16.0, -16.0, -16.0}, {16.0, 16.0, 16.0}, MASK_PLAYERSOLID, _TraceWallFilter, client);

    static bool routeBlocked;
    routeBlocked = TR_DidHit(hTrace);
    delete hTrace;

    if (routeBlocked)
        return false;

    return true;
}

stock void clearPathWait(int client) {
    g_AiChargers[client].m_flPathWaitStart = -1.0;
}

stock void enterPathWait(int client, bool invalidateOldPath) {
    static float now;
    now = GetGameTime();

    // 进入 Repath 等待期, 等待 Repath, 此时让引擎接管 Charger 动作, 清空连跳相关变量
    if (g_AiChargers[client].m_flPathWaitStart < 0.0)
        g_AiChargers[client].m_flPathWaitStart = now;

    ZeroVector(g_AiChargers[client].m_vecAirCorrGoal);
    g_AiChargers[client].m_BhopType = BhopType_None;
    g_AiChargers[client].m_AirStrafe.init();

    if (!invalidateOldPath)
        return;

    // 等待一个冷却时间, 然后 Invalidate Path, 让引擎重新计算新的 Path
    if (now - g_AiChargers[client].m_flLastPathInvalidateTime < PATH_REPATH_COOLDOWN)
        return;

    // 如果需要销毁旧的 Path, 那么就销毁, 然后等待 Repath
    SDKCall(g_hSdkPathInvalidate, g_AiChargers[client].m_pPathFollower);
    g_AiChargers[client].m_flLastPathInvalidateTime = now;

    g_AiChargers[client].m_PathSegment.init();
    g_AiChargers[client].m_NextPathSegment.init();
    g_AiChargers[client].m_LastPathSegment.init();
}

stock void setupGroundAirStrafe(int client, float targetDist, float airCorrDist) {
    /*
    * 在 Charger 起跳前配置下一次空中侧向连跳参数
    * airCorrDist 表示 Charger 到空中速度修正目标点的距离, 这个目标点在不侧向连跳的时候是目标位置, 沿着 Path 侧向连跳时是 PathLookAheadGoal
    */
    static AirStrafe airStrafe;
    airStrafe = g_AiChargers[client].m_AirStrafe;

    // 每次 GroundSetup 都先重置本次 Strafe 状态, 如果后续条件不满足, 本次空中不会执行侧向偏移
    airStrafe.m_flStrafeStartDist = airCorrDist;
    airStrafe.m_flStrafeAmp = 0.0;
    airStrafe.m_StrafeType = StrafeType_None;

    /*
    * 启用侧向连跳条件如下
    * 1. g_cvBhopStrafeMinDeg 开启, 开启侧向偏移功能
    * 2. targetDist 足够远, 大于 g_cvBhopStrafeMinDist.FloatValue
    * 3. airCorrDist 足够远, 大于 GOAL_POS_TOLERANCE_DIST, 然后再根据距离决定做一次侧向还是两次侧向偏移
    */
    static bool strafeEnable;
    strafeEnable = (
        g_cvBhopStrafeMinDeg.FloatValue > 0.0 &&
        targetDist > g_cvBhopStrafeMinDist.FloatValue &&
        airCorrDist > GOAL_POS_TOLERANCE_DIST
    );

    if (!strafeEnable) {
        g_AiChargers[client].m_AirStrafe = airStrafe;
        return;
    }

    /*
    * 每次真正启用侧向连跳时, 方向和上一次相反
    * 如果之前没有进行过侧向连跳的话, 那么随机选择一个左右方向
    */
    if (airStrafe.m_StrafeDir == StrafeDir_None) {
        airStrafe.m_StrafeDir = (GetRandomFloatInRange(0.0, 1.0) > 0.5) ? StrafeDir_Left : StrafeDir_Right;
    } else if (airStrafe.m_StrafeDir == StrafeDir_Left) {
        airStrafe.m_StrafeDir = StrafeDir_Right;
    } else {
        airStrafe.m_StrafeDir = StrafeDir_Left;
    }

    /*
    * targetDist 已经通过 g_cvBhopStrafeMinDist.FloatValue
    * 当 airCorrDist 足够大时执行两次偏移, 当 airCorrDist 大于 g_cvBhopStrafeOnceDist 时执行一次偏移, 否则不执行偏移
    */
    if (airCorrDist >= g_cvBhopStrafeTwiceDist.FloatValue) {
        airStrafe.m_StrafeType = StrafeType_Twice;
    } else if (airCorrDist >= g_cvBhopStrafeOnceDist.FloatValue) {
        airStrafe.m_StrafeType = StrafeType_Once;
    } else {
        airStrafe.m_StrafeType = StrafeType_None;
    }

    /*
    * tan(angle)
    * 使用一个角度, 根据 forward 速度向量算出需要偏移的方向向量, 然后 desired = forward + (right * amp)
    * amp = tan(theta) 可以让 desired 最终向量相对于 forward 前向向量偏转 theta 度
    */
    airStrafe.m_flStrafeAmp = Tangent(DegToRad(GetRandomFloatInRange(g_cvBhopStrafeMinDeg.FloatValue, g_cvBhopStrafeMaxDeg.FloatValue)));

    g_AiChargers[client].m_AirStrafe = airStrafe;
}

stock void limitGroundBhopVel(float vel[3]) {
    static float horizontalSpeed;
    horizontalSpeed = getVectorLength2D(vel);

    if (horizontalSpeed <= 0.0 || horizontalSpeed <= g_cvBhopMaxSpeed.FloatValue)
        return;
    
    ScaleVector(vel, (g_cvBhopMaxSpeed.FloatValue / horizontalSpeed));
}

stock Action performPathGroundBhop(int client, float targetDist, const float pos[3], const float targetPos[3], float speed, bool visible, int& buttons) {
    #pragma unused targetPos

    static float lookAheadPos[3];
    static float maxEstimateDist;
    maxEstimateDist = speed * getJumpAirTime();

    // 最小向前检查距离不能小于 PATH_LOOKAHEAD_MIN_DIST
    if (maxEstimateDist < PATH_LOOKAHEAD_MIN_DIST) {
        maxEstimateDist = PATH_LOOKAHEAD_MIN_DIST;
    }

    if (!getLookAheadGoalPos(client, pos, maxEstimateDist, lookAheadPos, g_cvPathLookAheadMaxDepth.IntValue)) {
        /*
        * 找不到可用的 LookAhead Goal Pos 不代表 Path 无效, 也不能因此切换到 Direct 连跳模式
        */
        ZeroVector(g_AiChargers[client].m_vecAirCorrGoal);
        g_AiChargers[client].m_BhopType = BhopType_None;
        g_AiChargers[client].m_AirStrafe.m_StrafeType = StrafeType_None;
        
        return Plugin_Continue;
    }

    static float vFwd[3];

    // Debug print, if current PathSegment is not the last, print charger pos and look ahead goal pos, color: cyan
    /* DrawBeamPoint(lookAheadPos, NULL_VECTOR, {0, 255, 255, 255}, 0.1); */
    MakeVectorFromPoints(pos, lookAheadPos, vFwd);
    vFwd[2] = 0.0;

    if (NormalizeVector(vFwd, vFwd) <= 0.0) {
        g_AiChargers[client].m_BhopType = BhopType_None;
        return Plugin_Continue;
    }

    ScaleVector(vFwd, speed + g_cvBhopImpulse.FloatValue);

    // 连跳前限制速度, 使检查距离与最终实际速度一致
    limitGroundBhopVel(vFwd);

    if (!nextTickPosCheck(client, vFwd, visible)) {
        g_AiChargers[client].m_BhopType = BhopType_None;
        g_AiChargers[client].m_AirStrafe.m_StrafeType = StrafeType_None;
        return Plugin_Continue;
    }

    static float airCorrDist;
    airCorrDist = getVectorDistance2D(pos, lookAheadPos);

    // 只有确定本次能够起跳后, 才写入空中状态
    g_AiChargers[client].m_BhopType = BhopType_Path;
    g_AiChargers[client].m_vecAirCorrGoal = lookAheadPos;

    setupGroundAirStrafe(client, targetDist, airCorrDist);

    buttons |= IN_JUMP;
    buttons |= IN_DUCK;

    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vFwd);

    // 保存起跳速度, 防止空中速度衰减
    g_AiChargers[client].m_flLastHopSpeed = getVectorLength2D(vFwd);

    stateLog.debugAll("Charger(%N) Path Ground Bhop, speed: %.2f, target dist: %.2f, air correction dist: %.2f, strafe type: %d",
        client, g_AiChargers[client].m_flLastHopSpeed, targetDist, airCorrDist, g_AiChargers[client].m_AirStrafe.m_StrafeType);

    return Plugin_Changed;
}

stock Action performDirectGrounBhop(int client, float targetDist, const float pos[3], const float targetPos[3], float speed, bool visible, int& buttons) {
    static float vFwd[3];
    buildDirectBhopVelocity(pos, targetPos, speed, vFwd);

    vFwd[2] = 0.0;

    if (getVectorLength2D(vFwd) <= 0.0) {
        g_AiChargers[client].m_BhopType = BhopType_None;
        return Plugin_Continue;
    }

    if (!isDirectBhopSafe(client, pos, targetPos, vFwd)) {
        g_AiChargers[client].m_BhopType = BhopType_None;
        g_AiChargers[client].m_AirStrafe.m_StrafeType = StrafeType_None;
        return Plugin_Continue;
    }

    if (!nextTickPosCheck(client, vFwd, visible)) {
        g_AiChargers[client].m_BhopType = BhopType_None;
        g_AiChargers[client].m_AirStrafe.m_StrafeType = StrafeType_None;
        return Plugin_Continue;
    }

    static float airCorrDist;
    airCorrDist = getVectorLength2D(vFwd) * getJumpAirTime();

    g_AiChargers[client].m_BhopType = BhopType_Normal;

    // Direct 连跳使用目标位置作为空中修正方向, 不需要写入 Path AirCorrGoal
    ZeroVector(g_AiChargers[client].m_vecAirCorrGoal);

    setupGroundAirStrafe(client, targetDist, airCorrDist);

    buttons |= IN_JUMP;
    buttons |= IN_DUCK;

    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vFwd);

    g_AiChargers[client].m_flLastHopSpeed = getVectorLength2D(vFwd);

    stateLog.debugAll("Charger(%N) Direct Ground Bhop, speed: %.2f, target dist: %.2f, air correction dist: %.2f, strafe type: %d",
        client, g_AiChargers[client].m_flLastHopSpeed, targetDist, airCorrDist, g_AiChargers[client].m_AirStrafe.m_StrafeType);

    return Plugin_Changed;
}

/**
* 处理地面连跳逻辑
* @param client 客户端索引
* @param target 目标索引
* @param dist 与目标距离
* @param speed 当前速度
* @param visible 是否有视野
* @param nextSeg 下一个 PathSegment
* @param pos 当前位置
* @param targetPos 目标位置
* @param vVel 当前速度
* @return Action
**/
stock Action executeGroundBhop(
    int client, int target, float dist, float speed, bool visible,
    const float pos[3], const float targetPos[3], const float vVel[3], int& buttons
) {
    // 如果无视野, 且不允许连跳, 返回
    if (!visible && !g_cvBhopNoVision.BoolValue)
        return Plugin_Continue;

    /*
        使用 Next PathSegment 的 Goal Pos 作为连跳加速度与空中速度方向修正的方向
        因为在一块 Nav 之内, Current PathSegment 的 Goal Pos 可能会根据当前 bot 位置被多次改变, 没有激活 PathSegment 之前, Goal Pos (不变)
        进入当前 PathSegment 并激活当前 PathSegment 后, 会根据当前 bot 位置改变 Goal Pos, Goal Pos 频繁被改变则会影响空中速度方向修正
    */
    /*
    * 沿着 Path 的连跳还需要注意当前 Path 是否断档, 比如 c4m2 楼梯, Charger 的一条 Path 可能最后一个节点在楼梯口
    * 此时直接判断 currentSegment == lastSegment 认为已经没有后续 Path, 让 Charger 沿着目标方向 (在楼的另一侧) 连跳会导致 Charger 摔下楼梯, 因此需要更加严格的判断
    * 如果还可以 Repath, 不要着急切换到朝着目标方向直线连跳
    * 
    * currentSeg != lastSeg 表示当前 Path 还有后续节点, 可以继续走
    * currentSeg == lastSeg 表示正在前往最后一个 Segment 的 GoalPos, Path 仍然有效
    * lastGoalReached 表示当前 Path 已经走完
    */
    static bool hasPath, atLastSegment, lastGoalReached;

    /*
    * currentSeg == lastSeg && !targetOnPath 可以解释为当前 Path 断裂, 等待 Repath
    * currentSeg == null && !targetOnPath 解释为目标不在有效 Nav 上, 直接朝着目标方向加速
    */
    static PathSegment currentSeg, lastSeg;
    currentSeg = g_AiChargers[client].m_PathSegment;
    lastSeg = g_AiChargers[client].m_LastPathSegment;

    // 当前 PathSegment 和当前 Path 最后一个 Segment 均有效, 则为路径有效
    hasPath = g_AiChargers[client].m_pPathFollower && (currentSeg.m_pPathSegment && lastSeg.m_pPathSegment);
    // 是否到达当前 Path 的最后一个 Segment
    atLastSegment = hasPath && (currentSeg.m_pPathSegment == lastSeg.m_pPathSegment);
    // 是否已经走完最后一个 PathSegment
    lastGoalReached = (atLastSegment && isFinalGoalReached(pos, vVel, currentSeg.m_vecGoalPos));

    /*
    * targetOnPath 判断目标是否在 Charger 当前 Path 上, 如果目标不在 Charger 当前 Path 上, 且 Charger 当前 Path 无效, 允许朝着目标方向连跳加速,
    * 平地正常 Path, 目标位于 Charger 当前 Path 上, 如果是 c4m2 楼梯口 Path 断裂, 那么 targetOnPath == false
    * hasSpecialMove 表示当前 Path 到目标是否中间存在 SegmentType != OnGround 的 Segment
    */
    static bool hasSpecialMove, targetOnPath;
    hasSpecialMove = false;
    targetOnPath = false;

    static Address targetNavArea;
    targetNavArea = L4D_GetLastKnownArea(target);
    if (!targetNavArea) {
        static float targetPos_cpy[3];
        targetPos_cpy = targetPos;
        targetPos_cpy[2] += 20.0;
        targetNavArea = L4D_GetNearestNavArea(targetPos_cpy, _, false, true, true, TEAM_SURVIVOR);
    }
    if (!targetNavArea) {
        stateLog.error("[ExecuteGroundBhop]: Client %N is on invalid NavArea!", client);
        targetOnPath = false;
    }
    if (hasPath && targetNavArea) {
        targetOnPath = isRemainingPathSupportsTarget(client, targetNavArea, hasSpecialMove);
    }

    stateLog.debugAll("[ExecuteGroundBhop]: Client: %d, dist: %.2f, speed: %.2f, visible: %d, hasPath: %d, atLastSegment: %d, lastGoalReached: %d, targetOnPath: %d",
        client, dist, speed, visible, hasPath, atLastSegment, lastGoalReached, targetOnPath);


    /*
    * 直接连跳模式加入退出缓冲距离, 避免在 direct bhop 距离阈值附近来回切换模式
    */
    static float directBhopDist;
    directBhopDist = g_cvDirectBhopDist.FloatValue;
    if (g_AiChargers[client].m_BhopType == BhopType_Normal) {
        directBhopDist += DIRECT_BHOP_TOLERANCE_BUFFER;
    }

    /*
    * Direct 距离阈值只用于限制有 Path 时的模式切换
    * 当前完全没有 Path 时, 允许直接尝试朝目标方向连跳, 再交给 performDirectGrounBhop 做安全检查
    */
    static bool withinDirectDistance;
    withinDirectDistance = (
        !hasPath ||
        dist <= directBhopDist
    );

    /*
    * 进行朝着目标方向直线连跳的基础判断
    * 1. pathProvenDirect: 目标仍然处于剩余 Path 上, 且中间没有特殊移动, 说明 Path 证明可以直接朝着目标方向连跳
    * 2. closeStalePath: 目标已经不在当前 Path 上, 通常是由于目标移动, 然后旧的 Path 已经过期
    *   此时允许尝试直线连跳, 但是需要通过 performDirectGrounBhop 内部的 isDirectBhopSafe 和 nextTickPosCheck
    */

    static bool pathProvenDirect;
    pathProvenDirect = (
        hasPath &&
        targetOnPath &&
        !hasSpecialMove
    );

    static bool closeStalePath;
    closeStalePath = (
        hasPath &&
        !targetOnPath &&
        withinDirectDistance &&
        visible
    );

    static bool canTryDirectBhop;
    canTryDirectBhop = (
        visible &&
        withinDirectDistance && (
            pathProvenDirect ||
            closeStalePath
        )
    );

    static Action directBhopRes;

    /*
    * 正常平地, 可以直接使用到目标的直线方向连跳, Path 有效且仍然通向目标, 地形检查通过, 直接转为直线连跳
    */
    if (canTryDirectBhop) {
        g_AiChargers[client].m_BhopType = BhopType_DirectCandidate;

        directBhopRes = performDirectGrounBhop(client, dist, pos, targetPos, speed, visible, buttons);

        // 正常连跳, return Plugin_Changed
        if (directBhopRes != Plugin_Continue) {
            clearPathWait(client);
            return directBhopRes;
        }

        /*
        * 如果 performDirectGrounBhop 拒绝执行连跳, 那么返回 Plugin_Continue
        * 这通常说明近距离目标不在旧的 Path 上, 已经产生了移动, 而且直线连跳不安全, 这通常是楼梯口, 断层等需要绕路的场景
        * 不要继续沿着旧的 Path 连跳前进, 而是将当前旧的 Path Invalidate, 交给给引擎决定, 重新计算新的 Path
        */
        if (closeStalePath) {
            enterPathWait(client, true);
            return Plugin_Continue;
        }
    }

    /*
    * 当前 Path 仍有未完成部分, 即使距离已经进入直线连跳阈值, 只要直线连跳不安全, 那么就继续沿着 Path
    */
    if (hasPath && !lastGoalReached) {
        clearPathWait(client);

        return performPathGroundBhop(client, dist, pos, targetPos, speed, visible, buttons);
    }

    /*
    * 到达 Path 终点, 但它没有安全连接到目标, 返回原生控制, 等待 ChargerAttack::Update 计算新的 Path
    */
    if (hasPath && lastGoalReached) {
        enterPathWait(client, true);

        // canEnterDirectBhop 返回 false 说明直线连跳不安全, 然后当前 Path 已经走完, 返回原生控制, 等待 Repath
        return Plugin_Continue;
    }

    // 当前完全没有 Path, 可能是目标站在了无效的 NavArea 上, 直接尝试直线连跳
    static bool canTryNoPathDirectBhop;
    canTryNoPathDirectBhop = (
        visible &&
        withinDirectDistance
    );

    stateLog.debugAll("[ExecuteGroundBhop]: Client: %N, visible: %d, withinDirectDist: %d, directDist: %.2f, canTryNoPathDirectBhop: %d",
        client, visible, withinDirectDistance, directBhopDist, canTryNoPathDirectBhop);

    if (canTryNoPathDirectBhop) {
        directBhopRes = performDirectGrounBhop(client, dist, pos, targetPos, speed, visible, buttons);

        if (directBhopRes != Plugin_Continue) {
            clearPathWait(client);

            return directBhopRes;
        }
    }

    return Plugin_Continue;
}

stock bool buildStrafedDesiredVector(int client, const float baseDir[3], float curDist, float outDesired[3]) {
    outDesired = baseDir;
    outDesired[2] = 0.0;

    if (NormalizeVector(outDesired, outDesired) <= 0.0)
        return false;

    static StrafeType strafeType;
    strafeType = g_AiChargers[client].m_AirStrafe.m_StrafeType;

    if (strafeType == StrafeType_None || g_cvBhopStrafeMinDeg.FloatValue <= 0.0 || curDist <= GOAL_POS_TOLERANCE_DIST) {
        return false;
    }

    static float startDist;
    startDist = g_AiChargers[client].m_AirStrafe.m_flStrafeStartDist;

    if (startDist <= 10.0)
        return false;

    static float progress;
    progress = curDist / startDist;

    if (progress > 1.0)
        progress = 1.0;
    else if (progress < 0.0)
        progress = 0.0;

    // 获取当前侧向连跳的方向
    static StrafeDir strafeDir;
    strafeDir = g_AiChargers[client].m_AirStrafe.m_StrafeDir;

    // 获取之前起跳时设置的振幅
    static float amp;
    amp = g_AiChargers[client].m_AirStrafe.m_flStrafeAmp;

    if (amp <= 0.0 || strafeDir == StrafeDir_None)
        return false;

    // M 是由余弦函数生成的侧向偏移幅度, M 越大侧向连跳时横向位移越大
    static float M;
    M = 0.0;

    if (strafeType == StrafeType_Once) {
        // 只做 (0~π/2) 的余弦曲线或 (π~3/2π) 的余弦曲线
        M = Cosine(progress * PI) * float(view_as<int>(strafeDir)) * amp;
    } else if (strafeType == StrafeType_Twice) {
        // 做一个完整的余弦曲线偏移
        M = Cosine(progress * PI * 2.0) * float(view_as<int>(strafeDir)) * amp;
    }

    // 计算与 vDir 方向正交的方向向量
    static float vRight[3];
    GetVectorCrossProduct(outDesired, {0.0, 0.0, 1.0}, vRight);
    
    if (NormalizeVector(vRight, vRight) <= 0.0)
        return false;

    // 算出包含了偏移曲线在内的最终方向
    outDesired[0] += vRight[0] * M;
    outDesired[1] += vRight[1] * M;
    outDesired[2] = 0.0;
    NormalizeVector(outDesired, outDesired);

    // 可视化黄色 desired 位置曲线, 绿色 vRight 方向向量曲线, 橙色 air correction goal 坐标点
    /* static float vPos[3];
    vPos = pos;
    ShowDir(COLOR_GREEN, vPos, vRight, 5.0, 50.0);
    ShowDir(COLOR_YELLOW, vPos, vDesired, 5.0, 50.0);
    DrawBeamPoint(g_AiChargers[client].m_vecAirCorrGoal, NULL_VECTOR, {251, 164, 20, 255}, 10.0); */

    return true;
}

/**
* 处理空中速度方向修正逻辑
* @param client 客户端索引
* @param dist 到目标距离
* @param speed 当前速度
* @param visible 是否有目标视野
* @param nextSeg 下一个 PathSegment
* @param pos 当前位置
* @param target 目标位置
* @param vVel 当前速度向量
* @return Action
**/
stock Action executeAirCorrection(
    int client, float dist, float speed, bool visible,
    const float pos[3], const float targetPos[3], const float vVel[3], int& buttons
) {

    static float vFwd[3], vVel_cpy[3], vDir[3], dot, d2Goal, h2Goal;
    #pragma unused h2Goal

    vVel_cpy = vVel;
    vVel_cpy[2] = 0.0;

    // ============================================================
    // 1. 当前连跳模式为基于 PATH 的连跳, 进行基于 PATH 的空中速度方向修正
    // ============================================================
    if (g_AiChargers[client].m_BhopType == BhopType_Path) {

        /*
            当前连跳模式是基于 PATH 的连跳, 那么可以尝试在空中进行前向寻路, 获取落地前以当前速度可以达到的的最远的目标点
            在一些场景 (c4m2 电梯楼, Charger 需要走楼梯上来, 在楼梯上连跳时, 连跳前在地上前向寻找的目标点可能在楼梯扶手的一侧, 然后 Charger 在楼梯上连跳, 以这个目标点进行修正时就会被向后推, 导致 Charger 无法到达楼梯扶手的另一侧, 导致无法上楼梯或需要重新寻路, 因此增加空中前向寻找目标点的逻辑)
        */
        static bool needLookAhead;
        needLookAhead = false;

        // 获取 Charger 当前的连跳前前向寻找的目标点
        static float curGoal[3];
        curGoal = g_AiChargers[client].m_vecAirCorrGoal;
        
        /*
            将 IsNullVector 改用 IsZeroVector, 因为 NULL_VECTOR 仅仅是一个标志, 将参数传递给 C++ 引擎时表示这个参数是 null (比如 SdkCall 调用函数, 参数是 Vector &pos 这样的, 如果不想传递, 可以传递 NULL_VECTOR), 并不代表在插件编写自己定义的 float[3] 类型的变量无效
            e.g., float v[3]; v = NULL_VECTOR; IsNullVector(v) 返回 false, 将 v 的三个分量全部置为 0, 再次判断, 也是返回 false, 因此无法使用 IsNullVector 判断插件中的一个向量是否为无效
        */
        if (IsZeroVector(curGoal)) {
            // 如果当前空中速度修正目标为空, 则需要计算一个目标
            needLookAhead = true;
        } else {
            // 在空中时, 判断当前目标点是否在 Charger 背后, 若在 Charger 背后, 则需要重新前向找到一个新的目标点
            MakeVectorFromPoints(pos, curGoal, vDir);
            vDir[2] = 0.0;

            d2Goal = getVectorDistance2D(pos, curGoal);

            /*
                首先获取引擎的 NextBot 最小前向寻找距离, 没有特殊情况一般是 -1.0, 于是自己设定最小前向寻找距离
                minLookAheadDist 的含义为: 当 Charger 距离当前目标点的距离小于这个距离, 开始进行前向寻找新的以当前速度可达的最远目标点
            */
            static float minLookAheadDist;
            minLookAheadDist = getMinLookAheadDist(g_AiChargers[client].m_pPathFollower);
            if (minLookAheadDist <= GOAL_POS_TOLERANCE_DIST) {
                minLookAheadDist = DEFAULT_PATH_LOOKAHEAD_DIST;
            }

            if (d2Goal < minLookAheadDist) {
                needLookAhead = true;
            } else {
                /*
                    计算当前目标点到 Charger 位置的向量与 Charger 的速度向量夹角, 若夹角大于 90 度, 则说明当前目标点在 Charger 背后, Charger 飞过头了
                    此时直接触发前向寻找新的目标点, 以调整空中速度修正方向
                */
                NormalizeVector(vDir, vDir);
                NormalizeVector(vVel_cpy, vVel_cpy);
                dot = RadToDeg(ArcCosine(GetVectorDotProduct(vDir, vVel_cpy)));
                if (dot > 90.0) {
                    needLookAhead = true;
                }
            }

            static float curTime;
            curTime = GetEngineTime();

            // 0.1 秒触发一次, 避免每帧都触发, 减少性能消耗
            if (needLookAhead && (curTime - g_AiChargers[client].m_flLastLookAheadTime > 0.1)) {
                // 获取当前 Charger z 轴高度, 计算剩余落地的时间
                static float estimateAirTime;
                estimateAirTime = calcRemainingAirTime(pos, vVel);

                static float maxEstimateDist;
                maxEstimateDist = getVectorLength2D(vVel) * estimateAirTime;
                if (maxEstimateDist < PATH_LOOKAHEAD_MIN_DIST) {
                    maxEstimateDist = PATH_LOOKAHEAD_MIN_DIST;
                }
                
                float vNewGoal[3];
                if (getLookAheadGoalPos(client, pos, maxEstimateDist, vNewGoal, g_cvPathLookAheadMaxDepth.IntValue)) {
                    // Debug draw new in ari goal pos, color: light blue
                    /* stateLog.debugAll("Charger (%N) in air found new ahead goal pos (%f %f %f)", client, vNewGoal[0], vNewGoal[1], vNewGoal[2]);
                    DrawBeamPoint(vNewGoal, NULL_VECTOR, {30, 90, 143, 255}, 1.0); */
                    g_AiChargers[client].m_vecAirCorrGoal = vNewGoal;
                }

                g_AiChargers[client].m_flLastLookAheadTime = curTime;
            }
        }

        MakeVectorFromPoints(pos, g_AiChargers[client].m_vecAirCorrGoal, vDir);
        dot = calcVectorAngle(vVel, vDir, true);

        // 空中前向遍历目标点完毕, 获取到当前最新目标点的距离和高度差
        d2Goal = getVectorDistance2D(pos, g_AiChargers[client].m_vecAirCorrGoal);
        h2Goal = g_AiChargers[client].m_vecAirCorrGoal[2] - pos[2];

        // ============================================================
        // 处理主动侧向连跳
        // ============================================================
        static float vDesired[3];
        vDesired = vDir;

        static bool isStrafing;
        isStrafing = buildStrafedDesiredVector(client, vDir, d2Goal, vDesired);

        // ============================================================
        // 正常连跳, 判断是否需要空中速度修正
        // ============================================================
        static bool shouldCorrect;
        shouldCorrect = false;
        
        static float airCorrLerp;
        airCorrLerp = g_cvAirVecModifyLerp.FloatValue;
        if (isStrafing && d2Goal > GOAL_POS_TOLERANCE_DIST) {
            shouldCorrect = true;
            airCorrLerp = 0.50;
        } else {
            if (
                dot >= g_cvAirVecModifyMinDegree.FloatValue &&
                dot <= g_cvAirVecModifyMaxDegree.FloatValue &&
                d2Goal > GOAL_POS_TOLERANCE_DIST
                /*
                    TODO: 确认是否要增加有 PATH 时速度修正的高度限制, 无高度限制比如 charger 跌落楼梯在空中还是一直会触发速度方向修正
                    && h2Goal < CHARGE_Z_THRESHOLD or h2Goal < JUMP_HEIGHT
                */
            ) {
                shouldCorrect = true;
            }
        }

        if (shouldCorrect) {
            // 避免空中速度衰减
            if (speed < g_AiChargers[client].m_flLastHopSpeed)
                speed = g_AiChargers[client].m_flLastHopSpeed;

            /*
                使用原始速度 vVel 和目标方向的 vDiesired 构建修正后的速度
                解决原来使用 vVel_cpy 而 vVel_cpy 没有被归一化, 导致 vVel_cpy 和 vDesired 的量纲不匹配导致的速度方向修正效果微乎其微
            */
            buildAirCorrectionVelocity2D(vVel, vDesired, airCorrLerp, speed, vFwd);

            // 缩放空中速度修正的速度向量
            TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vFwd);

            // 记录空中速度方向修正时间
            g_AiChargers[client].m_flLastAirVecModifyTime = GetEngineTime();
            return Plugin_Changed;
        }
    }

    // ============================================================
    // 寻路结束, 或路径无效, 进行选择性空中速度方向修正
    // ============================================================

    // 防止目标在上方频繁触发速度修正
    static float dx, dz, pitch;
    dx = SquareRoot(Pow(targetPos[0] - pos[0], 2.0) + Pow(targetPos[1] - pos[1], 2.0));
    dz = targetPos[2] - pos[2];
    pitch = RadToDeg(ArcTangent2(dz, dx));
    if (pitch > 45.0)
        return Plugin_Continue;

    // 计算当前方向与到目标方向的夹角
    MakeVectorFromPoints(pos, targetPos, vDir);
    dot = calcVectorAngle(vVel, vDir, true);

    static float vDirectDesired[3];
    vDirectDesired = vDir;

    static bool isDirectStrafing;
    isDirectStrafing = buildStrafedDesiredVector(client, vDir, dist, vDirectDesired);

    static bool inAngleRange, notPressBack, delayExpired;
    #pragma unused delayExpired

    inAngleRange = (dot >= g_cvAirVecModifyMinDegree.FloatValue && dot <= g_cvAirVecModifyMaxDegree.FloatValue);
    notPressBack = !(buttons & IN_BACK);
    delayExpired = (GetEngineTime() - g_AiChargers[client].m_flLastAirVecModifyTime) > g_cvAirVecModifyInterval.FloatValue;

    if (visible &&
        notPressBack &&
        (
            isDirectStrafing ||
            (
                inAngleRange &&
                dist <= g_cvDirectBhopDist.FloatValue
            )
        )
        // && delayExpired
    ) {
        stateLog.debugAll("Charger: %N triggered air speed modify, current vector angle: %.2f", client, dot);
        
        // 将方向向量缩放成原速度大小, 刚起跳时加速度可能没有应用, 缩放使用的速度为起跳前的速度, 导致连跳无法加速, 因此这里保存加速度并取最大速度缩放
		if (speed < g_AiChargers[client].m_flLastHopSpeed)
			speed = g_AiChargers[client].m_flLastHopSpeed;

        static float directAirCorrLerp;
        directAirCorrLerp = isDirectStrafing ? 0.50 : g_cvAirVecModifyLerp.FloatValue;
        
        buildAirCorrectionVelocity2D(vVel, vDirectDesired, directAirCorrLerp, speed, vFwd);

		vFwd[2] = vVel[2];
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vFwd);
		// 记录空中速度方向修正时间
		g_AiChargers[client].m_flLastAirVecModifyTime = GetEngineTime();
    }
    return Plugin_Changed;
}

stock void buildAirCorrectionVelocity2D(const float curVel[3], const float desiredVec[3], float lerp, float finalSpeed, float outVel[3]) {
    static float curDir[3], desireDir[3];
    curDir = curVel;
    curDir[2] = 0.0;

    desireDir = desiredVec;
    desireDir[2] = 0.0;

    NormalizeVector(curDir, curDir);
    NormalizeVector(desireDir, desireDir);

    if (lerp < 0.0) {
        lerp = 0.0;
    } else if (lerp > 1.0) {
        lerp = 1.0;
    }

    outVel[0] = curDir[0] + (desireDir[0] - curDir[0]) * lerp;
    outVel[1] = curDir[1] + (desireDir[1] - curDir[1]) * lerp;
    outVel[2] = 0.0;
    NormalizeVector(outVel, outVel);
    ScaleVector(outVel, finalSpeed);
    
    outVel[2] = curVel[2];
}

/**
* 2026-01-13
* Charger 在连跳接近目标的时候, 如果落地, 可以检测周围是否有距离原目标更近的目标, 如果有, 且新目标无法在 Charger 朝他冲锋的时间内躲开冲锋, 直接更换目标冲锋,
* 这样可以一定程度上减少原目标距离 Charger 较远时, 一味地追击原目标而在追击过程中被其他生还者打掉很多血量, 条件:
* 1. 新目标是有效生还者, 且没有倒地挂边和被 hunter 控制 (其他特感 smoker, jockey 等控制可以抢控)
* 2. 新目标必须可视, 而且距离新目标的距离比原目标更近
* @param client 客户端索引
* @param curTarDist 当前目标距离
* @param unavoidableDist 新目标在冲锋路径上无法躲避冲锋的距离
* @return int 如果找到了更好的新目标, 返回新目标的客户端索引, 若没有, 返回 -1
**/
stock int getChargeUnavoidableTarget(int client, int curTarget, float pos[3], float curTarDist, float unavoidableDist = 150.0) {
    if (!isAiCharger(client))
        return -1;
    if (!IsValidSurvivor(curTarget) || !IsPlayerAlive(curTarget))
        return -1;

    // 获取冲锋时的冲锋速度
    static float chargeSpeed;
    chargeSpeed = !cvChargeSpeed ? DEFAULT_CHARGE_SPEED : cvChargeSpeed.FloatValue;

    // 遍历所有生还者, 寻找更近的目标
    static float dist, targetPos[3], targetEyePos[3];
    for (int i = 1; i <= MaxClients; i++) {
        if (i == client || i == curTarget || !IsValidSurvivor(i) || !IsPlayerAlive(i))
            continue;
        if (IsClientIncapped(i) || IsClientHanging(i))
            continue;
        // 跳过被 hunter 控制的生还者, 无法抢控
        if (isSurvivorPinned(i))
            continue;

        GetClientAbsOrigin(i, targetPos);
        GetClientEyePosition(i, targetEyePos);
        // 高度差过大的目标不作为直接冲锋目标
        if (!isChargeHeightReachable(pos, targetPos))
            continue;

        // 跳过不可直视的玩家
        if (!L4D2_IsVisibleToPlayer(client, TEAM_INFECTED, TEAM_SURVIVOR, 0, targetEyePos))
            continue;
        
        dist = getVectorDistance2D(pos, targetPos);
        // 跳过距离比当前目标还远的玩家
        if (dist > unavoidableDist || dist > curTarDist)
            continue;
        
        // 计算冲锋无法躲避的条件
        static float timeToImpact;
        static float vTarVelVec[3], predictDist;
        timeToImpact = dist / chargeSpeed;
        GetEntPropVector(i, Prop_Data, "m_vecVelocity", vTarVelVec);
        vTarVelVec[2] = 0.0;
        // 计算玩家在 charger 冲锋到此处的时间后的位置 (线性计算)
        ScaleVector(vTarVelVec, timeToImpact);
        predictDist = GetVectorLength(vTarVelVec);

        // 获取冲锋方向 (直接使用自身位置到当前玩家位置的方向向量作为冲锋方向)
        static float chargeDir[3];
        MakeVectorFromPoints(pos, targetPos, chargeDir);
        NormalizeVector(chargeDir, chargeDir);

        // 计算玩家速度在冲锋方向上的投影长度
        // prj = |A| * cosθ, |A| * cosθ = dot(A,B) / |B|, B 已经归一化, 因此 |A| * cosθ = dot(A,B)
        static float dot;
        dot = GetVectorDotProduct(vTarVelVec, chargeDir);
        // 根据勾股定理计算垂直于冲锋方向上的躲避距离
        static float effDodgeDistSqr, effDodgeDist;
        effDodgeDistSqr = Pow(predictDist, 2.0) - Pow(dot, 2.0);
        if (effDodgeDistSqr < 0.0) {
            effDodgeDistSqr = 0.0;
        }
        effDodgeDist = SquareRoot(effDodgeDistSqr);
        if (effDodgeDist < unavoidableDist) {
            stateLog.debugAll("Charger (%N) find a unavoidable target (%N), distance: %.2f", client, i, dist);
            return i;
        }
    }
    return -1;
}

/**
* 进入 Bait, Lock, Charge 阶段时, 当 Charger 在空中时, 将其水平速度方向修正到可见目标的预测位置
* @param client 客户端索引
* @param target 目标客户端索引
* @param visible 是否可见目标
* @param lerp 方向插值强度, 越接近于 1 转向越强
* @return bool, 修改速度方向成功返回 true
* @error 
**/
stock bool preserveAirChargeLine(int client, int target, bool visible, float lerp) {
    if (!isAiCharger(client)) {
        return false;
    }
    if (!IsValidSurvivor(target) || !IsPlayerAlive(target)) {
        return false;
    }
    if (!visible) {
        return false;
    }
    // 仅做空中速度修正, Charger 在地面时不进行速度修正
    if (IsClientOnGround(client)) {
        return false;
    }
    if (isChargerCharging(client) || IsPinningSurvivor(client)) {
        return false;
    }

    static float pos[3], targetPos[3], curVel[3], targetVel[3];
    L4D_GetEntityWorldSpaceCenter(client, pos);
    L4D_GetEntityWorldSpaceCenter(target, targetPos);
    GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", curVel);
    GetEntPropVector(target, Prop_Data, "m_vecAbsVelocity", targetVel);

    /*
    * 检查目标对 Charger 的几何关系, 目标过近或者过高, 或 Charger 明显在目标上方太多时, 不做空中速度方向修正
    */
    static float dx, dz, pitch;
    dx = getVectorDistance2D(pos, targetPos);
    if (dx <= 1.0) {
        return false;
    }

    dz = targetPos[2] - pos[2];
    pitch = RadToDeg(ArcTangent2(dz, dx));
    if (pitch > 45.0) {
        return false;
    }

    if (pos[2] - targetPos[2] > getChargeHeightLimit()) {
        return false;
    }

    static float curSpeed, baseSpeed, finalSpeed;
    curSpeed = getVectorLength2D(curVel);
    baseSpeed = SDKCall(g_hSdkGetRunTopSpeed, client);
    finalSpeed = curSpeed;

    // 如果当前的空中最终速度小于上一次连跳的起跳前速度, 那么就使用上一次连跳的起跳速度, 避免空中速度衰减
    if (finalSpeed < g_AiChargers[client].m_flLastHopSpeed) {
        finalSpeed = g_AiChargers[client].m_flLastHopSpeed;
    }
    // 最小速度至少是基础速度加上一次连跳的加速度
    if (finalSpeed < baseSpeed + g_cvBhopImpulse.FloatValue) {
        finalSpeed = baseSpeed + g_cvBhopImpulse.FloatValue;
    }
    // 最大速度不能超过设置的连跳速度上限
    if (finalSpeed > g_cvBhopMaxSpeed.FloatValue) {
        finalSpeed = g_cvBhopMaxSpeed.FloatValue;
    }

    static float predictTime;
    predictTime = dx / finalSpeed;
    if (predictTime < AIR_CHARGE_LINE_MIN_PREDICT_TIME) {
        predictTime = AIR_CHARGE_LINE_MIN_PREDICT_TIME;
    } else if (predictTime > AIR_CHARGE_LINE_MAX_PREDICT_TIME) {
        predictTime = AIR_CHARGE_LINE_MAX_PREDICT_TIME;
    }

    static float predictPos[3];
    predictPos[0] = targetPos[0] + (targetVel[0] * predictTime);
    predictPos[1] = targetPos[1] + (targetVel[1] * predictTime);
    predictPos[2] = targetPos[2];

    static float desiredDir[3], outVel[3];
    MakeVectorFromPoints(pos, predictPos, desiredDir);
    desiredDir[2] = 0.0;

    if (NormalizeVector(desiredDir, desiredDir) <= 0.0) {
        return false;
    }

    buildAirCorrectionVelocity2D(curVel, desiredDir, lerp, finalSpeed, outVel);
    outVel[2] = curVel[2];

    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, outVel);

    /*
    * 当前已经改为朝着目标预测位置修正, 所以不再使用 PahtLookAhead GoalPos
    * 空中速度修正应该稳定朝着目标预测位置靠近, 不应该继续 Strafe
    */
    g_AiChargers[client].m_BhopType = BhopType_Normal;
    ZeroVector(g_AiChargers[client].m_vecAirCorrGoal);
    g_AiChargers[client].m_AirStrafe.m_StrafeType = StrafeType_None;
    g_AiChargers[client].m_flLastHopSpeed = getVectorLength2D(outVel);
    g_AiChargers[client].m_flLastAirVecModifyTime = GetEngineTime();

    return true;
}

// ============================================================
// OnExit 函数
// ============================================================
stock void StateApproach_OnExit(int client) {
    stateLog.debugAll("\n========== Charger (%N) State Approach On Exit ===========", client);
    // 重置空中急停标记
    g_AiChargers[client].m_bHasAirBreaked = false;
}

// ======== End of: ./state_approach.inc ========

// ======== Included from: ./state_bait.inc ========



// ======== Included from: ../setup.inc ========

// ======== End of: ../setup.inc ========

// ======== Included from: ../stocks.inc ========

// ======== End of: ../stocks.inc ========

// ======== Included from: ./state.inc ========

// ======== End of: ./state.inc ========

#define STATE_BAIT_NAME         "STATE_BAIT"
#define TARGET_PURSUIT_FACTOR   1.2       // 面对手持近战目标 Charger 后跳时, 此时目标若朝着 Charger 移动, Charger 后跳速度的加速倍数
#define TARGET_RETREAT_FACTOR   0.5       // 面对手持近战目标 Charger 后跳时, 此时目标若远离 Charger 移动, Charger 后跳速度的减速倍数
#define MELEE_PRESS_MIN_SPEED   50.0      // 目标朝 Charger 移动速度超过该值时, 视为主动进入近战危险区
#define MELEE_EMERGENCY_BUFFER  20.0      // 目标距离 Charger 小于 (meleeRange + 这个值) 时, 视为非常危险, 无论目标速度如何都尝试后跳
#define BAIT_LOST_SIGHT_GRACE   3.0       // 连续丢失目标视野超过该时间才退出 Bait

// =========================================================================
// State Bait 接近目标时的博弈状态 (dist < g_cvBhopMinDist.FloatValue 时进入 BAIT_STATE)
// 注册状态函数
// =========================================================================
stock void RegisterState_Bait() {
    ChargerState stateBait;
    strcopy(stateBait.name, sizeof(stateBait.name), "State_Bait");
    stateBait.OnEnter = StateBait_OnEnter;
    stateBait.OnUpdate = StateBait_OnUpdate;
    stateBait.OnExit = StateBait_OnExit;
    g_ChargerStates.PushArray(stateBait);
}

// ============================================================
// OnEnter 函数
// ============================================================
stock void StateBait_OnEnter(int client) {
    g_AiChargers[client].m_flLastVisibleTime = GetGameTime();
    stateLog.debugAll("\n========== Charger (%N) State Bait On Enter ===========", client);
}

// ============================================================
// OnUpdate 函数
// ============================================================
stock Action StateBait_OnUpdate(int client, int& buttons, float vel[3], float ang[3]) {
    if (!isAiCharger(client))
        return Plugin_Continue;
    if (IsPinningSurvivor(client))
        return Plugin_Continue;
    
    static int target;
    target = GetClientOfUserId(g_AiChargers[client].m_iTarget);
    if (!IsValidSurvivor(target) || !IsPlayerAlive(target)) {
        stateLog.debugAll("(%s) Charger (%N)'s target %d is invalid, transition to APPROACH STATE", STATE_BAIT_NAME, client, target);
        g_ChargerStateContext[client].transitionTo(CH_STATE_APPROACH);
        return Plugin_Continue;
    }

    // 计算 charger 当前到目标的距离
    static float pos[3], targetPos[3], targetEyePos[3], dist;
    GetClientAbsOrigin(client, pos);
    GetClientAbsOrigin(target, targetPos);
    GetClientEyePosition(target, targetEyePos);
    dist = getVectorDistance2D(pos, targetPos);
    // 是否可视目标
    static bool visible;
    visible = L4D2_IsVisibleToPlayer(client, TEAM_INFECTED, TEAM_SURVIVOR, 0, targetEyePos);
    if (visible) {
        g_AiChargers[client].m_flLastVisibleTime = GetGameTime();
    }
    // 目标是否正在看着 charger
    // 除了目标之外还有多少生还者正在看着 charger
    static bool isWatching, isOnGround;
    static int watchers;
    isOnGround = IsClientOnGround(client);
    isWatching = isTargetWatchingCharger(client, target, g_cvTargetWatchMaxDeg.FloatValue);
    watchers = isAnySurvivorWatchingCharger(client, target, g_cvTargetWatchMaxDeg.FloatValue);
    // 目标威胁类型
    static TargetThreatType threatType;
    threatType = getTargetThreatType(client, target);

    // 只在 Charger 落地后检查高度, 避免后跳在空中时因高度差而错误的退出 Bait 状态
    if (isOnGround && !isChargeHeightReachable(pos, targetPos)) {
        stateLog.debugAll("Charger (%N) bait target (%N) height diff %.2f > %.2f, transition to APPROACH STATE",
            client, target,FloatAbs(pos[2] - targetPos[2]), CHARGE_Z_THRESHOLD);
        
        g_ChargerStateContext[client].transitionTo(CH_STATE_APPROACH);
        return Plugin_Continue;
    }

    /*
    * Bait 可能在 Charger 仍处于上一次 Approach 连跳的空中阶段时触发 (在空中距离目标小于 BaitRange 进入 Bait 状态)
    * 之前的 Bait State 并没有修正空中速度, 如果此时不持续修正空中速度, Charger 会沿着旧的 Path/Strafe 速度从目标侧面飞走
    * 导致后续 Bait -> Locked -> Charging 时 Charger 已经飞出去很远, 需要从 Charging -> Approach 继续接近目标, 错过一次冲锋
    */
    static bool airLineCorrected;
    airLineCorrected = false;

    /*
    * 目标的威胁类型不是近战, 且 Charger 从 Approach 状态转为 Bait 状态但是最后一跳还没结束还在空中时
    * 进行空中速度修正, 避免 Charger 飞过目标
    */
    if (threatType != Threat_Melee && !isOnGround && visible) {
        airLineCorrected = preserveAirChargeLine(client, target, visible, AIR_CHARGE_LINE_CORR_LERP);
    }

    // ============================================================
    // 进入博弈状态, 说明距离正常威胁目标距离小于 g_cvBhopMinDist.FloatValue
    // 距离手持近战目标距离小于 melee_range + g_cvMeleeBaitZoneMaxRange.FloatValue
    // 这时候先阻止冲锋, 并尝试右键挥拳, 若后续满足冲锋条件, 转换到冲锋状态
    // ============================================================
    buttons |= IN_ATTACK2;
    setChargerAbilityCooldown(client, 1.0);

    // ============================================================
    // 优先行动检查, 检测是否有更好的可以直接冲锋的目标, 如果有, 直接转换为冲锋状态
    // 这避免了如果在与手持近战的目标博弈时, 另一个生还者在 charger 身后疯狂输出的行为
    // 若 charger 身后突然出现另一个生还者, 且 charger 此时距离到他更近且他无法躲避冲锋, 直接向他冲锋, 否则, 继续朝着原目标冲锋
    // ============================================================
    if (isOnGround) {
        static int betterTarget;
        betterTarget = getChargeUnavoidableTarget(client, target, pos, dist, g_cvBhopMinDist.FloatValue);
        if (IsValidSurvivor(betterTarget) && IsPlayerAlive(betterTarget) &&
            isChargeAbilityReady(client) &&
            isChargeTargetHeightReachable(client, betterTarget) &&
            !isChargePathBlocked(client, betterTarget)
        ) {
            stateLog.debugAll("Charger (%N) find a better charge target %N, transition to LOCKED STATE", client, betterTarget);
            g_AiChargers[client].m_iBetterTarget = GetClientUserId(betterTarget);
            g_ChargerStateContext[client].transitionTo(CH_STATE_LOCKED);
            return Plugin_Changed;
        }
    }

    // ============================================================
    // 检查是否需要退出博弈状态, 转移到接近状态
    // 1. 不可见目标时, 转换为接近状态
    // 2. 目标非手持近战, 且到目标距离大于 bhopMinDist + 容差距离, 转换为接近状态
    // 3. 目标手持近战, 且到目标距离大于 meleeRange + baitZoneMax, 出了博弈区, 转换为接近状态
    // ============================================================
    if (shouldExitBaitState(client, target, dist, visible, threatType)) {
        /*
        * Bait 状态下空中速度修正成功, 但是已经达到了退出 Bait 状态的条件, 是否直接退出 Bait 转给 Approach 状态空中修正?
        * 理论上不应该, 这里返回 Plugin_Changed 的语义是当前 Charger 在 Bait 状态的空中, 然后已经对空中速度进行修正
        * Charger 在空中的时候先让其继续修正, 暂时不要在同一帧之内切换状态, 否则在 Bait 中做了速度修正, 然后又退出 Bait, 速度修正就被打断
        * 所以等到 Charger 落地, 再切换到 Approach 状态
        */
        if (airLineCorrected) {
            return Plugin_Changed;
        }

        g_ChargerStateContext[client].transitionTo(CH_STATE_APPROACH);
        return Plugin_Continue;
    }

    // ============================================================
    // 如果当前目标已经被其他强控特感控制, hunter, charger
    // 中止转换到 CHARGING STATE, 停留在 BAIT 状态, 持续对目标挥拳
    // ============================================================
    if (isSurvivorPinned(target)) {
        // stateLog.debugAll("Charger (%N)'s target (%N) is pinned! Suspending charge, melee to it", client, target);
        return Plugin_Continue;
    }

    // ============================================================
    // 根据威胁类型分别处理
    // ============================================================
    static Action resAction;
    if (threatType == Threat_Melee) {
        // handleMeleeThreat 的返回值为 Plugin_Changed 表示执行了后跳动作, 需要结束这一帧
        resAction = handleMeleeThreat(client, target, dist, visible, isWatching, watchers, buttons);
        if (resAction != Plugin_Continue)
            return resAction;
        /*
        * 如果 handleMeleeThreat 中不能冲锋, 也不允许向后跳, 或向后跳失败了, 且 Charger 在地上
        * 那么如果目标正在看着 Charger, Charger 进入 baitZoneMin 那么 Charger 后退, 出了 baitZoneMax 朝着目标前进进行近战博弈
        * 若向后移动方向不安全, 且技能就绪, 那么直接冲锋
        */
        static Action distanceControlResult;
        distanceControlResult = maintainMeleeBaitDistance(client, target, dist, visible, vel, buttons);
        if (distanceControlResult != Plugin_Continue)
            return distanceControlResult;
    } else if (threatType == Threat_Shotgun) {
        resAction = handleShotgunThreat(client, target, dist, visible);
    } else {
        resAction = handleNonMeleeThreat(client, target, dist, visible);
    }

    if (resAction != Plugin_Continue)
        return resAction;

    return airLineCorrected ? Plugin_Changed : Plugin_Continue;
}

/**
* 当 Charger 距离目标距离小于 baitZoneMin 时, 若目标看着 Charger 那么 Charger 后退, 如果距离目标距离大于 baitZoneMax 那么前进继续接近目标
* 后跳时保留远离目标的水平动量, 只在空中存在异常指向目标的速度 (如 Approach 最后一跳进入 BaitZone, 那么急停, 清除输入和当前速度)
* @param client Charger 客户端索引
* @param target 目标客户端索引
* @param dist 到目标的距离
* @param visible 是否可见目标
* @param cmdVel 当前速度
* @param buttons 输入按键状态
* @return Action
* @error 
**/

#define BAIT_RETREAT_NONE       0
#define BAIT_RETREAT_BACK       1
#define BAIT_RETREAT_FORWARD    -1

Action maintainMeleeBaitDistance(int client, int target, float dist, bool visible, float cmdVel[3], int& buttons) {
    static float pos[3], targetPos[3], currentVel[3], awayDir[3];
    GetClientAbsOrigin(client, pos);
    GetClientAbsOrigin(target, targetPos);
    GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", currentVel);

    // awayDir = target -> Charger
    MakeVectorFromPoints(targetPos, pos, awayDir);
    awayDir[2] = 0.0;

    if (NormalizeVector(awayDir, awayDir) <= 0.0)
        return Plugin_Continue;

    // currentAwaySpeed > 0 表示 Charger 正沿 target -> Charger 方向远离目标。
    static float currentAwaySpeed;
    currentAwaySpeed = GetVectorDotProduct(currentVel, awayDir);

    // 后跳起飞后保留远离目标的动量, 不再被下一帧的距离控制清零
    if (!IsClientOnGround(client)) {
        // 先清除原生的移动输入
        buttons &= ~(IN_FORWARD | IN_BACK | IN_MOVELEFT | IN_MOVERIGHT);
        cmdVel[0] = 0.0;
        cmdVel[1] = 0.0;

        // 如果 BhopType 是 BhopType_BaitRetreat, 且当前的 Charger 后跳速度分量有效, 那么说明在空中的这次连跳确实由后跳发起, 保持后跳
        if (g_AiChargers[client].m_BhopType == BhopType_BaitRetreat && currentAwaySpeed > 1.0) {
            return Plugin_Changed;
        }

        // 否则说明当前的速度不是由 BhopType_BaitRetreat 发起的, 可能是 Approach 的最后一跳在空中进入 BaitZone, 此时要急停, 清除输入和速度
        currentVel[0] = 0.0;
        currentVel[1] = 0.0;
        TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, currentVel);
        g_AiChargers[client].m_BhopType = BhopType_None;
        g_AiChargers[client].m_flLastHopSpeed = 0.0;
        return Plugin_Changed;
    }

    if (g_AiChargers[client].m_BhopType == BhopType_BaitRetreat) {
        g_AiChargers[client].m_BhopType = BhopType_None;
        g_AiChargers[client].m_flLastHopSpeed = 0.0;
    }

    // 只有目标正在看着 Charger 时才进行距离博弈, 否则目标不看着 Charger, 安全, 不需要进行近战博弈操作
    if (!isTargetWatchingCharger(client, target))
        return Plugin_Continue;

    static float meleeRange, baitZoneMin, baitZoneMax;
    meleeRange = !cvMeleeRange ? DEFAULT_MELEE_RANGE : cvMeleeRange.FloatValue;
    baitZoneMin = meleeRange + g_cvMeleeBaitZoneMinRange.FloatValue;
    baitZoneMax = meleeRange + g_cvMeleeBaitZoneMaxRange.FloatValue;

    static int moveSign;
    moveSign = BAIT_RETREAT_NONE;

    if (dist < baitZoneMin) {
        // 距离过近, 沿 awayDir 后退
        moveSign = BAIT_RETREAT_BACK;
    } else if (dist > baitZoneMax) {
        // 距离过远, 朝目标前进
        moveSign = BAIT_RETREAT_FORWARD;
    }

    if (moveSign == 0) {
        buttons &= ~(IN_FORWARD | IN_BACK | IN_MOVELEFT | IN_MOVERIGHT);
        cmdVel[0] = 0.0;
        cmdVel[1] = 0.0;
        currentVel[0] = 0.0;
        currentVel[1] = 0.0;
        TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, currentVel);
        return Plugin_Changed;
    }

    static float baseSpeed, moveSpeed;
    baseSpeed = SDKCall(g_hSdkGetRunTopSpeed, client);
    moveSpeed = baseSpeed;

    static float desiredVel[3];
    desiredVel[0] = awayDir[0] * moveSpeed * float(moveSign);
    desiredVel[1] = awayDir[1] * moveSpeed * float(moveSign);
    desiredVel[2] = 0.0;

    if (!nextTickPosCheck(client, desiredVel, visible)) {
        // 无论前进还是后退, 方向不安全都不接管移动
        // handleMeleeThreat 已在这个函数之前执行, 此时保留其朝着目标右键打拳或者冲锋决策及原生 PathFollower 输入
        return Plugin_Continue;
    }

    buttons &= ~(IN_FORWARD | IN_BACK | IN_MOVELEFT | IN_MOVERIGHT);
    cmdVel[0] = 0.0;
    cmdVel[1] = 0.0;
    desiredVel[2] = currentVel[2];
    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, desiredVel);

    g_AiChargers[client].m_BhopType = BhopType_None;
    g_AiChargers[client].m_flLastHopSpeed = 0.0;
    ZeroVector(g_AiChargers[client].m_vecAirCorrGoal);
    g_AiChargers[client].m_AirStrafe.init();
    return Plugin_Changed;
}

/**
* 是否应该退出博弈状态, 转换为 APPROACH State
* @param client 客户端索引
* @param target 目标索引
* @param dist 距离
* @param visible 是否可见
* @param threatType 目标威胁类型
* @return bool
**/
bool shouldExitBaitState(int client, int target, float dist, bool visible, TargetThreatType threatType) {
    if (!isAiCharger(client) || !IsValidSurvivor(target) || !IsPlayerAlive(target))
        return true;

    // 向后跳在空中时, 禁止因视野或距离变化中途退出 Bait
    if (!IsClientOnGround(client) &&
        g_AiChargers[client].m_BhopType == BhopType_BaitRetreat
    ) {
        return false;
    }

    static float minDist;
    minDist = g_cvBhopMinDist.FloatValue + STATE_TOLERANCE_DIST;
    
    // 连续失去目标视野超过宽限期才转换为 APPROACH STATE
    if (!visible &&
        GetGameTime() - g_AiChargers[client].m_flLastVisibleTime >= BAIT_LOST_SIGHT_GRACE
    ) {
        stateLog.debugAll("Charger (%N) lost the sight of target (%N) for %.2f seconds, transition to APPROACH STATE",
            client, target, BAIT_LOST_SIGHT_GRACE);
        return true;
    }
    // 目标非手持近战, 且到目标距离大于 g_cvBhopMinDist.FloatValue + 容差距离, 转换为 APPROACH STATE
    if (threatType != Threat_Melee && dist > minDist) {
        stateLog.debugAll("Charger (%N), target (%N), distance %.2f > min dist %.2f, transition to APPROACH STATE", client, target, dist, minDist);
        return true;
    }
    // 目标手持近战, 且到目标距离大于 meleeRange + g_cvMeleeBaitZoneMaxRange.FloatValue, 转换为 APPROACH STATE
    static float meleeRange;
    meleeRange = !cvMeleeRange ? DEFAULT_MELEE_RANGE : cvMeleeRange.FloatValue;
    minDist = meleeRange + g_cvMeleeBaitZoneMaxRange.FloatValue + STATE_TOLERANCE_DIST;
    if (threatType == Threat_Melee && dist > minDist) {
        stateLog.debugAll("Charger (%N), target (%N) holding melee, dist %.2f > baitZoneMax %.2f, transition to APPROACH STATE", client, target, dist, minDist);
        return true;
    }
    return false;
}

/**
* Charger 面对手持近战目标时的处理逻辑
* 1. 若目标没有看着 Charger, 且没有其他人看着 Charger, 处在博弈区内, 概率冲锋
* 2. 目标处于易受攻击状态, 直接冲锋
* 3. 目标不处于易受攻击状态, Charger 血量大于近战斩杀线时, 概率冲锋
* @param client 客户端索引
* @param target 目标索引
* @param dist 距离
* @param visible 是否可见目标
* @param isWatching 目标是否正在看着 Charger
* @param watchers 正在看着 Charger 的人数
* @return void
**/
Action handleMeleeThreat(int client, int target, float dist, bool visible, bool isWatching, int watchers, int& buttons) {
    static int health;
    health = GetEntProp(client, Prop_Data, "m_iHealth");

    static float meleeRange, baitZoneMin, baitZoneMax;
    meleeRange = !cvMeleeRange ? DEFAULT_MELEE_RANGE : cvMeleeRange.FloatValue;
    baitZoneMin = meleeRange + g_cvMeleeBaitZoneMinRange.FloatValue;
    baitZoneMax = meleeRange + g_cvMeleeBaitZoneMaxRange.FloatValue;

    // 如果已经出了博弈区, 允许原生移动继续朝着目标接近
    if (dist > baitZoneMax)
        return Plugin_Continue;

    // 冲锋的收益高于后跳, 如果满足冲锋条件, 那么优先冲锋
    if (IsClientOnGround(client) &&
        shouldChargeInMeleeBait(client, target, health, visible, isWatching, watchers) &&
        isChargeAbilityReady(client)
    ) {
        stateLog.debugAll("Charger (%N) melee bait: charging holding melee target (%N), dist %.2f, transition to LOCKED STATE", client, target, dist);
        g_ChargerStateContext[client].transitionTo(CH_STATE_LOCKED);
        return Plugin_Changed;
    }

    /*
    * 如果不满足冲锋条件, 那么目标接近时尝试后跳
    * 1. 目标主动进入 baitZoneMin 时, 且在 target -> Charger 方向的速度分量大于 MELEE_PRESS_MIN_SPEED 时, 表示目标正在主动接近 Charger, 应该后跳
    * 2. 目标距离 Charger 小于 (meleeRange + MELEE_EMERGENCY_BUFFER) 时, 情况紧急, 应该后跳, 否则会被砍
    */
    static float chargerPos[3], targetPos[3], targetVel[3], targetToCharger[3];
    GetClientAbsOrigin(client, chargerPos);
    GetClientAbsOrigin(target, targetPos);
    GetEntPropVector(target, Prop_Data, "m_vecAbsVelocity", targetVel);

    MakeVectorFromPoints(targetPos, chargerPos, targetToCharger);
    targetToCharger[2] = 0.0;
    NormalizeVector(targetToCharger, targetToCharger);
    targetVel[2] = 0.0;

    // 计算目标速度和 Charger -> target 方向的分量, 如果 targetApproachSpeed > 0 表示目标正在朝着 Charger 主动接近, 此时应该向后跳
    static float targetApproachSpeed;
    targetApproachSpeed = GetVectorDotProduct(targetVel, targetToCharger);

    /*
    * targetPressing: 目标主动进入 baitZoneMin 时, 且速度分量大于 MELEE_PRESS_MIN_SPEED 时, 应该后跳
    * emergencyClose: 目标距离 Charger 小于 (meleeRange + MELEE_EMERGENCY_BUFFER) 时, 情况紧急, 应该后跳, 否则会被砍
    */
    static bool targetPressing, emergencyClose;
    targetPressing = dist <= baitZoneMin && targetApproachSpeed >= MELEE_PRESS_MIN_SPEED;
    emergencyClose = dist <= meleeRange + MELEE_EMERGENCY_BUFFER;

    // 无法冲锋时, 目标主动进入 baitZoneMin 或已经过近才尝试后跳
    if (targetPressing || emergencyClose) {
        static Action backhopResult;
        backhopResult = performBackwardBhop(client, target, visible, buttons);
        if (backhopResult != Plugin_Continue)
            return backhopResult;
    }

    return Plugin_Continue;
}

/**
* Charger 在面对手持近战的目标时, 且距离处于博弈区内 (baitZoneMin, baitZoneMax], 判断是否冲锋
* @param client 客户端索引
* @param target 目标索引
* @param dist 距离
* @param health Charger 生命值
* @param isWatching 目标是否正在看着 Charger
* @param watchers 正在看着 Charger 的人数
* @return bool
**/
bool shouldChargeInMeleeBait(int client, int target, int health, bool visible, bool isWatching, int watchers) {
    // 能力未就绪, 不允许冲锋
    if (!isChargeAbilityReady(client))
        return false;
    // 0. 无目标视野, 不允许冲锋
    if (!visible)
        return false;
    // 1. 目标手持近战, 但是没有看着自己, 且没有其他生还者看着自己, 概率冲锋
    if (!isWatching && watchers <= 0 && isChargerProbCharge(client))
        return true;
    // 2. 目标手持近战, 且处于易受攻击状态, 直接冲锋
    if (isTargetVulnerable(client, target))
        return true;
    // 3. 目标手持近战, 且不处于易受攻击状态, Charger 血量大于近战斩杀线时, 概率冲锋
    static int meleeDamageCharger;
    meleeDamageCharger = getLegacyMeleeDamage();
    if (health > meleeDamageCharger && isChargerProbCharge(client))
        return true;
    return false;
}

/**
* Charger 在面对手持近战目标时, 执行向后连跳操作
* @param client 客户端索引
* @param target 目标索引
* @param dist 距离
* @param visible 是否可见目标
* @return Action
**/
Action performBackwardBhop(int client, int target, bool visible, int& buttons) {
    if (!IsClientOnGround(client) || !allowToBhop(client))
        return Plugin_Continue;

    /*
    * 使用目标到 Charger 的方向, 确保后跳严格远离目标, 不受当前 Charger 视角影响, 之前是使用 Charger 视角方向, 不够健壮
    */
    static float pos[3], targetPos[3], vBack[3];
    GetClientAbsOrigin(client, pos);
    GetClientAbsOrigin(target, targetPos);
    MakeVectorFromPoints(targetPos, pos, vBack);
    vBack[2] = 0.0;

    if (NormalizeVector(vBack, vBack) <= 0.0)
        return Plugin_Continue;

    // 获取 runTopSpeed 作为基础速度
    static float baseSpeed;
    baseSpeed = SDKCall(g_hSdkGetRunTopSpeed, client);

    // 计算目标速度在 charger 后退方向上的投影, dot > 0 表示目标在追 charger, dot < 0 表示目标远离 charger
    static float targetAbsVel[3], approachSpeed;
    GetEntPropVector(target, Prop_Data, "m_vecAbsVelocity", targetAbsVel);
    targetAbsVel[2] = 0.0;
    approachSpeed = GetVectorDotProduct(targetAbsVel, vBack);
    
    // 计算 charger 需要的后退速度
    static float backSpeed;
    // backSpeed = baseSpeed + g_cvBhopImpulse.FloatValue;
    backSpeed = baseSpeed;
    if (approachSpeed > 0.0) {
        backSpeed += approachSpeed * TARGET_PURSUIT_FACTOR;
    } else {
        // approachSpeed < 0, 目标远离 charger, 在 backSpeed 速度上叠加目标速度 (approachSpeed 是负数, 因此是减速), 减少距离
        // 控制减速大小, 0.5 表示在 backSpeed 基础上减速目标速度的 50%
        backSpeed += approachSpeed * TARGET_RETREAT_FACTOR;
    }

    // 限制最小后跳速度为 RunToSpeed, 最大后跳速度不超过设置的连跳速度上限
    if (backSpeed < baseSpeed) {
        backSpeed = baseSpeed;
    }
    if (backSpeed > g_cvBhopMaxSpeed.FloatValue) {
        backSpeed = g_cvBhopMaxSpeed.FloatValue;
    }

    // 应用缩放
    ScaleVector(vBack, backSpeed);

    // 连跳后退的落点不安全的时候, 则转为冲锋状态
    if (!nextTickPosCheck(client, vBack, visible)) {
        if (!isChargePathBlocked(client, target) && isChargeAbilityReady(client)) {
            stateLog.debugAll("Charger (%N) bait to holding melee target (%N), backward jump unsafe, transition to LOCKED STATE", client, target);
            g_ChargerStateContext[client].transitionTo(CH_STATE_LOCKED);
            return Plugin_Changed;
        }

        return Plugin_Continue;
    }

    stateLog.debugAll("Charger (%N) bait to holding melee target (%N), performing backward bunnyhop, speed %.2f", client, target, backSpeed);
    g_AiChargers[client].m_BhopType = BhopType_BaitRetreat;
    g_AiChargers[client].m_flLastHopSpeed = backSpeed;
    ZeroVector(g_AiChargers[client].m_vecAirCorrGoal);
    g_AiChargers[client].m_AirStrafe.init();
    buttons |= IN_DUCK;
    buttons |= IN_JUMP;
    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vBack);
    return Plugin_Changed;
}

/**
* Charger 面对手持霰弹枪的目标的处理逻辑
* 1. 若目标手持霰弹枪, Charger 到目标距离小于 bhopMinDist, 直接冲锋
* @param client 玩家索引
* @param target 目标索引
* @param dist 距离
* @param visible 是否可见目标
* @return Action
**/
Action handleShotgunThreat(int client, int target, float dist, bool visible) {
    // 能力未就绪, 不允许冲锋
    if (!isChargeAbilityReady(client))
        return Plugin_Continue;
    // 无目标视野, 或者距离大于 bhopMinDist, 不允许冲锋
    if (!visible || dist > g_cvBhopMinDist.FloatValue)
        return Plugin_Continue;
    // 能力未就绪, 不允许冲锋
    if (!isChargeAbilityReady(client))
        return Plugin_Continue;

    stateLog.debugAll("Charger (%N) handling shotgun threat, charging to target (%N), transition to LOCKED STATE", client, target);
    g_ChargerStateContext[client].transitionTo(CH_STATE_LOCKED);
    return Plugin_Continue;
}

/**
* Charger 面对手持非近战, 非霰弹枪的目标的处理逻辑
* 1. 目标没有看着 Charger, 且没有其他人看着 Charger, 继续接近挥拳, 同时概率冲锋
* 2. 目标处于易受攻击状态, 直接冲锋
* 3. 无论目标有没有看着 Charger, 若血量大于近战斩杀线, 概率冲锋, 小于则直接冲锋
* @param client 客户端索引
* @param target 目标索引
* @param dist 距离
* @param health Charger 生命值
* @param visible 是否可见目标
* @param meleeDamage Charger 近战斩杀线
* @param watchers 正在看着 Charger 的人数
* @return Action
**/
Action handleNonMeleeThreat(int client, int target, float dist, bool visible) {
    // 能力未准备就绪, 不允许冲锋
    if (!isChargeAbilityReady(client))
        return Plugin_Continue;
    // 无目标视野, 或距离大于最小连跳允许距离, 不允许冲锋
    if (!visible || dist > g_cvBhopMinDist.FloatValue)
        return Plugin_Continue;
    // 能力未就绪, 不允许冲锋
    if (!isChargeAbilityReady(client))
        return Plugin_Continue;

    // 如果目标处于易受攻击状态, 直接冲锋
    if (isTargetVulnerable(client, target)) {
        stateLog.debugAll("Charger (%N) handling non-melee threat: target (%N) vulnerable, charging", client, target);
        g_ChargerStateContext[client].transitionTo(CH_STATE_LOCKED);
        return Plugin_Continue;
    }
    // 血量条件
    static int health, meleeDamageCharger;
    health = GetEntProp(client, Prop_Data, "m_iHealth");
    meleeDamageCharger = getLegacyMeleeDamage();
    if (health > meleeDamageCharger && isChargerProbCharge(client)) {
        stateLog.debugAll("Charger (%N) handling non-melee: health %d > melee damage charger %d, probabilistic charge to (%N)", client, health, meleeDamageCharger, target);
        g_ChargerStateContext[client].transitionTo(CH_STATE_LOCKED);
    } else if (health <= meleeDamageCharger) {
        stateLog.debugAll("Charger (%N) handling non-melee: health %d <= melee damage charger %d, instant charge to (%N)", client, health, meleeDamageCharger, target);
        g_ChargerStateContext[client].transitionTo(CH_STATE_LOCKED);
    }
    return Plugin_Continue;
}

// ============================================================
// OnExit 函数
// ============================================================
stock void StateBait_OnExit(int client) {
    stateLog.debugAll("\n========== Charger (%N) State Bait On Exit ===========", client);
    if (g_AiChargers[client].m_BhopType == BhopType_BaitRetreat) {
        g_AiChargers[client].m_BhopType = BhopType_None;
        g_AiChargers[client].m_flLastHopSpeed = 0.0;
    }
}

// ======== End of: ./state_bait.inc ========

// ======== Included from: ./state_locked.inc ========



// ======== Included from: ../setup.inc ========

// ======== End of: ../setup.inc ========

// ======== Included from: ../stocks.inc ========

// ======== End of: ../stocks.inc ========

// ======== Included from: ./state.inc ========

// ======== End of: ./state.inc ========

#define STATE_LOCKED_NAME "STATE_LOCKED"

// =========================================================================
// State Locked 锁定目标状态
// 作为转移到 CHARGING 状态的过渡状态, 似乎并没有什么用, 因为 CHARGING 状态还需要预测目标位置并冲锋
// 注册状态函数
// =========================================================================
stock void RegisterState_Locked() {
    ChargerState stateLocked;
    strcopy(stateLocked.name, sizeof(stateLocked.name), "State_Locked");
    stateLocked.OnEnter = StateLocked_OnEnter;
    stateLocked.OnUpdate = StateLocked_OnUpdate;
    stateLocked.OnExit = StateLocked_OnExit;
    g_ChargerStates.PushArray(stateLocked);
}

// ============================================================
// OnEnter 函数
// ============================================================
stock void StateLocked_OnEnter(int client) {
    g_AiChargers[client].m_flLastVisibleTime = GetGameTime();
    stateLog.debugAll("\n========== State Locked On Enter ===========");
}

// ============================================================
// OnUpdate 函数
// ============================================================
stock Action StateLocked_OnUpdate(int client, int& buttons, float vel[3], float ang[3]) {
    if (!isAiCharger(client))
        return Plugin_Continue;
    
    static int target, betterTarget;
    target = GetClientOfUserId(g_AiChargers[client].m_iTarget);
    betterTarget = GetClientOfUserId(g_AiChargers[client].m_iBetterTarget);
    // 检查更好的目标是否有效
    target = (IsValidSurvivor(betterTarget) && IsPlayerAlive(betterTarget)) ? betterTarget : target;
    if (!IsValidSurvivor(target) || !IsPlayerAlive(target)) {
        stateLog.error("(%s) Charger (%N)'s target %d is invalid", STATE_LOCKED_NAME, client, target);
        return Plugin_Continue;
    }

    /*
    * 如果目标高度差过大无法冲锋, 那么就不要切换到 Charging 状态了
    * 并且清除 better target, 避免下一帧还使用这个旧的 better target
    */
    if (!isChargeTargetHeightReachable(client, target)) {
        stateLog.debugAll("Charger (%N) locked target (%N) is outside charge height %.2f, transition to APPROACH STATE",
            client, target, CHARGE_Z_THRESHOLD);
        
        g_AiChargers[client].m_iBetterTarget = 0;
        g_ChargerStateContext[client].transitionTo(CH_STATE_APPROACH);
        return Plugin_Continue;
    }

    /*
    * Locked 是 Bait -> Charging 转换的一帧过渡状态
    * 如果 Charger 此时还在空中, 在切入 Charging 前补一次空中速度修正
    * 避免上一次 Approach/Bait 的空中速度把 Charger 从目标侧面继续甩出去
    */
    static float targetEyePos[3];
    GetClientEyePosition(target, targetEyePos);

    static bool visible;
    visible = L4D2_IsVisibleToPlayer(client, TEAM_INFECTED, TEAM_SURVIVOR, 0, targetEyePos);
    if (visible) {
        g_AiChargers[client].m_flLastVisibleTime = GetGameTime();
    }
    preserveAirChargeLine(client, target, visible, AIR_CHARGE_LINE_CORR_LOCK_LERP);

    // 转换为冲锋状态
    stateLog.debugAll("Charger (%N) locked target (%N), is better target %d, transition to CHARGING STATE",
        client, target, (IsValidSurvivor(betterTarget) && IsPlayerAlive(betterTarget)));
    g_ChargerStateContext[client].transitionTo(CH_STATE_CHARGING);
    return Plugin_Changed;
}

// ============================================================
// OnExit 函数
// ============================================================
stock void StateLocked_OnExit(int client) {
    stateLog.debugAll("\n========== State Locked On Exit ===========");
}

// ======== End of: ./state_locked.inc ========

// =========================================================================
// 按 enum 顺序注册状态到 g_ChargerStates 中
// =========================================================================
stock void registerStates() {
    // 注册 Approach State
    RegisterState_Approach();
    // 注册 Bait_State
    RegisterState_Bait();
    // 注册 Locked_State
    RegisterState_Locked();
    // 注册 Charging_State
    RegisterState_Charging();
}
// ======== End of: ./state/state.inc ========

// 将插件日志前缀改成自己插件的日志前缀
#define PLUGIN_PREFIX "AI-Charger3"
#define ACT_NAME_CHARGER_EVADE		"ChargerEvade"
#define ACT_NAME_CHARGE_AT_VICTIM 	"ChargerChargeAtVictim"

ConVar
	g_cvPluginName,
	g_cvLogLevel;

Logger
	log;

public Plugin myinfo = 
{
	name 			= "Ai-Charger 3.0",
	author 			= "夜羽真白",
	description 	= "Ai Charger 增强 3.0 版本",
	version 		= "1.0.0.0",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

public void OnPluginStart() {
	// allow charger to bhop?
	g_cvBhop = CreateConVar("ai_charger3_bhop", "1", "是否允许 Charger 进行在接近状态时连跳操作, 0=禁止, 1=允许", CVAR_FLAGS, true, 0.0, true, 1.0);
	// charger is allowed to bhop when its distance from the target is between [ai_charger3_bhop_min_dist, ai_charger3_bhop_max_dist], if the distance is less than this value, charger will transition to bait state
	g_cvBhopMinDist = CreateConVar("ai_charger3_bhop_min_dist", "100.0", "禁止连跳的最小距离, 小于这个距离转换为博弈状态", CVAR_FLAGS, true, 0.0);
	g_cvBhopMaxDist = CreateConVar("ai_charger3_bhop_max_dist", "9999.0", "允许连跳的最大距离", CVAR_FLAGS, true, 0.0);
	g_cvDirectBhopDist = CreateConVar("ai_charger3_bhop_direct_dist", "400.0", "Charger 在接近状态中切换到朝目标方向直线连跳的距离阈值", CVAR_FLAGS, true, 0.0);
	// the bhop impulse, when charger is allowed to bhop, each time it jumps up from the ground, it will gain a speed impulse with the value of ai_charger3_bhop_impulse
	g_cvBhopImpulse = CreateConVar("ai_charger3_bhop_impulse", "60.0", "连跳的加速度", CVAR_FLAGS, true, 0.0);
	// when charger's speed is greater than 'ai_charger3_bhop_min_speed', it is allowed to bhop, and its max bhop speed will not greater than 'ai_charger3_bhop_max_speed'
	g_cvBhopMinSpeed = CreateConVar("ai_charger3_bhop_min_speed", "200", "允许连跳的最小速度", CVAR_FLAGS, true, 0.0);
	g_cvBhopMaxSpeed = CreateConVar("ai_charger3_bhop_max_speed", "300", "连跳的最大限制速度", CVAR_FLAGS, true, 0.0);
	g_cvBhopMaxHeight = CreateConVar("ai_charger3_bhop_max_height", "100.0", "Charger 连跳相对起跳地面的最大高度, 0=不限制", CVAR_FLAGS, true, 0.0);
	// Whether charger is allowed to perform bhop before charging. 0=Disabled, 1=Enabled
	g_cvBhopBeforeCharge = CreateConVar("ai_charger3_bhop_before_charge", "1", "是否允许在冲锋前进行连跳, 0=禁止, 1=允许", CVAR_FLAGS, true, 0.0, true, 1.0);
	// when charger has no vision of the target survivor, allow it to bhop?
	g_cvBhopNoVision = CreateConVar("ai_charger3_bhop_no_vision", "1", "是否允许Charger无目标视野时进行连跳, 0=禁止, 1=允许", CVAR_FLAGS, true, 0.0, true, 1.0);
	// when charger has no sight of target, it is allowed to bhop when its speed vector and eye angle forward vector within this degree
	g_cvBhopNoVisionMaxAng = CreateConVar("ai_charger3_bhop_nvis_maxang", "90.0", "无生还者视野时速度向量与视角前向向量在这个角度范围内, 允许连跳", CVAR_FLAGS, true, 0.0);
	// when the vector of charger to target and charger's eye angle forward vector within this degree, consider the target is looking at charger
	g_cvTargetWatchMaxDeg = CreateConVar("ai_charger3_target_watch_maxdeg", "22.5", "目标视角与到 Charger 位置向量夹角小于这个值时, 认为目标正在看着 Charger", CVAR_FLAGS, true, 0.0, true, 180.0);
	// when the distance between charger and target is less than this value, disable left/right strafing offset of charger's bhop direction
	g_cvBhopStrafeMinDist = CreateConVar("ai_charger3_bhop_strafe_mindist", "9999.0", "与目标小于这个距离时, 禁止连跳方向左右偏移", CVAR_FLAGS, true, 0.0);
	// the minimum angle of random left/right strafing offset for charger's bhop direction. Enable if greater than 0.0, disable this feature if set to -1.0
	g_cvBhopStrafeMinDeg = CreateConVar("ai_charger3_bhop_strafe_mindeg", "0.0", "Charger 连跳方向左右随机偏移 (侧向连跳) 的最小偏移角度, 大于 0.0 启用, -1.0 禁用此功能", CVAR_FLAGS, true, -1.0);
	// the maximum angle of random left/right strafing offset for charger's bhop direction
	g_cvBhopStrafeMaxDeg = CreateConVar("ai_charger3_bhop_strafe_maxdeg", "30.0", "Charger 侧向连跳的最大角度", CVAR_FLAGS, true, 0.0, true, 89.0);
	// The minimum distance from target required for charger to perform single strafe bhop (bhopping is disabled when closer than this distance)
	g_cvBhopStrafeOnceDist = CreateConVar("ai_charger3_bhop_strafe_once_dist", "200.0", "允许 Charger 侧向连跳一次的最小距离 (距离目标点小于这个距离不允许侧向连跳)", CVAR_FLAGS);
	// The minimum distance from target required for charger to perform double strafe bhop (bhopping is disabled when closer than this distance)
	g_cvBhopStrafeTwiceDist = CreateConVar("ai_charger3_bhop_strafe_twice_dist", "400.0", "允许 Charger 侧向连跳两次的最小距离 (距离目标点大于这个距离才允许侧向连跳两次)", CVAR_FLAGS);
	// when the target is holding a melee weapon, the minimum range of the melee bait zone (calculated as melee_range plus this value)
	g_cvMeleeBaitZoneMinRange = CreateConVar("_ai_charger3_melee_bait_minrange", "15.0", "目标拿着近战时, 近战博弈区的最小范围, melee_range + 这个值", CVAR_FLAGS, true, 0.0);
	// when the target is holding a melee weapon, the maximum range of the melee bait zone (calculated as melee_range plus this value)
	g_cvMeleeBaitZoneMaxRange = CreateConVar("_ai_charger3_melee_bait_maxrange", "50.0", "目标拿着近战时, 近战博弈区的最大范围, melee_range + 这个值", CVAR_FLAGS, true, 0.0);
	// when the angle between charger's air velocity direction and the direction from charger to target exceeds this value, perform air velocity modification (air modification: set charger's current velocity direction to the target direction)
	g_cvAirVecModifyMinDegree = CreateConVar("ai_charger3_airvec_modify_min_deg", "0.0", "在空中速度方向与自身到目标方向角度超过这个值进行速度修正", CVAR_FLAGS, true, 0.0);
	// When the angle between charger's air velocity direction and the direction from charger to target exceeds this value, abandon air velocity modification
	g_cvAirVecModifyMaxDegree = CreateConVar("ai_charger3_airvec_modify_max_deg", "990.0", "在空中速度方向与自身到目标方向角度超过这个值放弃速度修正", CVAR_FLAGS, true, 0.0);
	// the interval (in seconds) between consecutive air velocity vector modifications for charger
	g_cvAirVecModifyInterval = CreateConVar("ai_charger3_airvec_modify_interval", "0.1", "空中速度修正间隔", CVAR_FLAGS, true, 0.0);
	// The interpolation factor for charger's air velocity direction modification. Min: 0.0, Max: 1.0. Lower values result in smoother air turning, higher values result in sharper air turning
	g_cvAirVecModifyLerp = CreateConVar("_ai_charger3_airvec_modify_lerp", "0.1", "空中速度方向修正的修正插值因子, 0.1~1.0, 越小转向越平滑, 但是需要更多的帧数, 越大转向越锐利, 需要较少的帧数就可以完成空中转向", CVAR_FLAGS, true, 0.0, true, 1.0);
	// the maximum allowed duration (in seconds) for charger to stay in the bait state
	g_cvBaitMaxDuration = CreateConVar("ai_charger3_bait_max_duration", "0.1", "Charger 进入博弈状态的最大允许时间", CVAR_FLAGS, true, 0.0);
	// the detection interval (in seconds) for charger's probabilistic charge when in the bait state
	g_cvProbChargeChkDur = CreateConVar("ai_charger3_prob_charge_chk_dur", "0.1", "Charger 进入博弈状态概率冲锋的检测间隔", CVAR_FLAGS, true, 0.0);
	// the probability (0.0 to 1.0) of charger performing a probabilistic charge when in the bait state
	g_cvProbChargeProb = CreateConVar("ai_charger3_prob_charge_prob", "1.0", "Charger 进入博弈状态概率冲锋的概率", CVAR_FLAGS, true, 0.0);
	// whether to prohibit charger from retreating: 0=Disabled (allow retreat), 1=Enabled (forbid retreat)
	g_cvAntiRetreat = CreateConVar("ai_charger3_anti_retreat", "1", "是否禁止 Charger 逃跑, 0=禁止, 1=允许", CVAR_FLAGS, true, 0.0, true, 1.0);
	// refresh interval for the target destination used by BehaviorMoveTo while ChargerEvade is intercepted
	g_cvEvadeMoveToRefreshInterval = CreateConVar("ai_charger3_evade_moveto_refresh_interval", "1.0", "ChargerEvade 追击时检查并刷新 BehaviorMoveTo 目标坐标的间隔", CVAR_FLAGS, true, 0.1, true, 10.0);
	// The maximum depth of path segments that charger will look ahead when it is on ground and preparing to bhop (0 = disabled). Controls how far ahead charger scans the current PATH to find suitable landing spots before hopping from ground
	g_cvPathLookAheadMaxDepth = CreateConVar("ai_charger3_path_lookahead_maxdepth", "5", "Charger 向前搜索以当前速度可以一步到达的 PathSegment 的最大深度", CVAR_FLAGS, true, 0.0);
	// 提前冲锋的血量阈值，低于此血量时允许提前冲锋
	g_cvEarlyChargeHealth = CreateConVar("ai_charger3_early_charge_health", "390", "血量低于此值时允许提前冲锋", CVAR_FLAGS, true, 0.0);
	// 提前冲锋的距离阈值，小于此距离时允许提前冲锋
	g_cvEarlyChargeDist = CreateConVar("ai_charger3_early_charge_dist", "200.0", "距离小于此值时允许提前冲锋", CVAR_FLAGS, true, 0.0);

	// 兼容 ai_charger_2 的配置。先查找旧 Cvar，支持同一局内从旧版本切换到新版本。
	g_cvLegacyBhop = getOrCreateLegacyConVar("ai_ChargerBhop", "1", "是否开启 Charger 连跳", true, 0.0, true, 1.0);
	g_cvLegacyBhopSpeed = getOrCreateLegacyConVar("ai_ChagrerBhopSpeed", "60.0", "Charger 连跳速度/加速度兼容值", true, 0.0, false, 0.0);
	g_cvLegacyChargeDistance = getOrCreateLegacyConVar("ai_ChargerChargeDistance", "250.0", "Charger 旧版冲锋距离，转换为 3.0 直线连跳阈值", true, 0.0, false, 0.0);
	g_cvLegacyExtraTargetDistance = getOrCreateLegacyConVar("ai_ChargerExtraTargetDistance", "0,550", "Charger 额外目标范围，格式为最小距离,最大距离", false, 0.0, false, 0.0);
	g_cvLegacyAimOffset = getOrCreateLegacyConVar("ai_ChargerAimOffset", "30.0", "目标视角与 Charger 的兼容判定角度", true, 0.0, false, 0.0);
	g_cvLegacyMeleeAvoid = getOrCreateLegacyConVar("ai_ChargerMeleeAvoid", "0", "是否启用 Charger 近战回避", true, 0.0, true, 1.0);
	g_cvLegacyMeleeDamage = getOrCreateLegacyConVar("ai_ChargerMeleeDamage", "0", "Charger 血量低于该值时避免近战目标", true, 0.0, false, 0.0);
	g_cvLegacyTarget = getOrCreateLegacyConVar("ai_ChargerTarget", "1", "Charger 目标选择：1=原生，2=最近，3=人群中心", true, 1.0, true, 3.0);
	g_cvLegacyChargeHeightDiff = getOrCreateLegacyConVar("ai_ChargerChargeHeightDiff", "80.0", "允许直接冲锋的最大高度差，<=0 使用默认值", false, 0.0, false, 0.0);
	g_cvLegacyBhop.AddChangeHook(legacyChargerConfigChanged);
	g_cvLegacyBhopSpeed.AddChangeHook(legacyChargerConfigChanged);
	g_cvLegacyChargeDistance.AddChangeHook(legacyChargerConfigChanged);
	g_cvLegacyExtraTargetDistance.AddChangeHook(legacyChargerConfigChanged);
	g_cvLegacyAimOffset.AddChangeHook(legacyChargerConfigChanged);
	g_cvLegacyMeleeAvoid.AddChangeHook(legacyChargerConfigChanged);
	g_cvLegacyMeleeDamage.AddChangeHook(legacyChargerConfigChanged);
	g_cvLegacyTarget.AddChangeHook(legacyChargerConfigChanged);
	g_cvLegacyChargeHeightDiff.AddChangeHook(legacyChargerConfigChanged);

	// 将插件名称改成自己插件名称
	g_cvPluginName = CreateConVar("ai_charger3_plugin_name", "ai_charger3");

	char cvName[64];
	g_cvPluginName.GetString(cvName, sizeof(cvName));
	FormatEx(cvName, sizeof(cvName), "%s_log_level", cvName);
	// log recording level: 1=Disabled, 2=Console output, 4=Log file output, 8=Chat box output, 16=Server console output, 32=Error file output. Values can be added together for multiple outputs
	g_cvLogLevel = CreateConVar(cvName, "1", "日志记录级别, 1=关闭, 2=控制台输出, 4=log文件输出, 8=聊天框输出, 16=服务器控制台输出, 32=error文件输出, 数字相加", CVAR_FLAGS);

	HookEvent("round_start", evtRoundStart);
	HookEvent("round_end", evtRoundEnd);
	HookEvent("player_spawn", evtPlayerSpawn, EventHookMode_Pre);

	log = new Logger(PLUGIN_PREFIX, g_cvLogLevel.IntValue);

	// 子模块初始化
	SetUp_OnModuleStart();
	State_OnModuleStart(g_cvPluginName);
	Stock_OnModuleStart(g_cvPluginName);
}

public void OnPluginEnd() {
	SetUp_OnModuleEnd();
	State_OnModuleEnd();
	Stock_OnModuleEnd();
	delete log;
}

public void OnAllPluginsLoaded() {
	SetUp_OnAllPluginsLoaded();
}

public void OnConfigsExecuted() {
	SetUp_OnConfigsExecuted();
	syncLegacyChargerConfig();
}

ConVar getOrCreateLegacyConVar(const char[] name, const char[] defaultValue, const char[] description,
	bool hasMin, float minValue, bool hasMax, float maxValue)
{
	ConVar convar = FindConVar(name);
	if (convar != null)
		return convar;

	if (hasMin && hasMax)
		return CreateConVar(name, defaultValue, description, CVAR_FLAGS, true, minValue, true, maxValue);
	if (hasMin)
		return CreateConVar(name, defaultValue, description, CVAR_FLAGS, true, minValue);
	return CreateConVar(name, defaultValue, description, CVAR_FLAGS);
}

void syncLegacyChargerConfig()
{
	if (g_cvLegacyBhop != null)
		g_cvBhop.SetInt(g_cvLegacyBhop.IntValue);
	if (g_cvLegacyBhopSpeed != null)
		g_cvBhopImpulse.SetFloat(g_cvLegacyBhopSpeed.FloatValue);
	if (g_cvLegacyChargeDistance != null)
		g_cvDirectBhopDist.SetFloat(g_cvLegacyChargeDistance.FloatValue);
	if (g_cvLegacyAimOffset != null)
		g_cvTargetWatchMaxDeg.SetFloat(g_cvLegacyAimOffset.FloatValue);

	g_fLegacyExtraTargetMin = 0.0;
	g_fLegacyExtraTargetMax = 350.0;
	if (g_cvLegacyExtraTargetDistance != null)
	{
		char range[64];
		char values[2][32];
		g_cvLegacyExtraTargetDistance.GetString(range, sizeof(range));
		int count = ExplodeString(range, ",", values, sizeof(values), sizeof(values[]));
		if (count >= 1)
			g_fLegacyExtraTargetMin = StringToFloat(values[0]);
		if (count >= 2)
			g_fLegacyExtraTargetMax = StringToFloat(values[1]);
		if (g_fLegacyExtraTargetMax < g_fLegacyExtraTargetMin)
			g_fLegacyExtraTargetMax = g_fLegacyExtraTargetMin;
	}
}

void legacyChargerConfigChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	syncLegacyChargerConfig();
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon) {
	if (!isAiCharger(client))
		return Plugin_Continue;

	// 每帧限制异常上升，靠近生还者时也不会因连跳速度叠加而飞上天
	limitBhopJumpHeight(client);

	// BehaviorMoveTo 无法被 actions.ext 捕获, 因此从始终执行的 RunCmd 维护 BOT_CMD_MOVE 的目标坐标
	maintainEvadeMoveCommand(client);

	if (GetEntityMoveType(client) == MOVETYPE_LADDER) {
		buttons &= ~IN_JUMP;
		buttons &= ~IN_DUCK;
	}

	static int ability;
	ability = getChargeAbilityEnt(client);
	if (!IsValidEdict(ability))
		return Plugin_Continue;
	static bool isCharging;
	isCharging = view_as<bool>(GetEntProp(ability, Prop_Send, "m_isCharging"));
	if (isCharging && g_AiChargers[client].m_bChargeDelayed)
		g_AiChargers[client].m_bChargeDelayed = false;
	
	// 状态自检必须早于目标检查。即使暂时没有有效目标，新实体也要先完成初始化，
	// 避免目标恢复后继续沿用旧的冲锋、连跳或博弈状态。
	if (g_ChargerStateContext[client].userId != GetClientUserId(client)) {
		g_AiChargers[client].init();
		g_ChargerStateContext[client].init(client);
		g_ChargerStateContext[client].transitionTo(CH_STATE_APPROACH);
	}

	static int target;
	target = GetClientOfUserId(g_AiChargers[client].m_iTarget);
	if (!IsValidSurvivor(target) || !IsPlayerAlive(target))
		return Plugin_Continue;

	// 执行当前状态的每帧行为更新操作
	return g_ChargerStateContext[client].update(buttons, vel, angles);
}

void evtRoundStart(Event event, const char[] name, bool dontBroadcast) {

}

void evtRoundEnd(Event event, const char[] name, bool dontBroadcast) {

}

void evtPlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	static int client;
	client = GetClientOfUserId(event.GetInt("userid"));
	if (!isAiCharger(client))
		return;
	
	// 新的 charger, 重置状态
	g_AiChargers[client].init();
	g_ChargerStateContext[client].init(client);
	g_ChargerStateContext[client].transitionTo(CH_STATE_APPROACH);
}

public void OnMapStart() 
{
	GetVectorShowSprite();
}

public void OnMapEnd() {

}

public Action L4D2_OnChooseVictim(int client, int &curTarget) {
	if (!isAiCharger(client))
		return Plugin_Continue;

	int selected = selectLegacyCompatibleTarget(client, curTarget);
	if (selected > 0 && selected != curTarget)
	{
		curTarget = selected;
		g_AiChargers[client].m_iTarget = GetClientUserId(selected);
		return Plugin_Changed;
	}

	if (IsValidSurvivor(curTarget) && IsPlayerAlive(curTarget))
		g_AiChargers[client].m_iTarget = GetClientUserId(curTarget);
	return Plugin_Continue;
}

bool isLegacyTargetCandidate(int client, int target, const float origin[3], float &distance)
{
	if (target == client || !IsValidSurvivor(target) || !IsPlayerAlive(target))
		return false;
	if (IsClientIncapped(target) || IsClientHanging(target) || IsClientPinned(target))
		return false;

	float targetPos[3];
	GetClientAbsOrigin(target, targetPos);
	distance = GetVectorDistance(origin, targetPos);
	return distance >= g_fLegacyExtraTargetMin && distance <= g_fLegacyExtraTargetMax;
}

int selectLegacyCompatibleTarget(int client, int currentTarget)
{
	if (!g_cvLegacyTarget || g_cvLegacyTarget.IntValue <= 1)
		return (IsValidSurvivor(currentTarget) && IsPlayerAlive(currentTarget)) ? currentTarget : getClosestSurvivorAndValid(client);

	float origin[3];
	GetClientAbsOrigin(client, origin);

	int bestTarget = -1;
	float bestDistance = 999999.0;
	float bestScore = 999999999.0;
	int mode = g_cvLegacyTarget.IntValue;

	for (int i = 1; i <= MaxClients; i++)
	{
		float distance;
		if (!isLegacyTargetCandidate(client, i, origin, distance))
			continue;

		if (mode == 2)
		{
			if (distance < bestDistance)
			{
				bestDistance = distance;
				bestTarget = i;
			}
			continue;
		}

		float candidatePos[3];
		GetClientAbsOrigin(i, candidatePos);
		float crowdScore = 0.0;
		for (int j = 1; j <= MaxClients; j++)
		{
			if (j == client || !IsValidSurvivor(j) || !IsPlayerAlive(j))
				continue;

			float survivorPos[3];
			GetClientAbsOrigin(j, survivorPos);
			crowdScore += GetVectorDistance(candidatePos, survivorPos, true);
		}

		if (crowdScore < bestScore)
		{
			bestScore = crowdScore;
			bestTarget = i;
		}
	}

	if (bestTarget > 0)
		return bestTarget;
	if (IsValidSurvivor(currentTarget) && IsPlayerAlive(currentTarget))
		return currentTarget;
	return getClosestSurvivorAndValid(client);
}

// PathFollower::Update(long double a1@<st0>, PathFollower *this, INextBot *a3)
// PathFollower::Update 首次执行晚于 OnPlayerRunCmd, 并且频率大概是 OnPlayerRunCmd 的 1/3
MRESReturn Detour_PathFollower_Update(Address pThis, Handle hParams) {
	if (!pThis) {
		stateLog.error("Detour for signature: %s got null this pointer", SIG_PATH_FOLLOWER_UPDATE);
		return MRES_Ignored;
	}
	if (!hParams) {
		stateLog.error("Detour for signature: %s got null params handle", SIG_PATH_FOLLOWER_UPDATE);
		return MRES_Ignored;
	}

	// 首先获取 client index
	static Address pNextBot;
	pNextBot = view_as<Address>(DHookGetParam(hParams, 1));
	if (!pNextBot) {
		stateLog.error("Detour for signature: %s got null parameter 1: nextbot pointer", SIG_PATH_FOLLOWER_UPDATE);
		return MRES_Ignored;
	}
	static int client;
	client = SDKCall(g_hSdkNextBotGetCombatCharacter, pNextBot);
	if (!isAiCharger(client))
		return MRES_Ignored;

	// 保存 IPathFollower 指针, 用于路径前瞻与失效化处理
	g_AiChargers[client].m_pPathFollower = pThis;

	// v37 = *((_DWORD *)this + 4566); 因为 this 被转成了 DWORD 类型, 因此后面的偏移量 4566 也是基于 4 字节的
	static Address pPathSeg, pNextSeg, pLastSeg;
	static PathSegment curSegment, nextSegment, lastSegment;
	// Current Segment struct
	pPathSeg = view_as<Address>(SDKCall(g_hSdkPathGetCurGoal, pThis));
	if (!pPathSeg) {
		g_AiChargers[client].m_PathSegment.init();
		return MRES_Ignored;
	} else {
		constructPathSegment(pPathSeg, curSegment);
		g_AiChargers[client].m_PathSegment = curSegment;
	}

	// Next Segment struct
	pNextSeg = view_as<Address>(SDKCall(g_hSdkPathNextSegment, pThis, pPathSeg));
	if (!pNextSeg) {
		g_AiChargers[client].m_NextPathSegment.init();
	} else {
		constructPathSegment(pNextSeg, nextSegment);
		g_AiChargers[client].m_NextPathSegment = nextSegment;
	}

	// Last Segment struct
	// class PathFollower : public Path; PathFollower 继承自 Path, 可以使用 Path 类中的虚函数 Path::LastSegment
	pLastSeg = view_as<Address>(SDKCall(g_hSdkPathLastSegment, pThis));
	if (!pLastSeg) {
		g_AiChargers[client].m_LastPathSegment.init();
	} else {
		constructPathSegment(pLastSeg, lastSegment);
		g_AiChargers[client].m_LastPathSegment = lastSegment;
	}

	// 检查落后的 m_goal；无法在剩余路径中重新定位时，无效化旧路径并等待原生 Action 重新寻路。
	checkGoalIsBehind(client, pThis, pPathSeg);
	return MRES_Ignored;
}

void checkGoalIsBehind(int client, Address pPathFollower, Address pCurrentSeg) {
	if (!isAiCharger(client))
		return;
	if (!pPathFollower)
		return;
	if (!pCurrentSeg)
		return;

	PathSegment curSeg;
	curSeg = g_AiChargers[client].m_PathSegment;
	if (!curSeg.m_pNavArea)
		return;

	Address pLastKnownArea = L4D_GetLastKnownArea(client);
	if (!pLastKnownArea) {
		static float pos[3];
		GetClientAbsOrigin(client, pos);
		pos[2] += 20.0;
		pLastKnownArea = view_as<Address>(L4D_GetNearestNavArea(pos, _, _, true, true, TEAM_INFECTED));

		if (!pLastKnownArea) {
			log.error("[CheckGoalIsBehind]: Failed to get client %N's LastKnownArea or nearest NavArea", client);
			return;
		}
	}

	/*
	 * 原生 CheckProgress 的 LookAhead 机制可能一次跳过多个 Segment, 虽然 LookAhead Range 一般会被设置成 0, 所以是关闭的
	 * 但是为了防止这种情况, 考虑 LookAhead 机制, 开启 LookAhead 时, LastKnownArea 位于 CurrentGoal
	 * 之前的任意 Segment 都可能是正常状态，不能仅检查 PriorSegment
	 */
	static Address pPastSeg;
	static PathSegment pastSeg;
	pPastSeg = pCurrentSeg;
	while (pPastSeg) {
		constructPathSegment(pPastSeg, pastSeg);
		if (pastSeg.m_pNavArea == pLastKnownArea)
			return;

		pPastSeg = view_as<Address>(SDKCall(g_hSdkPathPriorSegment, pPathFollower, pPastSeg));
	}

	/*
	* 向前检查当前路径的 PathSegment, 检查 LastKnownArea 是否属于 CurrentGoal 本身或者之前的路径
	* 如果是, 说明 Charger 正在朝着 CurrentGoal 或者已经到达了 CurrentGoal, 此时无需干预
	*/
	if (pPastSeg) {
		log.debugAll("[CheckGoalIsBehind]: Aborted prior path scan for Charger %N because found a prior segment (NavId: %d) is same as LastKnownArea (NavId: %d)",
			client, L4D_GetNavAreaID(pastSeg.m_pNavArea)), L4D_GetNavAreaID(pLastKnownArea);
		return;
	}

	/*
	* CurrentGoal 落后于 LastKnownArea 但是 LastKnownArea 仍然在当前 Path 上
	* 从 CurrengSegment 开始向后扫描, 直到 LastKnownArea, 如果找到了一个 Segment 等于 LastKnownArea, 那么将 CurrentGoal 设置为 LastKnownArea 的 Segment
	*/
	static Address pIterSeg, pMatchedSeg;
	pIterSeg = view_as<Address>(SDKCall(g_hSdkPathNextSegment, pPathFollower, pCurrentSeg));
	pMatchedSeg = Address_Null;

	// 从 CurrentGoal 开始向后扫描整段路径
	while (pIterSeg) {
		static PathSegment iterSeg;
		constructPathSegment(pIterSeg, iterSeg);

		if (iterSeg.m_pNavArea == pLastKnownArea) {
			pMatchedSeg = pIterSeg;
			break;
		}

		pIterSeg = view_as<Address>(SDKCall(g_hSdkPathNextSegment, pPathFollower, pIterSeg));
	}

	if (pMatchedSeg) {
		// 进入匹配 NavArea 不代表已经越过该 Segment 的 GoalPos, 因此不再额外跳到 NextSegment
		static Address pNewGoal;
		pNewGoal = pMatchedSeg;
		// 将 PathFollower::m_goal 写成当前 LastKnownArea 对应的 PathSegment 的 m_goal
		StoreToAddress(pPathFollower + view_as<Address>(g_iPathFollowerGoalOffset), pNewGoal, NumberType_Int32);

		static PathSegment newGoalSeg;
		constructPathSegment(pNewGoal, newGoalSeg);
		g_AiChargers[client].m_PathSegment = newGoalSeg;

		static Address pNewNext;
		pNewNext = view_as<Address>(SDKCall(g_hSdkPathNextSegment, pPathFollower, pNewGoal));
		if (pNewNext) {
			static PathSegment newNextSeg;
			constructPathSegment(pNewNext, newNextSeg);
			g_AiChargers[client].m_NextPathSegment = newNextSeg;
		} else {
			g_AiChargers[client].m_NextPathSegment.init();
		}

		// 重新找到了新的 CurrentGoal, 重置空中速度修正坐标
		ZeroVector(g_AiChargers[client].m_vecAirCorrGoal);
		g_AiChargers[client].m_AirStrafe.init();

		log.debugAll("[CheckGoalIsBehind]: Advanced Charger %N goal after matching future NavArea %d", client, L4D_GetNavAreaID(pLastKnownArea));
		return;
	}

	/*
	* 如果 LastKnownArea 无法匹配当前 Path 上任何一个节点, 说明 Charger 已经脱离该 Path, 此时需要使旧的 Path 无效化
	* 然后通过 ChargerAttack::Update 这个 Action 重新构造一条新的 Path
	*/
	SDKCall(g_hSdkPathInvalidate, pPathFollower);

	g_AiChargers[client].m_PathSegment.init();
	g_AiChargers[client].m_NextPathSegment.init();
	g_AiChargers[client].m_LastPathSegment.init();
	ZeroVector(g_AiChargers[client].m_vecAirCorrGoal);
	g_AiChargers[client].m_AirStrafe.init();
	g_AiChargers[client].m_BhopType = BhopType_None;

	log.debugAll("[CheckGoalIsBehind]: Invalidated Charger %N path because LastKnownArea %d is absent from the remaining path", client, L4D_GetNavAreaID(pLastKnownArea));
}

/**
* 将生还者当前位置解析为适合 BOT_CMD_MOVE 的 Nav 目的地。
* 目标可能站在箱子或处于空中, 因此优先使用当前位置附近的 NavArea,
* LastKnownArea 只作为最后回退, 避免传送后继续使用旧区域。
*/
stock bool getEvadeMoveDestination(int target, float movePos[3]) {
	if (!IsValidSurvivor(target) || !IsPlayerAlive(target))
		return false;

	static float targetPos[3], navQueryPos[3];
	GetClientAbsOrigin(target, targetPos);

	static Address targetNavArea;
	targetNavArea = L4D2Direct_GetTerrorNavArea(targetPos);

	if (!targetNavArea) {
		navQueryPos = targetPos;
		navQueryPos[2] += 20.0;
		targetNavArea = L4D_GetNearestNavArea(navQueryPos, _, false, true, true, TEAM_SURVIVOR);
	}

	if (!targetNavArea)
		targetNavArea = L4D_GetLastKnownArea(target);

	if (!targetNavArea)
		return false;

	L4D_GetNavAreaCenter(targetNavArea, movePos);
	return true;
}

stock void clearEvadeMoveCommandTracking(int client) {
	g_AiChargers[client].m_bEvadeMoveCommandActive = false;
	g_AiChargers[client].m_flLastEvadeMoveToCheckTime = 0.0;
	ZeroVector(g_AiChargers[client].m_vecEvadeMoveToPos);
}

stock void stopEvadeMoveCommand(int client, const char[] reason) {
	static bool accepted;
	accepted = L4D2_CommandABot(client, 0, BOT_CMD_RESET);

	log.debugAll("[EvadeMoveCommand]: Reset Charger %N command, accepted: %d, reason: %s", client, accepted, reason);
	clearEvadeMoveCommandTracking(client);
}

/**
* actions.ext 无法观察 CommandABot 创建的 BehaviorMoveTo, 因此由 RunCmd 定时维护命令
* 目标 Nav 目的地变化后只 RESET 旧的 CommandABot MOVE 命令; ChargerEvade 恢复时负责读取新坐标并重新下发 MOVE
*/
stock void maintainEvadeMoveCommand(int client) {
	if (!g_AiChargers[client].m_bEvadeMoveCommandActive)
		return;

	if (!g_cvAntiRetreat.BoolValue) {
		stopEvadeMoveCommand(client, "anti-retreat disabled");
		return;
	}

	if (isChargerCharging(client) ||
		IsValidSurvivor(L4D2_GetQueuedPummelVictim(client)) ||
		IsValidSurvivor(L4D_GetVictimCharger(client)) ||
		IsValidSurvivor(L4D_GetVictimCarry(client))
	) {
		stopEvadeMoveCommand(client, "charging or pinning");
		return;
	}

	static int target;
	target = GetClientOfUserId(g_AiChargers[client].m_iTarget);
	if (!IsValidSurvivor(target) || !IsPlayerAlive(target)) {
		stopEvadeMoveCommand(client, "target invalid");
		return;
	}

	/*
	* 检查旧的目标位置是否仍然有效, 目标移动超过 EVADE_MOVETO_REFRESH_MIN_DIST 时, 下达 BOT_CMD_RESET 恢复 Charger 原生行为
	* 如果 ChargerEvade 继续生效, 那么会尝试获取新的目标位置, 下达 BOT_CMD_MOVE 命令
	*/
	static float now;
	now = GetEngineTime();
	if (now - g_AiChargers[client].m_flLastEvadeMoveToCheckTime < g_cvEvadeMoveToRefreshInterval.FloatValue)
		return;

	g_AiChargers[client].m_flLastEvadeMoveToCheckTime = now;

	static float newMovePos[3];
	if (!getEvadeMoveDestination(target, newMovePos)) {
		log.debugAll("[EvadeMoveCommand]: Failed to resolve target %N's current move destination", target);
		return;
	}

	static float movedDist;
	movedDist = GetVectorDistance(g_AiChargers[client].m_vecEvadeMoveToPos, newMovePos);
	if (movedDist < EVADE_MOVETO_REFRESH_MIN_DIST)
		return;

	/*
	* 不在这里更新旧坐标或清除 active 标记。若 RESET 未生效, 下一周期仍会重试
	* 若 RESET 生效, 恢复的 ChargerEvade 会重新下发 MOVE 并写入新坐标
	*/
	static bool accepted;
	accepted = L4D2_CommandABot(client, 0, BOT_CMD_RESET);
	log.debugAll("[EvadeMoveCommand]: Target %N destination moved %.2f units, reset Charger %N command, accepted: %d",
		target, movedDist, client, accepted);
}

// ============================================================
// Action Extension
// ============================================================
public void OnActionCreated(BehaviorAction action, int actor, const char[] name) {
	if (action == INVALID_ACTION || !isAiCharger(actor))
		return;

	if (g_cvAntiRetreat.BoolValue) {
		if (strcmp(name, ACT_NAME_CHARGER_EVADE, false) == 0) {
			action.OnUpdate = chargerEvade_OnUpdate;
			action.OnEnd = chargerEvade_OnEnd;
		}
	}
	// 防止 charger 刷新距离生还者很近时, 游戏强制冲撞, 但是 APPROACH STATE 同时将 Charger 能力就绪时间设置为 1 秒后, 导致 Charger 原地卡住
	if (strcmp(name, ACT_NAME_CHARGE_AT_VICTIM, false) == 0) {
		action.OnUpdate = chargerChargeAtVictim_OnUpdate;
	}
}

Action chargerEvade_OnUpdate(BehaviorAction action, int actor, float interval, ActionResult result) {
	if (!isAiCharger(actor)) {
		return Plugin_Continue;
	}
	if (!g_cvAntiRetreat.BoolValue) {
		clearEvadeMoveCommandTracking(actor);
		return Plugin_Continue;
	}
	// 撞停准备控人的时候有时候会触发 Evade 行为
	if (isChargerCharging(actor) ||
		IsValidSurvivor(L4D2_GetQueuedPummelVictim(actor)) ||
		IsValidSurvivor(L4D_GetVictimCharger(actor)) ||
		IsValidSurvivor(L4D_GetVictimCarry(actor))
	) {
		return Plugin_Continue;
	}

	static int target;
	target = GetClientOfUserId(g_AiChargers[actor].m_iTarget);
	if (!IsValidSurvivor(target) || !IsPlayerAlive(target)) {
		return Plugin_Continue;
	}
	
	static float movePos[3];
	if (!getEvadeMoveDestination(target, movePos)) {
		log.debugAll("[ChargerEvadeOnUpdate]: Failed to resolve target %N's move destination", target);
		return Plugin_Continue;
	}

	/* static float movePos_cpy[3];
	movePos_cpy = movePos;
	movePos_cpy[2] += 200.0;
	ShowPos(COLOR_GREEN, movePos, movePos_cpy); */

	g_AiChargers[actor].m_vecEvadeMoveToPos = movePos;
	g_AiChargers[actor].m_flLastEvadeMoveToCheckTime = GetEngineTime();
	g_AiChargers[actor].m_bEvadeMoveCommandActive = true;

	/*
	* accepted 大概率是 false, 不知道为什么, 使用 nb_debug BEHAVIOR 可以看到 BehaviorMoveTo << ChargerEvade << ChargerAttack
	* 但是 actions 拓展的 OnActionCreated 却无法捕捉到 BehaviorMoveTo 的创建, 无论是 raw action 还是验证过的有效 action 都无法捕捉
	*/
	static bool accepted;
	accepted = L4D2_CommandABot(actor, target, BOT_CMD_MOVE, movePos);
	log.debugAll("[ChargerEvadeOnUpdate]: CommandABot MOVE acctpted: %d", accepted);

	/*
	* 不能在这里直接 action.Done(), 因为 CommandABot 这个 Action 创建成功之后, BehaviorMoveTo 应当暂停 ChargerEvade
	* 如果直接 Done, 那么由 ChargerEvade 派生出来的 BehaviorMoveTo 也会被跟着 ChargerEvade 释放掉
	*/
	return Plugin_Changed;
}

void chargerEvade_OnEnd(BehaviorAction action, int actor, BehaviorAction nextAction, ActionResult result) {
	if (!isAiCharger(actor))
		return;

	g_AiChargers[actor].m_bEvadeMoveCommandActive = false;
	g_AiChargers[actor].m_flLastEvadeMoveToCheckTime = 0.0;
	ZeroVector(g_AiChargers[actor].m_vecEvadeMoveToPos);
}

Action chargerChargeAtVictim_OnUpdate(BehaviorAction action, int actor, float interval, ActionResult result) {
	if (!isAiCharger(actor))
		return Plugin_Continue;

	/*
		防止 Charger 刷新后满足冲锋条件, 引擎立即让其冲锋, 但插件进入 APPROACH STATE 会设置能力延时, 导致其无法进行冲锋而在原地罚站
		既然插件接管了, 就必须在 CHARGING STATE 中手动冲锋, 其他不在 CHARGING STATE 中的冲锋都视为非法, 直接停止
	*/
	static int curState;
	curState = g_ChargerStateContext[actor].currentStateId;
	if (curState != CH_STATE_CHARGING) {
		log.debugAll("Charger (%N) try to charge, but in approach state, force stop charge", actor);
		action.Done();
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

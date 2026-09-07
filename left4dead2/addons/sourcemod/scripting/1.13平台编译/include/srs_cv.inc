// SRS code enum (datatype)
enum
{
	// Infected Kill
	SRS_S_K_CI			= 0,		// Surivivor Killed Common Infected
	SRS_S_K_SK		    = 1,		// Surivivor Killed Smoker
	SRS_S_K_B   		= 2,		// Surivivor Killed Boomer
	SRS_S_K_H	  		= 3,		// Surivivor Killed Hunter
	SRS_S_K_ST  		= 4,		// Surivivor Killed Spitter
	SRS_S_K_J   		= 5,		// Surivivor Killed Jockey
	SRS_S_K_C   		= 6,		// Surivivor Killed Changer
	SRS_S_K_W   		= 7,		// Surivivor Killed Witch
	SRS_S_K_T   		= 8,		// Surivivor Killed Tank
	// Infected Kill Headshot
	SRS_S_K_CI_HS 		= 9,		// Surivivor Killed Common Infected (Headshot)
	SRS_S_K_SK_HS     	= 10,		// Surivivor Killed Smoker (Headshot)
	SRS_S_K_B_HS	    = 11,		// Surivivor Killed Boomer (Headshot)
	SRS_S_K_H_HS     	= 12,		// Surivivor Killed Hunter (Headshot)
	SRS_S_K_ST_HS	    = 13,		// Surivivor Killed Spitter (Headshot)
	SRS_S_K_J_HS     	= 14,		// Surivivor Killed Jockey (Headshot)
	SRS_S_K_C_HS     	= 15,		// Surivivor Killed Changer (Headshot)
	SRS_S_K_W_HS 		= 16,		// Surivivor Killed Witch (Headshot)
	SRS_S_K_T_HS 		= 17,		// Surivivor Killed Tank (Headshot)

	SRS_S_K_W_OS 		= 18,		// Surivivor Killed Witch in one shot

	// Gun statistic
	SRS_S_K_SMG			= 19,		// Surivivor killed CI/SI by SMG
	SRS_S_K_SILENCED	= 20,		// Surivivor killed CI/SI by SMG silenced
	SRS_S_K_MP5			= 21,		// Surivivor killed CI/SI by MP5
	SRS_S_K_M16			= 22,		// Surivivor killed CI/SI by RIFLE (M16)
	SRS_S_K_DESERT		= 23,		// Surivivor killed CI/SI by Desert
	SRS_S_K_AK47		= 24,		// Surivivor killed CI/SI by AK47
	SRS_S_K_SG552		= 25,		// Surivivor killed CI/SI by Sg552
	SRS_S_K_M60			= 26,		// Surivivor killed CI/SI by m60
	SRS_S_K_HUNTING		= 27,		// Surivivor killed CI/SI by Hunting
	SRS_S_K_MILITARY	= 28,		// Surivivor killed CI/SI by Military
	SRS_S_K_AWP			= 29,		// Surivivor killed CI/SI by Awp
	SRS_S_K_SCOUT		= 30,		// Surivivor killed CI/SI by Awp
	SRS_S_K_PUMP		= 31,		// Surivivor killed CI/SI by Pump
	SRS_S_K_CHROME		= 32,		// Surivivor killed CI/SI by CHROME
	SRS_S_K_AUTO		= 33,		// Surivivor killed CI/SI by auto
	SRS_S_K_SPAS		= 34,		// Surivivor killed CI/SI by Spas
	SRS_S_K_PISTOL		= 35,		// Surivivor killed CI/SI by PISTOL
	SRS_S_K_MAGNUM		= 36,		// Surivivor killed CI/SI by magnum
	SRS_S_K_GL			= 37,		// Surivivor killed CI/SI by Grenade Launcher
    
	// Melee statistic
	SRS_S_K_KATANA		= 38,		// Surivivor killed CI/SI by katana
	SRS_S_K_AXE			= 39,		// Surivivor killed CI/SI by AXE
	SRS_S_K_MACHATE		= 40,		// Surivivor killed CI/SI by machete
	SRS_S_K_KNIFE		= 41,		// Surivivor killed CI/SI by Knife
	SRS_S_K_SAW			= 42,		// Surivivor killed CI/SI by chainsaw
	SRS_S_K_PITCHFORK	= 43,		// Surivivor killed CI/SI by pitchfork
	SRS_S_K_SHOVEL		= 44,		// Surivivor killed CI/SI by shovel
	SRS_S_K_GOLF		= 45,		// Surivivor killed CI/SI by golfclub
	SRS_S_K_GUITAR		= 46,		// Surivivor killed CI/SI by guitar
	SRS_S_K_TONFA		= 47,		// Surivivor killed CI/SI by tonfa
	SRS_S_K_BASEBALL	= 48,		// Surivivor killed CI/SI by baseballc
	SRS_S_K_CRICKET		= 49,		// Surivivor killed CI/SI by cricket
	SRS_S_K_PAN			= 50,		// Surivivor killed CI/SI by Pan
	SRS_S_K_CROWBAR		= 51,		// Surivivor killed CI/SI by crowbar
	SRS_S_K_PIPE		= 52,		// Surivivor killed CI/SI by Pipe
	SRS_S_K_MOLO		= 53,		// Surivivor killed CI/SI by Molotov
    SRS_S_K_NONE        = 54,        // Surivivor killed CI/SI by none (e.g. Throwables)
	SRS_S_SHOT			= 55,		// Amount of surivivor shot
	SRS_S_HIT			= 56,		// Amount of surivivor hit
	SRS_S_DMG			= 57,		// Amount of damage made

	SRS_S_PILLS			= 58,		// Surivivor used Pills 
	SRS_S_ADRENALINE	= 59,		// Surivivor used Adrenaline 
	SRS_S_MEDKIT		= 60,		// Surivivor used Medikit 
	SRS_S_HEALED		= 61,		// Surivivor is healed by someone
	SRS_S_SELF_HEALED	= 62,		// Surivivor is healed by himself
	SRS_S_HEAL			= 63,		// Surivivor used Medikit for healing someone
	SRS_S_DEFIBRILLATE	= 64,		// Surivivor defibrillated someone
	SRS_S_DEFIBRILLATED	= 65,		// Surivivor is defibrillated by someone

	SRS_S_TH_MOLO		= 66,		// Surivivor throwed molotov
	SRS_S_TH_PIPE		= 67,		// Surivivor throwed pipe boom
	SRS_S_TH_VOMITJAR	= 68,		// Surivivor throwed vomitjar

	// Survivor event
	SRS_S_RESCUE		= 69,		// Surivivor rescued someone
	SRS_S_RESCUED		= 70,		// Surivivor is rescued by someone
	SRS_S_REVIVE		= 71,		// Surivivor revived someone
	SRS_S_REVIVED		= 72,		// Surivivor is revived by someone
	SRS_S_INCAPACITATED	= 73,		// Amount of surivivor incapacated
	SRS_S_PROTECTED		= 74,		// Amount of surivivor was protected
	SRS_S_PROTECT		= 75,		// Amount of surivivor protect
	SRS_S_DEATH			= 76,		// Amount of death of surivivor
	SRS_S_TEAMKILL		= 77,		// Amount of Team kill
	SRS_S_J_RIDE		= 78,		// Amount of being rode (as survivor)
	SRS_S_C_CARRY		= 79,		// Amount of being carrid by charger (as survivor)
	SRS_S_C_PUMMEL		= 80,		// Amount of being pummeled by charger (as survivor)
	SRS_S_SK_POUNCE		= 81,		// Amount of being pounced by smoker (as survivor)
	SRS_S_H_PUNCHED		= 82,		// Amount of being punched by hunter (as survivor)
	SRS_S_ST_DMG		= 83,		// Amount of damage hurt by Spitter
	SRS_S_B_NOW_IT		= 84,		// Amount of vomit by boomer
	SRS_S_HURT			= 85,		// Amount of damage hurt
    
	SRS_I_J_RIDE		= 86,		// Amount of ride jockey did
	SRS_I_C_CARRY		= 87,		// Amount of carry charger did
	SRS_I_C_PUMMEL		= 88,		// Amount of pummel charger did
	SRS_I_SK_POUNCE		= 89,		// Amount of pounch smoker did
	SRS_I_H_PUNCHED		= 90,		// Amount of being punched hunter did
	SRS_I_ST_DMG		= 91,		// Amount of damage hurt Spitter did
	SRS_I_B_NOW_IT		= 92,		// Amount of vomit boomer did
	SRS_I_J_RIDE_HIT	= 93,		// Amount of (hit) rode did
	SRS_I_C_CARRY_HIT	= 94,		// Amount of (hit) carrid charger did
	SRS_I_C_PUMMEL_HIT	= 95,		// Amount of (hit) pummeled charger did
	SRS_I_SK_POUNCE_HIT	= 96,		// Amount of (hit) pounced smoker did
	SRS_I_H_PUNCHED_HIT	= 97,		// Amount of (hit) punched hunter did
	SRS_I_ST_DMG_HIT	= 98,		// Amount of (hit) hurt Spitter did
	SRS_I_B_NOW_IT_HIT	= 99,		// Amount of (hit) vomit boomer did
	SRS_I_T_DMG_STONE	= 100,		// Amount of damage for surivior by stone tank did.
	SRS_I_T_DMG_CROW	= 101,		// Amount of damage for surivior by crow tank did.
	SRS_I_T_DMG_CAR		= 102,		// Amount of damage for surivior by car tank did.
	SRS_I_HURT			= 103,		// Amount of damage hurt
	SRS_I_DMG			= 104,		// Amount of damage made
	SRS_I_KILL			= 105,		// Amount of Killing Surivivor
	SRS_I_INCAPACITATE	= 106,		// Amount of Incapacitating Surivivor
	SRS_I_DEATH			= 107,		// Amount of death of infected

	SRS_H_MX_CB			= 108,		// History max Combo 

	SRS_CODE_SIZE		= 109,		// Statistic size
}

// SRS type enum (affect life circle)
enum
{
    SRS_TYPE_MVP_BOT    = 0, // Clear each round 
    SRS_TYPE_DB_BOT     = 1, // 
    SRS_TYPE_MVP		= 2, // Clear each round
    SRS_TYPE_DB			= 3, // Clear when client leave
    SRS_TYPE_SIZE       = 4,
}

stock const char g_sSRSSIName[][] =
{
	"Smoker",
	"Boomer",
	"Hunter",
	"Spitter",
	"Jockey",
	"Charger",
	"Witch",
	"Tank",
}

// DB Field name, the length must equal to SRS_CODE_SIZE.
stock const char g_sSRSCode[][]=
{
	"SRS_S_K_CI",
	"SRS_S_K_SK",
	"SRS_S_K_B",
	"SRS_S_K_H",
	"SRS_S_K_ST",
	"SRS_S_K_J",
	"SRS_S_K_C",
	"SRS_S_K_W",
	"SRS_S_K_T",
	"SRS_S_K_CI_HS",
	"SRS_S_K_SK_HS",
	"SRS_S_K_B_HS",
	"SRS_S_K_H_HS",
	"SRS_S_K_ST_HS",
	"SRS_S_K_J_HS",
	"SRS_S_K_C_HS",
	"SRS_S_K_W_HS",
	"SRS_S_K_T_HS",
	"SRS_S_K_W_OS",
	"SRS_S_K_SMG",
	"SRS_S_K_SILENCED",
	"SRS_S_K_MP5",
	"SRS_S_K_M16",
	"SRS_S_K_DESERT",
	"SRS_S_K_AK47",
	"SRS_S_K_SG552",
	"SRS_S_K_M60",
	"SRS_S_K_HUNTING",
	"SRS_S_K_MILITARY",
	"SRS_S_K_AWP",
	"SRS_S_K_SCOUT",
	"SRS_S_K_PUMP",
	"SRS_S_K_CHROME",
	"SRS_S_K_AUTO",
	"SRS_S_K_SPAS",
	"SRS_S_K_PISTOL",
	"SRS_S_K_MAGNUM",
	"SRS_S_K_GL",
	"SRS_S_K_KATANA",
	"SRS_S_K_AXE",
	"SRS_S_K_MACHATE",
	"SRS_S_K_KNIFE",
	"SRS_S_K_SAW",
	"SRS_S_K_PITCHFORK",
	"SRS_S_K_SHOVEL",
	"SRS_S_K_GOLF",
	"SRS_S_K_GUITAR",
	"SRS_S_K_TONFA",
	"SRS_S_K_BASEBALL",
	"SRS_S_K_CRICKET",
	"SRS_S_K_PAN",
	"SRS_S_K_CROWBAR",
	"SRS_S_K_PIPE",
	"SRS_S_K_MOLO",
	"SRS_S_K_NONE",
	"SRS_S_SHOT",
	"SRS_S_HIT",
	"SRS_S_DMG",
	"SRS_S_PILLS",
	"SRS_S_ADRENALINE",
	"SRS_S_MEDKIT",
	"SRS_S_HEALED",
	"SRS_S_SELF_HEALED",
	"SRS_S_HEAL",
	"SRS_S_DEFIBRILLATE",
	"SRS_S_DEFIBRILLATED",
	"SRS_S_TH_MOLO",
	"SRS_S_TH_PIPE",
	"SRS_S_TH_VOMITJAR",
	"SRS_S_RESCUE",
	"SRS_S_RESCUED",
	"SRS_S_REVIVE",
	"SRS_S_REVIVED",
	"SRS_S_INCAPACITATED",
	"SRS_S_PROTECTED",
	"SRS_S_PROTECT",
	"SRS_S_DEATH",
	"SRS_S_TEAMKILL",
	"SRS_S_J_RIDE",
	"SRS_S_C_CARRY",
	"SRS_S_C_PUMMEL",
	"SRS_S_SK_POUNCE",
	"SRS_S_H_PUNCHED",
	"SRS_S_ST_DMG",
	"SRS_S_B_NOW_IT",
	"SRS_S_HURT",
	"SRS_I_J_RIDE",
	"SRS_I_C_CARRY",
	"SRS_I_C_PUMMEL",
	"SRS_I_SK_POUNCE",
	"SRS_I_H_PUNCHED",
	"SRS_I_ST_DMG",
	"SRS_I_B_NOW_IT",
	"SRS_I_J_RIDE_HIT",
	"SRS_I_C_CARRY_HIT",
	"SRS_I_C_PUMMEL_HIT",
	"SRS_I_SK_POUNCE_HIT",
	"SRS_I_H_PUNCHED_HIT",
	"SRS_I_ST_DMG_HIT",
	"SRS_I_B_NOW_IT_HIT",
	"SRS_I_T_DMG_STONE",
	"SRS_I_T_DMG_CROW",
	"SRS_I_T_DMG_CAR",
	"SRS_I_HURT",
	"SRS_I_DMG",
	"SRS_I_KILL",
	"SRS_I_INCAPACITATE",
	"SRS_I_DEATH",
	"SRS_H_MX_CB",
}

stock const int g_iSRSWeaponCodes[] = 
{
	SRS_S_K_SMG,
	SRS_S_K_SILENCED,
	SRS_S_K_MP5,
	SRS_S_K_M16,
	SRS_S_K_DESERT,
	SRS_S_K_AK47,
	SRS_S_K_SG552,
	SRS_S_K_M60,
	SRS_S_K_HUNTING,
	SRS_S_K_MILITARY,
	SRS_S_K_AWP,
	SRS_S_K_SCOUT,
	SRS_S_K_PUMP,
	SRS_S_K_CHROME,
	SRS_S_K_AUTO,
	SRS_S_K_SPAS,
	SRS_S_K_PISTOL,
	SRS_S_K_MAGNUM,
	SRS_S_K_GL,
	SRS_S_K_KATANA,
	SRS_S_K_AXE,
	SRS_S_K_MACHATE,
	SRS_S_K_KNIFE,
	SRS_S_K_SAW,
	SRS_S_K_PITCHFORK,
	SRS_S_K_SHOVEL,
	SRS_S_K_GOLF,
	SRS_S_K_GUITAR,
	SRS_S_K_TONFA,
	SRS_S_K_BASEBALL,
	SRS_S_K_CRICKET,
	SRS_S_K_PAN,
	SRS_S_K_CROWBAR,
	SRS_S_K_PIPE,
	SRS_S_K_MOLO,
	SRS_S_K_NONE,
	SRS_S_K_PISTOL,
	SRS_S_K_NONE,
	SRS_S_K_MOLO,
	SRS_S_K_MOLO,
	SRS_S_K_GL,
}

enum SRS_DBA
{
	DBA_CREATE,
	DBA_DROP,DBA_ALTER,
	DBA_TOP10,
	DBA_LOAD,
	DBA_SAVE,
	DBA_RANK,
	DBA_INSERT,
}

enum struct Combo
{
	int iCount;
	float fTime;
	float fPercentage;
	bool bEff;
	bool bSound;
}

enum
{
	ET_DMG		 = 0, // Extend the damage statistic 
	ET_KILL 	 = 1, // Extend the damage statistic 
	ET_DATE		 = 2,
	ET_HEALTH	 = 3,
	ET_USED		 = 4,
	ET_HELP		 = 5,
	ET_HURT		 = 6,
	ET_OPTIONS 	 = 7,
	ET_SIZE 	 = 8,
}

enum 
{
	PG_PANEL	= 0,
	PG_TOP10	= 1,
	PG_MVP		= 2,
	PG_SIZE		= 3
}

enum
{
	PT_ME		= 0,
	PT_TOP10	= 1,
	PT_MVP		= 2,
	PT_SIZE		= 3,
}

enum struct Player
{
	int id;
	int rank[SRS_TYPE_SIZE];
	int iPanelSRSType;
	int iPanelTarget;
	int iPanelPage[PG_SIZE];

	int iPanelType;
	bool bPanel;
	bool bFired;
	bool bET[ET_SIZE];
	int bAutoOpen;
	bool bMVPSelecting;
	// bool bTag;

	char tag[6];
	char name[MAX_NAME_LENGTH];
	char steamId[32];
	char sCreatedDate[64];
	char sUpdatedDate[64];

	float fPlayedTime[SRS_TYPE_SIZE];
	float fScore[SRS_TYPE_SIZE];
	float fPanelRefreshTime;
	float fLastScore;
	float fExScore;
	float fMaxScore;

	Handle tJoin;
	Handle tTag;

	Weapon weapon;
	Combo combo;
}


//原RPG插件
//常规设定
#define TEAM_SPECTATORS 1		//Team数值
#define TEAM_SURVIVORS 2		//Team数值
#define TEAM_INFECTED 3		//Team数值
#define IsValidClient(%1)		(1 <= %1 <= MaxClients && IsClientInGame(%1))    //定义客户端是否在游戏中
#define IsValidAliveClient(%1)	(1 <= %1 <= MaxClients && IsClientInGame(%1) && IsPlayerAlive(%1))   //定义客户端是否在游戏中并且扮演
//购买武器
#define ARMS 			1	//武器
#define WEAPON			2	//近战
#define PROPS 			3	//道具
#define	PISTOL			10	//手枪
#define	MAGNUM			11	//马格南手枪
#define	SMG				12	//冲锋枪
#define	SMGSILENCED		13	//消声冲锋枪
#define	AddFullCount		14	//满属性体验卡
#define PUMPSHOTGUN1	15	//老式单发霰弹
#define PUMPSHOTGUN2	16	//新式单发霰弹
#define	AUTOSHOTGUN1	17	//老式连发霰弹
#define	AUTOSHOTGUN2	18	//新式连发霰弹
#define HUNTING1		19	//猎枪
#define	HUNTING2		20	//G3SG1狙击枪
#define M16				23  //M16
#define	AK47			24   //AK47
#define	SCAR			25	//三连发
#define	AWP			26	//AWP
#define	grenadelauncher			27	//榴弹
#define	sniperscout			28	//AWP
#define	m60			29	//m60
//补给物品
#define	ADRENALINE		50	//肾上腺素
#define	PAINPILLS		51	//药丸
#define	FIRSTAIDKIT		52	//医疗包
#define	GASCAN		53	//油桶
#define	DEFIBRILLATOR  54  //defibrillator电击器

#define colored	1
#define simple	2

new BuyCount[MAXPLAYERS+1];




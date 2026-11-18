#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_NAME		"[L4D2] HUD Server Info (No VScript)"
#define PLUGIN_AUTHOR	"Kimi"
#define PLUGIN_DESC		"Server logo, progress %, tank % and hostname on the scripted HUD, without any .nut file."
#define PLUGIN_VERSION	"1.4.0"
#define PLUGIN_URL		""

// ---------------------------------------------------------------------------
// HUD slots (same as EMS Appendix: HUD)
// IMPORTANT: only slots 0-3 are used, because older SourceMod versions
// (1.10 and earlier, issue #1386) cannot write m_szScriptedHUDStringSet
// elements directly - the fallback path writes a 512 byte buffer covering
// exactly slots 0-3. Positions are overridden with HUDPlace anyway.
// ---------------------------------------------------------------------------
#define SLOT_LOGO		0	// HUD_LEFT_TOP
#define SLOT_HOSTNAME	1	// HUD_LEFT_BOT
#define SLOT_PROGRESS	2	// HUD_MID_TOP
#define SLOT_TANK		3	// HUD_MID_BOT
#define NUM_LINES		4
#define MAX_SIZE_HUD	15

// ---------------------------------------------------------------------------
// HUD flags (same values as the .nut version)
// ---------------------------------------------------------------------------
#define HUD_FLAG_BLINK			(1<<3)
#define HUD_FLAG_NOBG			(1<<6)
#define HUD_FLAG_ALIGN_LEFT		(1<<8)
#define HUD_FLAG_ALIGN_CENTER	(1<<9)
#define HUD_FLAG_ALIGN_RIGHT	(3<<8)
#define HUD_FLAG_TEAM_SURVIVORS	(1<<10)
#define HUD_FLAG_TEAM_INFECTED	(1<<11)
#define HUD_FLAG_TEXT			(1<<13)	// must be set or the text won't draw
#define HUD_FLAG_NOTVISIBLE		(1<<14)

// string write methods
#define METHOD_UNKNOWN	0
#define METHOD_ELEMENT	1	// SM 1.11+ : GameRules_SetPropString supports element
#define METHOD_PADDING	2	// any SM  : one 512 byte write covering slots 0-3

ConVar
	g_cvEnable,
	g_cvText,
	g_cvX,
	g_cvY,
	g_cvW,
	g_cvH,
	g_cvAlign,
	g_cvBlink,
	g_cvTeam,
	g_cvHostEnable,
	g_cvHostX,
	g_cvHostY,
	g_cvHostW,
	g_cvHostH,
	g_cvProgEnable,
	g_cvProgX,
	g_cvProgY,
	g_cvProgW,
	g_cvProgH,
	g_cvTankEnable,
	g_cvTankX,
	g_cvTankY,
	g_cvTankW,
	g_cvTankH,
	g_cvWitchEnable,
	g_cvDebug,
	g_cVsBossBuff,
	g_cHostname;

char
	g_sText[128],
	g_sLineText[NUM_LINES][128];

float
	g_fX,
	g_fY,
	g_fW,
	g_fH,
	g_fHostX,
	g_fHostY,
	g_fHostW,
	g_fHostH,
	g_fProgX,
	g_fProgY,
	g_fProgW,
	g_fProgH,
	g_fTankX,
	g_fTankY,
	g_fTankW,
	g_fTankH,
	g_fVsBossBuff,
	g_fTankPct,
	g_fWitchPct;

int
	g_iAlign,
	g_iTeam,
	g_iStringMethod;

bool
	g_bBlink,
	g_bEnabled,
	g_bHostEnable,
	g_bProgEnable,
	g_bTankEnable,
	g_bWitchEnable,
	g_bDebug,
	g_bLateLoad;

Handle
	g_hTimer;

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESC,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart() {
	CreateConVar("l4d2_hud_logo_version", PLUGIN_VERSION, "HUD Server Info plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	// ---- server logo ----
	g_cvEnable	= CreateConVar("l4d2_hud_logo_enable",	"1",	"Enable/Disable the plugin. (0 = OFF, 1 = ON)", _, true, 0.0, true, 1.0);
	g_cvText	= CreateConVar("l4d2_hud_logo_text",		"Your Text/Logo", "The text you want to display in the HUD.");
	g_cvX		= CreateConVar("l4d2_hud_logo_x",		"0.8",	"Logo X (horizontal) position. (0.0 - 1.0, screen relative)", _, true, -1.0, true, 1.0);
	g_cvY		= CreateConVar("l4d2_hud_logo_y",		"0.04",	"Logo Y (vertical) position. (0.0 - 1.0, screen relative)", _, true, -1.0, true, 1.0);
	g_cvW		= CreateConVar("l4d2_hud_logo_width",	"0.5",	"Logo text area width. Increase it if your long text is cut with \"...\"", _, true, 0.0, true, 2.0);
	g_cvH		= CreateConVar("l4d2_hud_logo_height",	"0.1",	"Logo text area height.", _, true, 0.0, true, 2.0);
	g_cvAlign	= CreateConVar("l4d2_hud_logo_align",	"2",	"Logo horizontal alignment. (1 = LEFT, 2 = CENTER, 3 = RIGHT)", _, true, 1.0, true, 3.0);
	g_cvBlink	= CreateConVar("l4d2_hud_logo_blink",	"0",	"Makes the logo text blink from white to red. (0 = OFF, 1 = ON)", _, true, 0.0, true, 1.0);
	g_cvTeam	= CreateConVar("l4d2_hud_logo_team",	"0",	"Which team should see the HUD. (0 = ALL, 1 = SURVIVORS, 2 = INFECTED)", _, true, 0.0, true, 2.0);

	// ---- server name ----
	g_cvHostEnable	= CreateConVar("l4d2_hud_servername_enable",	"1",	"Display the server name (hostname). (0 = OFF, 1 = ON)", _, true, 0.0, true, 1.0);
	g_cvHostX		= CreateConVar("l4d2_hud_servername_x",		"0.7",	"Server name X position.", _, true, -1.0, true, 1.0);
	g_cvHostY		= CreateConVar("l4d2_hud_servername_y",		"0.0","Server name Y position.", _, true, -1.0, true, 1.0);
	g_cvHostW		= CreateConVar("l4d2_hud_servername_width",	"0.5",	"Server name text area width.", _, true, 0.0, true, 2.0);
	g_cvHostH		= CreateConVar("l4d2_hud_servername_height",	"0.03",	"Server name text area height.", _, true, 0.0, true, 2.0);

	// ---- map progress % ----
	g_cvProgEnable	= CreateConVar("l4d2_hud_progress_enable",	"1",	"Display the map progress percentage (furthest survivor). (0 = OFF, 1 = ON)", _, true, 0.0, true, 1.0);
	g_cvProgX		= CreateConVar("l4d2_hud_progress_x",		"0.2",	"Progress X position.", _, true, -1.0, true, 1.0);
	g_cvProgY		= CreateConVar("l4d2_hud_progress_y",		"0.00",	"Progress Y position.", _, true, -1.0, true, 1.0);
	g_cvProgW		= CreateConVar("l4d2_hud_progress_width",	"1.0",	"Progress text area width.", _, true, 0.0, true, 2.0);
	g_cvProgH		= CreateConVar("l4d2_hud_progress_height",	"0.03",	"Progress text area height.", _, true, 0.0, true, 2.0);

	// ---- tank % ----
	g_cvTankEnable	= CreateConVar("l4d2_hud_tank_enable",	"1",	"Display the tank flow percentage (versus/realism versus). Hidden in coop where no flow is set. (0 = OFF, 1 = ON)", _, true, 0.0, true, 1.0);
	g_cvTankX		= CreateConVar("l4d2_hud_tank_x",		"0.3",	"Tank X position.", _, true, -1.0, true, 1.0);
	g_cvTankY		= CreateConVar("l4d2_hud_tank_y",		"0.0",	"Tank Y position.", _, true, -1.0, true, 1.0);
	g_cvTankW		= CreateConVar("l4d2_hud_tank_width",	"1.0",	"Tank text area width.", _, true, 0.0, true, 2.0);
	g_cvTankH		= CreateConVar("l4d2_hud_tank_height",	"0.03",	"Tank text area height.", _, true, 0.0, true, 2.0);

	g_cvTankH	= CreateConVar("l4d2_hud_tank_height",	"0.03",	"Tank text area height.", _, true, 0.0, true, 2.0);
	g_cvWitchEnable	= CreateConVar("l4d2_hud_witch_enable",	"1",	"Display the witch flow percentage on the same line as the tank. (0 = OFF, 1 = ON)", _, true, 0.0, true, 1.0);
	g_cvDebug	= CreateConVar("l4d2_hud_debug",	"0",	"Print the HUD line contents to the server console every second. (0 = OFF, 1 = ON)", _, true, 0.0, true, 1.0);


	g_cvEnable.AddChangeHook(OnCvarChanged);
	g_cvText.AddChangeHook(OnCvarChanged);
	g_cvX.AddChangeHook(OnCvarChanged);
	g_cvY.AddChangeHook(OnCvarChanged);
	g_cvW.AddChangeHook(OnCvarChanged);
	g_cvH.AddChangeHook(OnCvarChanged);
	g_cvAlign.AddChangeHook(OnCvarChanged);
	g_cvBlink.AddChangeHook(OnCvarChanged);
	g_cvTeam.AddChangeHook(OnCvarChanged);
	g_cvHostEnable.AddChangeHook(OnCvarChanged);
	g_cvHostX.AddChangeHook(OnCvarChanged);
	g_cvHostY.AddChangeHook(OnCvarChanged);
	g_cvHostW.AddChangeHook(OnCvarChanged);
	g_cvHostH.AddChangeHook(OnCvarChanged);
	g_cvProgEnable.AddChangeHook(OnCvarChanged);
	g_cvProgX.AddChangeHook(OnCvarChanged);
	g_cvProgY.AddChangeHook(OnCvarChanged);
	g_cvProgW.AddChangeHook(OnCvarChanged);
	g_cvProgH.AddChangeHook(OnCvarChanged);
	g_cvTankEnable.AddChangeHook(OnCvarChanged);
	g_cvTankX.AddChangeHook(OnCvarChanged);
	g_cvTankY.AddChangeHook(OnCvarChanged);
	g_cvTankW.AddChangeHook(OnCvarChanged);
	g_cvTankH.AddChangeHook(OnCvarChanged);
	g_cvWitchEnable.AddChangeHook(OnCvarChanged);
	g_cvDebug.AddChangeHook(OnCvarChanged);

	g_cVsBossBuff = FindConVar("versus_boss_buffer");
	g_cVsBossBuff.AddChangeHook(OnCvarChanged);
	g_cHostname = FindConVar("hostname");

	HookEvent("round_end",	Event_RoundEnd,	EventHookMode_PostNoCopy);
	HookEvent("round_start",	Event_RoundStart,	EventHookMode_PostNoCopy);
}

public void OnConfigsExecuted() {
	GetCvars();

	if (g_bLateLoad)
		StartTimer();
}

void OnCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars();
	// re-apply instantly so changes show without restarting the map
	TriggerUpdate();
}

void GetCvars() {
	g_bEnabled		= g_cvEnable.BoolValue;
	g_cvText.GetString(g_sText, sizeof g_sText);
	g_fX			= g_cvX.FloatValue;
	g_fY			= g_cvY.FloatValue;
	g_fW			= g_cvW.FloatValue;
	g_fH			= g_cvH.FloatValue;
	g_iAlign		= g_cvAlign.IntValue;
	g_bBlink		= g_cvBlink.BoolValue;
	g_iTeam			= g_cvTeam.IntValue;
	g_bHostEnable	= g_cvHostEnable.BoolValue;
	g_fHostX		= g_cvHostX.FloatValue;
	g_fHostY		= g_cvHostY.FloatValue;
	g_fHostW		= g_cvHostW.FloatValue;
	g_fHostH		= g_cvHostH.FloatValue;
	g_bProgEnable	= g_cvProgEnable.BoolValue;
	g_fProgX		= g_cvProgX.FloatValue;
	g_fProgY		= g_cvProgY.FloatValue;
	g_fProgW		= g_cvProgW.FloatValue;
	g_fProgH		= g_cvProgH.FloatValue;
	g_bTankEnable	= g_cvTankEnable.BoolValue;
	g_fTankX		= g_cvTankX.FloatValue;
	g_fTankY		= g_cvTankY.FloatValue;
	g_fTankW		= g_cvTankW.FloatValue;
	g_fTankH		= g_cvTankH.FloatValue;
	g_fVsBossBuff	= g_cVsBossBuff.FloatValue;
	g_bWitchEnable	= g_cvWitchEnable.BoolValue;
	g_bDebug		= g_cvDebug.BoolValue;
}

public void OnMapStart() {
	// Forces the engine to keep updating the scripted HUD every frame
	// (normally only mutations/scripted modes do this), works in coop/versus/etc.
	EnableHUD();

	g_iStringMethod = METHOD_UNKNOWN;
	g_fTankPct = -1.0;
	g_fWitchPct = -1.0;
	StartTimer();
}

public void OnMapEnd() {
	StopTimer();
	RemoveHUD(SLOT_LOGO);
	RemoveHUD(SLOT_HOSTNAME);
	RemoveHUD(SLOT_PROGRESS);
	RemoveHUD(SLOT_TANK);
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	StopTimer();
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	g_fTankPct = -1.0;
	g_fWitchPct = -1.0;
	StartTimer();
}

void StartTimer() {
	StopTimer();
	g_hTimer = CreateTimer(1.0, tmrUpdateHUD, _, TIMER_REPEAT);
	TriggerUpdate();
}

void StopTimer() {
	delete g_hTimer;
}

void TriggerUpdate() {
	CreateTimer(0.1, tmrUpdateHUD);
}

Action tmrUpdateHUD(Handle timer) {
	if (!g_bEnabled)
		return Plugin_Continue;

	// figure out once per map how scripted HUD strings can be written
	if (g_iStringMethod == METHOD_UNKNOWN) {
		DetectStringMethod();
		PrintToServer("[l4d2_hud_logo] scripted HUD string method: %s",
			g_iStringMethod == METHOD_ELEMENT ? "element (SM 1.11+)" : "512-byte padding (old SM workaround)");
	}

	// base flags for the info lines
	int flags = HUD_FLAG_NOBG | HUD_FLAG_TEXT | HUD_FLAG_ALIGN_LEFT;

	if (g_bBlink)
		flags |= HUD_FLAG_BLINK;

	if (g_iTeam == 1)
		flags |= HUD_FLAG_TEAM_SURVIVORS;
	else if (g_iTeam == 2)
		flags |= HUD_FLAG_TEAM_INFECTED;

	// gather all four line texts first (padding method writes them in one go)
	bool showLogo = g_sText[0] != '\0';
	strcopy(g_sLineText[SLOT_LOGO], 128, showLogo ? g_sText : "");

	bool showHost = false;
	if (g_bHostEnable) {
		static char hostname[128];
		g_cHostname.GetString(hostname, sizeof hostname);
		if (hostname[0]) {
			Format(g_sLineText[SLOT_HOSTNAME], 128, "%s", hostname);
			showHost = true;
		}
	}
	if (!showHost)
		g_sLineText[SLOT_HOSTNAME][0] = '\0';

	// ---- combined line: 路程 %  Tank: x%  Witch: y% (single slot) ----
	static char lineBuf[128];
	lineBuf[0] = '\0';
	int len = 0;

	if (g_bProgEnable) {
		float maxFlow = L4D2Direct_GetMapMaxFlowDistance();
		float flow = 0.0;
		int client = L4D_GetHighestFlowSurvivor();
		if (client > 0 && IsClientInGame(client))
			flow = L4D2Direct_GetFlowDistance(client);
		if (flow <= 0.0)
			flow = L4D2_GetFurthestSurvivorFlow();

		if (maxFlow > 0.0)
			// show 0% early in the round instead of hiding the line
			len = Format(lineBuf, sizeof lineBuf, "路程: %d%%    ", flow > 0.0 ? RoundToCeil(flow / maxFlow * 100.0) : 0);
		else
			// nav flow unavailable (left4dhooks gamedata mismatch?) - keep the line visible
			len = strcopy(lineBuf, sizeof lineBuf, "路程: --    ");
	}

	// tank + witch: refresh the cached percentage while the engine still reports
	// a flow for this round; once the boss has spawned the natives stop reporting
	// it, so we keep the last value until the next round
	if (g_bTankEnable || g_bWitchEnable) {
		float maxFlow = L4D2Direct_GetMapMaxFlowDistance();
		int round = GameRules_GetProp("m_bInSecondHalfOfRound");

		if (g_bTankEnable && maxFlow > 0.0 && L4D2Direct_GetVSTankToSpawnThisRound(round)) {
			float tankFlow = L4D2Direct_GetVSTankFlowPercent(round) * 100.0;
			if (tankFlow > 0.0) {
				// convert the versus boss buffer distance into a percentage,
				// same adjustment the survivor team sees on the versus HUD
				tankFlow -= g_fVsBossBuff / maxFlow * 100.0;
				g_fTankPct = tankFlow < 0.0 ? 0.0 : tankFlow;
			}
		}

		if (g_bWitchEnable && maxFlow > 0.0 && L4D2Direct_GetVSWitchToSpawnThisRound(round)) {
			float witchFlow = L4D2Direct_GetVSWitchFlowPercent(round) * 100.0;
			if (witchFlow > 0.0) {
				witchFlow -= g_fVsBossBuff / maxFlow * 100.0;
				g_fWitchPct = witchFlow < 0.0 ? 0.0 : witchFlow;
			}
		}

		if (g_bTankEnable && g_fTankPct >= 0.0)
			len += Format(lineBuf[len], sizeof lineBuf - len, "%sTank: %d%%    ", len ? "  " : "", RoundToCeil(g_fTankPct));

		if (g_bWitchEnable && g_fWitchPct >= 0.0)
			len += Format(lineBuf[len], sizeof lineBuf - len, "%sWitch: %d%%    ", len ? "  " : "", RoundToCeil(g_fWitchPct));
	}

	bool showProg = false;
	if (lineBuf[0]) {
		strcopy(g_sLineText[SLOT_PROGRESS], 128, lineBuf);
		showProg = true;
	}
	else
		g_sLineText[SLOT_PROGRESS][0] = '\0';

	// tank/witch now live on the combined line, slot 3 is unused
	RemoveHUD(SLOT_TANK);
	g_sLineText[SLOT_TANK][0] = '\0';

	// ---- apply flags / positions ----
	if (showLogo) {
		int logoFlags = HUD_FLAG_NOBG | HUD_FLAG_TEXT;
		switch (g_iAlign) {
			case 1: logoFlags |= HUD_FLAG_ALIGN_LEFT;
			case 3: logoFlags |= HUD_FLAG_ALIGN_RIGHT;
			default: logoFlags |= HUD_FLAG_ALIGN_CENTER;
		}
		if (g_bBlink)
			logoFlags |= HUD_FLAG_BLINK;
		if (g_iTeam == 1)
			logoFlags |= HUD_FLAG_TEAM_SURVIVORS;
		else if (g_iTeam == 2)
			logoFlags |= HUD_FLAG_TEAM_INFECTED;

		HUDSetFlags(SLOT_LOGO, logoFlags);
		HUDPlace(SLOT_LOGO, g_fX, g_fY, g_fW, g_fH);
	}
	else
		RemoveHUD(SLOT_LOGO);

	if (showHost) {
		HUDSetFlags(SLOT_HOSTNAME, flags);
		HUDPlace(SLOT_HOSTNAME, g_fHostX, g_fHostY, g_fHostW, g_fHostH);
	}
	else
		RemoveHUD(SLOT_HOSTNAME);

	if (showProg) {
		HUDSetFlags(SLOT_PROGRESS, flags);
		HUDPlace(SLOT_PROGRESS, g_fProgX, g_fProgY, g_fProgW, g_fProgH);
	}
	else
		RemoveHUD(SLOT_PROGRESS);

	// ---- write the strings ----
	for (int i = 0; i < NUM_LINES; i++)
		HUDSetText(i, g_sLineText[i]);

	if (g_bDebug)
		PrintToServer("[l4d2_hud_logo] method=%d | logo=[%s] | host=[%s] | prog=[%s] | tank=[%s]",
			g_iStringMethod, g_sLineText[SLOT_LOGO], g_sLineText[SLOT_HOSTNAME],
			g_sLineText[SLOT_PROGRESS], g_sLineText[SLOT_TANK]);

	return Plugin_Continue;
}

/**
 * Detects whether GameRules_SetPropString supports the element parameter
 * (SourceMod 1.11+, issue #1386) by writing a probe string to slot 3 and
 * reading it back. On older SM the element is silently ignored and slot 0
 * is returned instead, which is detected here.
 */
void DetectStringMethod() {
	static const char probe[] = "__l4d2_hud_probe__";
	char check[64];

	GameRules_SetPropString("m_szScriptedHUDStringSet", probe, true, SLOT_TANK);
	GameRules_GetPropString("m_szScriptedHUDStringSet", check, sizeof check, SLOT_TANK);

	if (strcmp(check, probe) == 0) {
		g_iStringMethod = METHOD_ELEMENT;
		GameRules_SetPropString("m_szScriptedHUDStringSet", "", true, SLOT_TANK);
	}
	else
		g_iStringMethod = METHOD_PADDING;
}

/**
 * Writes the text of one HUD slot.
 * METHOD_ELEMENT : direct element write (SM 1.11+).
 * METHOD_PADDING : builds one 512 byte buffer covering slots 0-3
 *                  (4 x 128 bytes, each slot padded with spaces) and writes
 *                  it with a single call. Works on any SourceMod version.
 */
void HUDSetText(int slot, const char[] text) {
	if (g_iStringMethod == METHOD_ELEMENT) {
		GameRules_SetPropString("m_szScriptedHUDStringSet", text, true, slot);
		return;
	}

	if (g_iStringMethod != METHOD_PADDING)
		return;

	static char combined[513];
	for (int i = 0; i < 512; i++)
		combined[i] = ' ';
	combined[512] = '\0';

	for (int i = 0; i < NUM_LINES; i++) {
		if (g_sLineText[i][0] == '\0')
			continue;
		strcopy(combined[i * 128], 128, g_sLineText[i]);
	}

	GameRules_SetPropString("m_szScriptedHUDStringSet", combined, true, 0);
}

// ---------------------------------------------------------------------------
// Core: these mirror the CScriptHud functions, but write straight into the
// CTerrorGameRules sendprops instead of calling VScript. No .nut needed.
// ---------------------------------------------------------------------------

/**
 * Enables scripted HUD drawing by forcing m_bChallengeModeActive to true,
 * which makes the engine run the CScriptHud update loop every frame.
 */
void EnableHUD() {
	GameRules_SetProp("m_bChallengeModeActive", true, _, _, true);
}

/**
 * Sets the flags of one HUD slot.
 */
void HUDSetFlags(int slot, int flags) {
	GameRules_SetProp("m_iScriptedHUDFlags", flags | HUD_FLAG_TEXT, _, slot, true);
}

/**
 * CScriptHud::HUDSetPosition (HUDPlace) equivalent.
 */
void HUDPlace(int slot, float x, float y, float width, float height) {
	GameRules_SetPropFloat("m_fScriptedHUDPosX", x, slot, true);
	GameRules_SetPropFloat("m_fScriptedHUDPosY", y, slot, true);
	GameRules_SetPropFloat("m_fScriptedHUDWidth", width, slot, true);
	GameRules_SetPropFloat("m_fScriptedHUDHeight", height, slot, true);
}

/**
 * CTerrorGameRules::ResetScriptedHUD equivalent - clears one slot.
 */
void RemoveHUD(int slot) {
	GameRules_SetProp("m_iScriptedHUDInts", 0, _, slot, true);
	GameRules_SetPropFloat("m_fScriptedHUDFloats", 0.0, slot, true);
	GameRules_SetProp("m_iScriptedHUDFlags", HUD_FLAG_NOTVISIBLE, _, slot, true);
	GameRules_SetPropFloat("m_fScriptedHUDPosX", 0.0, slot, true);
	GameRules_SetPropFloat("m_fScriptedHUDPosY", 0.0, slot, true);
	GameRules_SetPropFloat("m_fScriptedHUDWidth", 0.0, slot, true);
	GameRules_SetPropFloat("m_fScriptedHUDHeight", 0.0, slot, true);
}

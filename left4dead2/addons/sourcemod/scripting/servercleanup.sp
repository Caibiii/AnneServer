/**
 * ==================================================================================
 *  Server Clean Up Change Log
 * ==================================================================================
 * 
 * 1.0
 * - Initial release.
 *
 * 1.1
 * - Added full translation support to convars.
 * - Added new cvar to control what type of logs to delete (normal logs, normal + 
 *   error logs, all logs).
 * - Added a command to manually execute clean up "sm_srvcln_now" (set to root only).
 * - Added a convar to control whether server clean up automatically cleans up on map
 *   start or not (enabled by default).
 * - Detection code totally rewritten.
 *
 * 1.1.1
 * - Fixed a small memory leak.
 *
 * 1.1.2
 * - Added support to clean up sprays.
 *
 * 1.1.3
 * - Added cvar "sm_srvcln_demos_path" so users can point to an optional location to
 *   their demo files.
 * - Added proper directory detection.
 * - Fixed translation errors.
 *
 * 1.1.4
 * - Fixed issue if you installed the plugin on a fresh server it would complain
 *   about the downloads directory being missing.
 *
 * 1.1.5
 * - Removed warnings about directories, only confuses users.
 *
 * 1.1.6
 * - Fixed return on "clean now" command.
 * - Removed an old check for the spray folder.
 *
 * 1.1.7
 * - Added WarMod support.
 * ==================================================================================
 */
 
#include <sourcemod>
#pragma semicolon 1
#define PLUGIN_VERSION "1.1.7"

#define DEBUG 0

const LOG = 0;
const SML = 1;
const DEM = 2;
const SPR = 3;
const MAX = 4;

new Handle:cvar_type[MAX];
new Handle:cvar_time[MAX];
new Handle:cvar_arch;
new Handle:cvar_enable;
new Handle:cvar_logtype;
new Handle:cvar_demopath;
new Handle:g_warpath;
new Handle:g_logsdir;

new bool:b_useWarMod;

#if DEBUG
new String:LogFilePath[PLATFORM_MAX_PATH];
#endif

public Plugin:myinfo = 
{
	name = "Server Clean Up",
	author = "Jamster",
	description = "Cleans up logs and demo files automatically",
	version = PLUGIN_VERSION,
	url = "http://www.sourcemod.net/"
};

public OnPluginStart()
{
	LoadTranslations("servercleanup.phrases");
	decl String:desc[256];
	
	Format(desc, sizeof(desc), "%t", "srvcln_version");
	CreateConVar("sm_srvcln_version", PLUGIN_VERSION, desc, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	Format(desc, sizeof(desc), "%t", "srvcln_enable");
	cvar_enable = CreateConVar("sm_srvcln_enable", "1", desc, FCVAR_PLUGIN, true, 0.0, true, 1.0);
	
	Format(desc, sizeof(desc), "%t", "srvcln_logs");
	cvar_type[LOG] = CreateConVar("sm_srvcln_logs", "0", desc, FCVAR_PLUGIN, true, 0.0, true, 1.0);
	
	Format(desc, sizeof(desc), "%t", "srvcln_smlogs");
	cvar_type[SML] = CreateConVar("sm_srvcln_smlogs", "0", desc, FCVAR_PLUGIN, true, 0.0, true, 1.0);
	
	Format(desc, sizeof(desc), "%t", "srvcln_demos");
	cvar_type[DEM] = CreateConVar("sm_srvcln_demos", "0", desc, FCVAR_PLUGIN, true, 0.0, true, 1.0);
	
	Format(desc, sizeof(desc), "%t", "srvcln_demos_path");
	cvar_demopath = CreateConVar("sm_srvcln_demos_path", "", desc, FCVAR_PLUGIN);
	
	Format(desc, sizeof(desc), "%t", "srvcln_sprays");
	cvar_type[SPR] = CreateConVar("sm_srvcln_sprays", "0", desc, FCVAR_PLUGIN, true, 0.0, true, 1.0);
	
	Format(desc, sizeof(desc), "%t", "srvcln_demos_archives");
	cvar_arch = CreateConVar("sm_srvcln_demos_archives", "0", desc, FCVAR_PLUGIN, true, 0.0, true, 1.0);
	
	Format(desc, sizeof(desc), "%t", "srvcln_smlogs_type");
	cvar_logtype = CreateConVar("sm_srvcln_smlogs_type", "0", desc, FCVAR_PLUGIN, true, 0.0, true, 2.0);
	
	Format(desc, sizeof(desc), "%t", "srvcln_logs_time");
	cvar_time[LOG] = CreateConVar("sm_srvcln_logs_time", "168", desc, FCVAR_PLUGIN, true, 24.0);
	
	Format(desc, sizeof(desc), "%t", "srvcln_sprays_time");
	cvar_time[SPR] = CreateConVar("sm_srvcln_sprays_time", "168", desc, FCVAR_PLUGIN, true, 24.0);
	
	Format(desc, sizeof(desc), "%t", "srvcln_smlogs_time");
	cvar_time[SML] = CreateConVar("sm_srvcln_smlogs_time", "168", desc, FCVAR_PLUGIN, true, 24.0);
	
	Format(desc, sizeof(desc), "%t", "srvcln_demos_time");
	cvar_time[DEM] = CreateConVar("sm_srvcln_demos_time", "168", desc, FCVAR_PLUGIN, true, 24.0);
	
	Format(desc, sizeof(desc), "%t", "srvcln_now");
	RegAdminCmd("sm_srvcln_now", CommandCleanNow, ADMFLAG_ROOT, desc);
	
	g_logsdir = FindConVar("sv_logsdir");
	AutoExecConfig(true, "plugin.servercleanup");
}

public OnAllPluginsLoaded()
{
	g_warpath = FindConVar("wm_save_dir");
	if (g_warpath != INVALID_HANDLE)
		b_useWarMod = true;
	else
		b_useWarMod = false;
}

public OnConfigsExecuted()
{
	#if DEBUG
	BuildPath(Path_SM, LogFilePath, sizeof(LogFilePath), "logs/srvcln_debug.log");
	#endif
	
	if (GetConVarInt(cvar_enable))
	{
		for (new i; i < MAX; i++)
			if (GetConVarInt(cvar_type[i]))
				CleanServer(i);
	}
}

public Action:CommandCleanNow(client, args)
{
	ReplyToCommand(client, "%t", "Command Now Start");
	for (new i; i < MAX; i++)
		if (GetConVarInt(cvar_type[i]))
			CleanServer(i);
	ReplyToCommand(client, "%t", "Command Now End");
	LogMessage("\"%L\" %t", client, "Command Now Log");
	return Plugin_Handled;
}

CleanServer(const type)
{	
	new Time32 = GetTime() / 3600 - GetConVarInt(cvar_time[type]);
	decl String:filename[256];
	decl String:dir[PLATFORM_MAX_PATH];
	
	switch (type)
	{
		case LOG:
			GetConVarString(g_logsdir, dir, sizeof(dir));
		case SML:
			BuildPath(Path_SM, dir, sizeof(dir), "logs");
		case DEM:
			GetConVarString(cvar_demopath, dir, sizeof(dir));
		case SPR:
			Format(dir, sizeof(dir), "downloads");
	}
	
	if (b_useWarMod && type == DEM)
		GetConVarString(g_warpath, dir, sizeof(dir));
	
	if (!DirExists(dir) && strlen(dir))
	{
		filename = "\0";
		return false;
	}
	
	new Handle:h_dir = OpenDirectory(dir);
	
	#if DEBUG
	switch (type)
	{
		case LOG:
			LogToFileEx(LogFilePath, "~~ Regular logs dir files ~~");
		case SML:
			LogToFileEx(LogFilePath, "~~ SourceMod logs dir files ~~");
		case DEM:
			LogToFileEx(LogFilePath, "~~ Demo files ~~");
		case SPR:
			LogToFileEx(LogFilePath, "~~ Spray files ~~");
	}
	#endif
	
	new strLength;
	new DelArch = GetConVarInt(cvar_arch);
	new LogType = GetConVarInt(cvar_logtype);
	
	while (ReadDirEntry(h_dir, filename, sizeof(filename)))
	{
		
		if (StrEqual(filename, ".") || StrEqual(filename, ".."))
			continue;
			
		strLength = strlen(filename);
		
		if (type == LOG)
		{
			if (StrContains(filename, ".log", false) == strLength-4)
			{
					CanDelete(Time32, dir, filename, type);
					continue;
			}
		}
		else if (type == SML)
		{
			if (!LogType)
			{
				if (StrContains(filename, "l", false) == 0 && StrContains(filename, ".log", false) == strLength-4)
				{
					CanDelete(Time32, dir, filename, type);
					continue;
				}
			}
			else if (LogType == 1)
			{
				if ((StrContains(filename, "l", false) == 0 || StrContains(filename, "errors_", false) == 0) && StrContains(filename, ".log", false) == strLength-4)
				{
					CanDelete(Time32, dir, filename, type);
					continue;
				}
			}
			else if (LogType == 2 && StrContains(filename, ".log", false) == strLength-4)
			{
				CanDelete(Time32, dir, filename, type);
				continue;
			}
		}
		else if (type == DEM)
		{
			if ((StrContains(filename, "auto-", false) == 0 || b_useWarMod) && StrContains(filename, ".dem", false) == strLength-4)
			{
				CanDelete(Time32, dir, filename, type);
				continue;
			} 
			else if (((DelArch && StrContains(filename, "auto-", false) == 0) || b_useWarMod) && (StrContains(filename, ".zip", false) == strLength-4 || StrContains(filename, ".bz2", false) == strLength-4 || StrContains(filename, ".rar", false) == strLength-4 || StrContains(filename, ".7z", false) == strLength-3))
			{
				CanDelete(Time32, dir, filename, type);
				continue;
			}
		}
		else if (type == SPR)
		{
			if (StrContains(filename, ".dat", false) == strLength-4 || StrContains(filename, ".ztmp", false) == strLength-5)
			{
				CanDelete(Time32, dir, filename, type);
				continue;
			} 
		}
	}
	
	CloseHandle(h_dir);
	return true;
}

CanDelete(const Time32, const String:dir[], const String:filename[], const type)
{
	#if DEBUG
	LogToFileEx(LogFilePath, "%s", filename);
	#endif
	
	new TimeStamp;
	decl String:file[PLATFORM_MAX_PATH];
	Format(file, sizeof(file), "%s/%s", dir, filename);
	if (type == SPR)
	{
		// Sprays are done on last access due to players requesting them.
		TimeStamp = GetFileTime(file, FileTime_LastAccess);
		if (TimeStamp == -1)
		{
			TimeStamp = GetFileTime(file, FileTime_LastChange);
		}
	}
	else
	{
		TimeStamp = GetFileTime(file, FileTime_LastChange);
	}
	
	if (TimeStamp == -1)
	{
		LogError("%t", "CL Error TS", file);
	}
	
	TimeStamp /= 3600;
	if (Time32 > TimeStamp)
	{
		if (!DeleteFile(file))
		{
			LogError("%t", "CL Error Del", file);
		}
		#if DEBUG
		LogToFileEx(LogFilePath, "*deleted file*");
		#endif
	}
}
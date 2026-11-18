/**
 * server_name.sp
 *
 * 按 hostport 从 configs/hostname/hostname.txt 读取基础服务器名,
 * 并在末尾附加模式信息(默认 "[X特Y秒]"):
 *   X = l4d_infected_limit          (特感数量)
 *   Y = versus_special_respawn_interval (复活间隔秒数)
 *
 * 适用于: Left 4 Dead 2 (SourceMod 1.8+)
 */
#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

#define SN_NAME_MAX 256

ConVar    g_cvHostName;          // 引擎 hostname
ConVar    g_cvSuffixFormat;      // sn_suffix_format  后缀格式
ConVar    g_cvInfectedLimit;     // l4d_infected_limit
ConVar    g_cvRespawnInterval;   // versus_special_respawn_interval
ConVar    g_cvHostPort;          // hostport

KeyValues g_kvConfig;            // hostname.txt
char      g_sConfigPath[PLATFORM_MAX_PATH];
char      g_sOriginalName[SN_NAME_MAX];   // 插件加载前的原始 hostname,卸载时恢复

public Plugin myinfo =
{
	name        = "Server Name Manager",
	author      = "AnneHappy",
	description = "基础名 + [X特Y秒] 动态服务器名",
	version     = "1.2.0",
	url         = ""
};

public void OnPluginStart()
{
	g_cvHostName        = FindConVar("hostname");
	g_cvInfectedLimit   = FindConVar("l4d_infected_limit");
	g_cvRespawnInterval = FindConVar("versus_special_respawn_interval");
	g_cvHostPort        = FindConVar("hostport");

	g_cvSuffixFormat = CreateConVar("sn_suffix_format", "[{mode}特{min}秒]",
		"服务器名后缀格式: {mode}=特感数量, {min}=复活间隔(秒)");

	// 游戏相关 cvar 可能不存在,必须判空后再挂钩
	if (g_cvInfectedLimit != null)
		g_cvInfectedLimit.AddChangeHook(OnGameCvarChanged);
	if (g_cvRespawnInterval != null)
		g_cvRespawnInterval.AddChangeHook(OnGameCvarChanged);

	LoadConfig();

	// 记录原始 hostname 并立即应用一次
	if (g_cvHostName != null)
	{
		g_cvHostName.GetString(g_sOriginalName, sizeof(g_sOriginalName));
		if (g_sOriginalName[0] != '\0')
			UpdateServerName();
	}
}

public void OnMapStart()
{
	LoadConfig();
}

public void OnConfigsExecuted()
{
	if (g_sOriginalName[0] == '\0')
		return;

	UpdateServerName();
}

public void OnPluginEnd()
{
	// 恢复插件加载前的原始主机名
	if (g_cvHostName != null && g_sOriginalName[0] != '\0')
		g_cvHostName.SetString(g_sOriginalName);

	delete g_kvConfig;
}

/**
 * 特感数量 / 复活间隔变化时刷新服务器名
 */
public void OnGameCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	UpdateServerName();
}

/**
 * 加载 configs/hostname/hostname.txt
 */
void LoadConfig()
{
	BuildPath(Path_SM, g_sConfigPath, sizeof(g_sConfigPath), "configs/hostname/hostname.txt");
	if (!FileExists(g_sConfigPath))
		return;

	delete g_kvConfig;
	g_kvConfig = new KeyValues("AnneHappy");
	if (!g_kvConfig.ImportFromFile(g_sConfigPath))
	{
		delete g_kvConfig;
		g_kvConfig = null;
		LogError("[ServerName] 配置文件解析失败: %s", g_sConfigPath);
	}
}

/**
 * 重新组装并设置服务器名: 基础名 + 后缀
 */
void UpdateServerName()
{
	if (g_cvHostName == null)
		return;

	// 按端口从配置读取基础名
	char sBaseName[SN_NAME_MAX];
	if (g_kvConfig != null && g_cvHostPort != null)
	{
		char sPort[16];
		g_cvHostPort.GetString(sPort, sizeof(sPort));

		if (g_kvConfig.JumpToKey(sPort, false))
		{
			g_kvConfig.GetString("servername", sBaseName, sizeof(sBaseName));
			g_kvConfig.GoBack();
		}
	}

	if (sBaseName[0] == '\0')
		return;

	// 组装后缀,如 "[3特30秒]"
	char sSuffix[64];
	g_cvSuffixFormat.GetString(sSuffix, sizeof(sSuffix));

	if (g_cvInfectedLimit != null && g_cvRespawnInterval != null)
	{
		char sMode[16], sMin[16];
		g_cvInfectedLimit.GetString(sMode, sizeof(sMode));
		g_cvRespawnInterval.GetString(sMin, sizeof(sMin));

		ReplaceString(sSuffix, sizeof(sSuffix), "{mode}", sMode);
		ReplaceString(sSuffix, sizeof(sSuffix), "{min}", sMin);
	}

	char sFinalName[SN_NAME_MAX];
	Format(sFinalName, sizeof(sFinalName), "%s%s", sBaseName, sSuffix);

	g_cvHostName.SetString(sFinalName);
}

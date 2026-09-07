/* Create By 游而戏之 2023/04/06 01:14 */
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

static char ChatFile[PLATFORM_MAX_PATH];
char Country[MAXPLAYERS + 1][3];

File fileHandle;

public Plugin myinfo =
{
	name 		= "服务器|保存聊天 SaveChat",
	author 		= "citkabuto, 24の节气",
	description = "超精简",
	version 	= "2.B",
	url 		= "http://forums.alliedmods.net/showthread.php?t=117116"
}

public void OnPluginStart()	{BuildFile(ChatFile);}
public void OnMapStart()
{
	char map[128], msg[1024], time[24];

	GetCurrentMap(map, sizeof map);

	BuildFile(ChatFile); /*日期可能已经过去，因此请在此处更新日志文件名称*/

	FormatTime(time, sizeof time, "%d/%m/%Y %H:%M:%S");
	FormatEx(msg, sizeof msg, "========== [%s] 新地图开始: %s ==========", time, map);
	SaveMessage(msg);
}

public void OnClientPostAdminCheck(int client)
{
	if(IsFakeClient(client)) return;

	char msg[2048], time[24], steamid[128];

	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof steamid);

	FormatTime(time, sizeof time, "%H:%M:%S");
	FormatEx(msg, sizeof msg, "[%s] [%-19s] %40N", time, steamid, client);
	SaveMessage(msg);
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	LogChat(client, sArgs);
	return Plugin_Continue;
}
/*提取所有相关信息和格式*/
void LogChat(int client, const char[] text)
{
	char msg[2048], time[24];

	if(client == 0) 				Country[0] = "OP";	/*0-控制台消息，不获取客户国家 显示OP */
	else if(IsFakeClient(client)) 	return; 			/* 过滤AI */

	FormatTime(time, sizeof time, "%H:%M:%S");
	FormatEx(msg, sizeof(msg), "[%s] [%s] %40N 说: %s", time, Country[client], client, text);
	SaveMessage(msg);
}

void BuildFile(char []file)
{
	char date[24], log[100];

	/* 创建要使用的日志文件的名称 */
	FormatTime(date, sizeof date, "%Y%m%d");
	FormatEx(log, sizeof log, "/server/C%s.log", date);
	BuildPath(Path_SM, file, PLATFORM_MAX_PATH, log);
}

/* Log 将消息记录到文件 */
void SaveMessage(const char [] message)
{
	fileHandle = OpenFile(ChatFile, "a");
	fileHandle.WriteLine(message);
	delete fileHandle;
}
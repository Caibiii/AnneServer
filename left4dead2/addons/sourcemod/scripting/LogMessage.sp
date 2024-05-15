#include <sourcemod>

new	String:logfilepath[256];

public Plugin:myinfo = 
{
	name = "Log Message",
	author = "闲月疏云",
	description = "记录玩家所说的话",
	version = "1.0"
}

public OnPluginStart()
{
	HookEvent("player_say", OnPlayerSay);
	BuildPath(Path_SM, logfilepath, sizeof(logfilepath), "server\\PlayerMessage.log");
}

public OnPlayerSay(Handle:event, const String:name[], bool:dontBroadcast)
{
	new String:message[2048];
	GetEventString(event, "text", message, sizeof(message));
	new String:username[MAX_NAME_LENGTH];
	GetClientName(GetClientOfUserId(GetEventInt(event, "userid")), username, sizeof(username));
	LogToFile(logfilepath, "%s : %s", username, message);
}
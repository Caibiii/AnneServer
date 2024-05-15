#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#define L4D_MAXCLIENTS MaxClients
#define L4D_MAXCLIENTS_PLUS1 (L4D_MAXCLIENTS + 1)
#define L4D_MAXHUMANS_LOBBY_VERSUS 4
#define L4D_MAXHUMANS_LOBBY_OTHER 4
new Handle:cvarHostPort = INVALID_HANDLE;
new String:LobbyId[20];
new Handle:cvarUnreserve = INVALID_HANDLE;
new String:SavePath[256];
new Handle:IDSave = INVALID_HANDLE;
public OnPluginStart()
{
	IDSave = CreateKeyValues("United ID Save");
	BuildPath(Path_SM, SavePath, 255, "data/IDSave.txt");
	if (FileExists(SavePath))
	{
		FileToKeyValues(IDSave, SavePath);
	}
	else
	{
		KeyValuesToFile(IDSave, SavePath);
	}
	cvarHostPort = FindConVar("hostport");
	LoadTranslations("common.phrases");
	RegAdminCmd("sm_unreserve", Command_Unreserve, ADMFLAG_BAN, "sm_unreserve - manually force removes the lobby reservation");
	RegAdminCmd("sm_id", Command_ID, ADMFLAG_BAN, "sm_unreserve - manually force removes the lobby reservation");
	cvarUnreserve = CreateConVar("l4d_unreserve_full", "4", "多少人加入加入后取消大厅");
}
public OnMapStart()
{
	IDSave = CreateKeyValues("United ID Save");
	BuildPath(Path_SM, SavePath, 255, "data/IDSave.txt");
	FileToKeyValues(IDSave, SavePath);
}
IsServerLobbyFull()
{
	new humans = GetHumanCount();
	return humans >= L4D_MAXHUMANS_LOBBY_OTHER;
}

public OnClientPutInServer(client)
{
	if(client > 0 && IsClientConnected(client) && !IsFakeClient(client))
	{
		/*
		if(L4D_LobbyIsReserved())
		{
			L4D_GetLobbyReservation(LobbyId, 20);
			ClientSaveToFileSave();
		}
		*/
		if(GetConVarBool(cvarUnreserve) && IsServerLobbyFull())
		{
			L4D_LobbyUnreserve();
			SetConVarInt(FindConVar("sv_allow_lobby_connect_only"), 0);
		}
	}
}
/*
// 玩家离开显示离开提示，并检测服务器是否还有人，没人则自动重启服务器
public OnClientDisconnect(client)
{
	if (IsClientInGame(client) && IsFakeClient(client)) return;
	if(!IsServerLobbyFull())
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientConnected(i) && !IsFakeClient(i))
			{
				ClientSaveToFileLoad();
				//PrintToChatAll("%s",LobbyId);
				L4D_SetLobbyReservation(LobbyId);
				//SetConVarInt(FindConVar("sv_allow_lobby_connect_only"), 1);
				break;
			}
		}
	}
}
*/
public Action:Command_ID(client, args)
{
	//L4D_GetLobbyReservation(LobbyId, 20);
	ClientSaveToFileLoad();
	//PrintToChatAll("%s",LobbyId);
	L4D_SetLobbyReservation(LobbyId);
	//SetConVarInt(FindConVar("sv_allow_lobby_connect_only"), 1);
	return Plugin_Handled;
}

public Action:Command_Unreserve(client, args)
{
	L4D_LobbyUnreserve();
	SetConVarInt(FindConVar("sv_allow_lobby_connect_only"), 0);
	return Plugin_Handled;
}

stock bool:IsClientInGameHuman(client)
{
	return IsClientInGame(client) && !IsFakeClient(client);
}

stock GetHumanCount()
{
	new humans = 0;
	
	new i;
	for(i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		if(IsClientInGameHuman(i))
		{
			humans++
		}
	}
	
	return humans;
}


/* 读取存档Function */
ClientSaveToFileLoad()
{
	/* 读取玩家姓名 */
	decl String:ServerPort[128];
	GetConVarString(cvarHostPort, ServerPort, sizeof(ServerPort));
	KvJumpToKey(IDSave, ServerPort, true);
	KvGetString(IDSave,ServerPort,"SaveID", 20, LobbyId);
	KvGoBack(IDSave);
}

/* 存档Function */
ClientSaveToFileSave()
{
	decl String:ServerPort[128];
	GetConVarString(cvarHostPort, ServerPort, sizeof(ServerPort));
	KvJumpToKey(IDSave, ServerPort, true);
	KvDeleteKey(IDSave, "SaveID");
	KvSetString(IDSave, "SaveID", LobbyId);
	KvRewind(IDSave);
	KeyValuesToFile(IDSave, SavePath);
}
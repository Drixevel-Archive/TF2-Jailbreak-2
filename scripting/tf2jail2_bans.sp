//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines

//Sourcemod Includes
#include <sourcemod>
#include <clientprefs>
#include <tf2_stocks>

//External Includes
#include <sourcemod-misc>
#include <colorvariables>

//Our Includes
#include <tf2jail2/tf2jail2_bans>

#undef REQUIRE_PLUGIN
#include <tf2jail2/tf2jail2_core>
#define REQUIRE_PLUGIN

//ConVars
ConVar convar_Status;

//Globals
bool bLate;
Handle g_hCookie_WardenBan;
Handle g_hCookie_GuardBan;

//////////////////////////////////////////////////
//Info

public Plugin myinfo =
{
	name = "[TF2Jail2] Module: Bans",
	author = "Keith Warren (Sky Guardian)",
	description = "A basic bans module for TF2 Jailbreak.",
	version = "1.0.0",
	url = "https://github.com/SkyGuardian"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("tf2jail2_bans");

	CreateNative("TF2Jail2_IsWardenBanned", Native_IsWardenBanned);
	CreateNative("TF2Jail2_IsGuardBanned", Native_IsGuardBanned);
	CreateNative("TF2Jail2_BanFromWarden", Native_BanFromWarden);
	CreateNative("TF2Jail2_BanFromGuard", Native_BanFromGuard);

	bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Status = CreateConVar("sm_tf2jail2_bans_status", "1", "Status of the plugin.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	g_hCookie_WardenBan = RegClientCookie("tf2jail2_ban_warden", "Banned from Warden.", CookieAccess_Protected);
	g_hCookie_GuardBan = RegClientCookie("tf2jail2_ban_guard", "Banned from Guard.", CookieAccess_Protected);

	RegAdminCmd("sm_jailban", Command_JailBan, ADMFLAG_BAN, "Ban and unban clients from Warden and the Guards team.");

	HookEvent("player_spawn", Event_OnPlayerSpawn);

	//AddCommandListener(Listener_JoinTeam, "jointeam");
}

public void OnConfigsExecuted()
{
	if (bLate)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (AreClientCookiesCached(i))
			{
				OnClientCookiesCached(i);
			}
		}

		bLate = false;
	}
}

public void OnClientCookiesCached(int client)
{
	char sBanned[2];

	GetClientCookie(client, g_hCookie_WardenBan, sBanned, sizeof(sBanned));

	if (strlen(sBanned) == 0)
	{
		SetClientCookie(client, g_hCookie_WardenBan, "0");
	}

	GetClientCookie(client, g_hCookie_GuardBan, sBanned, sizeof(sBanned));

	if (strlen(sBanned) == 0)
	{
		SetClientCookie(client, g_hCookie_GuardBan, "0");
	}
}

public Action Listener_JoinTeam(int client, const char[] command, int args)
{
	char sBanned[2];
	GetClientCookie(client, g_hCookie_GuardBan, sBanned, sizeof(sBanned));

	if (TF2_GetClientTeam(client) > TFTeam_Spectator && StrEqual(sBanned, "1"))
	{
		TF2_ChangeClientTeam(client, TFTeam_Spectator);
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);

	if (client == 0 || client > MaxClients)
	{
		return;
	}

	char sBanned[2];
	GetClientCookie(client, g_hCookie_GuardBan, sBanned, sizeof(sBanned));

	if (StrEqual(sBanned, "1") && TF2_GetClientTeam(client) == TFTeam_Blue)
	{
		TF2_ChangeClientTeam(client, TFTeam_Red);
		CPrintToChat(client, "%s {red}ERROR: {default}You cannot spawn on the Guards team as you are banned, moving you to Prisoners team.", g_sGlobalTag);
	}
}

public void OnClientPutInServer(int client)
{
	//TF2_ChangeClientTeam(client, TFTeam_Spectator);
}

//////////////////////////////////////////////////
//Commands

public Action Command_JailBan(int client, int args)
{
	if (!GetConVarBool(convar_Status))
	{
		return Plugin_Handled;
	}

	ShowBansMenu(client);
	return Plugin_Handled;
}

//////////////////////////////////////////////////
//Stocks

void ShowBansMenu(int client)
{
	Menu menu = CreateMenu(MenuHandler_BansMenu);
	SetMenuTitle(menu, "TF2Jail 2 - Bans Menu\n \n");

	AddMenuItem(menu, "warden_ban", "Ban from Warden");
	AddMenuItem(menu, "guards_ban", "Ban from Guards\n \n");
	AddMenuItem(menu, "warden_unban", "Unban from Warden");
	AddMenuItem(menu, "guards_unban", "Unban from Guards");

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

void BanMenu(int client, bool warden, bool ban)
{
	Menu menu = CreateMenu(MenuHandler_ManageClient);
	SetMenuTitle(menu, "%s client from %s:", ban ? "Ban" : "Unban", warden ? "Warden" : "Guards");

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			char sBanned[2];
			GetClientCookie(i, warden ? g_hCookie_WardenBan : g_hCookie_GuardBan, sBanned, sizeof(sBanned));

			char sName[MAX_NAME_LENGTH];
			GetClientName(i, sName, sizeof(sName));

			char sID[32];
			IntToString(GetClientUserId(i), sID, sizeof(sID));

			AddMenuItem(menu, sID, sName, StrEqual(sBanned, ban ? "0" : "1") ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
	}

	PushMenuCell(menu, "warden", warden);
	PushMenuCell(menu, "ban", ban);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

void TF2Jail2Ban(Handle& cookie, bool status = true, int admin = -1, int target = 0, const char[] reason = "", bool announce = true)
{
	if (cookie == null)
	{
		return;
	}

	SetClientCookie(target, cookie, status ? "1" : "0");

	if (status && IsPlayerAlive(target) && TF2_GetClientTeam(target) == TFTeam_Blue)
	{
		ForcePlayerSuicide(target);
	}

	if (announce)
	{
		char sAdmin[128];

		if (admin != -1)
		{
			FormatEx(sAdmin, sizeof(sAdmin), " by {mediumslateblue}%N{default}.", admin);
		}

		CPrintToChatAll("%s {mediumslateblue}%N {default}has been %s from %s%s.", g_sGlobalTag, target, status ? "banned" : "unbanned", cookie == g_hCookie_WardenBan ? "Warden" : "Guards", sAdmin);

		if (strlen(reason) > 0)
		{
			CPrintToChatAll("%s Reason: %s", g_sGlobalTag, reason);
		}
	}
}

//////////////////////////////////////////////////
//MenuHandlers

public int MenuHandler_BansMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			GetMenuItem(menu, param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "warden_ban"))
			{
				BanMenu(param1, true, true);
			}
			else if (StrEqual(sInfo, "guards_ban"))
			{
				BanMenu(param1, false, true);
			}
			else if (StrEqual(sInfo, "warden_unban"))
			{
				BanMenu(param1, true, false);
			}
			else if (StrEqual(sInfo, "guards_unban"))
			{
				BanMenu(param1, false, false);
			}
		}

		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

public int MenuHandler_ManageClient(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32]; char sDisplay[MAX_NAME_LENGTH];
			GetMenuItem(menu, param2, sInfo, sizeof(sInfo), _, sDisplay, sizeof(sDisplay));
			int target = GetClientOfUserId(StringToInt(sInfo));

			if (target == 0)
			{
				CPrintToChat(param1, "%s {red}ERROR: {default}Client is no longer available, please try again.", g_sGlobalTag);
				return;
			}

			bool warden = view_as<bool>(GetMenuCell(menu, "warden"));
			bool ban = view_as<bool>(GetMenuCell(menu, "ban"));

			SetClientCookie(target, warden ? g_hCookie_WardenBan : g_hCookie_GuardBan, ban ? "1" : "0");
			CPrintToChat(param1, "%s You have %s the client {mediumslateblue}%N {default}from %s.", g_sGlobalTag, ban ? "banned" : "unbanned", target, warden ? "Warden" : "Guards");
			CPrintToChat(target, "%s {mediumslateblue}%N {default}has %s you from %s.", g_sGlobalTag, param1, ban ? "banned" : "unbanned", warden ? "Warden" : "Guards");
		}

		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

//////////////////////////////////////////////////
//Natives

public int Native_IsWardenBanned(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (client == 0 || client > MaxClients || IsFakeClient(client))
	{
		return false;
	}

	char sBanned[2];
	GetClientCookie(client, g_hCookie_WardenBan, sBanned, sizeof(sBanned));

	return StrEqual(sBanned, "1");
}

public int Native_IsGuardBanned(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (client == 0 || client > MaxClients || IsFakeClient(client))
	{
		return false;
	}

	char sBanned[2];
	GetClientCookie(client, g_hCookie_GuardBan, sBanned, sizeof(sBanned));

	return StrEqual(sBanned, "1");
}

public int Native_BanFromWarden(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int target = GetNativeCell(2);

	int size;
	GetNativeStringLength(3, size);

	char[] sReason = new char[size + 1];
	GetNativeString(3, sReason, size + 1);

	TF2Jail2Ban(g_hCookie_WardenBan, true, client, target, sReason);
}

public int Native_BanFromGuard(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int target = GetNativeCell(2);

	int size;
	GetNativeStringLength(3, size);

	char[] sReason = new char[size + 1];
	GetNativeString(3, sReason, size + 1);

	TF2Jail2Ban(g_hCookie_GuardBan, false, client, target, sReason);
}

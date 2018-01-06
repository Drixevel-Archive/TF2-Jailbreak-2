//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines

//Sourcemod Includes
#include <sourcemod>
#include <tf2_stocks>

//External Includes
#include <sourcemod-misc>
#include <colorvariables>

//Our Includes
#include <tf2jail2/tf2jail2_freekillers>

#undef REQUIRE_PLUGIN
#include <tf2jail2/tf2jail2_bans>
#include <tf2jail2/tf2jail2_core>
#include <tf2jail2/tf2jail2_warden>
#define REQUIRE_PLUGIN

//ConVars
ConVar convar_Status;

//Forwards
Handle g_hForward_OnMarkedFreekiller_Post;
Handle g_hForward_OnReportedFreekiller_Post;

//Globals
bool g_bIsFreekiller[MAXPLAYERS + 1];

//////////////////////////////////////////////////
//Info

public Plugin myinfo =
{
	name = "[TF2Jail2] Module: Freekillers",
	author = "Keith Warren (Sky Guardian)",
	description = "A module to keep track of freekillers for TF2 Jailbreak.",
	version = "1.0.0",
	url = "https://github.com/SkyGuardian"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("tf2jail2_freekillers");

	g_hForward_OnMarkedFreekiller_Post = CreateGlobalForward("TF2Jail2_OnMarkedFreekiller_Post", ET_Ignore, Param_Cell, Param_Cell);
	g_hForward_OnReportedFreekiller_Post = CreateGlobalForward("TF2Jail2_OnReportedFreekiller_Post", ET_Ignore, Param_Cell, Param_Cell);

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Status = CreateConVar("sm_tf2jail2_freekillers_status", "1", "Status of the plugin.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	RegConsoleCmd("sm_freekill", Command_Freekill, "As a player, report someone to the Warden as a Freekiller and as an admin, stop them from doing damage.");
}

public void OnConfigsExecuted()
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}


}

public void OnClientDisconnect(int client)
{
	g_bIsFreekiller[client] = false;
}

public Action Command_Freekill(int client, int args)
{
	if (!GetConVarBool(convar_Status) || client == 0)
	{
		return Plugin_Handled;
	}

	ShowFreekillMenu(client);
	return Plugin_Handled;
}

void ShowFreekillMenu(int client)
{
	Menu menu = CreateMenu(MenuHandler_Freekill);
	SetMenuTitle(menu, "Please choose the offendant:");

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && TF2_GetClientTeam(i) == TFTeam_Blue)
		{
			char sName[MAX_NAME_LENGTH];
			GetClientName(i, sName, sizeof(sName));

			char sUserid[32];
			IntToString(GetClientUserId(i), sUserid, sizeof(sUserid));

			AddMenuItem(menu, sUserid, sName);
		}
	}

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MenuHandler_Freekill(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sUserid[32]; char sName[MAX_NAME_LENGTH];
			GetMenuItem(menu, param2, sUserid, sizeof(sUserid), _, sName, sizeof(sName));

			int target = GetClientOfUserId(StringToInt(sUserid));

			if (target == -1)
			{
				CPrintToChat(param1, "%s {red}ERROR: {default}%s is no longer connected.", g_sGlobalTag, sName);
				return;
			}

			if (CheckCommandAccess(param1, "tf2jail2_override_markfreekillers", ADMFLAG_SLAY))
			{
				MarkFreekiller(param1, target);
				return;
			}

			HandleFreekillerInquiry(param1, target);
		}

		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

void MarkFreekiller(int client, int target)
{
	g_bIsFreekiller[target] = true;
	CPrintToChatAll("%s {mediumslateblue}%N {defaulthas marked {mediumslateblue}%N {default}as a {red}FREEKILLER{default}.", g_sGlobalTag, client, target);

	Call_StartForward(g_hForward_OnMarkedFreekiller_Post);
	Call_PushCell(client);
	Call_PushCell(target);
	Call_Finish();
}

void HandleFreekillerInquiry(int client, int target)
{
	if (TF2Jail2_IsWardenActive())
	{
		int warden = TF2Jail2_GetWarden();

		CPrintToChat(client, "%s Sending Freekill report on {mediumslateblue}%N {default}to {mediumslateblue}%N{default}...", g_sGlobalTag, target, warden);

		SendWardenReport(warden, client, target);
	}
	else
	{
		CPrintToChat(client, "%s Thank you for your Freekill report on {mediumslateblue}%N{default}, admins will take a look later.", g_sGlobalTag, target);
	}

	Call_StartForward(g_hForward_OnReportedFreekiller_Post);
	Call_PushCell(client);
	Call_PushCell(target);
	Call_Finish();
}

void SendWardenReport(int warden, int reporter, int reported)
{
	Menu menu = CreateMenu(MenuHandler_WardenReport);
	SetMenuTitle(menu, "%N {default}believes that %N is a freekiller:", reporter, reported);

	AddMenuItem(menu, "yes", "Justified");
	AddMenuItem(menu, "no", "Not Justified");

	PushMenuCell(menu, "target", GetClientUserId(reported));
	DisplayMenu(menu, warden, MENU_TIME_FOREVER);
}

public int MenuHandler_WardenReport(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			GetMenuItem(menu, param2, sInfo, sizeof(sInfo));

			int target = GetClientOfUserId(GetMenuCell(menu, "target"));

			if (target == -1)
			{
				CPrintToChat(param1, "%s {red}ERROR: {default}Client is no longer connected.", g_sGlobalTag);
				return;
			}

			WardenReport(param1, target, StrEqual(sInfo, "yes"));
		}

		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

void WardenReport(int client, int target, bool justified)
{
	if (justified)
	{
		TF2Jail2_BanFromWarden(client, target, "Reported as a Freekiller and Warden marked justified.");
	}
}

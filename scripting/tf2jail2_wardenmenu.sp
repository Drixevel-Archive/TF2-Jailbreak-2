//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define IS_PLUGIN

//Sourcemod Includes
#include <sourcemod>

//External Includes
#include <sourcemod-misc>
#include <colorvariables>

//Our Includes
//#include <tf2jail2/tf2jail2_wardenmenu>

#undef REQUIRE_PLUGIN
#include <tf2jail2/tf2jail2_core>
#include <tf2jail2/tf2jail2_lastrequests>
#include <tf2jail2/tf2jail2_maptriggers>
#include <tf2jail2/tf2jail2_warden>
#define REQUIRE_PLUGIN

//ConVars
ConVar convar_Status;

Handle convar_FriendlyFire;
Handle convar_TFPushAway;

//Globals

int g_iTimer_Cooldown;
Handle g_hTimer_Cooldown;

//////////////////////////////////////////////////
//Info

public Plugin myinfo =
{
	name = "[TF2Jail2] Module: Warden Menu",
	author = "Keith Warren (Shaders Allen)",
	description = "Allows access to a Warden menu with features for TF2 Jailbreaks Warden module.",
	version = "1.0.0",
	url = "https://www.shadersallen.com/"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Status = CreateConVar("sm_tf2jail2_wardenmenu_status", "1", "Status of the plugin.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	RegConsoleCmd("sm_wm", Command_WardenMenu, "Access the Warden menu.");
	RegConsoleCmd("sm_wmenu", Command_WardenMenu, "Access the Warden menu.");
	RegConsoleCmd("sm_wardenmenu", Command_WardenMenu, "Access the Warden menu.");

	convar_FriendlyFire = FindConVar("mp_friendlyfire");
	convar_TFPushAway = FindConVar("tf_avoidteammates_pushaway");
}

public void OnMapEnd()
{
	g_hTimer_Cooldown = null;
}

public void OnConfigsExecuted()
{

}

//////////////////////////////////////////////////
//TF2Jail2 Forwards

public void TF2Jail2_OnWardenSet_Post(int warden, int admin)
{
	if (GetConVarBool(convar_Status))
	{
		ShowWardenMenu(warden);
	}
}

//////////////////////////////////////////////////
//Commands

public Action Command_WardenMenu(int client, int args)
{
	if (!GetConVarBool(convar_Status) || client == 0)
	{
		return Plugin_Handled;
	}

	ShowWardenMenu(client, CheckCommandAccess(client, "tf2jail2_override_wardenmenu", ADMFLAG_SLAY));
	return Plugin_Handled;
}

//////////////////////////////////////////////////
//Stocks

void ShowWardenMenu(int client, bool admin = false)
{
	if (!admin && TF2Jail2_GetWarden() != client)
	{
		CPrintToChat(client, "%s {red}ERROR: {default}You are currently not the Warden.", g_sGlobalTag);
		return;
	}

	Menu menu = CreateMenu(MenuHandler_WardenMenu);
	SetMenuTitle(menu, "TF2Jail 2 - Warden Menu");

	AddMenuItem(menu, "", "---", ITEMDRAW_DISABLED);
	AddMenuItem(menu, "toggle_cells", "Toggle: Cells");
	AddMenuItem(menu, "toggle_friendlyfire", "Toggle: Friendly Fire");
	AddMenuItem(menu, "toggle_pushback", "Toggle: Pushback");
	AddMenuItem(menu, "grantlr", "Grant Last Request");
	AddMenuItem(menu, "announce_color", "Announce: Random Color");
	AddMenuItem(menu, "announce_number", "Announce: Random Number");
	AddMenuItem(menu, "announce_mathproblem", "Announce: Random Math Problem");

	PushMenuCell(menu, "admin", admin);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

bool IsOnCooldown()
{
	if (g_hTimer_Cooldown != null)
	{
		return true;
	}

	g_iTimer_Cooldown = 7;
	g_hTimer_Cooldown = CreateTimer(1.0, Timer_Cooldown, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	return false;
}

void GetRandomColor(char[] color, int size)
{
	switch (GetRandomInt(1, 12))
	{
		case 1: strcopy(color, size, "Red");
		case 2: strcopy(color, size, "Green");
		case 3: strcopy(color, size, "Blue");
		case 4: strcopy(color, size, "Green");
		case 5: strcopy(color, size, "Yellow");
		case 6: strcopy(color, size, "Black");
		case 7: strcopy(color, size, "Gray/Grey");
		case 8: strcopy(color, size, "Orange");
		case 9: strcopy(color, size, "Purple");
		case 10: strcopy(color, size, "Brown");
		case 11: strcopy(color, size, "Pink");
		case 12: strcopy(color, size, "Gold");
	}
}


//////////////////////////////////////////////////
//Timer Callbacks

public Action Timer_Cooldown(Handle timer)
{
	g_iTimer_Cooldown--;

	if (g_iTimer_Cooldown > 0)
	{
		return Plugin_Continue;
	}

	g_hTimer_Cooldown = null;
	return Plugin_Stop;
}

//////////////////////////////////////////////////
//MenuHandlers

public int MenuHandler_WardenMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			GetMenuItem(menu, param2, sInfo, sizeof(sInfo));

			bool admin = view_as<bool>(GetMenuCell(menu, "admin"));

			if (!GetConVarBool(convar_Status))
			{
				return;
			}

			if (!admin && TF2Jail2_GetWarden() != param1)
			{
				CPrintToChat(param1, "%s {red}ERROR: {default}You are currently not the Warden.", g_sGlobalTag);
				return;
			}

			if (IsOnCooldown())
			{
				CPrintToChat(param1, "%s {red}ERROR: {default}Warden actions are currently on cooldown. (%i seconds remaining)", g_sGlobalTag, g_iTimer_Cooldown);
				ShowWardenMenu(param1, admin);
				return;
			}

			if (StrEqual(sInfo, "toggle_cells"))
			{
				TF2Jail2_ToggleCells(param1);
				ShowWardenMenu(param1, admin);
			}
			else if (StrEqual(sInfo, "toggle_friendlyfire"))
			{
				SetConVarBool(convar_FriendlyFire, !GetConVarBool(convar_FriendlyFire));
				CPrintToChatAll("%s Friendly Fire: %s", g_sGlobalTag, GetConVarBool(convar_FriendlyFire) ? "Enabled" : "Disabled");
				ShowWardenMenu(param1, admin);
			}
			else if (StrEqual(sInfo, "toggle_pushback"))
			{
				SetConVarBool(convar_TFPushAway, !GetConVarBool(convar_TFPushAway));
				CPrintToChatAll("%s Pushback: %s", g_sGlobalTag, GetConVarBool(convar_TFPushAway) ? "Enabled" : "Disabled");
				ShowWardenMenu(param1, admin);
			}
			else if (StrEqual(sInfo, "grantlr"))
			{
				TF2Jail2_GiveLR(param1);
			}
			else if (StrEqual(sInfo, "announce_color"))
			{
				char sColor[MAX_NAME_LENGTH];
				GetRandomColor(sColor, sizeof(sColor));
				PrintCenterTextAll("Color: %s", sColor);
				ShowWardenMenu(param1, admin);
			}
			else if (StrEqual(sInfo, "announce_number"))
			{
				PrintCenterTextAll("Number: %i", GetRandomInt(1, 100));
				ShowWardenMenu(param1, admin);
			}
			else if (StrEqual(sInfo, "announce_mathproblem"))
			{
				int first = GetRandomInt(1, 20);
				int second = GetRandomInt(1, 20);
				int answer;

				char sEquasion[32];
				switch (GetRandomInt(1, 3))
				{
					case 1:
					{
						strcopy(sEquasion, sizeof(sEquasion), "added to");
						answer = first + second;
					}
					case 2:
					{
						strcopy(sEquasion, sizeof(sEquasion), "subtracted from");
						answer = first - second;
					}
					case 3:
					{
						strcopy(sEquasion, sizeof(sEquasion), "multiplied by");
						answer = first * second;
					}
				}

				PrintCenterTextAll("%i %s %i = ?", first, sEquasion, second);
				CPrintToChat(param1, "%s Answer: %i", g_sGlobalTag, answer);
				ShowWardenMenu(param1, admin);
			}
		}

		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

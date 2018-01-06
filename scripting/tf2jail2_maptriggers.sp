//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines

//Sourcemod Includes
#include <sourcemod>
#include <tf2_stocks>
#include <sdkhooks>

//External Includes
#include <sourcemod-misc>
#include <colorvariables>

//Our Includes
#include <tf2jail2/tf2jail2_maptriggers>

#undef REQUIRE_PLUGIN
#include <tf2jail2/tf2jail2_core>
#include <tf2jail2/tf2jail2_warden>
#define REQUIRE_PLUGIN

//ConVars
ConVar convar_Status;
ConVar convar_CellsDelay;

//Globals
bool g_bCellsOpen;
Handle g_hCellDelay;
bool g_bAreCellsLocked;

//////////////////////////////////////////////////
//Info

public Plugin myinfo =
{
	name = "[TF2Jail2] Module: Map Triggers",
	author = "Keith Warren (Sky Guardian)",
	description = "Allows for manipuation of maps for TF2 Jailbreak.",
	version = "1.0.0",
	url = "https://github.com/SkyGuardian"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("tf2jail2_maptriggers");

	CreateNative("TF2Jail2_ToggleCells", Native_ToggleCells);
	CreateNative("TF2Jail2_OpenCells", Native_OpenCells);
	CreateNative("TF2Jail2_CloseCells", Native_CloseCells);
	CreateNative("TF2Jail2_CellsStatus", Native_CellsStatus);
	CreateNative("TF2Jail2_ToggleCellsAccess", Native_ToggleCellsAccess);
	CreateNative("TF2Jail2_LockCells", Native_LockCells);
	CreateNative("TF2Jail2_UnlockCells", Native_UnlockCells);
	CreateNative("TF2Jail2_ToggleMedicStations", Native_ToggleMedicStations);
	CreateNative("TF2Jail2_ToggleHealthKits", Native_ToggleHealthKits);
	CreateNative("TF2Jail2_ToggleAmmoPacks", Native_ToggleAmmoPacks);

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Status = CreateConVar("sm_tf2jail2_maptriggers_status", "1", "Status of the plugin.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_CellsDelay = CreateConVar("sm_tf2jail2_maptriggers_cells_delay", "5.0", "Delay for toggling, opening and closing the cell doors.", FCVAR_NOTIFY, true, 0.0);

	RegConsoleCmd("sm_tc", Command_ToggleCells, "Toggle all cells to on or off as Warden or Admin.");
	RegConsoleCmd("sm_togglecells", Command_ToggleCells, "Toggle all cells to on or off as Warden or Admin.");
	RegConsoleCmd("sm_open", Command_Open, "Open all cells as Warden or Admin.");
	RegConsoleCmd("sm_opencells", Command_Open, "Open all cells as Warden or Admin.");
	RegConsoleCmd("sm_close", Command_Close, "Close all cells as Warden or Admin.");
	RegConsoleCmd("sm_closecells", Command_Close, "Close the cells as Warden.");

	RegAdminCmd("sm_lockcells", Command_LockCells, ADMFLAG_SLAY, "Lock all cells as Admin.");
	RegAdminCmd("sm_unlockcells", Command_UnlockCells, ADMFLAG_SLAY, "Unlock all cells as Admin.");

	HookEvent("teamplay_round_win", Event_OnRoundEnd);
}

public void OnMapEnd()
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	g_bCellsOpen = false;
	g_hCellDelay = null;
}

public void OnConfigsExecuted()
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}
}

//////////////////////////////////////////////////
//Events

public void Event_OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	g_bCellsOpen = false;
	delete g_hCellDelay;

	ToggleCellsAccess(-1, "func_door", "cell_door", false, false);
}

//////////////////////////////////////////////////
//Commands

public Action Command_ToggleCells(int client, int args)
{
	if (!GetConVarBool(convar_Status))
	{
		return Plugin_Handled;
	}

	ToggleCells(client, "func_door", "cell_door", !g_bCellsOpen, true, CheckCommandAccess(client, "tf2jail2_override_operatecells", ADMFLAG_SLAY));
	return Plugin_Handled;
}

public Action Command_Open(int client, int args)
{
	if (!GetConVarBool(convar_Status))
	{
		return Plugin_Handled;
	}

	if (g_bCellsOpen)
	{
		CPrintToChat(client, "%s Error opening all cell doors: cells already open", g_sGlobalTag);
		return Plugin_Handled;
	}

	ToggleCells(client, "func_door", "cell_door", true, true, CheckCommandAccess(client, "tf2jail2_override_operatecells", ADMFLAG_SLAY));
	return Plugin_Handled;
}

public Action Command_Close(int client, int args)
{
	if (!GetConVarBool(convar_Status))
	{
		return Plugin_Handled;
	}

	if (!g_bCellsOpen)
	{
		CPrintToChat(client, "%s Error closing all cell doors: cells already closed", g_sGlobalTag);
		return Plugin_Handled;
	}

	ToggleCells(client, "func_door", "cell_door", false, true, CheckCommandAccess(client, "tf2jail2_override_operatecells", ADMFLAG_SLAY));
	return Plugin_Handled;
}

public Action Command_LockCells(int client, int args)
{
	if (!GetConVarBool(convar_Status))
	{
		return Plugin_Handled;
	}

	ToggleCellsAccess(client, "func_door", "cell_door", true, true);
	return Plugin_Handled;
}

public Action Command_UnlockCells(int client, int args)
{
	if (!GetConVarBool(convar_Status))
	{
		return Plugin_Handled;
	}

	ToggleCellsAccess(client, "func_door", "cell_door", false, true);
	return Plugin_Handled;
}

//////////////////////////////////////////////////
//Stocks

void ToggleCells(int client = -1, const char[] classname, const char[] name, bool status, bool announce = true, bool admin = false, bool force = false)
{
	if (!force && !admin && TF2Jail2_GetWarden() != client)
	{
		if (client != -1)
		{
			CPrintToChat(client, "%s {red}ERROR: {default}You are currently not the Warden.", g_sGlobalTag);
		}

		return;
	}

	if (!force && !admin && g_hCellDelay != null)
	{
		if (client != -1)
		{
			CPrintToChat(client, "%s {red}ERROR: {default}Too many status change updates, please wait a bit.", g_sGlobalTag);
		}

		return;
	}

	int entity = INVALID_ENT_REFERENCE;
	while ((entity = FindEntityByClassname(entity, classname)) != INVALID_ENT_REFERENCE)
	{
		char sClass[MAX_NAME_LENGTH];
		GetEntPropString(entity, Prop_Data, "m_iName", sClass, sizeof(sClass));

		if (StrEqual(sClass, name))
		{
			AcceptEntityInput(entity, status ? "Open" : "Close");
		}
	}

	g_bCellsOpen = status;

	if (announce)
	{
		char sOperator[128];

		if (client != -1)
		{
			FormatEx(sOperator, sizeof(sOperator), " by {mediumslateblue}%N", client);
		}

		CPrintToChatAll("%s All cell doors have been %s%s{default}.", g_sGlobalTag, g_bCellsOpen ? "opened" : "closed", strlen(sOperator) > 0 ? sOperator : "");
	}

	float delay = GetConVarFloat(convar_CellsDelay);

	if (!force && delay > 0.0)
	{
		g_hCellDelay = CreateTimer(GetConVarFloat(convar_CellsDelay), Timer_DelayCells, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

void ToggleCellsAccess(int client, const char[] classname, const char[] name, bool status, bool announce = true)
{
	int entity = INVALID_ENT_REFERENCE;
	while ((entity = FindEntityByClassname(entity, classname)) != INVALID_ENT_REFERENCE)
	{
		char sClass[MAX_NAME_LENGTH];
		GetEntPropString(entity, Prop_Data, "m_iName", sClass, sizeof(sClass));

		if (StrEqual(sClass, name))
		{
			AcceptEntityInput(entity, status ? "Lock" : "Unlock");
		}
	}

	g_bAreCellsLocked = status;

	if (announce)
	{
		char sOperator[128];

		if (client != -1)
		{
			FormatEx(sOperator, sizeof(sOperator), " by {mediumslateblue}%N", client);
		}

		CPrintToChatAll("%s All cell doors have been %s%s{default}.", g_sGlobalTag, g_bAreCellsLocked ? "locked" : "unlocked", strlen(sOperator) > 0 ? sOperator : "");
	}
}

void DisableMedicStations(bool toggle = false)
{
	int entity = INVALID_ENT_REFERENCE;
	while ((entity = FindEntityByClassname(entity, "trigger_hurt")) != INVALID_ENT_REFERENCE)
	{
		if (GetEntPropFloat(entity, Prop_Data, "m_flDamage") < 0.0)
		{
			AcceptEntityInput(entity, toggle ? "Enable" : "Disable");
		}
	}
}

void DisableHealthKits(bool toggle = false)
{
	if (toggle)
	{
		KillAllEntities("item_healthkit_*");
	}
}

void DisableAmmoPacks(bool toggle = false)
{
	if (toggle)
	{
		KillAllEntities("item_ammo_*");
	}
}

void KillAllEntities(const char[] entity_name)
{
	int entity = INVALID_ENT_REFERENCE;
	while ((entity = FindEntityByClassname(entity, entity_name)) != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(entity, "Kill");
	}
}

//////////////////////////////////////////////////
//Timers

public Action Timer_DelayCells(Handle timer)
{
	g_hCellDelay = null;
	return Plugin_Stop;
}

//////////////////////////////////////////////////
//Natives

public int Native_ToggleCells(Handle plugin, int numParams)
{
	ToggleCells(GetNativeCell(1), "func_door", "cell_door", !g_bCellsOpen, GetNativeCell(2), GetNativeCell(3));
}

public int Native_OpenCells(Handle plugin, int numParams)
{
	ToggleCells(GetNativeCell(1), "func_door", "cell_door", true, GetNativeCell(2), GetNativeCell(3));
}

public int Native_CloseCells(Handle plugin, int numParams)
{
	ToggleCells(GetNativeCell(1), "func_door", "cell_door", false, GetNativeCell(2), GetNativeCell(3));
}

public int Native_CellsStatus(Handle plugin, int numParams)
{
	return g_bCellsOpen;
}

public int Native_ToggleCellsAccess(Handle plugin, int numParams)
{
	ToggleCellsAccess(GetNativeCell(1), "func_door", "cell_door", !g_bAreCellsLocked, GetNativeCell(2));
}

public int Native_LockCells(Handle plugin, int numParams)
{
	ToggleCellsAccess(GetNativeCell(1), "func_door", "cell_door", true, GetNativeCell(2));
}

public int Native_UnlockCells(Handle plugin, int numParams)
{
	ToggleCellsAccess(GetNativeCell(1), "func_door", "cell_door", false, GetNativeCell(2));
}

public int Native_ToggleMedicStations(Handle plugin, int numParams)
{
	DisableMedicStations(GetNativeCell(1));
}

public int Native_ToggleHealthKits(Handle plugin, int numParams)
{
	DisableHealthKits(GetNativeCell(1));
}

public int Native_ToggleAmmoPacks(Handle plugin, int numParams)
{
	DisableAmmoPacks(GetNativeCell(1));
}

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
#include <tf2jail2/tf2jail2_warden>

#undef REQUIRE_PLUGIN
#include <tf2jail2/tf2jail2_bans>
#include <tf2jail2/tf2jail2_core>
#define REQUIRE_PLUGIN

//ConVars
ConVar convar_Status;
ConVar convar_WardenPhase;

ConVar convar_LastWarden;

//Forwards
Handle g_hForward_OnWardenSet_Post;
Handle g_hForward_OnWardenRemoved_Post;
Handle g_hForward_OnWardenPhaseEnd_Post;

//Globals
bool bLate;

ArrayStack g_hSWardenQueue;
int g_iStackSize;
bool g_bIsInStack[MAXPLAYERS + 1];

int g_iCurrentWarden = NO_WARDEN;

int g_iTimer_WardenPhase;
Handle g_hTimer_WardenPhase;

bool g_bActiveRound;
bool g_bFreeWarden;

bool g_bLockWarden;
bool g_bWardenPhase = true;

Handle g_hudCurrentWarden;

//////////////////////////////////////////////////
//Info

public Plugin myinfo =
{
	name = "[TF2Jail2] Module: Warden",
	author = "Keith Warren (Sky Guardian)",
	description = "Handles and manages all Warden functionality for TF2 Jailbreak.",
	version = "1.0.0",
	url = "https://github.com/SkyGuardian"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("tf2jail2_warden");

	CreateNative("TF2Jail2_IsWardenActive", Native_IsWardenActive);
	CreateNative("TF2Jail2_GetWarden", Native_GetWarden);
	CreateNative("TF2Jail2_SetWarden", Native_SetWarden);
	CreateNative("TF2Jail2_RemoveWarden", Native_RemoveWarden);
	CreateNative("TF2Jail2_IsWardenLocked", Native_IsWardenLocked);
	CreateNative("TF2Jail2_LockWarden", Native_LockWarden);
	CreateNative("TF2Jail2_EndWardenPhase", Native_EndWardenPhase);
	CreateNative("TF2Jail2_NoWardenPhase", Native_NoWardenPhase);

	g_hForward_OnWardenSet_Post = CreateGlobalForward("TF2Jail2_OnWardenSet_Post", ET_Ignore, Param_Cell, Param_Cell);
	g_hForward_OnWardenRemoved_Post = CreateGlobalForward("TF2Jail2_OnWardenRemoved_Post", ET_Ignore, Param_Cell, Param_Cell);
	g_hForward_OnWardenPhaseEnd_Post = CreateGlobalForward("TF2Jail2_OnWardenPhaseEnd_Post", ET_Ignore, Param_Cell);

	bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Status = CreateConVar("sm_tf2jail2_warden_status", "1", "Status of the plugin.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_WardenPhase = CreateConVar("sm_tf2jail2_warden_phase_seconds", "20", "Time amount for the Warden phase.", FCVAR_NOTIFY, true, 1.0);

	//Dummy ConVar
	convar_LastWarden = CreateConVar("sm_tf2jail2_last_warden", "0", "", FCVAR_PROTECTED);

	RegConsoleCmd("sm_w", Command_GoWarden, "Go Warden is the current server state allows you to.");
	RegConsoleCmd("sm_warden", Command_GoWarden, "Go Warden is the current server state allows you to.");

	RegConsoleCmd("sm_qw", Command_QueueWarden, "Set yourself as Warden if no current warden is active or queue for it.");
	RegConsoleCmd("sm_queuewarden", Command_QueueWarden, "Set yourself as Warden if no current warden is active or queue for it.");
	RegConsoleCmd("sm_wq", Command_QueueWarden, "Set yourself as Warden if no current warden is active or queue for it.");
	RegConsoleCmd("sm_wardenqueue", Command_QueueWarden, "Set yourself as Warden if no current warden is active or queue for it.");

	RegConsoleCmd("sm_uw", Command_UnWarden, "Remove yourself from Warden if you're Warden.");
	RegConsoleCmd("sm_unwarden", Command_UnWarden, "Remove yourself from Warden if you're Warden.");

	RegAdminCmd("sm_sw", Command_SetWarden, ADMFLAG_SLAY, "Set a client to Warden if no Warden is currently active.");
	RegAdminCmd("sm_setwarden", Command_SetWarden, ADMFLAG_SLAY, "Set a client to Warden if no Warden is currently active.");
	RegAdminCmd("sm_fw", Command_SetWarden, ADMFLAG_SLAY, "Set a client to Warden and remove any currently active Wardens.");
	RegAdminCmd("sm_forcewarden", Command_SetWarden, ADMFLAG_SLAY, "Set a client to Warden and remove any currently active Wardens.");

	RegAdminCmd("sm_rw", Command_RemoveWarden, ADMFLAG_SLAY, "Remove the currently active Warden.");
	RegAdminCmd("sm_removewarden", Command_RemoveWarden, ADMFLAG_SLAY, "Remove the currently active Warden.");

	HookEvent("teamplay_round_start", Event_OnRoundStart);
	HookEvent("arena_round_start", Event_OnRoundActive);
	HookEvent("teamplay_round_active", Event_OnRoundActive);
	HookEvent("teamplay_round_win", Event_OnRoundEnd);
	HookEvent("player_death", Event_OnPlayerDeath);

	g_hSWardenQueue = CreateStack();
	g_hudCurrentWarden = CreateHudSynchronizer();
}

public void OnMapEnd()
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	g_iCurrentWarden = NO_WARDEN;
	while (PopStack(g_hSWardenQueue)) { }

	g_iStackSize = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		g_bIsInStack[i] = false;
	}

	g_hTimer_WardenPhase = null;
}

public void OnMapStart()
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	PrecacheModel("models/player/warden_soldier/warden_soldier.mdl");
}

public void OnConfigsExecuted()
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	if (bLate)
	{
		int lastwarden = GetConVarInt(convar_LastWarden);

		if (lastwarden != 0)
		{
			SetWarden(lastwarden, -1);
			SetConVarInt(convar_LastWarden, 0);
		}

		bLate = false;
	}
}

public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			ClearSyncHud(i, g_hudCurrentWarden);
		}
	}

	if (g_iCurrentWarden != NO_WARDEN)
	{
		SetConVarInt(convar_LastWarden, g_iCurrentWarden);
		RemoveWarden(-1, true);
	}
}

public void OnClientDisconnect(int client)
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	if (g_iCurrentWarden == client)
	{
		CPrintToChat(client, "%s {mediumslateblue}%N {default}has disconnected as the warden.", g_sGlobalTag, g_iCurrentWarden);
		RemoveWarden(-1, false);
	}

	if (g_bIsInStack[client])
	{
		RemoveFromStack(g_hSWardenQueue, GetClientUserId(client));
		g_iStackSize--;
		g_bIsInStack[client] = false;
	}
}

//////////////////////////////////////////////////
//Events

public void Event_OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}
}

public void Event_OnRoundActive(Event event, const char[] name, bool dontBroadcast)
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	RequestFrame(Frame_StartWardenProcess);

	g_bActiveRound = true;
}

public void Event_OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	EndWardenPhase();
	g_bLockWarden = false;

	RemoveWarden(-1, false);

	g_bActiveRound = false;
}

public void Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (client > 0 && client == g_iCurrentWarden)
	{
		CPrintToChatAll("%s Warden has died.", g_sGlobalTag);
		RemoveWarden(-1, false);
	}
}

//////////////////////////////////////////////////
//Commands

public Action Command_GoWarden(int client, int args)
{
	if (!GetConVarBool(convar_Status) || client == 0)
	{
		return Plugin_Handled;
	}

	if (g_hTimer_WardenPhase != null)
	{
		Command_QueueWarden(client, 0);
		return Plugin_Handled;
	}

	if (TF2Jail2_IsWardenBanned(client))
	{
		CPrintToChat(client, "%s {red}ERROR: {default}You are banned from Warden, please contact an administrator for assistance.", g_sGlobalTag);
		return Plugin_Handled;
	}

	if (g_bLockWarden)
	{
		CPrintToChat(client, "%s {red}ERROR: {default}Warden is currently locked and cannot be used.", g_sGlobalTag);
		return Plugin_Handled;
	}

	if (!g_bActiveRound)
	{
		CPrintToChat(client, "%s {red}ERROR: {default}You cannot go Warden during a non-active round phase.", g_sGlobalTag);
		return Plugin_Handled;
	}

	if (g_hTimer_WardenPhase != null)
	{
		CPrintToChat(client, "%s {red}ERROR: {default}You cannot use this command during the Warden pick phase.", g_sGlobalTag);
		return Plugin_Handled;
	}

	if (g_iCurrentWarden != NO_WARDEN)
	{
		CPrintToChat(client, "%s {red}ERROR: {default}Warden is currently active.", g_sGlobalTag);
		return Plugin_Handled;
	}

	if (!g_bFreeWarden)
	{
		CPrintToChat(client, "%s {red}ERROR: {default}You cannot go Warden at this time.", g_sGlobalTag);
		return Plugin_Handled;
	}

	SetWarden(client);

	return Plugin_Handled;
}

public Action Command_QueueWarden(int client, int args)
{
	if (!GetConVarBool(convar_Status) || client == 0)
	{
		return Plugin_Handled;
	}

	if (TF2Jail2_IsWardenBanned(client))
	{
		CPrintToChat(client, "%s {red}ERROR: {default}You are banned from Warden, please contact an administrator for assistance.", g_sGlobalTag);
		return Plugin_Handled;
	}

	if (g_bIsInStack[client])
	{
		CPrintToChat(client, "%s {red}ERROR: {default}You are already in the Warden queue. [Line Size: %i]", g_sGlobalTag, g_iStackSize);
		return Plugin_Handled;
	}

	PushStackCell(g_hSWardenQueue, GetClientUserId(client));
	g_iStackSize++;
	g_bIsInStack[client] = true;

	CPrintToChat(client, "%s You are now in the Warden queue. [Line Size: %i]", g_sGlobalTag, g_iStackSize);

	return Plugin_Handled;
}

public Action Command_UnWarden(int client, int args)
{
	if (!GetConVarBool(convar_Status) || client == 0)
	{
		return Plugin_Handled;
	}

	if (client != g_iCurrentWarden)
	{
		CPrintToChat(client, "%s {red}ERROR: {default}You are not currently the Warden.", g_sGlobalTag);
		return Plugin_Handled;
	}

	RemoveWarden(client, true);
	return Plugin_Handled;
}

public Action Command_SetWarden(int client, int args)
{
	if (!GetConVarBool(convar_Status))
	{
		return Plugin_Handled;
	}

	if (g_bLockWarden)
	{
		CPrintToChat(client, "%s {red}ERROR: {default}Warden is currently locked and cannot be used.", g_sGlobalTag);
		return Plugin_Handled;
	}

	if (!g_bActiveRound)
	{
		CPrintToChat(client, "%s {red}ERROR: {default}Round must be active to go Warden.", g_sGlobalTag);
		return Plugin_Handled;
	}

	if (g_iCurrentWarden != NO_WARDEN)
	{
		CPrintToChat(client, "%s {red}ERROR: {default}The Warden slot is currently occupied.", g_sGlobalTag);
		return Plugin_Handled;
	}

	char sTarget[MAX_NAME_LENGTH];
	GetCmdArgString(sTarget, sizeof(sTarget));

	int target = FindTarget(client, sTarget, true, false);

	if (target == -1)
	{
		CPrintToChat(client, "%s {red}ERROR: {default}Target not found, please try again.", g_sGlobalTag);
		return Plugin_Handled;
	}

	if (TF2Jail2_IsWardenBanned(target))
	{
		CPrintToChat(client, "%s {red}ERROR: {mediumslateblue}%N {default}is currently banned from Warden.", g_sGlobalTag, target);
		return Plugin_Handled;
	}

	SetWarden(target, client);
	return Plugin_Handled;
}

public Action Command_RemoveWarden(int client, int args)
{
	if (!GetConVarBool(convar_Status))
	{
		return Plugin_Handled;
	}

	if (g_iCurrentWarden == NO_WARDEN)
	{
		CPrintToChat(client, "%s {red}ERROR: {default}The Warden slot is currently not occupied.", g_sGlobalTag);
		return Plugin_Handled;
	}

	RemoveWarden(client, true);
	return Plugin_Handled;
}

//////////////////////////////////////////////////
//Stocks

public void Frame_StartWardenProcess(any data)
{
	if (g_bWardenPhase && !g_bLockWarden)
	{
		CPrintToChatAll("%s The Warden pick phase has started, if no Warden is chosen by the end of the phase then it will be freeday for all.", g_sGlobalTag);

		g_iTimer_WardenPhase = GetConVarInt(convar_WardenPhase);
		g_hTimer_WardenPhase = CreateTimer(1.0, Timer_EndWardenPhase, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}

	g_bWardenPhase = true;
}

bool PickNewWarden()
{
	if (IsStackEmpty(g_hSWardenQueue) || g_iStackSize == 0)
	{
		return false;
	}

	int userid;
	if (!PopStackCell(g_hSWardenQueue, userid))
	{
		return false;
	}

	int client = GetClientOfUserId(userid);

	if (client == 0)
	{
		return false;
	}

	if (SetWarden(client, -1))
	{
		g_iStackSize--;
		g_bIsInStack[client] = false;

		return true;
	}

	return false;
}

bool SetWarden(int client, int admin = -1, bool announce = true)
{
	if (!g_bActiveRound)
	{
		return false;
	}

	if (g_iCurrentWarden != NO_WARDEN)
	{
		RemoveWarden(admin, true);
	}

	if (TF2_GetClientTeam(client) != TFTeam_Blue)
	{
		TF2_ChangeClientTeam(client, TFTeam_Blue);
		TF2_RespawnPlayer(client);
	}

	g_iCurrentWarden = client;

	if (announce)
	{
		char sAdmin[128];

		if (admin != -1)
		{
			FormatEx(sAdmin, sizeof(sAdmin), " by {mediumslateblue}%N{default}", admin);
		}

		CPrintToChatAll("%s {mediumslateblue}%N {default}has been set to Warden%s.", g_sGlobalTag, client, strlen(sAdmin) > 0 ? sAdmin : "");
	}

	AttachParticle(client, "spell_batball_impact_blue", 2.0);
	//SetEntityRenderColor(client, 0, 212, 255, 255);

	if (TF2_GetPlayerClass(client) == TFClass_Soldier)
	{
		SetVariantString("models/player/warden_soldier/warden_soldier.mdl");
		AcceptEntityInput(client, "SetCustomModel");
		SetEntProp(client, Prop_Send, "m_bCustomModelRotates", true);
		SetEntProp(client, Prop_Send, "m_bUseClassAnimations", true);
	}

	TF2_RegeneratePlayer(client);
	RemoveValveHat(client);
	HideWeapons(client, true);

	SetHudTextParams(0.7, 0.95, 99999.0, 255, 00, 0, 255, 0, 0.0, 0.0, 0.0);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			ShowSyncHudText(i, g_hudCurrentWarden, "Current Warden: %N", g_iCurrentWarden);
		}
	}

	Call_StartForward(g_hForward_OnWardenSet_Post);
	Call_PushCell(client);
	Call_PushCell(admin);
	Call_Finish();

	return true;
}

void RemoveValveHat(int client, bool unhide = false)
{
	int edict = MaxClients + 1;
	while((edict = FindEntityByClassnameSafe(edict, "tf_wearable")) != -1)
	{
		char netclass[32];
		if (GetEntityNetClass(edict, netclass, sizeof(netclass)) && strcmp(netclass, "CTFWearable") == 0)
		{
			int idx = GetEntProp(edict, Prop_Send, "m_iItemDefinitionIndex");
			if (idx != 57 && idx != 133 && idx != 231 && idx != 444 && idx != 405 && idx != 608 && idx != 642 && GetEntPropEnt(edict, Prop_Send, "m_hOwnerEntity") == client)
			{
				SetEntityRenderMode(edict, (unhide ? RENDER_NORMAL : RENDER_TRANSCOLOR));
				SetEntityRenderColor(edict, 255, 255, 255, (unhide ? 255 : 0));
			}
		}
	}

	edict = MaxClients + 1;
	while((edict = FindEntityByClassnameSafe(edict, "tf_powerup_bottle")) != -1)
	{
		char netclass[32];
		if (GetEntityNetClass(edict, netclass, sizeof(netclass)) && strcmp(netclass, "CTFPowerupBottle") == 0)
		{
			int idx = GetEntProp(edict, Prop_Send, "m_iItemDefinitionIndex");
			if (idx != 57 && idx != 133 && idx != 231 && idx != 444 && idx != 405 && idx != 608 && idx != 642 && GetEntPropEnt(edict, Prop_Send, "m_hOwnerEntity") == client)
			{
				SetEntityRenderMode(edict, (unhide ? RENDER_NORMAL : RENDER_TRANSCOLOR));
				SetEntityRenderColor(edict, 255, 255, 255, (unhide ? 255 : 0));
			}
		}
	}
}

void HideWeapons(int client, bool unhide = false)
{
	HideWeaponWearables(client, unhide);
	int m_hMyWeapons = FindSendPropInfo("CTFPlayer", "m_hMyWeapons");

	for (int i = 0, weapon; i < 47; i += 4)
	{
		weapon = GetEntDataEnt2(client, m_hMyWeapons + i);

		char classname[64];
		if (weapon > MaxClients && IsValidEdict(weapon) && GetEdictClassname(weapon, classname, sizeof(classname)) && StrContains(classname, "weapon") != -1)
		{
			SetEntityRenderMode(weapon, (unhide ? RENDER_NORMAL : RENDER_TRANSCOLOR));
			SetEntityRenderColor(weapon, 255, 255, 255, (unhide ? 255 : 5));
		}
	}
}

void HideWeaponWearables(int client, bool unhide = false)
{
	int edict = MaxClients + 1;
	while((edict = FindEntityByClassnameSafe(edict, "tf_wearable")) != -1)
	{
		char netclass[32];
		if (GetEntityNetClass(edict, netclass, sizeof(netclass)) && strcmp(netclass, "CTFWearable") == 0)
		{
			int idx = GetEntProp(edict, Prop_Send, "m_iItemDefinitionIndex");
			if (idx != 57 && idx != 133 && idx != 231 && idx != 444 && idx != 405 && idx != 608 && idx != 642) continue;
			if (GetEntPropEnt(edict, Prop_Send, "m_hOwnerEntity") == client)
			{
				SetEntityRenderMode(edict, (unhide ? RENDER_NORMAL : RENDER_TRANSCOLOR));
				SetEntityRenderColor(edict, 255, 255, 255, (unhide ? 255 : 0));
			}
		}
	}
}

int FindEntityByClassnameSafe(int iStart, const char[] strClassname)
{
	while (iStart > -1 && !IsValidEntity(iStart)) iStart--;
	return FindEntityByClassname(iStart, strClassname);
}

void RemoveWarden(int admin = -1, bool announce = true)
{
	if (g_iCurrentWarden == NO_WARDEN)
	{
		return;
	}

	int old_warden = g_iCurrentWarden;
	g_iCurrentWarden = NO_WARDEN;

	//SetEntityRenderColor(old_warden, 255, 255, 255, 255);

	SetVariantString("");
	AcceptEntityInput(old_warden, "SetCustomModel");

	if (announce)
	{
		char sAdmin[128];

		if (admin != -1)
		{
			FormatEx(sAdmin, sizeof(sAdmin), " by {mediumslateblue}%N{default}", admin);
		}

		CPrintToChatAll("%s {mediumslateblue}%N {default}has been removed from Warden%s.", g_sGlobalTag, old_warden, strlen(sAdmin) > 0 ? sAdmin : "");
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			ClearSyncHud(i, g_hudCurrentWarden);
		}
	}

	Call_StartForward(g_hForward_OnWardenRemoved_Post);
	Call_PushCell(old_warden);
	Call_PushCell(admin);
	Call_Finish();

	g_bFreeWarden = false;
}

stock void RemoveFromStack(Handle &stack, int value)
{
	if (IsStackEmpty(stack))
	{
		return;
	}

	ArrayStack newstack = CreateStack();

	int data;
	while (PopStackCell(stack, data))
	{
		if (data == value)
		{
			continue;
		}

		PushStackCell(newstack, data);
	}

	delete stack;
	stack = newstack;
}

void EndWardenPhase()
{
	if (g_hTimer_WardenPhase == null)
	{
		return;
	}

	KillTimerSafe(g_hTimer_WardenPhase);

	g_bLockWarden = true;
	CPrintToChatAll("%s The Warden pick phase has ended.", g_sGlobalTag);

	Call_StartForward(g_hForward_OnWardenPhaseEnd_Post);
	Call_PushCell(g_iCurrentWarden);
	Call_Finish();

	g_bFreeWarden = true;
}

//////////////////////////////////////////////////
//Timers

public Action Timer_EndWardenPhase(Handle timer, any data)
{
	if (!GetConVarBool(convar_Status) || g_bLockWarden)
	{
		EndWardenPhase();

		g_hTimer_WardenPhase = null;
		return Plugin_Stop;
	}

	g_iTimer_WardenPhase--;
	PrintHintTextToAll("Warden phase ends in %i seconds...", g_iTimer_WardenPhase);

	if (g_iTimer_WardenPhase <= 0 || PickNewWarden())
	{
		EndWardenPhase();

		g_hTimer_WardenPhase = null;
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

//////////////////////////////////////////////////
//Natives

public int Native_IsWardenActive(Handle plugin, int numParams)
{
	return g_iCurrentWarden != NO_WARDEN;
}

public int Native_GetWarden(Handle plugin, int numParams)
{
	return g_iCurrentWarden;
}

public int Native_SetWarden(Handle plugin, int numParams)
{
	SetWarden(GetNativeCell(2), GetNativeCell(1));
}

public int Native_RemoveWarden(Handle plugin, int numParams)
{
	RemoveWarden(GetNativeCell(1), view_as<bool>(GetNativeCell(2)));
}

public int Native_IsWardenLocked(Handle plugin, int numParams)
{
	return g_bLockWarden;
}

public int Native_LockWarden(Handle plugin, int numParams)
{
	g_bLockWarden = view_as<bool>(GetNativeCell(1));
}

public int Native_EndWardenPhase(Handle plugin, int numParams)
{
	EndWardenPhase();
}

public int Native_NoWardenPhase(Handle plugin, int numParams)
{
	g_bWardenPhase = false;
}

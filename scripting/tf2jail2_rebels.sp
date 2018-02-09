//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define IS_PLUGIN

//Sourcemod Includes
#include <sourcemod>
#include <tf2_stocks>

//External Includes
#include <sourcemod-misc>
#include <colorvariables>

//Our Includes
#include <tf2jail2/tf2jail2_rebels>

#undef REQUIRE_PLUGIN
#include <tf2jail2/tf2jail2_core>
#define REQUIRE_PLUGIN

//ConVars
ConVar convar_Status;
ConVar convar_Announce;
ConVar convar_RebelTimer;

//Forwards
Handle g_hForward_OnRebel_Post;

//Globals
bool g_bLate;
bool g_bIsMarkedRebel[MAXPLAYERS + 1];
Handle g_hRebelTimer[MAXPLAYERS + 1];

//////////////////////////////////////////////////
//Info

public Plugin myinfo =
{
	name = "[TF2Jail2] Module: Rebels",
	author = "Keith Warren (Sky Guardian)",
	description = "Handles and keeps track of all rebels for TF2 Jailbreak.",
	version = "1.0.0",
	url = "https://github.com/SkyGuardian"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("tf2jail2_rebels");

	CreateNative("TF2Jail2_IsRebel", Native_IsRebel);

	g_hForward_OnRebel_Post = CreateGlobalForward("TF2Jail2_OnRebel_Post", ET_Ignore, Param_Cell);

	g_bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Status = CreateConVar("sm_tf2jail2_rebels_status", "1", "Status of the plugin.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Announce = CreateConVar("sm_tf2jail2_rebels_announce", "1", "Announce to players once someone becomes a rebel.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_RebelTimer = CreateConVar("sm_tf2jail2_rebels_timer", "30.0", "Time to keep rebel on a client, resets on damage.", FCVAR_NOTIFY, true, 0.0);

	HookEvent("player_hurt", Event_OnPlayerHurt);
	HookEvent("player_death", Event_OnPlayerDeath_Pre, EventHookMode_Pre);
}

public void OnConfigsExecuted()
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	if (g_bLate)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				OnClientPutInServer(i);
			}
		}

		g_bLate = false;
	}
}

public void OnClientPutInServer(int client)
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	g_bIsMarkedRebel[client] = false;
	delete g_hRebelTimer[client];
}

public void OnClientDisconnect(int client)
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	g_bIsMarkedRebel[client] = false;
	delete g_hRebelTimer[client];
}

//////////////////////////////////////////////////
//Events

public Action Event_OnPlayerDeath_Pre(Event event, const char[] name, bool dontBroadcast)
{
	int userid = GetEventInt(event, "userid");
	int userid_attacker = GetEventInt(event, "attacker");

	int client = GetClientOfUserId(userid);
	int attacker = GetClientOfUserId(userid_attacker);

	if (!GetConVarBool(convar_Status) || !IsPlayerIndex(client) || !IsPlayerIndex(attacker))
	{
		return Plugin_Continue;
	}

	TFTeam team = TF2_GetClientTeam(client);
	TFTeam team_attacker = TF2_GetClientTeam(attacker);

	if (team_attacker == TFTeam_Red && team == TFTeam_Blue)
	{
		SetEventBroadcast(event, true);
	}

	return Plugin_Continue;
}

public void Event_OnPlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int userid = GetEventInt(event, "userid");
	int userid_attacker = GetEventInt(event, "attacker");

	int client = GetClientOfUserId(userid);
	int attacker = GetClientOfUserId(userid_attacker);

	if (!GetConVarBool(convar_Status) || !IsPlayerIndex(client) || !IsPlayerIndex(attacker))
	{
		return;
	}

	TFTeam team = TF2_GetClientTeam(client);
	TFTeam team_attacker = TF2_GetClientTeam(attacker);

	if (team_attacker == TFTeam_Red && team == TFTeam_Blue)
	{
		MarkRebel(attacker);
	}
}

void MarkRebel(int client)
{
	if (!g_bIsMarkedRebel[client])
	{
		SetEntityRenderColor(client, 10, 91, 45, 255);
		AttachParticle(client, "unusual_zap_green", GetConVarFloat(convar_RebelTimer), "effect_hand_R");
		g_bIsMarkedRebel[client] = true;
		CPrintToChat(client, "%s You have been marked as a rebel.", g_sGlobalTag);

		if (GetConVarBool(convar_Announce))
		{
			CPrintToChatAll("%s {mediumslateblue}%N {default}has been marked as a Rebel!", g_sGlobalTag, client);
		}

		Call_StartForward(g_hForward_OnRebel_Post);
		Call_PushCell(client);
		Call_Finish();
	}

	delete g_hRebelTimer[client];
	g_hRebelTimer[client] = CreateTimer(GetConVarFloat(convar_RebelTimer), Timer_DisableRebel, GetClientUserId(client), TIMER_REPEAT);
}

//////////////////////////////////////////////////
//Timers

public Action Timer_DisableRebel(Handle timer, any data)
{
	int client = GetClientOfUserId(data);

	if (!GetConVarBool(convar_Status))
	{
		g_hRebelTimer[client] = null;
		return Plugin_Stop;
	}

	SetEntityRenderColor(client, 255, 255, 255, 255);
	g_bIsMarkedRebel[client] = false;

	g_hRebelTimer[client] = null;
	return Plugin_Stop;
}

//////////////////////////////////////////////////
//Natives

public int Native_IsRebel(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return g_bIsMarkedRebel[client];
}

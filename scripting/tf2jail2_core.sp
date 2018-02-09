//Pragma
#pragma semicolon 1
#include <tf2items>
#pragma newdecls required

//Defines
#define IS_PLUGIN

//Sourcemod Includes
#include <sourcemod>
#include <tf2_stocks>

//External Includes
#include <sourcemod-misc>
#include <colorvariables>

//Required Includes
//#include <voiceannounce_ex>
#include <tf2items>
#include <tf2attributes>

//Our Includes
#include <tf2jail2/tf2jail2_core>

#undef REQUIRE_PLUGIN
#include <tf2jail2/tf2jail2_bans>
#include <tf2jail2/tf2jail2_lastrequests>
#define REQUIRE_PLUGIN

//ConVars
ConVar convar_Status;

//Globals
Handle g_hTimerHud;
int g_iTimer;
Handle g_hTimer;
//bool bHasSpeaked[MAXPLAYERS + 1];

Handle g_hudSpyNames;

//////////////////////////////////////////////////
//Info

public Plugin myinfo =
{
	name = "[TF2Jail2] Module: Core",
	author = "Keith Warren (Sky Guardian)",
	description = "The core systems for TF2 Jailbreak.",
	version = "1.0.0",
	url = "https://github.com/SkyGuardian"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("tf2jail2_core");

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Status = CreateConVar("sm_tf2jail2_core_status", "1", "Status of the plugin.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	g_hTimerHud = CreateHudSynchronizer();

	HookEvent("teamplay_round_start", Event_OnRoundStart);
	HookEvent("arena_round_start", Event_OnRoundActive);
	HookEvent("teamplay_round_active", Event_OnRoundActive);
	HookEvent("teamplay_round_win", Event_OnRoundEnd);
	HookEvent("player_spawn", Event_OnPlayerSpawn);

	AddCommandListener(Listener_OnTeamChange, "jointeam");

	g_hudSpyNames = CreateHudSynchronizer();

	RegAdminCmd("sm_testtextformat", Command_TestTextFormat, ADMFLAG_ROOT);
	RegAdminCmd("sm_holyshit", Command_HolyShit, ADMFLAG_ROOT);
}

public void OnMapStart()
{
	SetConVarInt(FindConVar("mp_stalemate_enable"), 0);
	SetConVarInt(FindConVar("tf_arena_use_queue"), 0);
	SetConVarInt(FindConVar("mp_teams_unbalance_limit"), 0);
	SetConVarInt(FindConVar("mp_autoteambalance"), 0);
	SetConVarInt(FindConVar("tf_arena_first_blood"), 0);
	SetConVarInt(FindConVar("mp_scrambleteams_auto"), 0);
	SetConVarInt(FindConVar("phys_pushscale"), 1000);
	SetConVarInt(FindConVar("mp_autoteambalance"), 0);
}

public Action Command_TestTextFormat(int client, int args)
{
	CPrintToChatAll("%s {mediumslateblue}%N {default}is testing the format system for text and custom colors.", g_sGlobalTag, client);
	return Plugin_Handled;
}

public Action Command_HolyShit(int client, int args)
{
	for (int i = 0; i < 15; i++)
	{
		float vecRandom[3];
		GetRandomPostion(vecRandom);

		int Medipack = CreateEntityByName("item_healthkit_full");
		DispatchKeyValue(Medipack, "OnPlayerTouch", "!self,Kill,,0,-1");

		if (DispatchSpawn(Medipack))
		{
			SetEntProp(Medipack, Prop_Send, "m_iTeamNum", 0, 4);
			TeleportEntity(Medipack, vecRandom, NULL_VECTOR, NULL_VECTOR);
			EmitSoundToAll("items/spawn_item.wav", Medipack, _, _, _, 0.75);
		}
	}

	PrintToChatAll("done");
	return Plugin_Handled;
}

void GetRandomPostion(float result[3])
{
	float vWorldMins[3]; float vWorldMaxs[3];
	GetEntPropVector(0, Prop_Data, "m_WorldMins", vWorldMins);
	GetEntPropVector(0, Prop_Data, "m_WorldMaxs", vWorldMaxs);

	// if you need change height, edit here
	vWorldMins[2] = 10.0, vWorldMaxs[2] = 20.0;

	__GetRandomPostion(result, vWorldMins, vWorldMaxs);
}

void __GetRandomPostion(float result[3], float mins[3], float maxs[3])
{
	result[0] = GetRandomFloat(mins[0], maxs[0]);
	result[1] = GetRandomFloat(mins[1], maxs[1]);
	result[2] = GetRandomFloat(mins[2], maxs[2]);

	if (TR_PointOutsideWorld(result))
	{
		__GetRandomPostion(result, mins, maxs);
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (client == 0 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client) || IsFakeClient(client))
	{
		return Plugin_Continue;
	}

	int target = GetClientAimTarget(client, true);

	if (target != -1)
	{
		SetHudTextParams(-1.0, -1.0, 0.05, 255, 00, 0, 255, 0, 0.0, 0.0, 0.0);
		ShowSyncHudText(client, g_hudSpyNames, "%s: %N", TF2_GetClientTeam(target) == TFTeam_Blue ? "Guard" : "Prisoner", target);
	}
	else
	{
		ClearSyncHud(client, g_hudSpyNames);
	}

	return Plugin_Continue;
}

public void OnMapEnd()
{
	g_hTimer = null;
}

public void OnConfigsExecuted()
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}
}

public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			ClearSyncHud(i, g_hudSpyNames);
		}
	}
}

/*public void OnClientSpeakingEx(int client)
{
bHasSpeaked[client] = true;
}*/

public void OnClientDisconnect(int client)
{
	//bHasSpeaked[client] = false;
}

public void Event_OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			CancelClientMenu(i, true);
		}
	}

	g_iTimer = 0;
	KillTimerSafe(g_hTimer);
}

public Action Timer_Ratios(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
		{
			continue;
		}

		float Ratio = float(TF2_GetTeamClientCount(TFTeam_Blue)) / float(TF2_GetTeamClientCount(TFTeam_Red));

		if (Ratio <= 0.5)
		{
			break;
		}

		if (IsClientInGame(i) && TF2_GetClientTeam(i) == TFTeam_Blue)
		{
			TF2_ChangeClientTeam(i, TFTeam_Red);
			TF2_RespawnPlayer(i);

			CPrintToChat(i, "%s You have been moved for balance.", g_sGlobalTag);
		}
	}
}

int TF2_GetTeamClientCount(TFTeam team)
{
	int value = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && TF2_GetClientTeam(i) == team)
		{
			value++;
		}
	}

	return value;
}

public void Event_OnRoundActive(Event event, const char[] name, bool dontBroadcast)
{
	g_iTimer = 480;

	KillTimerSafe(g_hTimer);
	g_hTimer = CreateTimer(1.0, Timer_ShowTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	if (GetClientCount(true) >= 3)
	{
		CreateTimer(1.0, Timer_Ratios, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		CPrintToChatAll("%s Autobalance is disabled this round. (3 players required)", g_sGlobalTag);
	}
}

public Action Timer_ShowTimer(Handle timer, any data)
{
	g_iTimer--;

	SetHudTextParams(-1.0, 0.3, 1.1, 20, 200, 255, 255);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			ShowSyncHudText(i, g_hTimerHud, "%02d:%02d", g_iTimer / 60, g_iTimer % 60);
		}
	}

	if (g_iTimer <= 0)
	{
		TF2_ForceRoundWin(TFTeam_Blue);

		g_hTimer = null;
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public void Event_OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_iTimer = 0;
	KillTimerSafe(g_hTimer);

	SetConVarBool(FindConVar("mp_friendlyfire"), false);
	SetConVarBool(FindConVar("tf_avoidteammates_pushaway"), false);
}

public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!GetConVarBool(convar_Status) || !IsPlayerIndex(client))
	{
		return;
	}

	TFTeam team = TF2_GetClientTeam(client);

	if (team == TFTeam_Red)
	{
		RequestFrame(Frame_KillWeapons, client);
		TF2Attrib_SetByName(client, "no double jump", 1.0);
	}
	else if (team == TFTeam_Blue)
	{
		TF2Attrib_RemoveByName(client, "no double jump");
	}
}

public void Frame_KillWeapons(any data)
{
	int client = data;

	bool sandvich;
	for (int i = 0; i < 2; i++)
	{
		int weapon = GetPlayerWeaponSlot(client, i);

		if (IsValidEntity(weapon))
		{
			char sWeapon[MAX_NAME_LENGTH];

			if (StrEqual(sWeapon, "tf_weapon_lunchbox"))
			{
				sandvich = true;
				continue;
			}

			SetPlayerWeaponAmmo(client, weapon, 0, 0);
		}
	}

	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Grenade);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Building);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_PDA);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Item1);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Item2);

	int melee = GetPlayerWeaponSlot(client, sandvich ? 1 : 2);

	if (IsValidEntity(melee))
	{
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", melee);
	}

	TF2Attrib_SetByName(client, "effect bar recharge rate increased", 0.75);
	TF2Attrib_SetByName(client, "mod see enemy health", 1.0);
}

public Action Listener_OnTeamChange(int client, const char[] command, int argc)
{
	char sNewTeam[4];
	GetCmdArg(1, sNewTeam, sizeof(sNewTeam));
	TFTeam new_team = view_as<TFTeam>(StringToInt(sNewTeam));

	if (new_team == TFTeam_Blue && TF2Jail2_IsGuardBanned(client))
	{
		CPrintToChat(client, "%s {red}ERROR: {default}You are currently banned from Guards, please contact an administrator for assistance.", g_sGlobalTag);
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "tf_ammo_pack") || StrEqual(classname, "tf_dropped_weapon") || StrEqual(classname, "halloween_souls_pack"))
	{
		AcceptEntityInput(entity, "Kill");
	}
}

public void TF2_OnConditionAdded(int client, TFCond condition)
{
	if (condition == TFCond_Charging && TF2_GetClientTeam(client) == TFTeam_Red)
	{
		TF2_RemoveCondition(client, condition);
	}
}

public int TF2Items_OnGiveNamedItem_Post(int client, char[] classname, int itemDefinitionIndex, int itemLevel, int itemQuality, int entityIndex)
{
	bool bRemove;
	switch (itemDefinitionIndex)
	{
		case 142, 58, 264, 589: bRemove = true;
	}

	if (bRemove && IsValidEntity(entityIndex))
	{
		Handle trie = CreateTrie();
		SetTrieValue(trie, "client", client);
		SetTrieValue(trie, "itemDefinitionIndex", itemDefinitionIndex);
		SetTrieValue(trie, "entityIndex", entityIndex);

		CreateTimer(0.01, Timer_ReplaceWeapon, trie);
	}
}

public Action Timer_ReplaceWeapon(Handle timer, any data)
{
	int entityIndex = -1;
	GetTrieValue(data, "entityIndex", entityIndex);

	int client = -1;
	GetTrieValue(data, "client", client);

	int iItemDefinitionIndex = -1;
	GetTrieValue(data, "itemDefinitionIndex", iItemDefinitionIndex);

	CloseHandle(data);

	if (IsValidEntity(entityIndex))
	{
		int iSlot = GetWeaponSlot(client, entityIndex);

		RemovePlayerItem(client, entityIndex);
		AcceptEntityInput(entityIndex, "Kill");

		GiveReplacementItem(client, iSlot);
	}
}

void GiveReplacementItem(int client, int iSlot)
{
	TFClassType tfclass = TF2_GetPlayerClass(client);

	char sWeaponClassName[128];
	if (GetDefaultWeaponForClass(tfclass, iSlot, sWeaponClassName, sizeof(sWeaponClassName)))
	{
		int iOverrideIDI = GetDefaultIDIForClass(tfclass, iSlot);

		Handle hItem = TF2Items_CreateItem(OVERRIDE_CLASSNAME | OVERRIDE_ITEM_DEF | OVERRIDE_ITEM_LEVEL | OVERRIDE_ITEM_QUALITY | OVERRIDE_ATTRIBUTES);
		TF2Items_SetClassname(hItem, sWeaponClassName);
		TF2Items_SetItemIndex(hItem, iOverrideIDI);
		TF2Items_SetLevel(hItem, 1);
		TF2Items_SetQuality(hItem, 6);
		TF2Items_SetNumAttributes(hItem, 0);

		int iWeapon = TF2Items_GiveNamedItem(client, hItem);
		CloseHandle(hItem);

		EquipPlayerWeapon(client, iWeapon);
		SetPlayerWeaponAmmo(client, iWeapon, 0, 0);
	}
}

stock bool GetDefaultWeaponForClass(TFClassType xClass, int iSlot, char[] sOutput, int maxlen) {
	switch(xClass) {
		case TFClass_Scout: {
			switch(iSlot) {
				case 0: { Format(sOutput, maxlen, "tf_weapon_scattergun"); return true; }
				case 1: { Format(sOutput, maxlen, "tf_weapon_pistol_scout"); return true; }
				case 2: { Format(sOutput, maxlen, "tf_weapon_bat"); return true; }
			}
		}
		case TFClass_Sniper: {
			switch(iSlot) {
				case 0: { Format(sOutput, maxlen, "tf_weapon_sniperrifle"); return true; }
				case 1: { Format(sOutput, maxlen, "tf_weapon_smg"); return true; }
				case 2: { Format(sOutput, maxlen, "tf_weapon_club"); return true; }
			}
		}
		case TFClass_Soldier: {
			switch(iSlot) {
				case 0: { Format(sOutput, maxlen, "tf_weapon_rocketlauncher"); return true; }
				case 1: { Format(sOutput, maxlen, "tf_weapon_shotgun_soldier"); return true; }
				case 2: { Format(sOutput, maxlen, "tf_weapon_shovel"); return true; }
			}
		}
		case TFClass_DemoMan: {
			switch(iSlot) {
				case 0: { Format(sOutput, maxlen, "tf_weapon_grenadelauncher"); return true; }
				case 1: { Format(sOutput, maxlen, "tf_weapon_pipebomblauncher"); return true; }
				case 2: { Format(sOutput, maxlen, "tf_weapon_bottle"); return true; }
			}
		}
		case TFClass_Medic: {
			switch(iSlot) {
				case 0: { Format(sOutput, maxlen, "tf_weapon_syringegun_medic"); return true; }
				case 1: { Format(sOutput, maxlen, "tf_weapon_medigun"); return true; }
				case 2: { Format(sOutput, maxlen, "tf_weapon_bonesaw"); return true; }
			}
		}
		case TFClass_Heavy: {
			switch(iSlot) {
				case 0: { Format(sOutput, maxlen, "tf_weapon_minigun"); return true; }
				case 1: { Format(sOutput, maxlen, "tf_weapon_shotgun_hwg"); return true; }
				case 2: { Format(sOutput, maxlen, "tf_weapon_fists"); return true; }
			}
		}
		case TFClass_Pyro: {
			switch(iSlot) {
				case 0: { Format(sOutput, maxlen, "tf_weapon_flamethrower"); return true; }
				case 1: { Format(sOutput, maxlen, "tf_weapon_shotgun_pyro"); return true; }
				case 2: { Format(sOutput, maxlen, "tf_weapon_fireaxe"); return true; }
			}
		}
		case TFClass_Spy: {
			switch(iSlot) {
				case 0: { Format(sOutput, maxlen, "tf_weapon_revolver"); return true; }
				case 1: { Format(sOutput, maxlen, "tf_weapon_builder"); return true; }
				case 2: { Format(sOutput, maxlen, "tf_weapon_knife"); return true; }
				case 4: { Format(sOutput, maxlen, "tf_weapon_invis"); return true; }
			}
		}
		case TFClass_Engineer: {
			switch(iSlot) {
				case 0: { Format(sOutput, maxlen, "tf_weapon_shotgun_primary"); return true; }
				case 1: { Format(sOutput, maxlen, "tf_weapon_pistol"); return true; }
				case 2: { Format(sOutput, maxlen, "tf_weapon_wrench"); return true; }
				case 3: { Format(sOutput, maxlen, "tf_weapon_pda_engineer_build"); return true; }
			}
		}
	}

	Format(sOutput, maxlen, "");
	return false;
}

stock int GetDefaultIDIForClass(TFClassType xClass, int iSlot)
{
	switch(xClass) {
		case TFClass_Scout: {
			switch(iSlot) {
				case 0: { return 13; }
				case 1: { return 23; }
				case 2: { return 0; }
			}
		}
		case TFClass_Sniper: {
			switch(iSlot) {
				case 0: { return 14; }
				case 1: { return 16; }
				case 2: { return 3; }
			}
		}
		case TFClass_Soldier: {
			switch(iSlot) {
				case 0: { return 18; }
				case 1: { return 10; }
				case 2: { return 6; }
			}
		}
		case TFClass_DemoMan: {
			switch(iSlot) {
				case 0: { return 19; }
				case 1: { return 20; }
				case 2: { return 1; }
			}
		}
		case TFClass_Medic: {
			switch(iSlot) {
				case 0: { return 17; }
				case 1: { return 29; }
				case 2: { return 8; }
			}
		}
		case TFClass_Heavy: {
			switch(iSlot) {
				case 0: { return 15; }
				case 1: { return 11; }
				case 2: { return 5; }
			}
		}
		case TFClass_Pyro: {
			switch(iSlot) {
				case 0: { return 21; }
				case 1: { return 12; }
				case 2: { return 2; }
			}
		}
		case TFClass_Spy: {
			switch(iSlot) {
				case 0: { return 24; }
				case 1: { return 735; }
				case 2: { return 4; }
				case 4: { return 30; }
			}
		}
		case TFClass_Engineer: {
			switch(iSlot) {
				case 0: { return 9; }
				case 1: { return 22; }
				case 2: { return 7; }
				case 3: { return 25; }
			}
		}
	}

	return -1;
}

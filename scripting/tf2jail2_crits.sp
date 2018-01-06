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
//#include <tf2jail2/tf2jail2_crits>

#undef REQUIRE_PLUGIN
#include <tf2jail2/tf2jail2_core>
#include <tf2jail2/tf2jail2_warden>
#define REQUIRE_PLUGIN

//ConVars
ConVar convar_Status;
ConVar convar_WardenCrits;
ConVar convar_BlueCrits;

//Globals

//////////////////////////////////////////////////
//Info

public Plugin myinfo =
{
	name = "[TF2Jail2] Module: Crits",
	author = "Keith Warren (Sky Guardian)",
	description = "A basic criticals module for TF2 Jailbreak.",
	version = "1.0.0",
	url = "https://github.com/SkyGuardian"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Status = CreateConVar("sm_tf2jail2_crits_status", "1", "Status of the plugin.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_WardenCrits = CreateConVar("sm_tf2jail2_crits_warden", "1", "Always enable crits for Warden.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_BlueCrits = CreateConVar("sm_tf2jail2_crits_blue", "1", "Always enable crits for Blue.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
	}
}

public void OnConfigsExecuted()
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponSwitchPost, Hook_OnWeaponSwitchPost);
	//SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
}

public void Hook_OnWeaponSwitchPost(int client, int weapon)
{
	char sClass[MAX_NAME_LENGTH];
	GetEntityClassname(weapon, sClass, sizeof(sClass));

	if (TF2_GetClientTeam(client) == TFTeam_Blue && TF2_GetPlayerClass(client) == TFClass_Pyro)
	{
		if (StrEqual(sClass, "tf_weapon_flamethrower"))
		{
			TF2_AddCondition(client, TFCond_CritCola, 99999.0);
		}
		else
		{
			TF2_RemoveCondition(client, TFCond_CritCola);
		}
	}
}

/*public Action Hook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (victim == 0 || victim > MaxClients || attacker == 0 || attacker > MaxClients)
	{
		return Plugin_Continue;
	}

	SetEntityHealth(victim, 300);
	return Plugin_Changed;
}*/

public void TF2Jail2_OnWardenSet_Post(int warden, int admin)
{
	if (GetConVarBool(convar_Status) && GetConVarBool(convar_WardenCrits))
	{
		TF2_AddCondition(warden, TFCond_Kritzkrieged, 99999.0);
	}
}

public void TF2Jail2_OnWardenRemoved_Post(int old_warden, int admin)
{
	if (GetConVarBool(convar_Status) && GetConVarBool(convar_WardenCrits))
	{
		TF2_RemoveCondition(old_warden, TFCond_Kritzkrieged);
	}
}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool &result)
{
	if (GetConVarBool(convar_BlueCrits) && TF2_GetClientTeam(client) == TFTeam_Blue && TF2Jail2_GetWarden() != client)
	{
		if (StrEqual(weaponname, "tf_weapon_rocketlauncher") && GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") != 127)
		{
			result = false;
			return Plugin_Changed;
		}

		if (StrEqual(weaponname, "tf_weapon_grenadelauncher") || StrEqual(weaponname, "tf_weapon_minigun") || StrEqual(weaponname, "tf_weapon_pipebomblauncher"))
		{
			result = false;
			return Plugin_Changed;
		}

		if (TF2_GetPlayerClass(client) == TFClass_Pyro)
		{
			int active = GetPlayerWeaponSlot(client, 2);
			result = active == weapon ? true : false;
			return Plugin_Changed;
		}

		result = true;
		return Plugin_Changed;
	}

	if (TF2_GetClientTeam(client) == TFTeam_Red)
	{
		result = false;
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

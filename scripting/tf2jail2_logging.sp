//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines

//Sourcemod Includes
#include <sourcemod>

//External Includes
#include <sourcemod-misc>
#include <colorvariables>

//Our Includes
//#include <tf2jail2/tf2jail2_logging>

#undef REQUIRE_PLUGIN
#include <tf2jail2/tf2jail2_core>
#include <tf2jail2/tf2jail2_freekillers>
#include <tf2jail2/tf2jail2_rebels>
#include <tf2jail2/tf2jail2_warden>
#define REQUIRE_PLUGIN

//ConVars
ConVar convar_Status;
ConVar convar_Path;

//Globals

//////////////////////////////////////////////////
//Info

public Plugin myinfo =
{
	name = "[TF2Jail2] Module: Logging",
	author = "Keith Warren (Sky Guardian)",
	description = "A simple logging module for TF2 Jailbreak.",
	version = "1.0.0",
	url = "https://github.com/SkyGuardian"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Status = CreateConVar("sm_tf2jail2_logging_status", "1", "Status of the plugin.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Path = CreateConVar("sm_tf2jail2_logging_path", "logs/tf2jail2/", "Location of the logs folder.", FCVAR_NOTIFY);
}

public void OnConfigsExecuted()
{

}

//////////////////////////////////////////////////
//TF2Jail2 Forwards

public void TF2Jail2_OnWardenSet_Post(int warden, int admin)
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	char sAdmin[512];

	if (admin != -1)
	{
		FormatEx(sAdmin, sizeof(sAdmin), " by %N", admin);
	}

	TF2Jail2_Log("tf2jail2_wardens", "%N has been set to Warden%s.", warden, strlen(sAdmin) > 0 ? sAdmin : "");
}

public void TF2Jail2_OnWardenRemoved_Post(int old_warden, int admin)
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	char sAdmin[512];

	if (admin != -1)
	{
		FormatEx(sAdmin, sizeof(sAdmin), " by %N", admin);
	}

	TF2Jail2_Log("tf2jail2_wardens", "%N has been removed from Warden%s.", old_warden, strlen(sAdmin) > 0 ? sAdmin : "");
}

public void TF2Jail2_OnRebel_Post(int client)
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	TF2Jail2_Log("tf2jail2_rebels", "%N has been marked as a Rebel.", client);
}

public void TF2Jail2_OnMarkedFreekiller_Post(int admin, int marked)
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	TF2Jail2_Log("tf2jail2_freekillers", "%N has marked %N as a Freekiller.", admin, marked);
}

public void TF2Jail2_OnReportedFreekiller_Post(int reporter, int reported)
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	TF2Jail2_Log("tf2jail2_freekillers", "%N has been reported as a Freekiller by %N.", reported, reporter);
}

//////////////////////////////////////////////////
//Stocks

void TF2Jail2_Log(const char[] file, const char[] format, any ...)
{
	if (strlen(file) == 0)
	{
		return;
	}

	char sLocation[PLATFORM_MAX_PATH];
	GetConVarString(convar_Path, sLocation, sizeof(sLocation));

	if (strlen(sLocation) == 0)
	{
		return;
	}

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), sLocation);

	if (!DirExists(sPath))
	{
		CreateDirectory(sPath, 511);
	}

	char sFile[PLATFORM_MAX_PATH];
	Format(sFile, sizeof(sFile), "%s/%s.log", sPath, file);

	char sBuffer[1024];
	VFormat(sBuffer, sizeof(sBuffer), format, 3);

	LogToFileEx(sFile, sBuffer);
}

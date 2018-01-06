#if defined _tf2jail2_lastrequests_included
  #endinput
#endif
#define _tf2jail2_lastrequests_included

//Typedefs
typedef TF2Jail2_Func_OnLRChosen = function void (int client);
typedef TF2Jail2_Func_OnLRRoundStart = function void (int client);
typedef TF2Jail2_Func_OnLRRoundActive = function void (int client);
typedef TF2Jail2_Func_OnLRRoundEnd = function void (int client);

//Defines

//Natives
native bool TF2Jail2_RegisterLR(char[] name, TF2Jail2_Func_OnLRChosen onlrchosen = INVALID_FUNCTION, TF2Jail2_Func_OnLRRoundStart onlrroundstart = INVALID_FUNCTION, TF2Jail2_Func_OnLRRoundActive onlrroundactive = INVALID_FUNCTION, TF2Jail2_Func_OnLRRoundEnd onlrroundend = INVALID_FUNCTION);
native void TF2Jail2_ExecuteLR(int client, const char[] name);
native void TF2Jail2_GiveLR(int client);
native bool TF2Jail2_IsFreeday(int client);
native bool TF2Jail2_IsPendingFreeday(int client);
native void TF2Jail2_GetCurrentLR(char[] last_request, int size);

//Forwards
forward void TF2Jail2_OnlastRequestRegistrations();

//Info
#if !defined REQUIRE_PLUGIN
public void __pl_tf2jail2_lastrequests_SetNTVOptional()
{
	MarkNativeAsOptional("TF2Jail2_RegisterLR");
	MarkNativeAsOptional("TF2Jail2_ExecuteLR");
	MarkNativeAsOptional("TF2Jail2_GiveLR");
	MarkNativeAsOptional("TF2Jail2_IsFreeday");
	MarkNativeAsOptional("TF2Jail2_IsPendingFreeday");
	MarkNativeAsOptional("TF2Jail2_GetCurrentLR");
}
#endif

public SharedPlugin __pl_tf2jail2_lastrequests =
{
	name = "tf2jail2_lastrequests",
	file = "tf2jail2_lastrequests.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

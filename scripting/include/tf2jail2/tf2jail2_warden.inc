#if defined _tf2jail2_warden_included
  #endinput
#endif
#define _tf2jail2_warden_included

//Defines
#define NO_WARDEN 0

//Natives
native bool TF2Jail2_IsWardenActive();
native int TF2Jail2_GetWarden();
native void TF2Jail2_SetWarden(int client, int admin);
native void TF2Jail2_RemoveWarden(int admin, bool announce = true);
native bool TF2Jail2_IsWardenLocked();
native void TF2Jail2_LockWarden(bool status);
native void TF2Jail2_EndWardenPhase();
native void TF2Jail2_NoWardenPhase();

//Forwards
forward void TF2Jail2_OnWardenSet_Post(int warden, int admin);
forward void TF2Jail2_OnWardenRemoved_Post(int old_warden, int admin);
forward void TF2Jail2_OnWardenPhaseEnd_Post(int warden);

//Info
#if !defined REQUIRE_PLUGIN
public void __pl_tf2jail2_warden_SetNTVOptional()
{
	MarkNativeAsOptional("TF2Jail2_IsWardenActive");
	MarkNativeAsOptional("TF2Jail2_GetWarden");
	MarkNativeAsOptional("TF2Jail2_SetWarden");
	MarkNativeAsOptional("TF2Jail2_RemoveWarden");
	MarkNativeAsOptional("TF2Jail2_IsWardenLocked");
	MarkNativeAsOptional("TF2Jail2_LockWarden");
	MarkNativeAsOptional("TF2Jail2_EndWardenPhase");
	MarkNativeAsOptional("TF2Jail2_NoWardenPhase");
}
#endif

public SharedPlugin __pl_tf2jail2_warden =
{
	name = "tf2jail2_warden",
	file = "tf2jail2_warden.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

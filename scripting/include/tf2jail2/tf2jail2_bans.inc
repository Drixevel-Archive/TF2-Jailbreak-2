#if defined _tf2jail2_bans_included
  #endinput
#endif
#define _tf2jail2_bans_included

//Defines

//Natives
native void TF2Jail2_IsWardenBanned(int client);
native void TF2Jail2_IsGuardBanned(int client);
native void TF2Jail2_BanFromWarden(int client, int target, char[] reason);
native void TF2Jail2_BanFromGuard(int client, int target, char[] reason);

//Forwards

//Info
#if !defined REQUIRE_PLUGIN
public void __pl_tf2jail2_bans_SetNTVOptional()
{
	MarkNativeAsOptional("TF2Jail2_IsWardenBanned");
	MarkNativeAsOptional("TF2Jail2_IsGuardBanned");
	MarkNativeAsOptional("TF2Jail2_BanFromWarden");
	MarkNativeAsOptional("TF2Jail2_BanFromGuard");
}
#endif

public SharedPlugin __pl_tf2jail2_bans =
{
	name = "tf2jail2_bans",
	file = "tf2jail2_bans.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

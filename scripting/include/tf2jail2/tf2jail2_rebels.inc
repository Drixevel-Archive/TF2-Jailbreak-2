#if defined _tf2jail2_rebels_included
  #endinput
#endif
#define _tf2jail2_rebels_included

//Defines

//Natives
native bool TF2Jail2_IsRebel(int client);

//Forwards
forward void TF2Jail2_OnRebel_Post(int client);

//Info
#if !defined REQUIRE_PLUGIN
public void __pl_tf2jail2_rebels_SetNTVOptional()
{
	MarkNativeAsOptional("TF2Jail2_IsRebel");
}
#endif

public SharedPlugin __pl_tf2jail2_rebels =
{
	name = "tf2jail2_rebels",
	file = "tf2jail2_rebels.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

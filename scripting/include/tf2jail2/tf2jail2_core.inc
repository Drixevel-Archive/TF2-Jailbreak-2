#if defined _tf2jail2_core_included
  #endinput
#endif
#define _tf2jail2_core_included

stock char g_sGlobalTag[] = "{gold}[TF2Jail2]{default}";

//Defines

//Natives

//Forwards

//Info
#if !defined REQUIRE_PLUGIN
public void __pl_tf2jail2_core_SetNTVOptional()
{
	//MarkNativeAsOptional("TF2Jail2_IsWardenActive");
}
#endif

public SharedPlugin __pl_tf2jail2_core =
{
	name = "tf2jail2_core",
	file = "tf2jail2_core.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

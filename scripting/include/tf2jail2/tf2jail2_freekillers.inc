#if defined _tf2jail2_freekillers_included
  #endinput
#endif
#define _tf2jail2_freekillers_included

//Defines

//Natives

//Forwards
forward void TF2Jail2_OnMarkedFreekiller_Post(int admin, int marked);
forward void TF2Jail2_OnReportedFreekiller_Post(int reporter, int reported);

//Info
#if !defined REQUIRE_PLUGIN
public void __pl_tf2jail2_freekillers_SetNTVOptional()
{
	//MarkNativeAsOptional("");
}
#endif

public SharedPlugin __pl_tf2jail2_freekillers =
{
	name = "tf2jail2_freekillers",
	file = "tf2jail2_freekillers.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

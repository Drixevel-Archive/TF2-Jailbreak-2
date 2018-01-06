#if defined _tf2jail2_maptriggers_included
  #endinput
#endif
#define _tf2jail2_maptriggers_included

//Defines

//Natives
native void TF2Jail2_ToggleCells(int client, bool verbose = true, bool force = false);
native void TF2Jail2_OpenCells(int client, bool verbose = true, bool force = false);
native void TF2Jail2_CloseCells(int client, bool verbose = true, bool force = false);
native bool TF2Jail2_CellsStatus();
native bool TF2Jail2_ToggleCellsAccess(int client, bool verbose = true);
native bool TF2Jail2_LockCells(int client, bool verbose = true);
native bool TF2Jail2_UnlockCells(int client, bool verbose = true);
native void TF2Jail2_ToggleMedicStations(bool toggle = false);
native void TF2Jail2_ToggleHealthKits(bool toggle = false);
native void TF2Jail2_ToggleAmmoPacks(bool toggle = false);

//Forwards

//Info
#if !defined REQUIRE_PLUGIN
public void __pl_tf2jail2_maptriggers_SetNTVOptional()
{
	MarkNativeAsOptional("TF2Jail2_ToggleCells");
	MarkNativeAsOptional("TF2Jail2_OpenCells");
	MarkNativeAsOptional("TF2Jail2_CloseCells");
	MarkNativeAsOptional("TF2Jail2_CellsStatus");
	MarkNativeAsOptional("TF2Jail2_ToggleCellsAccess");
	MarkNativeAsOptional("TF2Jail2_LockCells");
	MarkNativeAsOptional("TF2Jail2_UnlockCells");
	MarkNativeAsOptional("TF2Jail2_ToggleMedicStations");
	MarkNativeAsOptional("TF2Jail2_ToggleHealthKits");
	MarkNativeAsOptional("TF2Jail2_ToggleAmmoPacks");
}
#endif

public SharedPlugin __pl_tf2jail2_maptriggers =
{
	name = "tf2jail2_maptriggers",
	file = "tf2jail2_maptriggers.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

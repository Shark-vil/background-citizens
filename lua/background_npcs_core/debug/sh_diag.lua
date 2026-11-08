--[[
	Testing mode (Settings -> Tools -> Testing, console "bgn_test"): checks that actors spawn, stay alive and
	behave, that cars work, and that a player can change server settings. Server runner: sv_diag.lua,
	camera and the results window: cl_diag.lua. Docs: docs/systems/testing.md

	Two cvars exist only for the settings test (they change nothing else):
		bgn_test_server_value  a server setting, changed through the same path as every settings window row
		bgn_cl_test_value      a client setting of this player
--]]

bgNPC.Diag = bgNPC.Diag or {}

bgNPC.CVars.Register('bgn_test_server_value', 0, 'Testing mode: a server value used to check that settings can be changed.')

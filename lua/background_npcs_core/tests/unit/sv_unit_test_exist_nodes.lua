local snet = slib.Components.Network
local bgNPC = bgNPC
--

snet.Callback('bgn_sv_unit_test_exist_nodes', function(ply)
	local nodes = bgNPC.LoadRoutes()
	if #nodes ~= 0 then
		ply:ConCommand('bgn_unit_test_add_result "The movement mesh is not empty" "yes"')
	else
		ply:ConCommand('bgn_unit_test_add_result "The movement mesh is not empty" "no"')
	end
end).Protect()
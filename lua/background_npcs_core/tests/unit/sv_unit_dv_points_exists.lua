local snet = slib.Components.Network
--

snet.Callback('bgn_sv_unit_dv_points_exists', function(ply)
	local dvd = DecentVehicleDestination
	if not dvd then
		ply:ConCommand('bgn_unit_test_add_result "Addon - Decent Vehicle - not found" "no"')
	elseif not dvd.Waypoints or #dvd.Waypoints == 0 then
		ply:ConCommand('bgn_unit_test_add_result "The navmesh for DV cars has not been created" "no"')
	else
		ply:ConCommand('bgn_unit_test_add_result "There is a navmesh for DV cars" "yes"')
	end
end).Protect()
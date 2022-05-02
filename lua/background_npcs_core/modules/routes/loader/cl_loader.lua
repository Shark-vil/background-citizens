concommand.Add('cl_bgn_clear_tool_points', function()
	local wep = LocalPlayer():GetActiveWeapon()
	if not IsValid(wep) or wep:GetClass() ~= 'gmod_tool' then return end
	local tool = bgNPC:GetActivePlayerTool('bgn_point_editor')
	if not tool then return end
	tool:ClearPoints()
end)

concommand.Add('cl_citizens_load_route', function(ply)
	if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end
	snet.InvokeServer('bgn_movement_mesh_load')
end, nil, 'loads the displacement points. This is done automatically when the map is loaded, but if you want to update the points without rebooting, use this command.')

concommand.Add('cl_citizens_load_route_from_client', function(ply)
	if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end
	snet.InvokeServer('bgn_movement_mesh_load_from_client_sv')
end, nil, 'Technical command. Used to get an array of points from the server.')

local function LoadPointInfo(count)
	local ply = LocalPlayer()

	if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end

	bgNPC:Log('Client routes is loading! (' .. count .. ')', 'Route')

	if count == 0 then
		notification.AddLegacy(
			'[For admin] Mesh file not found. Background NPCs will not spawn.',
			NOTIFY_ERROR,
			4
		)
	else
		notification.AddLegacy(
			'[For admin] Loaded ' .. count .. ' mesh points to move and spawn Background NPCs.',
			NOTIFY_GENERIC,
			4
		)
	end
end

snet.Callback('bgn_movement_mesh_load_info', function(_, count)
	LoadPointInfo(count)
end).Protect()

snet.Callback('bgn_movement_mesh_load_from_client_cl', function(_, data_table)
	local newMap = BGN_NODE:JsonToMap(data_table)
	local count = table.Count(newMap)
	LoadPointInfo(count)
	BGN_NODE:SetMap(newMap)
	hook.Run('BGN_LoadingClientRoutes', BGN_NODE:GetMap())
end).Protect()
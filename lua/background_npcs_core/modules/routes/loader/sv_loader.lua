bgNPC.LoadRoutes = function()
	local map_name = game.GetMap()
	local jsonString = BGN_NODE:GetRouteFileData()
	hook.Run('BGN_PreLoadRoutes', map_name)

	BGN_NODE:ClearNodeMap()

	if jsonString then
		BGN_NODE:SetMap(BGN_NODE:JsonToMap(jsonString))
	end

	local count = BGN_NODE:CountNodesOnMap()
	bgNPC.Util.Log('Load citizens walk points - ' .. tostring(count), 'Route')
	hook.Run('BGN_PostLoadRoutes', map_name)

	return BGN_NODE:GetMap()
end

bgNPC.Net.Receive('bgn_movement_mesh_get_load_info', function(ply)
	bgNPC.Net.Send('bgn_movement_mesh_load_info', ply, BGN_NODE:CountNodesOnMap())
end, { admin = true })

bgNPC.Net.Receive('bgn_movement_mesh_load', function(ply)
	bgNPC.LoadRoutes()

	bgNPC.Net.Send('bgn_movement_mesh_load_info', ply, BGN_NODE:CountNodesOnMap())
end, { admin = true })

bgNPC.Net.Receive('bgn_movement_mesh_unload', function(ply)
	BGN_NODE:ClearNodeMap()

	bgNPC.Net.Send('bgn_movement_mesh_load_info', ply, BGN_NODE:CountNodesOnMap())
end, { admin = true })

bgNPC.Net.Receive('bgn_movement_mesh_load_from_client_sv', function(ply)
	-- if BGN_NODE:CountNodesOnMap() == 0 then
	-- 	bgNPC.LoadRoutes()
	-- end

	local jsonString = (BGN_NODE:RouteFileExists() and BGN_NODE:GetRouteFileData()) or (BGN_NODE:CountNodesOnMap() ~= 0 and BGN_NODE:MapToJson())
	-- local jsonString = BGN_NODE:GetRouteFileData()

	bgNPC.Net.Send('bgn_movement_mesh_load_from_client_cl', ply, jsonString)
end, { admin = true })

hook.Add('InitPostEntity', 'BGN_FirstInitializeRoutesOnMap', function()
	bgNPC.LoadRoutes()
end)
bgNPC.LoadRoutes = function()
	local map_name = game.GetMap()
	local jsonString = BGN_NODE:GetRouteFileData()
	hook.Run('BGN_PreLoadRoutes', map_name)

	BGN_NODE:ClearNodeMap()

	if jsonString then
		BGN_NODE:SetMap(BGN_NODE:JsonToMap(jsonString))
	end

	local count = BGN_NODE:CountNodesOnMap()
	bgNPC:Log('Load citizens walk points - ' .. tostring(count), 'Route')
	hook.Run('BGN_PostLoadRoutes', map_name)

	return BGN_NODE:GetMap()
end

snet.Callback('bgn_movement_mesh_get_load_info', function(ply)
	snet.Request('bgn_movement_mesh_load_info', BGN_NODE:CountNodesOnMap())
		.Invoke(ply)
end).Protect()

snet.Callback('bgn_movement_mesh_load', function(ply)
	bgNPC.LoadRoutes()

	snet.Request('bgn_movement_mesh_load_info', BGN_NODE:CountNodesOnMap())
		.Invoke(ply)
end).Protect()

snet.Callback('bgn_movement_mesh_unload', function(ply)
	BGN_NODE:ClearNodeMap()

	snet.Request('bgn_movement_mesh_load_info', BGN_NODE:CountNodesOnMap())
		.Invoke(ply)
end).Protect()

snet.Callback('bgn_movement_mesh_load_from_client_sv', function(ply)
	-- if BGN_NODE:CountNodesOnMap() == 0 then
	-- 	bgNPC.LoadRoutes()
	-- end

	local jsonString = (BGN_NODE:RouteFileExists() and BGN_NODE:GetRouteFileData()) or (BGN_NODE:CountNodesOnMap() ~= 0 and BGN_NODE:MapToJson())
	-- local jsonString = BGN_NODE:GetRouteFileData()

	snet.Request('bgn_movement_mesh_load_from_client_cl', jsonString)
		.ProgressText('Loading mesh from server')
		.Invoke(ply)
end).Protect()

hook.Add('InitPostEntity', 'BGN_FirstInitializeRoutesOnMap', function()
	bgNPC.LoadRoutes()
end)
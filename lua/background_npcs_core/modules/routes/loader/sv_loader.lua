bgNPC.LoadRoutes = function()
	local jsonString
	local map_name = game.GetMap()
	hook.Run('BGN_PreLoadRoutes', map_name)

	if file.Exists('background_npcs/nodes/' .. map_name .. '.dat', 'DATA') then
		local file_data = file.Read('background_npcs/nodes/' .. map_name .. '.dat', 'DATA')
		jsonString = util.Decompress(file_data)
	elseif file.Exists('background_npcs/nodes/' .. map_name .. '.json', 'DATA') then
		jsonString = file.Read('background_npcs/nodes/' .. map_name .. '.json', 'DATA')
	end

	BGN_NODE:ClearNodeMap()

	if jsonString and jsonString ~= '' then
		BGN_NODE:SetMap(BGN_NODE:JsonToMap(jsonString))
	end

	local count = BGN_NODE:CountNodesOnMap()
	bgNPC:Log('Load citizens walk points - ' .. tostring(count), 'Route')
	hook.Run('BGN_PostLoadRoutes', map_name)

	return BGN_NODE:GetMap()
end

snet.Callback('bgn_movement_mesh_load', function(ply)
	bgNPC.LoadRoutes()

	snet.Request('bgn_movement_mesh_load_info', BGN_NODE:CountNodesOnMap())
		.Invoke(ply)
end).Protect()

snet.Callback('bgn_movement_mesh_load_from_client_sv', function(ply)
	if BGN_NODE:CountNodesOnMap() == 0 then
		bgNPC.LoadRoutes()
	end

	snet.Request('bgn_movement_mesh_load_from_client_cl', BGN_NODE:MapToJson())
		.ProgressText('Loading mesh from server')
		.Invoke(ply)
end).Protect()

hook.Add('InitPostEntity', 'BGN_FirstInitializeRoutesOnMap', function()
	bgNPC.LoadRoutes()
end)
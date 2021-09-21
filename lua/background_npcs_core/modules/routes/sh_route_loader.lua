if SERVER then
	bgNPC.PointsExist = false

	bgNPC.LoadRoutes = function()
		bgNPC.PointsExist = false

		local jsonString = ''

		if file.Exists('background_npcs/nodes/' .. game.GetMap() .. '.dat', 'DATA') then
			local file_data = file.Read('background_npcs/nodes/' .. game.GetMap() .. '.dat', 'DATA')
			jsonString = util.Decompress(file_data)
		elseif file.Exists('background_npcs/nodes/' .. game.GetMap() .. '.json', 'DATA') then
			jsonString = file.Read('background_npcs/nodes/' .. game.GetMap() .. '.json', 'DATA')
		end

		BGN_NODE:ClearNodeMap()

		if jsonString ~= '' then
			BGN_NODE:SetMap(BGN_NODE:JsonToMap(jsonString))
		end

		local count = BGN_NODE:CountNodesOnMap()
		if count > 0 then
			bgNPC.PointsExist = true
		end

		bgNPC:Log('Load citizens walk points - ' .. tostring(count), 'Route')

		return BGN_NODE:GetMap()
	end

	bgNPC.SendRoutesFromClient = function(ply)
		snet.Request('bgn_movement_mesh_load_from_client_cl')
			.BigData(BGN_NODE:MapToJson(), nil, 'Loading mesh from server')
			.Invoke(ply)
	end

	snet.Callback('bgn_movement_mesh_load', function(ply)
		bgNPC.LoadRoutes()
		bgNPC.SendRoutesFromClient(ply)
	end).Protect()

	snet.Callback('bgn_movement_mesh_load_from_client_sv', function(ply)
		bgNPC.SendRoutesFromClient(ply)
	end).Protect()

	hook.Add('InitPostEntity', 'BGN_FirstInitializeRoutesOnMap', function()
		hook.Run('BGN_PreLoadRoutes', game.GetMap())
		bgNPC.LoadRoutes()
	end)
else
	concommand.Add('cl_bgn_clear_tool_points', function()
		local wep = LocalPlayer():GetActiveWeapon()
		if not IsValid(wep) or wep:GetClass() ~= 'gmod_tool' then return end

		local tool = bgNPC:GetActivePlayerTool('bgn_point_editor')
		if not tool then return end

		tool:ClearPoints()
	end)

	hook.Add('SnetBigDataStartSending', 'BGN_LoadingNodesFromServer', function(ply, name)
		if name ~= 'bgn_movement_mesh_load_from_client_cl' then return end
		notification.Kill('BGN_LoadingNodesFromServer')
	end)

	concommand.Add('cl_citizens_load_route', function(ply)
		if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end

		notification.AddProgress('BGN_LoadingNodesFromServer', 'The server is preparing files, please wait...')
		snet.InvokeServer('bgn_movement_mesh_load')

	end, nil, 'loads the displacement points. This is done automatically when the map is loaded, but if you want to update the points without rebooting, use this command.')

	concommand.Add('cl_citizens_load_route_from_client', function(ply)
		if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end

		notification.AddProgress('BGN_LoadingNodesFromServer', 'The server is preparing files, please wait...')
		snet.InvokeServer('bgn_movement_mesh_load_from_client_sv')

	end, nil, 'Technical command. Used to get an array of points from the server.')

	snet.Callback('bgn_movement_mesh_load_from_client_cl', function(ply, data_table)
		local newMap = BGN_NODE:JsonToMap(data_table)
		local count = table.Count(newMap)

		bgNPC:Log('Client routes is loading! (' .. count .. ')', 'Route')
		if (LocalPlayer():IsAdmin() or LocalPlayer():IsSuperAdmin()) then
			if count == 0 then
				notification.AddLegacy('[For admin] Mesh file not found. Background NPCs will not spawn.', NOTIFY_ERROR, 4)
			else
				notification.AddLegacy('[For admin] Loaded ' .. count .. ' mesh points to move and spawn Background NPCs.', NOTIFY_GENERIC, 4)
			end
		end

		BGN_NODE:SetMap(newMap)
		hook.Run('BGN_LoadingClientRoutes', BGN_NODE:GetMap())
	end).Protect()
end
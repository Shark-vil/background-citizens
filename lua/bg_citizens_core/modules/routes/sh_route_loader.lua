if SERVER then
	util.AddNetworkString('bgNPCLoadRoute')
	util.AddNetworkString('bgNPCLoadExistsRoutesFromClient')
	util.AddNetworkString('bgNPCLoadRouteFromClient')

	bgNPC.PointsExist = false

	bgNPC.LoadRoutes = function()
		bgNPC.PointsExist = false

		if file.Exists('citizens_points/' .. game.GetMap() .. '.dat', 'DATA') then
			local file_data = file.Read('citizens_points/' .. game.GetMap() .. '.dat', 'DATA')
			local load_table = util.JSONToTable(util.Decompress(file_data))

			bgNPC.points = load_table
		elseif file.Exists('citizens_points/' .. game.GetMap() .. '.json', 'DATA') then
			bgNPC.points = util.JSONToTable(file.Read('citizens_points/' .. game.GetMap() .. '.json', 'DATA'))
		else
			bgNPC.points = {}
		end

		local count = #bgNPC.points
		if count > 0 then
			bgNPC.PointsExist = true
		end

		bgNPC:Log('Load citizens walk points - ' .. tostring(count), 'Route')

		return bgNPC.points
	end

	bgNPC.SendRoutesFromClient = function(ply)
		snet.InvokeBigData('bgn_load_routes', ply, bgNPC.points)
	end

	net.Receive('bgNPCLoadRoute', function(len, ply)
		if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end
		bgNPC.LoadRoutes()
		bgNPC.SendRoutesFromClient(ply)
	end)

	net.Receive('bgNPCLoadExistsRoutesFromClient', function(len, ply)
		if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end
		bgNPC.SendRoutesFromClient(ply)
	end)

	hook.Add("Initialize", "BGN_FirstInitializeRoutesOnMap", function()
		bgNPC.LoadRoutes()
	end)
else
	concommand.Add('cl_citizens_load_route', function(ply)
		if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end

		net.Start('bgNPCLoadRoute')
		net.SendToServer()
	end, nil, 'loads the displacement points. This is done automatically when the map is loaded, but if you want to update the points without rebooting, use this command.')

	local client_point_load_progress = false
	concommand.Add('cl_citizens_load_route_from_client', function(ply)
		if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end

		notification.AddProgress('BgnLoadClientRoutes',  'Loading points for client...')
		client_point_load_progress = true

		net.Start('bgNPCLoadExistsRoutesFromClient')
		net.SendToServer()
	end, nil, 'Technical command. Used to get an array of points from the server.')

	net.RegisterCallback('bgn_load_routes', function(ply, data_table)
		local count = table.Count(data_table)

		if client_point_load_progress then
			notification.Kill('BgnLoadClientRoutes')
			notification.AddLegacy('Success! Loading points for client...', NOTIFY_GENERIC, 3)
		end

		bgNPC:Log('Client routes is loading! (' .. count .. ')', 'Route')
		if (LocalPlayer():IsAdmin() or LocalPlayer():IsSuperAdmin()) then
			if count == 0 then
				notification.AddLegacy("[For admin] Mesh file not found. Background NPCs will not spawn.", NOTIFY_ERROR, 4)
			else
				notification.AddLegacy("[For admin] Loaded " .. count .. " mesh points to move and spawn Background NPCs.", NOTIFY_GENERIC, 4)
			end
		end

		bgNPC.points = data_table

		hook.Run('BGN_LoadingClientRoutes', bgNPC.points)
	end)
end
snet.Callback('sv_start_bgn_compile', function(ply)
	local map_name = game.GetMap()
	local nodes = ''
	local seats = ''
	local dv_nodes = ''

	do
		local file_path = 'background_npcs/nodes/' .. map_name .. '.dat'
		if file.Exists(file_path, 'DATA') then
			nodes = util.Decompress(file.Read(file_path, 'DATA'))
		end
	end

	do
		local file_path = 'background_npcs/seats/' .. map_name .. '.dat'
		if file.Exists(file_path, 'DATA') then
			seats = util.Decompress(file.Read(file_path, 'DATA'))
		end
	end

	do
		local file_path = 'decentvehicle/' .. map_name .. '.txt'
		if file.Exists(file_path, 'DATA') then
			dv_nodes = util.Decompress(file.Read(file_path, 'DATA'))
		end
	end

	local send_data = {
		map_name = map_name,
		nodes = nodes,
		seats = seats,
		dv_nodes = dv_nodes
	}

	snet.Request('cl_start_bgn_compile', send_data)
		.ProgressText('Loading data from the server')
		.Invoke(ply)
end).Protect()
concommand.Add('bgn_compile', function(ply, cmd, args)
	if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end
	bgNPC:Log('Wait for all points to load...', 'Route')
	snet.InvokeServer('sv_start_bgn_compile')
end, nil, 'Saves your points as a lua script so you can place your mesh in the workshop.')

local function get_write_string(file_path, json_data)
	local directory_name = string.GetPathFromFilename(file_path)
	local code_string = ''
	code_string = code_string .. 'if not file.Exists(\'' .. directory_name .. '\', \'DATA\') then '
	code_string = code_string .. 'file.CreateDir(\'' .. directory_name .. '\')'
	code_string = code_string .. ' end '
	code_string = code_string .. 'if not file.Exists(\'' .. file_path .. '\', \'DATA\') then '
	code_string = code_string .. 'file.Write(\'' .. file_path .. '\', util.Compress(\'' .. json_data .. '\'))'
	code_string = code_string .. ' end '
	return code_string
end

local function data_is_valid(data)
	return data and data ~= ''
end

snet.Callback('cl_start_bgn_compile', function(ply, data)
	local map_name = data.map_name
	local nodes = data.nodes
	local seats = data.seats
	local dv_nodes = data.dv_nodes
	local compile_path = 'background_npcs/compile/bgn_compile_' .. map_name .. '.txt'
	local code_string = ''

	if data_is_valid(nodes) then
		local insert_filepath = 'background_npcs/nodes/' .. map_name .. '.dat'
		code_string = code_string .. get_write_string(insert_filepath, nodes)
	end

	if data_is_valid(seats) then
		local insert_filepath = 'background_npcs/seats/' .. map_name .. '.dat'
		code_string = code_string .. get_write_string(insert_filepath, seats)
	end

	if data_is_valid(dv_nodes) then
		local insert_filepath = 'decentvehicle/' .. map_name .. '.txt'
		code_string = code_string .. get_write_string(insert_filepath, dv_nodes)
	end

	if not data_is_valid(code_string) then
		notification.AddLegacy('You do not have all the data you need to save', NOTIFY_ERROR, 4)
		return
	end

	file.Write(compile_path, code_string)

	notification.AddLegacy('Finaly compile! Check the chat or console for information.', NOTIFY_GENERIC, 4)

	local localPlayer = LocalPlayer()
	localPlayer:ChatPrint('>> ' .. map_name .. ' <<')
	localPlayer:ChatPrint('Finaly compile! File path - ../GarrysMod/garrysmod/data/' .. compile_path)
	localPlayer:ChatPrint('Place this file in directory - garrysmod/scripts/background_npcs/')
	localPlayer:ChatPrint('Or addon - myaddon/scripts/background_npcs/')
	localPlayer:ChatPrint('==============')
end).Protect()
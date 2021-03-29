local is_load_compiler = false
concommand.Add('cl_citizens_compile_route', function(ply, cmd, args)
	if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end
	bgNPC:Log('Wait for all points to load...', 'Route')
	is_load_compiler = true
	ply:ConCommand('cl_citizens_load_route_from_client')
end, nil, 'Saves your points as a lua script so you can place your mesh in the workshop.')

local code_string
hook.Add("BGN_LoadingClientRoutes", 'BGN_RoutesCompiler', function(nodes)
	if not is_load_compiler then return end
	is_load_compiler = false

	if #nodes == 0 then return end

	notification.AddProgress("BGN_RouteCompileMesh", "Compile mesh...")
	bgNPC:Log('Start compile...', 'Route')

	local insert_file_path = 'background_npcs/nodes/' .. game.GetMap() .. '.dat'
	local json_nodes = BGN_NODE:MapToJson(nodes)

	code_string = ""
	code_string = code_string.."if not file.Exists('"..insert_file_path.."', 'DATA') then "
	code_string = code_string.."file.Write('"..insert_file_path.."', util.Compress('"..json_nodes.."'))"
	code_string = code_string.." end "

	LocalPlayer():ConCommand('bgn_tool_seat_compile')
end)

hook.Add('BGN_LoadingClienSeats', 'BGN_AddSeatsCompile', function(points)
	if not code_string or code_string == '' then return end
	
	local insert_file_path = 'background_npcs/seats/' .. game.GetMap() .. '.dat'
	local json_nodes = util.TableToJSON(points)
	code_string = code_string.."if not file.Exists('"..insert_file_path.."', 'DATA') then "
	code_string = code_string.."file.Write('"..insert_file_path.."', util.Compress('"..json_nodes.."'))"
	code_string = code_string.." end"

	local compile_file_path = 'background_npcs/compile/bgn_compile_' .. game.GetMap() .. '.txt'
	file.Write(compile_file_path, code_string)

	notification.Kill("BGN_RouteCompileMesh")
	notification.AddLegacy("Finaly compile! Check the chat or console for information.", NOTIFY_GENERIC, 4)

	LocalPlayer():ChatPrint('>> ' .. game.GetMap() .. ' <<')
	LocalPlayer():ChatPrint('Finaly compile! File path - ../GarrysMod/garrysmod/data/' .. compile_file_path)
	LocalPlayer():ChatPrint('Change .txt to .lua and place this file in directory - lua/autorun/server')
	LocalPlayer():ChatPrint('==============')

	code_string = nil
end)
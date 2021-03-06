local is_load_compiler = false
concommand.Add('cl_citizens_compile_route', function(ply, cmd, args)
	if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end
	notification.AddProgress("BGN_RouteCompileLoadMesh", "Loading mesh...")

	bgNPC:Log('Wait for all points to load...', 'Route')
	is_load_compiler = true
	ply:ConCommand('cl_citizens_load_route_from_client')
end, nil, 'Saves your points as a lua script so you can place your mesh in the workshop.')

hook.Add("BGN_LoadingClientRoutes", 'BGN_RoutesCompiler', function(points)
	notification.Kill("BGN_RouteCompileLoadMesh")
	if not is_load_compiler then return end
	notification.AddProgress("BGN_RouteCompileMesh", "Compile mesh...")

	bgNPC:Log('Start compile...', 'Route')
	is_load_compiler = false

	local compile_file_path = 'citizens_points_compile/bgn_compile_' .. game.GetMap() .. '.txt'
	local insert_file_path = 'citizens_points/' .. game.GetMap() .. '.json'
	local json_points = util.TableToJSON(points)
	local code_string = ""
	code_string = code_string.."if not file.Exists('"..insert_file_path.."', 'DATA') then "
	code_string = code_string.."file.Write('"..insert_file_path.."', '"..json_points.."')"
	code_string = code_string.." end"

	file.Write(compile_file_path, code_string)

	notification.Kill("BGN_RouteCompileMesh")
	notification.AddLegacy("Finaly compile! Check the chat or console for information.", NOTIFY_GENERIC, 4)

	LocalPlayer():ChatPrint('Finaly compile! File path - ../GarrysMod/garrysmod/data/' .. compile_file_path)
	LocalPlayer():ChatPrint('Change .txt to .lua and place this file in directory - lua/autorun/server')
end)
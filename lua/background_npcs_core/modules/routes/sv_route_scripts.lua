local RunString = RunString

hook.Add('BGN_PreLoadRoutes', 'BGN_LoadRoutesScripts', function(map_name)
	if file.Exists('scripts/background_npcs/' .. map_name .. '.txt', 'GAME') then
		local file_data = file.Read('scripts/background_npcs/' .. map_name .. '.txt', 'GAME')
		local lua_string = util.Decompress(file_data)
		RunString(lua_string)
	end
end)
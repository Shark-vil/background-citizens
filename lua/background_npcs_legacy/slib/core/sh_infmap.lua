local file_Exists = file.Exists
local game_GetMap = game.GetMap

function slib.IsInfinityMap()
	return file_Exists('infmap/' .. game_GetMap(), 'LUA')
end
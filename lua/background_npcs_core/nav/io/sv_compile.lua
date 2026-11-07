--[[
	"bgn_compile": packs the map's route, seats and Decent Vehicle waypoints into a Lua file for the Workshop.
	Output: data/background_npcs/compile/bgn_compile_<map>.txt -> rename to .lua and put into lua/autorun/server.
	The script writes the files only if the server does not have them yet.
--]]

local FILES = {
	function(map) return bgNPC.Nav.CustomProvider.GraphPath(map) end,
	function(map) return 'background_npcs/seats/' .. map .. '.dat' end,
	function(map) return 'decentvehicle/' .. map .. '.txt' end,
}

local function WriteStatement(path, data)
	local dir = string.GetPathFromFilename(path)
	return string.format('if not file.Exists(%q, "DATA") then file.CreateDir(%q) file.Write(%q, util.Base64Decode(%q)) end\n',
		path, dir, path, util.Base64Encode(data, true))
end

bgNPC.Commands.Register('bgn_compile', {
	admin = true,
	help = 'Packs the route, seats and DV waypoints of the map into a Lua file for the Workshop.',
	server = function(ply)
		local map = game.GetMap()
		local code = '-- Background NPCs route pack for ' .. map .. '\nif game.GetMap() ~= ' .. string.format('%q', map) .. ' then return end\n'
		local count = 0

		for _, path_of in ipairs(FILES) do
			local path = path_of(map)
			if file.Exists(path, 'DATA') then
				code = code .. WriteStatement(path, file.Read(path, 'DATA'))
				count = count + 1
			end
		end

		local text
		if count == 0 then
			text = 'Nothing to compile: save a route (point editor) or seats first.'
		else
			local out = 'background_npcs/compile/bgn_compile_' .. map .. '.txt'
			file.CreateDir('background_npcs/compile')
			file.Write(out, code)
			text = 'Compiled ' .. count .. ' file(s) to garrysmod/data/' .. out .. ' - rename to .lua and put into lua/autorun/server'
		end

		text = '[Background NPCs] ' .. text
		MsgN(text)
		if IsValid(ply) then ply:ChatPrint(text) end
	end,
})

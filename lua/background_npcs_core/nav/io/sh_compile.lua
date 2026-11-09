--[[
	"bgn_compile": packs the map's route, seats and Decent Vehicle waypoints into a Lua file for the Workshop.
	Output: data/background_npcs/compile/bgn_compile_<map>.txt -> rename to .lua and put into lua/autorun/server.
	The script writes the files only if the server does not have them yet.
--]]

local Net = bgNPC.Net

if CLIENT then
	Net.Receive('bgn_compile_result', function(_, map, code, count)
		local out = 'background_npcs/compile/bgn_compile_' .. map .. '.txt'
		file.CreateDir('background_npcs/compile')
		file.Write(out, code)
		if file.Read(out, 'DATA') ~= code then
			bgNPC.Util.Notify(nil, 'Could not save route pack: garrysmod/data/' .. out, NOTIFY_ERROR)
			return
		end
		local text = bgNPC.Util.Lang({
			default = 'Saved %d file(s) to your computer:\ngarrysmod/data/%s\n\nRename .txt to .lua and put it in your addon\'s lua/autorun/server folder to publish a route pack.',
			russian = 'Сохранено файлов: %d. Результат на вашем компьютере:\ngarrysmod/data/%s\n\nПереименуйте .txt в .lua и поместите в lua/autorun/server своего аддона для публикации маршрутов.',
		})
		text = string.format(text, count, out)
		MsgN('[Background NPCs] ' .. text)
		Derma_Message(text, 'Background NPCs', 'OK')
	end, { admin = true })
end

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
			local data = file.Read(path, 'DATA')
			if path == bgNPC.Nav.CustomProvider.GraphPath(map) then
				local provider = bgNPC.Nav.GetProvider()
				if provider.GetGraph and provider:Count() > 0 then data = provider:GetGraph():Serialize() end
			end
			if data and #data > 0 then
				code = code .. WriteStatement(path, data)
				count = count + 1
			end
		end

		local text
		local failed = count == 0
		if count == 0 then
			text = 'Nothing to compile: save a route (point editor) or seats first.'
		else
			local out = 'background_npcs/compile/bgn_compile_' .. map .. '.txt'
			file.CreateDir('background_npcs/compile')
			file.Write(out, code)
			if file.Read(out, 'DATA') ~= code then
				failed = true
				text = 'Could not save route pack: garrysmod/data/' .. out
			else
				text = 'Compiled ' .. count .. ' file(s) to garrysmod/data/' .. out .. ' - rename to .lua and put into lua/autorun/server'
				if IsValid(ply) then Net.Send('bgn_compile_result', ply, map, code, count) end
			end
		end

		text = '[Background NPCs] ' .. text
		MsgN(text)
		if IsValid(ply) then ply:ChatPrint(text) end
		if failed and IsValid(ply) then bgNPC.Util.Notify(ply, text, NOTIFY_ERROR) end
	end,
})

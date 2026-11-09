--[[
	Old route files (unversioned and 1.x): background_npcs/nodes/ or citizens_points/, .dat or .json.
		{ "version": "1.2", "nodes": [ { "position": "[x y z]", "parents": [i, ...], "links": { "walk": [i, ...] } } ] }

	"bgn_convert_legacy_nodes [map]" writes the new graph file and keeps the old one.
	Map packs on the Workshop still write the old files, so the custom provider also converts them on load.
--]]

local LegacyNodes = bgNPC.LegacyNodes or {}
bgNPC.LegacyNodes = LegacyNodes

local function Paths(map_name)
	map_name = map_name or game.GetMap()
	return {
		'background_npcs/nodes/' .. map_name .. '.dat', 'background_npcs/nodes/' .. map_name .. '.json',
		'citizens_points/' .. map_name .. '.dat', 'citizens_points/' .. map_name .. '.json',
	}
end

local function HasData(path)
	return file.Exists(path, 'DATA') and file.Size(path, 'DATA') > 0
end

function LegacyNodes.Exists(map_name)
	for _, path in ipairs(Paths(map_name)) do
		if HasData(path) then return true end
	end
	return false
end

-- @return string|nil json
function LegacyNodes.Read(map_name)
	for _, path in ipairs(Paths(map_name)) do
		if HasData(path) then
			local data = file.Read(path, 'DATA')
			if string.GetExtensionFromFilename(path) == 'dat' then return util.Decompress(data) end
			return data
		end
	end
end

local function Position(pos)
	if isstring(pos) then
		local x, y, z = pos:match('^%s*%[?%s*([^%s]+)%s+([^%s]+)%s+([^%s%]]+)%s*%]?%s*$')
		pos = { x = tonumber(x), y = tonumber(y), z = tonumber(z) }
	end
	if not isvector(pos) and not istable(pos) then return end
	for _, axis in ipairs({ 'x', 'y', 'z' }) do
		local value = pos[axis]
		if not isnumber(value) or value ~= value or math.abs(value) == math.huge then return end
	end
	return Vector(pos.x, pos.y, pos.z)
end

-- @param data string|table old JSON or its table
-- @return NodeGraph|nil, string|nil error
function LegacyNodes.ToGraph(data)
	if isstring(data) then data = util.JSONToTable(data, true) end
	if not istable(data) then return nil, 'not an old route file' end
	local nodes = data.nodes or (not data.version and data[1] and data)
	if not istable(nodes) or #nodes > 200000 then return nil, 'invalid old route nodes' end
	if data.version and data.version ~= '1.0' and data.version ~= '1.1' and data.version ~= '1.2' then
		return nil, 'unsupported old route version'
	end

	local graph = bgNPC.NodeGraph()
	local ids = {}

	for index, node in ipairs(nodes) do
		if not istable(node) then return nil, 'invalid old route node' end
		local pos = Position(node.position or node.pos)
		if not pos then return nil, 'invalid old route position' end
		if node.parents ~= nil and not istable(node.parents) then return nil, 'invalid old route parents' end
		if node.links ~= nil and not istable(node.links) then return nil, 'invalid old route links' end
		ids[index] = graph:AddNode(pos)
	end

	local old_walk_links = not data.version or data.version == '1.0'
	for index, node in ipairs(nodes) do
		local id = ids[index]
		if id then
			for _, parent in ipairs(node.parents or {}) do
				if ids[parent] then graph:Link(id, ids[parent], old_walk_links and 'walk' or nil) end
			end
			for link_type, links in pairs(node.links or {}) do
				if not isstring(link_type) or not istable(links) then return nil, 'invalid old route link type' end
				for _, other in ipairs(links) do
					if ids[other] then graph:Link(id, ids[other], link_type) end
				end
			end
		end
		-- Before 1.1, parents were walking links; nearby geometric neighbours were rebuilt on migration.
		if old_walk_links then bgNPC.NavEditor.AutoLink(graph, id, false) end
		bgNPC.Tasks.Budget()
	end

	return graph
end

function LegacyNodes.Convert(map_name)
	local json = LegacyNodes.Read(map_name)
	if not json then return nil, 'no old route file' end
	return LegacyNodes.ToGraph(json)
end

local convertible_maps = {}

function LegacyNodes.GetConvertibleMaps()
	if CLIENT then return convertible_maps end
	local maps, seen = {}, {}
	for _, dir in ipairs({ 'background_npcs/nodes/', 'citizens_points/' }) do
		local files = file.Find(dir .. '*', 'DATA')
		for _, name in ipairs(files) do
			local map = name:match('^(.*)%.dat$') or name:match('^(.*)%.json$')
			if map and map ~= '' and not seen[map] and HasData(dir .. name)
				and not file.Exists(bgNPC.Nav.CustomProvider.GraphPath(map), 'DATA')
			then
				seen[map] = true
				maps[#maps + 1] = map
			end
		end
	end
	table.sort(maps)
	return maps
end

local function SendConvertibleMaps(ply)
	if IsValid(ply) and (ply:IsAdmin() or ply:IsSuperAdmin()) then
		bgNPC.Net.Send('bgn_legacy_maps', ply, LegacyNodes.GetConvertibleMaps())
	end
end

if SERVER then
	bgNPC.Net.Receive('bgn_legacy_maps_request', SendConvertibleMaps, { admin = true })
	hook.Add('BGN_PlayerReady', 'BGN_LegacyMaps', SendConvertibleMaps)
else
	bgNPC.Net.Receive('bgn_legacy_maps', function(_, maps) convertible_maps = maps end)
end

local next_request = 0
bgNPC.Commands.Register('bgn_convert_legacy_nodes', {
	admin = true,
	help = 'Converts the old route file of a map (default: current) to the new graph format.',
	autocomplete = function(cmd, args)
		if CLIENT and RealTime() >= next_request then
			local ply = LocalPlayer()
			if IsValid(ply) and (ply:IsAdmin() or ply:IsSuperAdmin()) then
				bgNPC.Net.SendToServer('bgn_legacy_maps_request')
				next_request = RealTime() + 1
			end
		end
		local prefix = string.Trim(args or ''):gsub('"', ''):lower()
		local suggestions = {}
		for _, map in ipairs(LegacyNodes.GetConvertibleMaps()) do
			if map:lower():sub(1, #prefix) == prefix then suggestions[#suggestions + 1] = cmd .. ' "' .. map .. '"' end
		end
		return suggestions
	end,
	server = function(ply, _, args)
		local map_name = args and args[1] or game.GetMap()
		local graph, err = LegacyNodes.Convert(map_name)

		local text
		if graph then
			file.CreateDir('background_npcs/graph')
			file.Write(bgNPC.Nav.CustomProvider.GraphPath(map_name), graph:Serialize())
			text = 'Converted ' .. graph:Count() .. ' points, ' .. graph:LinksCount() .. ' links for ' .. map_name
			if map_name == game.GetMap() then bgNPC.Nav.Load() end
			SendConvertibleMaps(ply)
		else
			text = 'Conversion failed for ' .. map_name .. ': ' .. tostring(err)
		end

		text = '[Background NPCs] ' .. text
		if IsValid(ply) then ply:ChatPrint(text) end
		MsgN(text)
	end,
})

bgNPC.Test.Add('nav.legacy_convert', function(check)
	local json = util.TableToJSON({
		version = '1.2',
		nodes = {
			{ position = Vector(0, 0, 0), parents = { 2 }, links = { walk = { 2 } } },
			{ position = Vector(100, 0, 0), parents = { 1, 3 }, links = { walk = { 1 } } },
			{ position = Vector(200, 0, 0), parents = { 2 }, links = {} },
		},
	})
	local graph = LegacyNodes.ToGraph(json)
	check(graph and graph:Count() == 3, 'three nodes')
	check(graph and graph:IsLinked(1, 2, 'walk') and graph:IsLinked(2, 3) and not graph:IsLinked(2, 3, 'walk'),
		'parents become plain links, walk links keep the type')
	check(LegacyNodes.ToGraph('garbage') == nil, 'garbage is rejected')
	for _, version in ipairs({ '1.0', '1.1', '1.2' }) do
		local copy = LegacyNodes.ToGraph({ version = version, nodes = {
			{ position = '[0 0 0]', parents = { 2 } }, { position = '[200 0 0]', parents = { 1 } },
		} })
		check(copy and copy:IsLinked(1, 2, version == '1.0' and 'walk' or nil), version .. ' converts')
	end
	local oldest = LegacyNodes.ToGraph({
		{ pos = Vector(0, 0, 0), parents = { 2 } }, { pos = Vector(200, 0, 0), parents = { 1 } },
	})
	check(oldest and oldest:IsLinked(1, 2, 'walk'), 'unversioned pos/parents stays walkable')
	check(LegacyNodes.ToGraph({ version = '1.2', nodes = { { position = 'garbage' } } }) == nil,
		'invalid positions are rejected instead of becoming the origin')
end)

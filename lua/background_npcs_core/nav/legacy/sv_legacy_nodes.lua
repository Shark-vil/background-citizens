--[[
	Old route files (format 1.x): data/background_npcs/nodes/<map>.dat (compressed JSON) or .json.
		{ "version": "1.2", "nodes": [ { "position": "[x y z]", "parents": [i, ...], "links": { "walk": [i, ...] } } ] }

	"bgn_convert_legacy_nodes [map]" writes the new graph file and keeps the old one.
	Map packs on the Workshop still write the old files, so the custom provider also converts them on load.
--]]

local LegacyNodes = bgNPC.LegacyNodes or {}
bgNPC.LegacyNodes = LegacyNodes

local function Paths(map_name)
	map_name = map_name or game.GetMap()
	return 'background_npcs/nodes/' .. map_name .. '.dat', 'background_npcs/nodes/' .. map_name .. '.json'
end

local function HasData(path)
	return file.Exists(path, 'DATA') and file.Size(path, 'DATA') > 0
end

function LegacyNodes.Exists(map_name)
	local dat, json = Paths(map_name)
	return HasData(dat) or HasData(json)
end

-- @return string|nil json
function LegacyNodes.Read(map_name)
	local dat, json = Paths(map_name)
	if HasData(dat) then return util.Decompress(file.Read(dat, 'DATA')) end
	if HasData(json) then return file.Read(json, 'DATA') end
end

-- @param data string|table old JSON or its table
-- @return NodeGraph|nil, string|nil error
function LegacyNodes.ToGraph(data)
	if isstring(data) then data = util.JSONToTable(data) end
	if not istable(data) or not istable(data.nodes) then return nil, 'not an old route file' end

	local graph = bgNPC.NodeGraph()
	local ids = {}

	for index, node in ipairs(data.nodes) do
		local pos = node.position
		if isstring(pos) then pos = Vector(pos:match('%[?([^%]]*)%]?')) end
		if isvector(pos) then ids[index] = graph:AddNode(pos) end
	end

	for index, node in ipairs(data.nodes) do
		local id = ids[index]
		if id then
			for _, parent in ipairs(node.parents or {}) do
				if ids[parent] then graph:Link(id, ids[parent]) end
			end
			for link_type, links in pairs(node.links or {}) do
				for _, other in ipairs(links) do
					if ids[other] then graph:Link(id, ids[other], link_type) end
				end
			end
		end
	end

	return graph
end

function LegacyNodes.Convert(map_name)
	local json = LegacyNodes.Read(map_name)
	if not json then return nil, 'no old route file' end
	return LegacyNodes.ToGraph(json)
end

bgNPC.Commands.Register('bgn_convert_legacy_nodes', {
	admin = true,
	help = 'Converts the old route file of a map (default: current) to the new graph format.',
	server = function(ply, _, args)
		local map_name = args and args[1] or game.GetMap()
		local graph, err = LegacyNodes.Convert(map_name)

		local text
		if graph then
			file.CreateDir('background_npcs/graph')
			file.Write(bgNPC.Nav.CustomProvider.GraphPath(map_name), graph:Serialize())
			text = 'Converted ' .. graph:Count() .. ' points, ' .. graph:LinksCount() .. ' links for ' .. map_name
			if map_name == game.GetMap() then bgNPC.Nav.Load() end
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
end)

--[[
	NodeGraph: movement points with links, a spatial hash for O(1) area queries and A* path finding.

		local graph = bgNPC.NodeGraph()
		local a = graph:AddNode(Vector(0, 0, 0))
		local b = graph:AddNode(Vector(200, 0, 0))
		graph:Link(a, b, 'walk')
		local path = graph:FindPath(a, b, 'walk') -- { a, b }

	Nodes are integer ids. A removed id leaves a hole until an explicit Compact().
	Every link is two-way. A link has a type mask; a link with mask 0 only marks the nodes as
	neighbours ("parents" in the old format), path finding over a type uses links that carry it.

	File format (version 2, util.Compress of JSON):
		{ "format": "bgn_graph", "version": 2, "nodes": [x, y, z, x, y, z, ...], "links": [a, b, mask, ...] }
--]]

local NodeGraph = bgNPC.Class('BGN_NodeGraph')
bgNPC.NodeGraph = NodeGraph

NodeGraph.FORMAT = 'bgn_graph'
NodeGraph.VERSION = 2
NodeGraph.CELL_SIZE = 512

-- Link type name -> bit. Add new types with NodeGraph.RegisterLinkType.
local LINK_TYPES = NodeGraph.LINK_TYPES or { walk = 1 }
NodeGraph.LINK_TYPES = LINK_TYPES

function NodeGraph.RegisterLinkType(name)
	if LINK_TYPES[name] then return LINK_TYPES[name] end
	local max_bit = 0
	for _, bit_value in pairs(LINK_TYPES) do max_bit = math.max(max_bit, bit_value) end
	LINK_TYPES[name] = max_bit * 2
	return LINK_TYPES[name]
end

local function MaskOf(link_type)
	if link_type == nil then return 0 end
	return LINK_TYPES[link_type] or NodeGraph.RegisterLinkType(link_type)
end

local floor = math.floor

function NodeGraph:Init(cell_size)
	self.cell_size = cell_size or NodeGraph.CELL_SIZE
	self.pos = {}      -- id -> Vector
	self.links = {}    -- id -> { [other_id] = mask }
	self.cells = {}    -- cell key -> { [id] = true }
	self.max_id = 0
	self.count = 0
end

function NodeGraph:CellKey(x, y, z)
	local s = self.cell_size
	-- 2^16 cells per axis (keys stay below 2^48, exact in a double)
	return (floor(x / s) + 32768) * 4294967296 + (floor(y / s) + 32768) * 65536 + (floor(z / s) + 32768)
end

-- ---------------------------------------------------------------------------
-- Nodes
-- ---------------------------------------------------------------------------

function NodeGraph:AddNode(pos)
	local id = self.max_id + 1
	self.max_id = id
	self.count = self.count + 1

	pos = Vector(pos.x, pos.y, pos.z)
	self.pos[id] = pos
	self.links[id] = {}

	local key = self:CellKey(pos.x, pos.y, pos.z)
	local cell = self.cells[key]
	if not cell then
		cell = {}
		self.cells[key] = cell
	end
	cell[id] = true

	return id
end

function NodeGraph:RemoveNode(id)
	local pos = self.pos[id]
	if not pos then return end

	for other in pairs(self.links[id]) do
		local other_links = self.links[other]
		if other_links then other_links[id] = nil end
	end

	local key = self:CellKey(pos.x, pos.y, pos.z)
	local cell = self.cells[key]
	if cell then
		cell[id] = nil
		if next(cell) == nil then self.cells[key] = nil end
	end

	self.pos[id] = nil
	self.links[id] = nil
	self.count = self.count - 1
end

function NodeGraph:SetPos(id, pos)
	local old = self.pos[id]
	if not old then return end

	local old_key = self:CellKey(old.x, old.y, old.z)
	local old_cell = self.cells[old_key]
	if old_cell then
		old_cell[id] = nil
		if next(old_cell) == nil then self.cells[old_key] = nil end
	end

	pos = Vector(pos.x, pos.y, pos.z)
	self.pos[id] = pos

	local key = self:CellKey(pos.x, pos.y, pos.z)
	self.cells[key] = self.cells[key] or {}
	self.cells[key][id] = true
end

function NodeGraph:Exists(id)
	return self.pos[id] ~= nil
end

function NodeGraph:GetPos(id)
	return self.pos[id]
end

function NodeGraph:Count()
	return self.count
end

-- Iterates over existing ids: for id, pos in graph:Nodes() do ... end
function NodeGraph:Nodes()
	return pairs(self.pos)
end

function NodeGraph:Clear()
	self:Init(self.cell_size)
end

-- ---------------------------------------------------------------------------
-- Links
-- ---------------------------------------------------------------------------

-- Links two nodes. Adds the type bit when the nodes are already linked.
function NodeGraph:Link(a, b, link_type)
	if a == b or not self.pos[a] or not self.pos[b] then return false end
	local mask = bit.bor(self.links[a][b] or 0, MaskOf(link_type))
	self.links[a][b] = mask
	self.links[b][a] = mask
	return true
end

-- Removes one link type; without a type removes the whole link.
function NodeGraph:Unlink(a, b, link_type)
	local links_a, links_b = self.links[a], self.links[b]
	if not links_a or not links_b or not links_a[b] then return end

	if link_type == nil then
		links_a[b], links_b[a] = nil, nil
		return
	end

	local mask = bit.band(links_a[b], bit.bnot(MaskOf(link_type)))
	links_a[b], links_b[a] = mask, mask
end

function NodeGraph:IsLinked(a, b, link_type)
	local links = self.links[a]
	local mask = links and links[b]
	if not mask then return false end
	if link_type == nil then return true end
	return bit.band(mask, MaskOf(link_type)) ~= 0
end

-- @return table list of neighbour ids
function NodeGraph:GetNeighbours(id, link_type)
	local result = {}
	local links = self.links[id]
	if not links then return result end

	local need = MaskOf(link_type)
	for other, mask in pairs(links) do
		if need == 0 or bit.band(mask, need) ~= 0 then result[#result + 1] = other end
	end

	return result
end

function NodeGraph:HasLinks(id, link_type)
	local links = self.links[id]
	if not links then return false end
	local need = MaskOf(link_type)
	for _, mask in pairs(links) do
		if need == 0 or bit.band(mask, need) ~= 0 then return true end
	end
	return false
end

function NodeGraph:LinksCount()
	local n = 0
	for _, links in pairs(self.links) do
		for _ in pairs(links) do n = n + 1 end
	end
	return n / 2
end

-- ---------------------------------------------------------------------------
-- Spatial queries
-- ---------------------------------------------------------------------------

-- Calls fn(id, pos, dist_sqr) for every node within radius. Return true from fn to stop.
function NodeGraph:ForEachInRadius(center, radius, fn)
	local s = self.cell_size
	local radius_sqr = radius * radius
	local cx, cy, cz = center.x, center.y, center.z
	local pos_list = self.pos

	-- A huge radius covers more cells than there are nodes: scan the nodes instead.
	local span = math.floor(2 * radius / s) + 2
	if span * span * span > self.count then
		for id, pos in pairs(pos_list) do
			local dist_sqr = pos:DistToSqr(center)
			if dist_sqr <= radius_sqr and fn(id, pos, dist_sqr) then return end
		end
		return
	end

	for x = floor((cx - radius) / s), floor((cx + radius) / s) do
		for y = floor((cy - radius) / s), floor((cy + radius) / s) do
			for z = floor((cz - radius) / s), floor((cz + radius) / s) do
				local cell = self.cells[(x + 32768) * 4294967296 + (y + 32768) * 65536 + (z + 32768)]
				if cell then
					for id in pairs(cell) do
						local dist_sqr = pos_list[id]:DistToSqr(center)
						if dist_sqr <= radius_sqr and fn(id, pos_list[id], dist_sqr) then return end
					end
				end
			end
		end
	end
end

-- @return table list of ids
function NodeGraph:GetInRadius(center, radius, link_type)
	local result = {}
	self:ForEachInRadius(center, radius, function(id)
		if link_type == nil or self:HasLinks(id, link_type) then result[#result + 1] = id end
	end)
	return result
end

-- @param filter function|nil (id, pos) -> boolean
-- @return number|nil id, number|nil distance squared
function NodeGraph:FindNearest(center, radius, filter)
	local best, best_dist
	self:ForEachInRadius(center, radius, function(id, pos, dist_sqr)
		if (not best_dist or dist_sqr < best_dist) and (not filter or filter(id, pos)) then
			best, best_dist = id, dist_sqr
		end
	end)
	return best, best_dist
end

-- @return number|nil id
function NodeGraph:FindFarthest(center, radius, filter)
	local best, best_dist
	self:ForEachInRadius(center, radius, function(id, pos, dist_sqr)
		if (not best_dist or dist_sqr > best_dist) and (not filter or filter(id, pos)) then
			best, best_dist = id, dist_sqr
		end
	end)
	return best
end

-- @return number|nil random id (over all nodes when no center is given)
function NodeGraph:GetRandom(center, radius, link_type)
	if center then
		local list = self:GetInRadius(center, radius, link_type)
		return list[math.random(#list)]
	end

	if self.count == 0 then return nil end
	-- Random probe first, the id space is usually dense
	for _ = 1, 8 do
		local id = math.random(self.max_id)
		if self.pos[id] and (link_type == nil or self:HasLinks(id, link_type)) then return id end
	end

	local list = {}
	for id in pairs(self.pos) do
		if link_type == nil or self:HasLinks(id, link_type) then list[#list + 1] = id end
	end
	return list[math.random(#list)]
end

-- ---------------------------------------------------------------------------
-- Path finding
-- ---------------------------------------------------------------------------

-- @param link_type string|nil walk only over links of this type
-- @return table|nil list of ids
function NodeGraph:FindPath(start_id, goal_id, link_type, max_iterations)
	if not self.pos[start_id] or not self.pos[goal_id] then return nil end

	local need = MaskOf(link_type)
	local pos_list, links_list = self.pos, self.links
	local goal_pos = pos_list[goal_id]

	return (bgNPC.AStar.Search({
		start = start_id,
		max_iterations = max_iterations,
		is_goal = function(id) return id == goal_id end,
		heuristic = function(id) return pos_list[id]:Distance(goal_pos) end,
		neighbours = function(id, push)
			local from = pos_list[id]
			for other, mask in pairs(links_list[id]) do
				if need == 0 or bit.band(mask, need) ~= 0 then
					push(other, from:Distance(pos_list[other]))
				end
			end
		end,
	}))
end

-- ---------------------------------------------------------------------------
-- Serialization
-- ---------------------------------------------------------------------------

-- Renumbers ids to 1..count without holes.
-- @return table old id -> new id
function NodeGraph:Compact()
	local ids = {}
	for id in pairs(self.pos) do ids[#ids + 1] = id end
	table.sort(ids)

	local remap = {}
	for new_id, old_id in ipairs(ids) do remap[old_id] = new_id end

	local old_pos, old_links = self.pos, self.links
	self:Init(self.cell_size)

	for _, old_id in ipairs(ids) do self:AddNode(old_pos[old_id]) end
	for old_id, links in pairs(old_links) do
		local a = remap[old_id]
		for other, mask in pairs(links) do
			local b = remap[other]
			if b and a < b then
				self.links[a][b] = mask
				self.links[b][a] = mask
			end
		end
	end

	return remap
end

function NodeGraph:ToTable()
	local nodes, links, remap = {}, {}, {}
	for id = 1, self.max_id do
		local pos = self.pos[id]
		if pos then
			local n = #nodes
			remap[id] = n / 3 + 1
			nodes[n + 1] = pos.x
			nodes[n + 2] = pos.y
			nodes[n + 3] = pos.z
		end
	end

	for a = 1, self.max_id do
		for b, mask in pairs(self.links[a] or {}) do
			if a < b and remap[a] and remap[b] then
				local n = #links
				links[n + 1], links[n + 2], links[n + 3] = remap[a], remap[b], mask
			end
		end
	end

	return { format = NodeGraph.FORMAT, version = NodeGraph.VERSION, nodes = nodes, links = links,
		node_count = self.count, link_count = #links / 3 }
end

-- @return string compressed data
function NodeGraph:Serialize()
	local data = self:ToTable()
	for i, value in ipairs(data.nodes) do data.nodes[i] = string.format('%.17g', value) end
	-- Encode flat numeric arrays directly: engine JSON limits must never truncate a navigation graph.
	local json = string.format('{"format":"%s","version":%d,"node_count":%d,"link_count":%d,"nodes":[%s],"links":[%s]}',
		data.format, data.version, data.node_count, data.link_count, table.concat(data.nodes, ','), table.concat(data.links, ','))
	return util.Compress(json)
end

-- @return NodeGraph|nil, string|nil error
function NodeGraph.FromTable(data, cell_size)
	if not istable(data) or data.format ~= NodeGraph.FORMAT then return nil, 'not a graph' end
	if data.version ~= NodeGraph.VERSION then return nil, 'unsupported version ' .. tostring(data.version) end

	local nodes, links = data.nodes or {}, data.links or {}
	if not istable(nodes) or not istable(links) or #nodes % 3 ~= 0 or #links % 3 ~= 0 or #nodes > 600000 then
		return nil, 'invalid graph arrays'
	end
	if (data.node_count ~= nil and data.node_count ~= #nodes / 3)
		or (data.link_count ~= nil and data.link_count ~= #links / 3)
	then
		return nil, 'graph counts do not match: data was truncated'
	end
	for _, value in ipairs(nodes) do
		if not isnumber(value) or value ~= value or math.abs(value) == math.huge then return nil, 'invalid graph position' end
	end
	for i = 1, #links, 3 do
		for j = i, i + 2 do
			local value = links[j]
			if not isnumber(value) or value < 0 or value > 2147483647 or value % 1 ~= 0 then
				return nil, 'invalid graph link'
			end
		end
		if links[i] < 1 or links[i] > #nodes / 3 or links[i + 1] < 1 or links[i + 1] > #nodes / 3 then
			return nil, 'graph link points to a missing node'
		end
	end
	local graph = NodeGraph(cell_size)

	for i = 1, #nodes - 2, 3 do
		graph:AddNode(Vector(nodes[i], nodes[i + 1], nodes[i + 2]))
	end

	for i = 1, #links - 2, 3 do
		local a, b, mask = links[i], links[i + 1], links[i + 2]
		if graph.pos[a] and graph.pos[b] and a ~= b then
			graph.links[a][b] = mask
			graph.links[b][a] = mask
		end
	end

	return graph
end

function NodeGraph.Deserialize(compressed, cell_size)
	if not isstring(compressed) or compressed == '' then return nil, 'empty data' end
	local json = util.Decompress(compressed)
	if not json then return nil, 'decompression failed' end
	return NodeGraph.FromTable(util.JSONToTable(json, true), cell_size)
end

-- ---------------------------------------------------------------------------
-- Tests
-- ---------------------------------------------------------------------------

bgNPC.Test.Add('nav.large_round_trip', function(check)
	local graph = NodeGraph()
	for i = 1, 6002 do
		graph:AddNode(Vector(i + 0.125, i % 10 + 0.0625, -0.03125))
		if i > 1 then graph:Link(i - 1, i, 'walk') end
	end
	local data = graph:ToTable()
	check(#data.nodes > 15000 and #data.links > 15000, 'both arrays exceed engine JSON limits')
	local copy = NodeGraph.Deserialize(graph:Serialize())
	check(copy and copy:Count() == 6002 and copy:LinksCount() == 6001, 'large graph counts survive serialization')
	if copy then
		for i = 1, 6002 do check(copy:GetPos(i) == graph:GetPos(i), 'point ' .. i .. ' keeps its coordinates') end
		for i = 1, 6001 do check(copy:IsLinked(i, i + 1, 'walk'), 'walk link ' .. i .. ' survives') end
	end
	table.remove(data.links)
	table.remove(data.links)
	table.remove(data.links)
	check(NodeGraph.FromTable(data) == nil, 'truncation of whole link triples is rejected')
end)

bgNPC.Test.Add('nav.node_graph', function(check)
	local g = NodeGraph(256)
	local ids = {}
	for i = 0, 9 do ids[i] = g:AddNode(Vector(i * 200, 0, 0)) end
	for i = 0, 8 do g:Link(ids[i], ids[i + 1], 'walk') end
	g:Link(ids[0], ids[9]) -- plain neighbour link, not walkable

	check(g:Count() == 10 and g:LinksCount() == 10, 'counts')
	check(g:IsLinked(ids[0], ids[9]) and not g:IsLinked(ids[0], ids[9], 'walk'), 'typed link mask')

	local walk = g:FindPath(ids[0], ids[9], 'walk')
	check(walk and #walk == 10, 'walk path goes through all nodes')
	local any = g:FindPath(ids[0], ids[9])
	check(any and #any == 2, 'untyped path uses the shortcut')

	check(#g:GetInRadius(Vector(0, 0, 0), 450) == 3, 'radius query')
	check(g:FindNearest(Vector(390, 10, 0), 1000) == ids[2], 'nearest')

	g:RemoveNode(ids[5])
	check(g:FindPath(ids[0], ids[9], 'walk') == nil, 'removed node breaks the walk path')
	check(not g:IsLinked(ids[4], ids[5]), 'links of removed node are gone')

	local copy = NodeGraph.Deserialize(g:Serialize(), 256)
	check(g.max_id == 10 and g:Exists(ids[9]) and not g:Exists(ids[5]), 'serialization keeps live ids and holes')
	check(copy and copy:Count() == 9 and copy:LinksCount() == 8, 'serialize round trip')
	check(copy and copy:FindPath(1, 5, 'walk') ~= nil, 'paths survive compaction')

	local moved = NodeGraph(256)
	local m1, m2 = moved:AddNode(Vector(0, 0, 0)), moved:AddNode(Vector(100, 0, 0))
	moved:Link(m1, m2, 'walk')
	moved:SetPos(m1, Vector(5000, 0, 0))
	check(moved:IsLinked(m1, m2, 'walk') and moved:FindNearest(Vector(5000, 0, 0), 10) == m1, 'SetPos keeps links')
end)

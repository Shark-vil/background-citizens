local Assert = bgNPC.Assert
local table_RemoveValueBySeq = bgNPC.Table.RemoveValue
local table_HasValueBySeq = bgNPC.Table.HasValue
local cvar_bgn_chunk_system  = GetConVar('bgn_chunk_system')
local cvar_bgn_chunk_size = GetConVar('bgn_chunk_size')
--
local MAP_CHUNKS
local is_infmap = bgNPC.Util.IsInfinityMap()
local LimitPointAxisZ = GetConVar('bgn_point_z_limit'):GetInt()
local CheckTraceSuccessToNodeUpperVector = Vector(0, 0, 10)
local CheckTraceSuccessToNodeFilter = function(ent)
	if ent:IsWorld() then return true end
end

BGN_NODE = {}
BGN_NODE.Map = {}
BGN_NODE.MapCount = 0
BGN_NODE.Chunks = {}
BGN_NODE.CHUNK_SIZE_X = 0
BGN_NODE.CHUNK_SIZE_Y = 0
BGN_NODE.CHUNK_SIZE_Z = 0

function BGN_NODE:IsOnChunkSystem()
	return cvar_bgn_chunk_system:GetBool()
end

-- Nodes are bucketed by cells of a uniform grid, a position maps to its cell in O(1).
local function InstanceChunks()
	local chunk_size = is_infmap and 10000 or cvar_bgn_chunk_size:GetInt()
	BGN_NODE.CHUNK_SIZE_X = chunk_size
	BGN_NODE.CHUNK_SIZE_Y = chunk_size
	BGN_NODE.CHUNK_SIZE_Z = chunk_size
	MAP_CHUNKS = bgNPC.SpatialGrid(chunk_size)
end

InstanceChunks()

if SERVER then
	local function OnChangeChunkCvars()
		timer.Create('BGN_Nodes_OnChangeChunkCvars', 2.5, 1, function()
			InstanceChunks()
			bgNPC.LoadRoutes()
		end)
	end

	cvars.AddChangeCallback('bgn_chunk_system', OnChangeChunkCvars, 'bgn_chunk_system_changed')
	cvars.AddChangeCallback('bgn_chunk_size', OnChangeChunkCvars, 'bgn_chunk_size_changed')
end

cvars.AddChangeCallback('bgn_point_z_limit', function(convar_name, value_old, value_new)
	LimitPointAxisZ = value_new
end, 'bgn_point_z_limit_change_callback')

local NODE = {}
NODE.__index = NODE
BGN_NODE.NodeClass = NODE

local function IsNode(value)
	return istable(value) and value.isNode == true
end

-- Calls fn(node) for every node on the map. Safe for maps with holes.
local function ForEachMapNode(fn)
	local map = BGN_NODE.Map
	for i = 1, BGN_NODE.MapCount do
		local node = map[i]
		if node then fn(node) end
	end
end

function NODE:AddParentNode(node)
	Assert.Arg(1, node, 'node', 'NODE:AddParentNode')

	if self == node or table_HasValueBySeq(self.parents, node) then return end
	table.insert(self.parents, node)
	if not node:HasParent(self) then node:AddParentNode(self) end
end

function NODE:RemoveParentNode(node)
	Assert.Arg(1, node, 'node', 'NODE:RemoveParentNode')

	if self == node then return end

	local parents = self.parents
	for i = 1, #parents do
		if parents[i] == node then
			self:RemoveLink(node)
			table.remove(parents, i)
			break
		end
	end

	if node:HasParent(self) then
		node:RemoveParentNode(self)
	end
end

function NODE:ClearParents()
	ForEachMapNode(function(node)
		if node ~= self and node:HasParent(self) then
			node:RemoveParentNode(self)
		end
	end)

	self.parents = {}
end

function NODE:HasParent(node)
	return table_HasValueBySeq(self.parents, node)
end

function NODE:AddLink(node, linkType)
	Assert.Arg(1, node, 'node', 'NODE:AddLink')
	Assert.Arg(2, linkType, 'string|nil', 'NODE:AddLink')

	if self == node or not linkType then return end

	local links = self.links[linkType]
	if not links then
		links = {}
		self.links[linkType] = links
	end

	if table_HasValueBySeq(links, node) then return end

	if not node:HasParent(self) then
		node:AddParentNode(self)
	end

	table.insert(links, node)

	if not node:HasLink(self, linkType) then
		node:AddLink(self, linkType)
	end
end

function NODE:RemoveLink(node, linkType)
	Assert.Arg(1, node, 'node', 'NODE:RemoveLink')
	Assert.Arg(2, linkType, 'string|nil', 'NODE:RemoveLink')

	if self == node then return end

	if not linkType then
		for linkTypeKey in pairs(self.links) do
			self:RemoveLink(node, linkTypeKey)
		end
		return
	end

	local links = self.links[linkType]
	if not links then return end

	for i = 1, #links do
		if links[i] == node then
			table.remove(links, i)
			break
		end
	end

	if node:HasLink(self, linkType) then
		node:RemoveLink(self, linkType)
	end
end

function NODE:ClearLinks(linkType)
	Assert.Arg(1, linkType, 'string', 'NODE:ClearLinks')

	if not self.links[linkType] then return end

	ForEachMapNode(function(node)
		if node ~= self and node:HasLink(self, linkType) then
			node:RemoveLink(self, linkType)
		end
	end)

	self.links[linkType] = {}
end

function NODE:HasLink(node, linkType)
	local links = self.links[linkType]
	if not links then return false end
	return table_HasValueBySeq(links, node)
end

function NODE:GetLinks(linkType)
	return self.links[linkType] or {}
end

function NODE:GetPos()
	return self.position
end

function NODE:CheckDistanceLimitToNode(position)
	return self.position:DistToSqr(position) <= self.parent_distance
end

function NODE:CheckHeightLimitToNode(position)
	local z = self.position.z
	return z >= position.z - LimitPointAxisZ and z <= position.z + LimitPointAxisZ
end

function NODE:CheckTraceSuccessToNode(position)
	local tr = util.TraceLine({
		start = self.position + CheckTraceSuccessToNodeUpperVector,
		endpos = position + CheckTraceSuccessToNodeUpperVector,
		filter = CheckTraceSuccessToNodeFilter
	})

	return not tr.Hit
end

function NODE:RemoveFromMap()
	if self.index == -1 then return end

	ForEachMapNode(function(node)
		if node ~= self and node:HasParent(self) then
			node:RemoveParentNode(self)
		end
	end)

	local node_chunk_id = self:GetChunkID()
	if node_chunk_id ~= -1 then
		local node_chunk = BGN_NODE.Chunks[node_chunk_id]
		if node_chunk then table_RemoveValueBySeq(node_chunk, self.index) end
	end

	if not table.remove(BGN_NODE.Map, self.index) then return end

	BGN_NODE.MapCount = BGN_NODE.MapCount - 1
	self.index = -1

	-- Indexes after the removed node have shifted, update them and their chunks.
	for i = 1, BGN_NODE.MapCount do
		local another_node = BGN_NODE.Map[i]
		if another_node and another_node.index ~= i then
			local past_index = another_node.index
			local chunk_id = another_node:GetChunkID()
			another_node.index = i

			if chunk_id ~= -1 then
				local another_chunk = BGN_NODE.Chunks[chunk_id]
				if another_chunk and table_RemoveValueBySeq(another_chunk, past_index) then
					table.insert(another_chunk, i)
				end
			end
		end
	end
end

function NODE:GetChunkID()
	if not self.chunk then return -1 end
	return self.chunk.index
end

function BGN_NODE:Instance(position_value)
	Assert.Arg(1, position_value, 'vector|table', 'BGN_NODE:Instance')

	local obj = setmetatable({}, NODE)
	obj.x = math.floor(position_value.x)
	obj.y = math.floor(position_value.y)
	obj.z = math.floor(position_value.z)
	obj.index = -1
	obj.isNode = true
	obj.position = Vector(obj.x, obj.y, obj.z)
	obj.parents = {}
	obj.links = {}
	obj.parent_distance = 250000
	obj.chunk = MAP_CHUNKS:GetCell(obj.position)

	-- Network form for bgNPC.Net (links are sent as node indexes).
	function obj.NetSerialize()
		local netobj = {}
		netobj.index = obj.index
		netobj.isNode = obj.isNode
		netobj.position = obj.position
		netobj.parents = {}
		netobj.links = {}

		for i = 1, #obj.parents do
			table.insert(netobj.parents, obj.parents[i].index)
		end

		for linkType, nodes in pairs(obj.links) do
			local net_links = {}
			for i = 1, #nodes do
				table.insert(net_links, nodes[i].index)
			end
			netobj.links[linkType] = net_links
		end

		return netobj
	end

	return obj
end

BGN_NODE.IsNode = IsNode

function BGN_NODE:GetChunkID(pos)
	return MAP_CHUNKS:Key(pos)
end

function BGN_NODE:GetChunkManager()
	return MAP_CHUNKS
end

function BGN_NODE:GetChunkNodesCount(pos)
	local chunk_id = self:GetChunkID(pos)
	if chunk_id == -1 then return 0 end
	local chunks = self.Chunks[chunk_id]
	if not chunks then return 0 end
	return #chunks
end

function BGN_NODE:GetChunkNodes(pos, is_async)
	assert(not is_async or isbool(is_async), 'Invalid parameter for calling asynchronous method')

	local chunk_id = self:GetChunkID(pos)
	if chunk_id == -1 then return {} end
	local chunks = self.Chunks[chunk_id]
	if not chunks then return {} end

	local nodes = {}
	local nodes_count = 0
	local async_pass

	if is_async then
		async_pass = 0
	end

	for i = 1, #chunks do
		local node = self.Map[chunks[i]]

		if node then
			nodes_count = nodes_count + 1
			nodes[nodes_count] = node
		end

		if is_async then
			async_pass = async_pass + 1
			if async_pass > bgNPC.Util.PassesPerYield() then
				async_pass = 0
				coroutine.yield()
			end
		end
	end

	return nodes
end

function BGN_NODE:GetChunkNodesAsync(pos)
	return self:GetChunkNodes(pos, true)
end

function BGN_NODE:AddNodeToMap(node)
	Assert.Arg(1, node, 'node|nil', 'BGN_NODE:AddNodeToMap')
	if not node then return end

	local chunk_id = node:GetChunkID()
	if SERVER and BGN_NODE:IsOnChunkSystem() and chunk_id == -1 then
		-- bgNPC.Util.Warning('Node cannot exist outside of a chunk!')
		bgNPC.Util.Log('Node ' .. tostring(node:GetPos()) .. ' cannot exist outside of a chunk!')
		return
	end

	local index
	if node.index ~= -1 then
		index = node.index
		if self.Map[index] == nil then self.MapCount = self.MapCount + 1 end
		self.Map[index] = node
	else
		index = table.insert(self.Map, node)
		node.index = index
		self.MapCount = self.MapCount + 1
	end

	if chunk_id ~= -1 then
		self.Chunks[chunk_id] = self.Chunks[chunk_id] or {}
		if not table_HasValueBySeq(self.Chunks[chunk_id], index) then
			table.insert(self.Chunks[chunk_id], index)
		end
	end
end

function BGN_NODE:GetNodeByIndex(index)
	return self.Map[index]
end

function BGN_NODE:GetNodeByPos(pos)
	for i = 1, self.MapCount do
		local node = self.Map[i]
		if node and node:GetPos() == pos then return node end
	end
end

function BGN_NODE:GetChunkNodesInRadius(pos, radius, is_async)
	assert(not is_async or isbool(is_async), 'Invalid parameter for calling asynchronous method')

	-- local async_pass
	local nodes_in_chunk = BGN_NODE:GetChunkNodes(pos, is_async)
	local nodes_in_radius = {}
	local nodes_count = 0
	radius = radius ^ 2

	-- if is_async then
	-- 	async_pass = 0
	-- end

	for i = 1, #nodes_in_chunk do
		local node = nodes_in_chunk[i]
		if node:GetPos():DistToSqr(pos) <= radius then
			nodes_count = nodes_count + 1
			nodes_in_radius[nodes_count] = node
		end

		-- if is_async then
		-- 	async_pass = async_pass + 1
		-- 	if async_pass > bgNPC.Util.PassesPerYield() then
		-- 		async_pass = 0
		-- 		coroutine.yield()
		-- 	end
		-- end
	end

	return nodes_in_radius
end

function BGN_NODE:GetChunkNodesInRadiusAsync(pos, radius)
	return self:GetChunkNodesInRadius(pos, radius, true)
end

function BGN_NODE:GetNodesInRadius(pos, radius, is_async)
	assert(not is_async or isbool(is_async), 'Invalid parameter for calling asynchronous method')

	local async_pass
	local nodes_in_radius = {}
	local nodes_count = 0
	radius = radius ^ 2

	if is_async then
		async_pass = 0
	end

	for i = 1, self.MapCount do
		local node = self.Map[i]
		if node and node:GetPos():DistToSqr(pos) <= radius then
			nodes_count = nodes_count + 1
			nodes_in_radius[nodes_count] = node
		end

		if is_async then
			async_pass = async_pass + 1
			if async_pass > bgNPC.Util.PassesPerYield() then
				async_pass = 0
				coroutine.yield()
			end
		end
	end

	return nodes_in_radius
end

function BGN_NODE:GetNodesInRadiusAsync(pos, radius)
	return self:GetNodesInRadius(pos, radius, true)
end

function BGN_NODE:GetChunkNodesCountInRadius(pos, radius, is_async)
	assert(not is_async or isbool(is_async), 'Invalid parameter for calling asynchronous method')

	-- local async_pass
	local nodes_in_chunk = BGN_NODE:GetChunkNodes(pos, is_async)
	local nodes_count = 0
	radius = radius ^ 2

	-- if is_async then
	-- 	async_pass = 0
	-- end

	for i = 1, #nodes_in_chunk do
		local node = nodes_in_chunk[i]
		if node:GetPos():DistToSqr(pos) <= radius then
			nodes_count = nodes_count + 1
		end

		-- if is_async then
		-- 	async_pass = async_pass + 1
		-- 	if async_pass > bgNPC.Util.PassesPerYield() then
		-- 		async_pass = 0
		-- 		coroutine.yield()
		-- 	end
		-- end
	end

	return nodes_count
end

function BGN_NODE:GetChunkNodesCountInRadiusAsync(pos, radius)
	return self:GetChunkNodesCountInRadius(pos, radius, true)
end

function BGN_NODE:GetNodesCountInRadius(pos, radius, is_async)
	assert(not is_async or isbool(is_async), 'Invalid parameter for calling asynchronous method')

	local async_pass
	local nodes_count = 0
	radius = radius ^ 2

	if is_async then
		async_pass = 0
	end

	for i = 1, self.MapCount do
		local node = self.Map[i]
		if node and node:GetPos():DistToSqr(pos) <= radius then
			nodes_count = nodes_count + 1
		end

		if is_async then
			async_pass = async_pass + 1
			if async_pass > bgNPC.Util.PassesPerYield() then
				async_pass = 0
				coroutine.yield()
			end
		end
	end

	return nodes_count
end

function BGN_NODE:GetNodesCountInRadiusAsync(pos, radius)
	return self:GetNodesCountInRadius(pos, radius, true)
end

function BGN_NODE:ClearNodeMap()
	self.Map = {}
	self.MapCount = 0
	self.Chunks = {}
end

function BGN_NODE:GetNodeMap()
	return self.Map
end

function BGN_NODE:CountNodesOnMap()
	return self.MapCount
end

function BGN_NODE:SetMap(map)
	self:ClearNodeMap()

	for i = 1, #map do
		self:AddNodeToMap(map[i])
	end

	self:FixOutsideMapNodes()
end

function BGN_NODE:ExpandMap(map, fix_outside_map_nodes, is_async)
	assert(not is_async or isbool(is_async), 'Invalid parameter for calling asynchronous method')

	for i = 1, #map do
		local node = map[i]
		if node.index == -1 then
			self:AddNodeToMap(node)
		end
		if is_async then coroutine.yield() end
	end

	if not isbool(fix_outside_map_nodes) and fix_outside_map_nodes == nil then
		fix_outside_map_nodes = true
	end

	if fix_outside_map_nodes then
		self:FixOutsideMapNodes()
	end
end

function BGN_NODE:ExpandMapAsync(map, fix_outside_map_nodes)
	self:ExpandMap(map, fix_outside_map_nodes, true)
end

function BGN_NODE:AutoLink(settings, is_async)
	assert(not is_async or isbool(is_async), 'Invalid parameter for calling asynchronous method')

	settings = settings or {}

	local nodes_count = self.MapCount
	local AsyncYield
	local async_current_pass

	if is_async then
		async_current_pass = 0
		AsyncYield = function()
			async_current_pass = async_current_pass + 1
			if async_current_pass > bgNPC.Util.PassesPerYield() then
				async_current_pass = 0
				coroutine.yield()
			end
		end
	end

	for i = 1, nodes_count do
		if is_async then AsyncYield() end

		local node = self.Map[i]
		if not node or (node.single_check and node.single_check_complete) then continue end
		if node.single_check then node.single_check_complete = true end

		for k = 1, nodes_count do
			if is_async then AsyncYield() end

			local another_node = self.Map[k]
			if not another_node or node == another_node then continue end
			-- if another_node.single_check and another_node.single_check_complete then continue end

			local another_node_pos = another_node:GetPos()
			if node:CheckDistanceLimitToNode(another_node_pos)
				and not another_node:HasParent(node)
				and node:CheckHeightLimitToNode(another_node_pos)
				and node:CheckTraceSuccessToNode(another_node_pos)
			then
				another_node:AddParentNode(node)
				another_node:AddLink(node, 'walk')
			end
		end
	end
end

function BGN_NODE:AutoLinkAsync(settings)
	self:AutoLink(settings, true)
end

function BGN_NODE:GetMap()
	return self.Map
end

function BGN_NODE:FixOutsideMapNodes()
	if CLIENT then return end

	local remove_count = 0

	for i = self.MapCount, 1, -1 do
		local node = self.Map[i]
		if not node or node.is_in_world then continue end

		local position = node:GetPos()
		if not util.IsInWorld(position) or bgNPC.Util.IsVectorInWater(position) then
			remove_count = remove_count + 1
			node:RemoveFromMap()
		else
			node.is_in_world = true
		end
	end

	if remove_count ~= 0 then
		bgNPC.Util.Log('[Background NPCs] "' .. remove_count .. '" points outside the map have been removed.')
	end
end

function BGN_NODE:MapToJson(map, prettyPrint, version)
	local JsonData = {}
	prettyPrint = prettyPrint or false
	map = map or self.Map

	for index, node in ipairs(map) do
		local JsonNode = {}
		JsonNode.position = node.position
		JsonNode.parents = {}
		JsonNode.links = {}

		if #node.parents ~= 0 then
			for _, parentNode in ipairs(node.parents) do
				if parentNode.index ~= -1 then
					table.insert(JsonNode.parents, parentNode.index)
				end
			end
		end

		if table.Count(node.links) ~= 0 then
			for linkType, links in pairs(node.links) do
				if #links ~= 0 then
					JsonNode.links[linkType] = JsonNode.links[linkType] or {}

					for _, node_value in ipairs(links) do
						table.insert(JsonNode.links[linkType], node_value.index)
					end
				end
			end
		end

		JsonData[index] = JsonNode
	end

	version = version or '1.2'

	return util.TableToJSON({
		bgn_wid_2341497926 = true,
		version = version,
		nodes = JsonData
	}, prettyPrint)
end

function BGN_NODE:JsonToMap(json_string)
	local mapData

	if isstring(json_string) then
		mapData = util.JSONToTable(json_string)
	elseif istable(json_string) then
		mapData = json_string
	else
		return {}
	end

	if not istable(mapData) or not mapData.version or not istable(mapData.nodes) then return {} end

	local map = {}

	for index, nodeData in ipairs(mapData.nodes) do
		local node = self:Instance(nodeData.position)
		node.index = index
		map[index] = node
	end

	for index, nodeData in ipairs(mapData.nodes) do
		local node = map[index]

		if node then
			for _, parentIndex in ipairs(nodeData.parents or {}) do
				local parentNode = map[parentIndex]

				if parentNode then
					node:AddParentNode(parentNode)
				end
			end

			for linkType, links in pairs(nodeData.links or {}) do
				for _, parentIndex in ipairs(links) do
					local parentNode = map[parentIndex]

					if parentNode then
						node:AddLink(parentNode, linkType)
					end
				end
			end
		end
	end

	return map
end

function BGN_NODE:GetRouteFileData()
	local map_name = game.GetMap()
	local jsonString

	if file.Exists('background_npcs/nodes/' .. map_name .. '.dat', 'DATA') and file.Size('background_npcs/nodes/' .. map_name .. '.dat', 'DATA') > 0 then
		local file_data = file.Read('background_npcs/nodes/' .. map_name .. '.dat', 'DATA')
		jsonString = util.Decompress(file_data)
	elseif file.Exists('background_npcs/nodes/' .. map_name .. '.json', 'DATA') and file.Size('background_npcs/nodes/' .. map_name .. '.json', 'DATA') > 0 then
		jsonString = file.Read('background_npcs/nodes/' .. map_name .. '.json', 'DATA')
	end

	if not jsonString or jsonString == '' then return end

	return jsonString
end

function BGN_NODE:RouteFileExists()
	local map_name = game.GetMap()

	if file.Exists('background_npcs/nodes/' .. map_name .. '.dat', 'DATA') and file.Size('background_npcs/nodes/' .. map_name .. '.dat', 'DATA') > 0 then
		return true
	elseif file.Exists('background_npcs/nodes/' .. map_name .. '.json', 'DATA') and file.Size('background_npcs/nodes/' .. map_name .. '.json', 'DATA') > 0 then
		return true
	end

	return false
end
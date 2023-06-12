local Vector = Vector
local pairs = pairs
local ipairs = ipairs
local math_floor = math.floor
-- local math_modf = math.modf
local table_insert = table.insert
local table_remove = table.remove
local table_RemoveValueBySeq = table.RemoveValueBySeq
local table_Count = table.Count
local table_HasValueBySeq = table.HasValueBySeq
local util_TraceLine = util.TraceLine
local util_TableToJSON = util.TableToJSON
local util_JSONToTable = util.JSONToTable
local coroutine_yield = coroutine.yield
--
local is_infmap = slib.IsInfinityMap()
if is_infmap then
	util_TraceLine = function(...) return util.TraceLine(...) end
end

local LimitPointAxisZ = GetConVar('bgn_point_z_limit'):GetInt()
local CheckTraceSuccessToNodeUpperVector = Vector(0, 0, 10)
local CheckTraceSuccessToNodeFilter = function(ent)
	if ent:IsWorld() then return true end
end

BGN_NODE = {}
BGN_NODE.Map = {}
BGN_NODE.MapCount = 0
BGN_NODE.Chunks = {}
BGN_NODE.CHUNK_SIZE_X = is_infmap and 10000 or 2000
BGN_NODE.CHUNK_SIZE_Y = is_infmap and 10000 or 2000
BGN_NODE.CHUNK_SIZE_Z = is_infmap and 10000 or 2000

local CHUNK_CLASS = slib.Component('Chunks')
local MAP_CHUNKS = CHUNK_CLASS:Instance({
	chunk_size_x = BGN_NODE.CHUNK_SIZE_X,
	chunk_size_y = BGN_NODE.CHUNK_SIZE_Y,
	chunk_size_z = BGN_NODE.CHUNK_SIZE_Z,
	no_check_is_in_world = true
})

if SERVER then
	hook.Add('BGN_PreLoadRoutes', 'BGN_Nodes_ChunkGenerate', function()
		if IsValid(MAP_CHUNKS) then return end
		-- MAP_CHUNKS:SetConditionChunkTouchesTheWorld()
		MAP_CHUNKS:MakeChunks()
	end)
end

cvars.AddChangeCallback('bgn_point_z_limit', function(convar_name, value_old, value_new)
	LimitPointAxisZ = value_new
end, 'bgn_point_z_limit_change_callback')

function BGN_NODE:Instance(position_value)
	local obj = {}
	obj.x = math_floor(position_value.x)
	obj.y = math_floor(position_value.y)
	obj.z = math_floor(position_value.z)
	obj.index = -1
	obj.isNode = true
	obj.position = Vector(obj.x, obj.y, obj.z)
	obj.parents = {}
	obj.links = {}
	obj.parent_distance = 250000
	obj.chunk = MAP_CHUNKS:GetChunkByVector(obj.position)

	function obj:_snet_getdata()
		local netobj = {}
		netobj.index = obj.index
		netobj.isNode = obj.isNode
		netobj.position = obj.position
		netobj.parents = {}
		netobj.links = {}

		for i = 1, #obj.parents do
			table_insert(netobj.parents, obj.parents[i].index)
		end

		for linkType, nodes in pairs(obj.links) do
			netobj.links[linkType] = netobj.links[linkType] or {}

			for i = 1, #nodes do
				table_insert(netobj.links[linkType], nodes[i].index)
			end
		end

		return netobj
	end

	function obj:AddParentNode(node)
		if self == node or table_HasValueBySeq(self.parents, node) then return end
		local index = table_insert(self.parents, node)
		self.parent_count = index
		if not node:HasParent(self) then node:AddParentNode(self) end
	end

	function obj:RemoveParentNode(node)
		if self == node then return end

		for i = 1, self.parent_count do
			local parentNode = self.parents[i]

			if parentNode == node then
				self:RemoveLink(parentNode)
				if table_remove(self.parents, i) then
					self.parent_count = self.parent_count - 1
				end
				break
			end
		end

		if node:HasParent(self) then
			node:RemoveParentNode(self)
		end
	end

	function obj:ClearParents()
		for i = 1, BGN_NODE.MapCount do
			local node = BGN_NODE.Map[i]

			if node:HasParent(self) then
				node:RemoveParentNode(self)
			end
		end

		self.parents = {}
	end

	function obj:HasParent(node)
		return table_HasValueBySeq(self.parents, node)
	end

	function obj:AddLink(node, linkType)
		if self == node then return end
		if not linkType then return end
		self.links[linkType] = self.links[linkType] or {}
		if table_HasValueBySeq(self.links[linkType], node) then return end

		if not node:HasParent(self) then
			node:AddParentNode(self)
		end

		table_insert(self.links[linkType], node)

		if not node:HasLink(self) then
			node:AddLink(self, linkType)
		end
	end

	function obj:RemoveLink(node, linkType)
		if self == node then return end

		if not linkType then
			for linkTypeKey, _ in pairs(self.links) do
				self:RemoveLink(node, linkTypeKey)
			end
		else
			for i = 1, #self.links[linkType] do
				local parentNode = self.links[linkType][i]

				if parentNode == node then
					table_remove(self.links[linkType], i)
					break
				end
			end

			if node:HasLink(self, linkType) then
				node:RemoveLink(self, linkType)
			end
		end
	end

	function obj:ClearLinks(linkType)
		if not self.links[linkType] then return end

		for i = 1, BGN_NODE.MapCount do
			local node = BGN_NODE.Map[i]

			if node:HasLink(self, linkType) then
				node:RemoveLink(self, linkType)
			end
		end

		self.links[linkType] = {}
	end

	function obj:HasLink(node, linkType)
		if not self.links[linkType] then return false end

		return table_HasValueBySeq(self.links[linkType], node)
	end

	function obj:GetLinks(linkType)
		return self.links[linkType] or {}
	end

	function obj:GetPos()
		return self.position
	end

	function obj:CheckDistanceLimitToNode(position)
		return self.position:DistToSqr(position) <= self.parent_distance
	end

	function obj:CheckHeightLimitToNode(position)
		local nodePos = self.position
		local anotherPosition = position
		return nodePos.z >= anotherPosition.z - LimitPointAxisZ and nodePos.z <= anotherPosition.z + LimitPointAxisZ
	end

	function obj:CheckTraceSuccessToNode(position)
		local nodePos = self.position + CheckTraceSuccessToNodeUpperVector
		local anotherPosition = position + CheckTraceSuccessToNodeUpperVector

		local tr = util_TraceLine({
			start = nodePos,
			endpos = anotherPosition,
			filter = CheckTraceSuccessToNodeFilter
		})

		return not tr.Hit
	end

	function obj:RemoveFromMap()
		if self.index == -1 then return end

		for i = 1, BGN_NODE.MapCount do
			local node = BGN_NODE.Map[i]
			if node ~= self and node:HasParent(self) then
				node:RemoveParentNode(self)
			end
		end

		do
			local node_chunk_id = self:GetChunkID()
			local node_chunk = BGN_NODE.Chunks[node_chunk_id]
			if node_chunk and table_HasValueBySeq(node_chunk, self.index) then
				table_RemoveValueBySeq(node_chunk, self.index)
			end
		end

		if table_remove(BGN_NODE.Map, self.index) then
			BGN_NODE.MapCount = BGN_NODE.MapCount - 1

			for i = 1, BGN_NODE.MapCount do
				local another_node = BGN_NODE.Map[i]
				local another_node_chunk_id = another_node:GetChunkID()
				local another_node_past_index = another_node.index
				another_node.index = i

				if another_node_past_index ~= another_node.index then
					local another_chunk = BGN_NODE.Chunks[another_node_chunk_id]
					if another_chunk and table_HasValueBySeq(another_chunk, another_node_past_index) then
						table_RemoveValueBySeq(another_chunk, another_node_past_index)
						table_insert(another_chunk, another_node.index)
					end
				end
			end
		end
	end

	function obj:GetChunkID()
		if not self.chunk then return -1 end
		return self.chunk.index
	end

	return obj
end

function BGN_NODE:GetChunkID(pos)
	local chunk = MAP_CHUNKS:GetChunkByVector(pos)
	if not chunk then return -1 end
	return chunk.index
end

function BGN_NODE:GetChunkManager()
	return MAP_CHUNKS
end

function BGN_NODE:GetChunkNodesCount(pos)
	local chunkId = self:GetChunkID(pos)
	local chunks = self.Chunks[chunkId]
	if not chunks then return 0 end
	return #chunks
end

function BGN_NODE:GetChunkNodes(pos)
	local chunkId = self:GetChunkID(pos)
	local chunks = self.Chunks[chunkId]

	if not chunks then return {} end

	local nodes = {}
	local nodes_count = 0

	for i = 1, #chunks do
		local node = self.Map[chunks[i]]

		if node then
			nodes_count = nodes_count + 1
			nodes[nodes_count] = node
		end
	end

	return nodes
end

function BGN_NODE:AddNodeToMap(node)
	if not node then return end

	local chunkId = node:GetChunkID()
	if SERVER and chunkId == -1 then
		slib.Warning('Node cannot exist outside of a chunk!')
		return
	end

	local index
	if node.index ~= -1 then
		index = node.index
		self.Map[index] = node
	else
		index = table_insert(self.Map, node)
		node.index = index
	end

	self.MapCount = self.MapCount + 1
	self.Chunks[chunkId] = self.Chunks[chunkId] or {}

	if not table_HasValueBySeq(self.Chunks[chunkId], index) then
		table_insert(self.Chunks[chunkId], index)
	end
end

function BGN_NODE:GetNodeByIndex(index)
	return self.Map[index]
end

function BGN_NODE:GetNodeByPos(pos)
	for i = 1, self.MapCount do
		if self.Map[i]:GetPos() == pos then return self.Map[i] end
	end
end

function BGN_NODE:GetChunkNodesInRadius(pos, radius)
	local nodes_in_chunk = BGN_NODE:GetChunkNodes(pos)
	local nodes_in_radius = {}
	local nodes_count = 0
	radius = radius ^ 2

	for i = 1, #nodes_in_chunk do
		local node = nodes_in_chunk[i]
		if node:GetPos():DistToSqr(pos) <= radius then
			nodes_count = nodes_count + 1
			nodes_in_radius[nodes_count] = node
		end
	end

	return nodes_in_radius
end

function BGN_NODE:GetNodesInRadius(pos, radius)
	local nodes_in_radius = {}
	local nodes_count = 0
	radius = radius ^ 2

	for i = 1, self.MapCount do
		local node = self.Map[i]
		if node:GetPos():DistToSqr(pos) <= radius then
			nodes_count = nodes_count + 1
			nodes_in_radius[nodes_count] = node
		end
	end

	return nodes_in_radius
end

function BGN_NODE:GetChunkNodesCountInRadius(pos, radius)
	local nodes_in_chunk = BGN_NODE:GetChunkNodes(pos)
	local nodes_count = 0
	radius = radius ^ 2

	for i = 1, #nodes_in_chunk do
		local node = nodes_in_chunk[i]
		if node:GetPos():DistToSqr(pos) <= radius then
			nodes_count = nodes_count + 1
		end
	end

	return nodes_count
end

function BGN_NODE:GetNodesCountInRadius(pos, radius)
	local nodes_count = 0
	radius = radius ^ 2

	for i = 1, self.MapCount do
		local node = self.Map[i]
		if node:GetPos():DistToSqr(pos) <= radius then
			nodes_count = nodes_count + 1
		end
	end

	return nodes_count
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

function BGN_NODE:ExpandMap(map, fix_outside_map_nodes)
	for i = 1, #map do
		local node = map[i]
		if node.index == -1 then
			self:AddNodeToMap(node)
		end
	end

	if not isbool(fix_outside_map_nodes) and fix_outside_map_nodes == nil then
		fix_outside_map_nodes = true
	end

	if fix_outside_map_nodes then
		self:FixOutsideMapNodes()
	end
end

function BGN_NODE:AutoLink(settings, is_async)
	settings = settings or {}

	local async_current_pass = 0
	local nodes_count = self.MapCount

	for i = 1, nodes_count do
		local node = self.Map[i]

		if is_async then
			async_current_pass = async_current_pass + 1
			if async_current_pass > 1 / slib.deltaTime then
				async_current_pass = 0
				coroutine_yield()
			end
		end

		if not node or (node.single_check and node.single_check_complete) then continue end
		if node.single_check then node.single_check_complete = true end

		for k = 1, nodes_count do
			local another_node = self.Map[k]
			if not another_node or node == another_node then continue end
			if another_node.single_check and another_node.single_check_complete then continue end

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

	for i = 1, nodes_count do
		local node = self.Map[i]
		if node.single_check then
			node.single_check_complete = true
		end
	end
end

function BGN_NODE:AutoLinkAsync(settings)
	BGN_NODE:AutoLink(settings, true)
end

function BGN_NODE:GetMap()
	return self.Map
end

function BGN_NODE:FixOutsideMapNodes()
	if CLIENT then return end

	local remove_count = 0
	local util_IsInWorld = util.IsInWorld

	for i = self.MapCount, 1, -1 do
		local node = self.Map[i]
		if not node or node.is_in_world then continue end

		if not util_IsInWorld(node:GetPos()) then
			remove_count = remove_count + 1
			node:RemoveFromMap()
		else
			node.is_in_world = true
		end
	end

	if remove_count ~= 0 then
		bgNPC:Log('[Background NPCs] "' .. remove_count .. '" points outside the map have been removed.')
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
					table_insert(JsonNode.parents, parentNode.index)
				end
			end
		end

		if table_Count(node.links) ~= 0 then
			for linkType, links in pairs(node.links) do
				if #links ~= 0 then
					JsonNode.links[linkType] = JsonNode.links[linkType] or {}

					for _, node_value in ipairs(links) do
						table_insert(JsonNode.links[linkType], node_value.index)
					end
				end
			end
		end

		JsonData[index] = JsonNode
	end

	version = version or '1.2'

	return util_TableToJSON({
		bgn_wid_2341497926 = true,
		version = version,
		nodes = JsonData
	}, prettyPrint)
end

function BGN_NODE:JsonToMap(json_string)
	local mapData

	if isstring(json_string) then
		mapData = util_JSONToTable(json_string)
	elseif istable(json_string) then
		mapData = json_string
	else
		return {}
	end

	if not mapData.version then return {} end

	local map = {}

	for index, nodeData in ipairs(mapData.nodes) do
		local node = self:Instance(nodeData.position)
		node.index = index
		map[index] = node
	end

	for index, nodeData in ipairs(mapData.nodes) do
		local node = map[index]

		if node then
			for _, parentIndex in ipairs(nodeData.parents) do
				local parentNode = map[parentIndex]

				if parentNode then
					node:AddParentNode(parentNode)
				end
			end

			for linkType, links in pairs(nodeData.links) do
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
local Vector = Vector
local pairs = pairs
local ipairs = ipairs
local math_floor = math.floor
local table_insert = table.insert
local table_remove = table.remove
local table_Count = table.Count
local table_HasValueBySeq = table.HasValueBySeq
local util_TraceLine = util.TraceLine
local util_TableToJSON = util.TableToJSON
local util_JSONToTable = util.JSONToTable
--
BGN_NODE = {}
BGN_NODE.Map = {}
BGN_NODE.Chunks = {}
local ChunkSizeMax = 32768
local OneChunkSize = 500

function BGN_NODE:Instance(position_value)
	local obj = {}
	obj.index = -1
	obj.isNode = true
	obj.position = position_value
	obj.parents = {}
	obj.links = {}

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
		table_insert(self.parents, node)

		if not node:HasParent(self) then
			node:AddParentNode(self)
		end
	end

	function obj:RemoveParentNode(node)
		if self == node then return end

		for i = 1, #self.parents do
			local parentNode = self.parents[i]

			if parentNode == node then
				self:RemoveLink(parentNode)
				table_remove(self.parents, i)
				break
			end
		end

		if node:HasParent(self) then
			node:RemoveParentNode(self)
		end
	end

	function obj:ClearParents()
		for i = 1, #BGN_NODE.Map do
			local node = BGN_NODE.Map[i]

			if node:HasParent(self) then
				node:RemoveParentNode(self)
			end
		end

		table.Empty(self.parents)
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

		for i = 1, #BGN_NODE.Map do
			local node = BGN_NODE.Map[i]

			if node:HasLink(self, linkType) then
				node:RemoveLink(self, linkType)
			end
		end

		table.Empty(self.links[linkType])
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
		-- local dist = GetConVar('bgn_ptp_distance_limit'):GetFloat() ^ 2
		-- return self.position:DistToSqr(position) <= dist
		return self.position:DistToSqr(position) <= 250000
	end

	function obj:CheckHeightLimitToNode(position)
		local z_limit = GetConVar('bgn_point_z_limit'):GetInt()
		local nodePos = self.position
		local anotherPosition = position

		return nodePos.z >= anotherPosition.z - z_limit and nodePos.z <= anotherPosition.z + z_limit
	end

	function obj:CheckTraceSuccessToNode(position)
		local nodePos = self.position
		local anotherPosition = position

		local tr = util_TraceLine({
			start = nodePos + Vector(0, 0, 10),
			endpos = anotherPosition + Vector(0, 0, 10),
			filter = function(ent)
				if ent:IsWorld() then return true end
			end
		})

		return not tr.Hit
	end

	function obj:RemoveFromMap()
		if self.index == -1 then return end

		for i = 1, #BGN_NODE.Map do
			local node = BGN_NODE.Map[i]

			if node ~= self and node:HasParent(self) then
				node:RemoveParentNode(self)
			end
		end

		local chunkId = self:GetChunkID()

		if BGN_NODE.Chunks[chunkId] and table_HasValueBySeq(BGN_NODE.Chunks[chunkId], self.index) then
			table_remove(BGN_NODE.Chunks[chunkId], self.index)
		end

		table_remove(BGN_NODE.Map, self.index)

		for i = 1, #BGN_NODE.Map do
			BGN_NODE.Map[i].index = i
		end
	end

	function obj:GetChunkID(chunkSize)
		return BGN_NODE:GetChunkID(self.position, chunkSize)
	end

	return obj
end

function BGN_NODE:GetChunkID(pos)
	local x = ChunkSizeMax - pos.x
	local y = ChunkSizeMax - pos.y
	local xid = math_floor(x / OneChunkSize)
	local yid = math_floor(y / OneChunkSize)

	return xid .. yid
end

function BGN_NODE:GetChunkNodes(pos)
	local chunkId = self:GetChunkID(pos)
	local chunk = self.Chunks[chunkId]
	if not chunk then return {} end
	local nodes = {}

	for i = 1, #chunk do
		local node = self.Map[chunk[i]]

		if node then
			table_insert(nodes, node)
		end
	end

	return nodes
end

function BGN_NODE:AddNodeToMap(node)
	local index

	if node.index ~= -1 then
		index = node.index
		self.Map[index] = node
	else
		index = table_insert(self.Map, node)
		node.index = index
	end

	local chunkId = node:GetChunkID()
	self.Chunks[chunkId] = self.Chunks[chunkId] or {}

	if not table_HasValueBySeq(self.Chunks[chunkId], index) then
		table_insert(self.Chunks[chunkId], index)
	end
end

function BGN_NODE:GetNodeByIndex(index)
	return self.Map[index]
end

function BGN_NODE:ClearNodeMap()
	table.Empty(self.Map)
	table.Empty(self.Chunks)
end

function BGN_NODE:GetNodeMap()
	return self.Map
end

function BGN_NODE:CountNodesOnMap()
	return #self.Map
end

function BGN_NODE:SetMap(map)
	self:ClearNodeMap()

	for i = 1, #map do
		self:AddNodeToMap(map[i])
	end

	self:FixOutsideMapNodes()
end

function BGN_NODE:GetMap()
	return self.Map
end

function BGN_NODE:FixOutsideMapNodes()
	if CLIENT then return end

	local remove_count = 0

	for i = #self.Map, 1, -1 do
		local node = self.Map[i]
		if not util.IsInWorld(node:GetPos()) then
			remove_count = remove_count + 1
			node:RemoveFromMap()
		end
	end

	if remove_count ~= 0 then
		MsgN('[Background NPCs] "' .. remove_count .. '" points outside the map have been removed.')
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
		version = version,
		nodes = JsonData
	}, prettyPrint)
end

function BGN_NODE:JsonToMap(json_string)
	local mapData = util_JSONToTable(json_string)
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
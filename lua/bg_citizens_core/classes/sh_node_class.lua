BGN_NODE = {}
BGN_NODE.Map = {}
BGN_NODE.Chunks = {}

local ChunkSizeMax = 32768
local OneChunkSize = 1000

function BGN_NODE:Instance(position)
   local obj = {}
   obj.index = -1
   obj.isNode = true
   obj.position = position
   obj.parents = {}

   function obj:AddParentNode(node)
      if self == node or table.HasValue(self.parents, node) then return end
      table.insert(self.parents, node)
      if not node:HasParent(self) then node:AddParentNode(self) end
   end

   function obj:RemoveParentNode(node)
      if self == node then return end
      for i = 1, #self.parents do
         local parentNode = self.parents[i]
         if parentNode == node then
            table.remove(self.parents, i)
            parentNode:RemoveParentNode(self)
            break
         end
      end
   end

   function obj:ClearParents()
      for _, node in ipairs(BGN_NODE.Map) do
         if node:HasParent(self) then
            node:RemoveParentNode(self)
         end
      end

      table.Empty(self.parents)
   end

   function obj:HasParent(node)
      return table.HasValue(self.parents, node)
   end

   function obj:GetPos()
      return self.position
   end

   function obj:CheckDistanceLimitToNode(position)
      local dist = GetConVar('bgn_ptp_distance_limit'):GetFloat() ^ 2
      return self.position:DistToSqr(position) <= dist
   end

   function obj:CheckHeightLimitToNode(position)
      local z_limit = GetConVar('bgn_point_z_limit'):GetInt()
      local nodePos = self.position
      local anotherPosition = position

      if nodePos.z >= anotherPosition.z - z_limit and nodePos.z <= anotherPosition.z + z_limit then
         local tr = util.TraceLine({
            start = nodePos + Vector(0, 0, 30),
            endpos = anotherPosition,
            filter = function(ent)
               if ent:IsWorld() then
                  return true
               end
            end
         })
         return not tr.Hit
      end

      return false
   end

   function obj:RemoveFromMap()
      if self.index == -1 then return end
      
      for index, node in ipairs(BGN_NODE.Map) do
         if node ~= self and node:HasParent(self) then
            node:RemoveParentNode(self)
         end
      end

      local chunkId = self:GetChunkID()
      if BGN_NODE.Chunks[chunkId] and table.HasValue(BGN_NODE.Chunks[chunkId], self.index) then
         table.remove(BGN_NODE.Chunks[chunkId], self.index)
      end

      table.remove(BGN_NODE.Map, self.index)

      for index, node in ipairs(BGN_NODE.Map) do
         node.index = index
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

   local xid = math.floor(x / OneChunkSize)
   local yid = math.floor(y / OneChunkSize)

   return xid .. yid
end

function BGN_NODE:GetChunkNodes(pos)
   local chunkId = self:GetChunkID(pos)
   local chunk = self.Chunks[chunkId]
   if not chunk then return {} end

   local nodes = {}
   for _, nodeIndex in ipairs(chunk) do
      local node = self.Map[nodeIndex]
      if node then
         table.insert(nodes, node)
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
      index = table.insert(self.Map, node)
      node.index = index
   end
   
   local chunkId = node:GetChunkID()
   self.Chunks[chunkId] = self.Chunks[chunkId] or {}
   if not table.HasValue(self.Chunks[chunkId], index) then
      table.insert(self.Chunks[chunkId], index)
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

   for _, node in ipairs(map) do
      self:AddNodeToMap(node)
   end
end

function BGN_NODE:GetMap()
   return self.Map
end

function BGN_NODE:MapToJson(map, prettyPrint)
   local JsonData = {}
   prettyPrint = prettyPrint or false
   map = map or self.Map

   for index, node in ipairs(map) do
      local JsonNode = {}
      JsonNode.position = node.position
      JsonNode.parents = {}

      if #node.parents ~= 0 then
         for _, parentNode in ipairs(node.parents) do
            if parentNode.index ~= -1 then
               table.insert(JsonNode.parents, parentNode.index)
            end
         end
      end

      JsonData[index] = JsonNode
   end

   return util.TableToJSON({
      version = '1.0',
      nodes = JsonData
   }, prettyPrint)
end

function BGN_NODE:JsonToMap(json_string)
   local mapData = util.JSONToTable(json_string)

   if not mapData.version then return {} end

   local map = {}

   for index, nodeData in ipairs(mapData.nodes) do
      local node = self:Instance(nodeData.position)
      node.index = index
      map[index] = node
   end

   for index, nodeData in ipairs(mapData.nodes) do
      if #nodeData.parents ~= 0 then
         for _, parentIndex in ipairs(nodeData.parents) do
            local node = map[index]
            local parentNode = map[parentIndex]
            node:AddParentNode(parentNode)
         end
      end
   end

   return map
end
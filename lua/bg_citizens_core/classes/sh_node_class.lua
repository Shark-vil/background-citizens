BGN_NODE = {}
BGN_NODE.Map = {}

function BGN_NODE:Instance(position)
   local obj = {}
   obj.index = -1
   obj.isNode = true
   obj.position = position
   obj.parents = {}

   function obj:AddParentNode(node)
      if self == node then return end
      table.insert(self.parents, node)
      if not node:HasParent(self) then node:AddParentNode(self) end
   end

   function obj:RemoveParentNode(node)
      for i = 1, #self.parents do
         local parentNode = self.parents[i]
         if parentNode == node then
            table.remove(self.parents, i)
            parentNode:RemoveParentNode(self)
            return
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
      table.RemoveByValue(BGN_NODE.Map, self)
   end

   return obj
end

function BGN_NODE:AddNodeToMap(node)
   local index = table.insert(self.Map, node)
   self.Map[index].index = index
end

function BGN_NODE:GetNodeByIndex(index)
   return self.Map[index]
end

function BGN_NODE:ClearNodeMap()
   table.Empty(self.Map)
end

function BGN_NODE:GetNodeMap()
   return self.Map
end

function BGN_NODE:CountNodesOnMap()
   return #self.Map
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
      local node = BGN_NODE:Instance(nodeData.position)
      node.index = index
      map[index] = node
   end

   for index, node in ipairs(map) do
      for nodeDataIndex, nodeData in ipairs(mapData.nodes) do
         if index == nodeDataIndex and #nodeData.parents ~= 0 then
            for _, parentIndex in ipairs(nodeData.parents) do
               local parentNode = map[parentIndex]
               node:AddParentNode(parentNode)
            end
         end
      end
   end

   return map
end
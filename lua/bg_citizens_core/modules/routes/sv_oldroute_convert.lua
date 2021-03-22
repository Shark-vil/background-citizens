local function getJsonString()
   local jsonString

   if file.Exists('citizens_points/' .. game.GetMap() .. '.dat', 'DATA') then
      local file_data = file.Read('citizens_points/' .. game.GetMap() .. '.dat', 'DATA')
      jsonString = util.Decompress(file_data)
   elseif file.Exists('citizens_points/' .. game.GetMap() .. '.json', 'DATA') then
      jsonString = file.Read('citizens_points/' .. game.GetMap() .. '.json', 'DATA')
   end

   return jsonString
end

local function VersionMigration()
   local jsonString = getJsonString()
   if not jsonString then return end

   local oldNodeMap = util.JSONToTable(jsonString)
   if oldNodeMap and not oldNodeMap.version then
      local newNodeMap = {}

      for index, v in ipairs(oldNodeMap) do
         local Node = BGN_NODE:Instance(v.pos)
         Node.index = index
         newNodeMap[index] = Node
      end

      for index, v in ipairs(oldNodeMap) do
         if #v.parents ~= 0 then
            local node = newNodeMap[index]
            for _, parentNodeIndex in ipairs(v.parents) do
               if parentNodeIndex ~= index then
                  local parentNode = newNodeMap[parentNodeIndex]
                  if parentNode then
                     node:AddParentNode(parentNode)
                  end
               end
            end
         end
      end

      local compressed_data = util.Compress(BGN_NODE:MapToJson(newNodeMap, false, '1.0'))
      file.Write('citizens_points/' .. game.GetMap() .. '.dat', compressed_data)

      MsgN('[Background NPCs] Migrated movement map to version - 1.0')

      VersionMigration()
   elseif oldNodeMap.version == '1.0' then
      local newNodeMap = {}

      for index, v in ipairs(oldNodeMap.nodes) do
         local Node = BGN_NODE:Instance(v.position)
         Node.index = index
         newNodeMap[index] = Node
      end

      for _, node in ipairs(newNodeMap) do
         for _, anotherNode in ipairs(newNodeMap) do
            if anotherNode ~= node then
               local pos = anotherNode:GetPos()
               
               if not anotherNode:HasParent(node) and node:CheckDistanceLimitToNode(pos) 
                  and node:CheckHeightLimitToNode(pos) and node:CheckTraceSuccessToNode(pos)
               then
                  anotherNode:AddParentNode(node)
               end
            end
         end
      end

      for index, v in ipairs(oldNodeMap.nodes) do
         if #v.parents ~= 0 then
            local node = newNodeMap[index]
            for _, parentNodeIndex in ipairs(v.parents) do
               local parentNode = newNodeMap[parentNodeIndex]
               if parentNode then
                  node:AddLink(parentNode, 'walk')
               end
            end
         end
      end

      local compressed_data = util.Compress(BGN_NODE:MapToJson(newNodeMap, false, '1.1'))
      file.Write('citizens_points/' .. game.GetMap() .. '.dat', compressed_data)

      MsgN('[Background NPCs] Migrated movement map to version - 1.1')

      VersionMigration()
   elseif oldNodeMap.version == '1.1' then
      if jsonString then
         local nodesMap = BGN_NODE:JsonToMap(jsonString)
         nodesMap.version = '1.2'
         file.Write('background_npcs/nodes/' .. game.GetMap() .. '.dat', 
            util.Compress(BGN_NODE:MapToJson(nodesMap)))
      end

      MsgN('[Background NPCs] Migrated movement map to version - 1.2')
   end
end

hook.Add('BGN_PreLoadRoutes', 'BGN_UpdateOldRoutes', function()
   VersionMigration()
end)
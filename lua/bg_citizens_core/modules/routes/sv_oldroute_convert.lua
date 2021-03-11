hook.Add('BGN_PreLoadRoutes', 'BGN_UpdateOldRoutes', function()
   local jsonString = ''

   if file.Exists('citizens_points/' .. game.GetMap() .. '.dat', 'DATA') then
      local file_data = file.Read('citizens_points/' .. game.GetMap() .. '.dat', 'DATA')
      jsonString = util.Decompress(file_data)
   elseif file.Exists('citizens_points/' .. game.GetMap() .. '.json', 'DATA') then
      jsonString = file.Read('citizens_points/' .. game.GetMap() .. '.json', 'DATA')
   end

   local oldNodeMap = util.JSONToTable(jsonString)
   if not oldNodeMap.version then
      local newNodeMap = {}

      for index, v in ipairs(oldNodeMap) do
         local Node = BGN_NODE:Instance(v.pos)
         Node.index = index
         newNodeMap[index] = Node
      end

      for index, node in ipairs(newNodeMap) do
         local oldNode = oldNodeMap[index]
         if oldNode.parents ~= 0 then
            for _, parentNodeIndex in ipairs(oldNode.parents) do
               node:AddParentNode(newNodeMap[parentNodeIndex])
            end
         end
      end

      local compressed_data = util.Compress(BGN_NODE:MapToJson(newNodeMap))
      file.Write('citizens_points/' .. game.GetMap() .. '.dat', compressed_data)
   end
end)
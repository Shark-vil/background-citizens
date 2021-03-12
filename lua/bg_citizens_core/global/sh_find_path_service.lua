local function CalculatePath(node, endPos)
   local foundPath = {}
   table.insert(foundPath, endPos)

   local currentNode = node
   while (currentNode.pastNode ~= nil) do
      table.insert(foundPath, currentNode.position)
      currentNode = currentNode.pastNode
   end

   table.insert(foundPath, currentNode.position)
   
   foundPath = table.Reverse(foundPath)

   return foundPath
end

local function GetNearNodeFromPos(nodes)
   local node = nil
	local F = nil
   local index = nil

	for id, v in ipairs(nodes) do
		if node == nil then
			node = v
			F = v.F
         index = id
      else
         if v.F < F then
            node = v
            F = v.F
            index = id
         end
      end
	end

	return node, index
end

local function NodeIsChecked(checkedNodes, node)
   for _, v in ipairs(checkedNodes) do
      if v.position == node.position then return true end
   end
   return false
end

local function IsNotWorld(startPos, endPos)
   local tr = util.TraceLine({
      start = startPos,
      endpos = endPos,
      filter = function(ent)
         if not ent:IsNPC() and ent:IsWorld() then
            return true
         end
      end
   })

   return not tr.Hit
end

function bgNPC:FindWalkPath(startPos, endPos, limitIteration)
   local G = startPos:DistToSqr(endPos)

   -- startPos = startPos + Vector(0, 0, 5)
   -- endPos = endPos + Vector(0, 0, 5)

   if G <= 250000 then 
      if IsNotWorld(startPos, endPos) then
         return { startPos, endPos }
      end
   end
   if BGN_NODE:CountNodesOnMap() == 0 then return {} end
   
   limitIteration = limitIteration or 100
   
   local currentIteration = 0
   local checkedNodes = {}
   local waitingNodes = {}

   local parents = {}
   for _, node in ipairs(BGN_NODE:GetChunkNodes(startPos)) do
      if IsNotWorld(startPos, node.position) then
         table.insert(parents, node)
      end
   end

   if #parents == 0 then return {} end

   local startNode = BGN_NODE:Instance(startPos)
   startNode.H = startNode.position:DistToSqr(endPos)
   startNode.F = G + startNode.H
   for _, node in ipairs(parents) do
      startNode:AddParentNode(node)
      node.pastNode = startNode
   end

   table.insert(waitingNodes, startNode)

   while (#waitingNodes > 0) do
      local nextNode, nodeIndex = GetNearNodeFromPos(waitingNodes)

      if IsNotWorld(nextNode.position, endPos) and nextNode.position:DistToSqr(endPos) <= 250000 then
         return CalculatePath(nextNode, endPos)
      else
         table.remove(waitingNodes, nodeIndex)

         if not NodeIsChecked(checkedNodes, nextNode) then
            table.insert(checkedNodes, nextNode)

            for _, node in ipairs(nextNode.parents) do
               local parentNode = BGN_NODE:Instance(node.position)
               parentNode.parents = node.parents
               parentNode.pastNode = nextNode
               parentNode.H = parentNode.position:DistToSqr(endPos)
               parentNode.F = G + parentNode.H
               table.insert(waitingNodes, parentNode)
            end
         end
      end

      currentIteration = currentIteration + 1
      if currentIteration > limitIteration then
         return {}
      end
   end

   return {}
end
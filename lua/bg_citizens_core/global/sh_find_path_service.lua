local function CalculatePath(node, endPos)
   local foundPath = {}
   table.insert(foundPath, endPos)

   local currentNode = node
   while (currentNode.pastNode ~= nil) do
      table.insert(foundPath, currentNode.position)
      currentNode = currentNode.pastNode
   end

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

function bgNPC:FindPath(startPos, endPos, limitIteration)
   local G = startPos:DistToSqr(endPos)

   startPos = startPos + Vector(0, 0, 20)
   endPos = endPos + Vector(0, 0, 20)

   if G <= 250000 then
      return { startPos, endPos }
   end

   if #bgNPC.points == 0 then return {} end

   limitIteration = limitIteration or 500

   local currentIteration = 0
   local checkedNodes = {}
   local waitingNodes = {}

   local parents = {}
   for _, index in ipairs(self:GetAllIndexPointsInRadius(startPos, 500)) do
      table.insert(parents, index)
   end

   if #parents == 0 then return {} end

   local startNode = BGN_NODE:Instance(startPos, parents)
   startNode.H = math.abs(startNode.position:DistToSqr(endPos))
   startNode.F = G + startNode.H
   table.insert(waitingNodes, startNode)

   while (#waitingNodes > 0) do
      local nextNode, nodeIndex = GetNearNodeFromPos(waitingNodes)

      local tr = util.TraceLine({
         start = nextNode.position,
         endpos = endPos,
         filter = function(ent)
            if ent:IsWorld() then
               return true
            end
         end
      })

      if not tr.Hit and nextNode.position:DistToSqr(endPos) <= 250000 then
         return CalculatePath(nextNode, endPos)
      else
         table.remove(waitingNodes, nodeIndex)

         if not NodeIsChecked(checkedNodes, nextNode) then
            table.insert(checkedNodes, nextNode)

            for _, index in ipairs(nextNode.parents) do
               local parentPoint = bgNPC.points[index]
               local parentNode = BGN_NODE:Instance(parentPoint.pos, parentPoint.parents)
               parentNode.pastNode = nextNode
               parentNode.H = math.abs(parentNode.position:DistToSqr(endPos))
               parentNode.F = G + parentNode.H
               table.insert(waitingNodes, parentNode)
            end
         else
            for i = 1, #checkedNodes do
               local node = checkedNodes[i]
               if node.position == nextNode.position and node.F > nextNode.F then
                  checkedNodes[i] = node
                  break
               end
            end
         end
      end

      currentIteration = currentIteration + 1
      if currentIteration > limitIteration then return {} end
   end

   return {}
end
local bgNPC = bgNPC
local table = table
local util = util
local isstring = isstring
local IsNotWorld = IsNotWorld
--

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

	for id = 1, #nodes do
		local v = nodes[id]

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
	for i = 1, #checkedNodes do
		if checkedNodes[i].position == node.position then return true end
	end

	return false
end

local function IsNotWorld(startPos, endPos)
	local tr = util.TraceLine({
		start = startPos,
		endpos = endPos,
		filter = function(ent)
			if not ent:IsNPC() and ent:IsWorld() then return true end
		end
	})

	return not tr.Hit
end

function bgNPC:FindWalkPath(startPos, endPos, limitIteration, pathType)
	local G = startPos:DistToSqr(endPos)

	if G <= 250000 and IsNotWorld(startPos, endPos) then
		return {startPos, endPos}
	end

	if BGN_NODE:CountNodesOnMap() == 0 then return {} end
	limitIteration = limitIteration or 300
	local currentIteration = 0
	local checkedNodes = {}
	local waitingNodes = {}
	local closetNode = bgNPC:GetClosestPointToPointInChunk(startPos, endPos)

	if not closetNode or not IsNotWorld(startPos, closetNode.position) then
		closetNode = bgNPC:GetClosestPointInRadius(startPos, 500)
		if not closetNode then return {} end
	end

	local startNode = BGN_NODE:Instance(startPos)
	startNode.H = startNode.position:DistToSqr(endPos)
	startNode.F = G + startNode.H
	startNode:AddParentNode(closetNode)

	if pathType and isstring(pathType) then
		startNode:AddLink(closetNode, pathType)
	end

	closetNode.pastNode = startNode
	table.insert(waitingNodes, startNode)

	while (#waitingNodes > 0) do
		local nextNode, nodeIndex = GetNearNodeFromPos(waitingNodes)

		if nextNode.position:DistToSqr(endPos) <= 250000 and IsNotWorld(nextNode.position, endPos) then
			return CalculatePath(nextNode, endPos)
		else
			table.remove(waitingNodes, nodeIndex)

			if not NodeIsChecked(checkedNodes, nextNode) then
				table.insert(checkedNodes, nextNode)
				local nodes = {}

				if pathType and isstring(pathType) then
					nodes = nextNode:GetLinks(pathType)
				else
					nodes = nextNode.parents
				end

				for i = 1, #nodes do
					local node = nodes[i]
					local parentNode = BGN_NODE:Instance(node.position)
					parentNode.parents = node.parents
					parentNode.links = node.links
					parentNode.pastNode = nextNode
					parentNode.H = parentNode.position:DistToSqr(endPos)
					parentNode.F = G + parentNode.H
					table.insert(waitingNodes, parentNode)
				end
			end
		end

		currentIteration = currentIteration + 1
		if currentIteration > limitIteration then return {} end
	end

	return {}
end
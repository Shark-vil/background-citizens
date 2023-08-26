local bgNPC = bgNPC
local isstring = isstring
local util_TraceLine = util.TraceLine
local table_remove = table.remove
local table_insert = table.insert
local table_Reverse = table.Reverse
local slib_IsInWorld = slib.IsInWorld
local math_sqrt = math.sqrt
local math_Round = math.Round
local vector_0_0_150 = Vector(0, 0, 150)
local vector_0_0_1000 = Vector(0, 0, 1000)
--

local function CalculatePath(node, endPos)
	local foundPath = {}
	table_insert(foundPath, endPos)
	local currentNode = node

	while (currentNode.pastNode ~= nil) do
		table_insert(foundPath, currentNode.position)
		currentNode = currentNode.pastNode
	end

	table_insert(foundPath, currentNode.position)
	foundPath = table_Reverse(foundPath)

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

local function IsNotWorld_Filter(ent)
	if not ent:IsNPC() and ent:IsWorld() then return true end
end

local function IsNotWorld(startPos, endPos)
	local tr = util_TraceLine({
		start = startPos,
		endpos = endPos,
		filter = IsNotWorld_Filter
	})

	return not tr.Hit
end

local function TracePositionFixed(trace_data, position)
	trace_data.start = position + vector_0_0_150
	trace_data.endpos = position - vector_0_0_1000
	return util_TraceLine(trace_data).HitPos
end

local function GetPrimitivePath(startPos, endPos, distance_point_to_point)
	local trace_data = {}
	local preliminary_point
	local point_spacing = 200
	local points_count = 1
	local points_limit = math_Round(math_sqrt(distance_point_to_point / (point_spacing ^ 2)))
	local add_direction = 0
	local direction = (endPos - startPos):GetNormalized()
	local movement_path = {}
	table_insert(movement_path, TracePositionFixed(trace_data, startPos))
	repeat
		add_direction = add_direction + point_spacing
		preliminary_point = startPos + (direction * add_direction)
		preliminary_point = TracePositionFixed(trace_data, preliminary_point)
		if not slib_IsInWorld(preliminary_point) then break end
		points_count = points_count + 1
		table_insert(movement_path, preliminary_point)
	until points_count >= points_limit
	table_insert(movement_path, TracePositionFixed(trace_data, endPos))
	return movement_path
end

function bgNPC:FindWalkPath(startPos, endPos, limitIteration, pathType)
	local G = startPos:DistToSqr(endPos)

	if G <= 250000 and IsNotWorld(startPos, endPos) then
		return {startPos, endPos}
	end

	if BGN_NODE:CountNodesOnMap() == 0 then
		return GetPrimitivePath(startPos, endPos, G)
	end

	limitIteration = limitIteration or 300
	local currentIteration = 0
	local checkedNodes = {}
	local waitingNodes = {}
	local closetNode = bgNPC:GetClosestPointInChunk(startPos)

	if not closetNode or not IsNotWorld(startPos, closetNode.position) then
		closetNode = bgNPC:GetClosestPointInRadius(startPos, 500)
		if not closetNode then
			return GetPrimitivePath(startPos, endPos, G)
		end
	end

	local startNode = BGN_NODE:Instance(startPos)
	startNode.H = startNode.position:DistToSqr(endPos)
	startNode.F = G + startNode.H
	startNode:AddParentNode(closetNode)

	if pathType and isstring(pathType) then
		startNode:AddLink(closetNode, pathType)
	end

	closetNode.pastNode = startNode
	table_insert(waitingNodes, startNode)

	while (#waitingNodes > 0) do
		local nextNode, nodeIndex = GetNearNodeFromPos(waitingNodes)

		if nextNode.position:DistToSqr(endPos) <= 250000 and IsNotWorld(nextNode.position, endPos) then
			return CalculatePath(nextNode, endPos)
		else
			table_remove(waitingNodes, nodeIndex)

			if not NodeIsChecked(checkedNodes, nextNode) then
				table_insert(checkedNodes, nextNode)
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
					table_insert(waitingNodes, parentNode)
				end
			end
		end

		currentIteration = currentIteration + 1
		if currentIteration > limitIteration then return {} end
	end

	return {}
end
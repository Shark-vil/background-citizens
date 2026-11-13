local bgNPC = bgNPC
local isstring = isstring
local util_TraceLine = util.TraceLine
local table_remove = table.remove
local table_insert = table.insert
local table_Reverse = table.Reverse
local slib_IsInWorld = slib.IsInWorld
local math_sqrt = math.sqrt
local math_Round = math.Round
local ents_FindInSphere = ents.FindInSphere
local table_Combine = table.Combine
local ipairs = ipairs
local Vector = Vector
local math_abs = math.abs
local vector_0_0_50 = Vector(0, 0, 50)
local vector_0_0_20 = Vector(0, 0, 20)
local vector_0_0_1000 = Vector(0, 0, 1000)
local MAX_MOVE_DISTANCE = 500
local MAX_MOVE_DISTANCE_SQRT = MAX_MOVE_DISTANCE ^ 2
--

local function CalculatePath(node, endPos)
	local foundPath = {}
	table_insert(foundPath, endPos)
	local currentNode = node

	while currentNode.pastNode do
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

local function IsWorld_Filter(ent)
	if ent:IsWorld()
		and not ent:IsNPC()
		and not ent:IsNextBot()
		and not ent:IsPlayer()
		and not ent:IsVehicle()
	then
		return true
	end
end

local function IsWorld(startPos, endPos)
	local tr = util_TraceLine({
		start = startPos,
		endpos = endPos,
		filter = IsWorld_Filter
	})

	return tr.Hit
end

local function IsNotWorld(startPos, endPos)
	return not IsWorld(startPos, endPos)
end

local TracePositionFixed
do
	local trace_data = {}
	function TracePositionFixed(position)
		trace_data.start = position + vector_0_0_50
		trace_data.endpos = position - vector_0_0_1000
		return util_TraceLine(trace_data).HitPos + vector_0_0_20
	end
end

local function TracePosViewDoor(door, endPos)
	local trace_data = {}
	trace_data.start = endPos
	trace_data.endpos = door:GetPos()
	trace_data.filter = function(ent) return IsValid(ent) and ent == door end
	return util_TraceLine(trace_data).HitPos
end

local function GetPrimitivePath(startPos, endPos, distance_point_to_point)
	local preliminary_point
	local point_spacing = 200
	local point_break_distance = point_spacing ^ 2
	local points_count = 1
	local points_limit = math_Round(math_sqrt(distance_point_to_point / (point_spacing ^ 2)))
	local add_direction = 0
	local direction = (endPos - startPos):GetNormalized()
	local movement_path = {}
	local entities_find_radius = 1000
	local doors_entities = {}

	table_insert(movement_path, TracePositionFixed(startPos))

	-- If there is an obstacle between the points,
	-- look for doors within a radius of 1000 points
	if IsWorld(startPos, endPos) then
		local duplicate_entities = {}
		local entities_in_radius = table_Combine(
			ents_FindInSphere(startPos, entities_find_radius),
			ents_FindInSphere(endPos, entities_find_radius)
		)
		for _, door in ipairs(entities_in_radius) do
			if not duplicate_entities[door] and not door:slibDoorIsLocked() then
				table_insert(doors_entities, door)
			end
			duplicate_entities[door] = true
		end
	end

	local doors_total_count = #doors_entities
	-- The function searches for the nearest door
	-- relative to the start point
	local NextDoorPoint = function(startTargetPos)
		if doors_total_count == 0 then
			return
		end
		if IsNotWorld(startTargetPos, endPos) then
			return
		end
		local near_door_pos, near_door_dist
		for i = #doors_entities, 1, -1 do
			local door = doors_entities[i]
			if not door:slibDoorIsLocked() then
				local door_pos = door:GetPos()
				local dist = endPos:DistToSqr(door_pos)
				if startTargetPos:DistToSqr(endPos) <= point_break_distance
					and (not near_door_pos or near_door_dist > dist)
					and (TracePosViewDoor(door, endPos) or TracePosViewDoor(door, startTargetPos))
				then
					table_remove(doors_entities, i)
					doors_total_count = doors_total_count - 1
					local min, max = door:GetModelBounds()
					local local_center = (min + max) / 2
					near_door_pos = door:LocalToWorld(local_center)
					near_door_dist = dist
					-- Fix point offset by direct to start pos
					local dir = (startPos - near_door_pos):GetNormalized()
					local forward = door:GetForward()
					local right = door:GetRight()
					local forwardDot = dir:Dot(forward)
					local rightDot = dir:Dot(right)
					local shift = 20
					if math_abs(forwardDot) > math_abs(rightDot) then
						near_door_pos = near_door_pos + forward * shift * (forwardDot > 0 and 1 or -1)
					else
						near_door_pos = near_door_pos + right * shift * (rightDot > 0 and 1 or -1)
					end
				end
			end
		end
		return near_door_pos
	end

	local near_door_pos = NextDoorPoint(startPos)
	if near_door_pos then
		table_insert(movement_path, near_door_pos)
		startPos = Vector(near_door_pos.x, near_door_pos.y, startPos.z)
	end

	repeat
		add_direction = add_direction + point_spacing
		preliminary_point = startPos + (direction * add_direction)
		preliminary_point = TracePositionFixed(preliminary_point)
		if preliminary_point:DistToSqr(endPos) <= point_break_distance or not slib_IsInWorld(preliminary_point) then
			break
		end
		near_door_pos = NextDoorPoint(preliminary_point)
		if near_door_pos then
			table_insert(movement_path, near_door_pos)
			preliminary_point = near_door_pos
			add_direction = point_spacing
		else
			table_insert(movement_path, preliminary_point)
		end
		points_count = points_count + 1
	until points_count >= points_limit

	table_insert(movement_path, TracePositionFixed(endPos))

	return movement_path
end

function bgNPC:FindWalkPath(startPos, endPos, limitIteration, pathType)
	local G = startPos:DistToSqr(endPos)

	if G <= MAX_MOVE_DISTANCE_SQRT and IsNotWorld(startPos, endPos) then
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
	if not closetNode or IsWorld(startPos, closetNode.position) then
		closetNode = bgNPC:GetClosestPointInRadius(startPos, 500)
		if not closetNode or IsWorld(startPos, closetNode.position) then
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

		if nextNode.position:DistToSqr(endPos) <= MAX_MOVE_DISTANCE_SQRT and IsNotWorld(nextNode.position, endPos) then
			local path =  CalculatePath(nextNode, endPos)
			-- Remove extra points that may be too redundant
			local path_count = #path
			while path_count > 0 do
				local node_position = path[1]
				if not node_position
					or node_position:DistToSqr(startPos) >= MAX_MOVE_DISTANCE_SQRT
					or IsWorld(startPos, node_position)
				then
					break
				end
				if table_remove(path, 1) then
					path_count = path_count - 1
				end
			end
			if #path == 0 then
				return GetPrimitivePath(startPos, endPos, G)
			end
			return path
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
		if currentIteration > limitIteration then
			break
		end
	end

	local easy_path = GetPrimitivePath(startPos, endPos, G)
	if #easy_path ~= 0 then
		return easy_path
	end

	return {}
end
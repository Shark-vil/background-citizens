local bgNPC = bgNPC
local Assert = bgNPC.Assert
local Points = bgNPC.Points
local IsValid = IsValid
local ipairs = ipairs
local Vector = Vector
local util_TraceLine = util.TraceLine
local table_remove = table.remove
local table_insert = table.insert
local ents_FindInSphere = ents.FindInSphere
local math_sqrt = math.sqrt
local math_Round = math.Round
local math_abs = math.abs
--

-- ---------------------------------------------------------------------------
-- Point queries
-- ---------------------------------------------------------------------------

local function HasLinkType(node, link_type)
	if not link_type then return true end
	local links = node.links[link_type]
	return links ~= nil and #links ~= 0
end

-- Returns the node with the smallest (or largest) distance to pos.
local function PickByDistance(nodes, pos, link_type, want_far)
	local result, result_dist

	for i = 1, #nodes do
		local node = nodes[i]
		if node and HasLinkType(node, link_type) then
			local dist = pos:DistToSqr(node.position)
			if not result_dist or (want_far and dist > result_dist) or (not want_far and dist < result_dist) then
				result = node
				result_dist = dist
			end
		end
	end

	return result
end

-- @param link_type string|nil only nodes that have links of this type
-- ! Without a link type the internal map table is returned, do not modify it.
function Points.GetAll(link_type)
	local map = BGN_NODE:GetMap()
	if not link_type then return map end

	local points = {}
	for i = 1, #map do
		local node = map[i]
		if node and HasLinkType(node, link_type) then points[#points + 1] = node end
	end
	return points
end

function Points.GetInRadius(center, radius, link_type)
	Assert.Arg(1, center, 'vector', 'bgNPC.Points.GetInRadius')
	Assert.Arg(2, radius, 'number', 'bgNPC.Points.GetInRadius')

	local radius_sqr = radius * radius
	local map = BGN_NODE:GetMap()
	local points = {}

	for i = 1, #map do
		local node = map[i]
		if node and node.position:DistToSqr(center) <= radius_sqr and HasLinkType(node, link_type) then
			points[#points + 1] = node
		end
	end

	return points
end

function Points.GetIndexesInRadius(center, radius, link_type)
	Assert.Arg(1, center, 'vector', 'bgNPC.Points.GetIndexesInRadius')
	Assert.Arg(2, radius, 'number', 'bgNPC.Points.GetIndexesInRadius')

	local radius_sqr = radius * radius
	local map = BGN_NODE:GetMap()
	local indexes = {}

	for i = 1, #map do
		local node = map[i]
		if node and node.position:DistToSqr(center) <= radius_sqr and HasLinkType(node, link_type) then
			indexes[#indexes + 1] = i
		end
	end

	return indexes
end

function Points.GetClosestInRadius(center, radius, link_type)
	Assert.Arg(1, center, 'vector', 'bgNPC.Points.GetClosestInRadius')
	return PickByDistance(Points.GetInRadius(center, radius or 500, link_type), center, nil, false)
end

function Points.GetDistantInRadius(center, radius, link_type)
	Assert.Arg(1, center, 'vector', 'bgNPC.Points.GetDistantInRadius')
	return PickByDistance(Points.GetInRadius(center, radius or 500, link_type), center, nil, true)
end

function Points.GetClosestInChunk(center, link_type)
	Assert.Arg(1, center, 'vector', 'bgNPC.Points.GetClosestInChunk')
	return PickByDistance(BGN_NODE:GetChunkNodes(center), center, link_type, false)
end

function Points.GetDistantInChunk(center, link_type)
	Assert.Arg(1, center, 'vector', 'bgNPC.Points.GetDistantInChunk')
	return PickByDistance(BGN_NODE:GetChunkNodes(center), center, link_type, true)
end

-- Closest to pos among the nodes of the chunk that contains center.
function Points.GetClosestToPosInChunk(center, pos, link_type)
	Assert.Arg(1, center, 'vector', 'bgNPC.Points.GetClosestToPosInChunk')
	Assert.Arg(2, pos, 'vector', 'bgNPC.Points.GetClosestToPosInChunk')
	return PickByDistance(BGN_NODE:GetChunkNodes(center), pos, link_type, false)
end

-- Farthest from pos among the nodes of the chunk that contains center.
function Points.GetDistantToPosInChunk(center, pos, link_type)
	Assert.Arg(1, center, 'vector', 'bgNPC.Points.GetDistantToPosInChunk')
	Assert.Arg(2, pos, 'vector', 'bgNPC.Points.GetDistantToPosInChunk')
	return PickByDistance(BGN_NODE:GetChunkNodes(center), pos, link_type, true)
end

-- ---------------------------------------------------------------------------
-- Path finding
-- ---------------------------------------------------------------------------

local MAX_MOVE_DISTANCE_SQR = 500 ^ 2
local DEFAULT_ITERATION_LIMIT = 300
local PRIMITIVE_POINT_SPACING = 200
local DOOR_SEARCH_RADIUS = 1000
local VECTOR_UP_50 = Vector(0, 0, 50)
local VECTOR_UP_20 = Vector(0, 0, 20)
local VECTOR_DOWN_1000 = Vector(0, 0, 1000)

local world_trace = {
	filter = function(ent) return ent:IsWorld() end
}

-- Is the line between two points blocked by the world.
local function IsWorldBetween(start_pos, end_pos)
	world_trace.start = start_pos
	world_trace.endpos = end_pos
	return util_TraceLine(world_trace).Hit
end

local floor_trace = {}

local function SnapToFloor(pos)
	floor_trace.start = pos + VECTOR_UP_50
	floor_trace.endpos = pos - VECTOR_DOWN_1000
	return util_TraceLine(floor_trace).HitPos + VECTOR_UP_20
end

local function CanSeeDoorFrom(door, pos)
	local tr = util_TraceLine({
		start = pos,
		endpos = door:GetPos(),
		filter = function(ent) return ent == door end
	})
	return tr.HitPos
end

-- A point just in front of the door, on the side facing start_pos.
local function GetDoorPassPoint(door, start_pos)
	local min, max = door:GetModelBounds()
	local door_pos = door:LocalToWorld((min + max) / 2)
	local dir = (start_pos - door_pos):GetNormalized()
	local forward, right = door:GetForward(), door:GetRight()
	local forward_dot, right_dot = dir:Dot(forward), dir:Dot(right)
	local shift = 20

	if math_abs(forward_dot) > math_abs(right_dot) then
		return door_pos + forward * shift * (forward_dot > 0 and 1 or -1)
	end

	return door_pos + right * shift * (right_dot > 0 and 1 or -1)
end

local function CollectUnlockedDoors(start_pos, end_pos)
	local doors = {}
	local seen = {}

	local function collect(ent)
		if not seen[ent] and IsValid(ent) and ent:slibIsDoor() and not ent:slibDoorIsLocked() then
			doors[#doors + 1] = ent
		end
		seen[ent] = true
	end

	for _, ent in ipairs(ents_FindInSphere(start_pos, DOOR_SEARCH_RADIUS)) do collect(ent) end
	for _, ent in ipairs(ents_FindInSphere(end_pos, DOOR_SEARCH_RADIUS)) do collect(ent) end

	return doors
end

-- A straight-line path used when there are no movement points.
-- If a wall is in the way, tries to route through nearby unlocked doors.
local function GetPrimitivePath(start_pos, end_pos)
	local break_dist_sqr = PRIMITIVE_POINT_SPACING ^ 2
	local points_limit = math_Round(math_sqrt(start_pos:DistToSqr(end_pos) / break_dist_sqr))
	local direction = (end_pos - start_pos):GetNormalized()
	local path = { SnapToFloor(start_pos) }
	local doors = IsWorldBetween(start_pos, end_pos) and CollectUnlockedDoors(start_pos, end_pos) or {}

	local function NextDoorPoint(from_pos)
		if #doors == 0 or not IsWorldBetween(from_pos, end_pos) then return end

		local best_pos, best_dist
		for i = #doors, 1, -1 do
			local door = doors[i]
			local dist = end_pos:DistToSqr(door:GetPos())
			if from_pos:DistToSqr(end_pos) <= break_dist_sqr
				and (not best_dist or best_dist > dist)
				and (CanSeeDoorFrom(door, end_pos) or CanSeeDoorFrom(door, from_pos))
			then
				table_remove(doors, i)
				best_pos = GetDoorPassPoint(door, start_pos)
				best_dist = dist
			end
		end

		return best_pos
	end

	local door_pos = NextDoorPoint(start_pos)
	if door_pos then
		table_insert(path, door_pos)
		start_pos = Vector(door_pos.x, door_pos.y, start_pos.z)
	end

	local offset = 0
	for _ = 1, points_limit do
		offset = offset + PRIMITIVE_POINT_SPACING

		local point = SnapToFloor(start_pos + direction * offset)
		if point:DistToSqr(end_pos) <= break_dist_sqr or not slib.IsInWorld(point) then
			break
		end

		door_pos = NextDoorPoint(point)
		if door_pos then
			table_insert(path, door_pos)
			offset = PRIMITIVE_POINT_SPACING
			start_pos = door_pos
		else
			table_insert(path, point)
		end
	end

	table_insert(path, SnapToFloor(end_pos))

	return path
end

local function FindStartNode(start_pos)
	local node = Points.GetClosestInChunk(start_pos)
	if node and not IsWorldBetween(start_pos, node.position) then return node end

	node = Points.GetClosestInRadius(start_pos, 500)
	if node and not IsWorldBetween(start_pos, node.position) then return node end
end

local function BuildPath(came_from, last_node, end_pos)
	local reversed = { end_pos }
	local node = last_node

	while node do
		reversed[#reversed + 1] = node.position
		node = came_from[node]
	end

	local path = {}
	for i = #reversed, 1, -1 do
		path[#path + 1] = reversed[i]
	end

	return path
end

-- Drops leading points the NPC can already walk past in a straight line.
local function TrimPathStart(path, start_pos)
	while #path > 1 do
		local pos = path[1]
		if pos:DistToSqr(start_pos) >= MAX_MOVE_DISTANCE_SQR or IsWorldBetween(start_pos, pos) then
			break
		end
		table_remove(path, 1)
	end
	return path
end

--[[
	Finds a walking path between two positions over the movement points (A*).
	The node map is never modified - all search state lives in local tables.

	@param start_pos vector
	@param end_pos vector
	@param iteration_limit number|nil max expanded nodes (default 300)
	@param link_type string|nil walk only over links of this type, nil - over all neighbours
	@return table list of positions, empty if no path was found
--]]
function Points.FindPath(start_pos, end_pos, iteration_limit, link_type)
	Assert.Arg(1, start_pos, 'vector', 'bgNPC.Points.FindPath')
	Assert.Arg(2, end_pos, 'vector', 'bgNPC.Points.FindPath')
	Assert.Arg(3, iteration_limit, 'number|nil', 'bgNPC.Points.FindPath')
	Assert.Arg(4, link_type, 'string|nil', 'bgNPC.Points.FindPath')

	if start_pos:DistToSqr(end_pos) <= MAX_MOVE_DISTANCE_SQR and not IsWorldBetween(start_pos, end_pos) then
		return { start_pos, end_pos }
	end

	if BGN_NODE:CountNodesOnMap() == 0 then
		return GetPrimitivePath(start_pos, end_pos)
	end

	local start_node = FindStartNode(start_pos)
	if not start_node then
		return GetPrimitivePath(start_pos, end_pos)
	end

	iteration_limit = iteration_limit or DEFAULT_ITERATION_LIMIT

	local open = { start_node }
	local in_open = { [start_node] = true }
	local closed = {}
	local came_from = {}
	local cost = { [start_node] = 0 }
	local score = { [start_node] = start_node.position:Distance(end_pos) }

	for _ = 1, iteration_limit do
		local open_count = #open
		if open_count == 0 then break end

		-- The open list stays small, a linear scan is cheaper than a heap here.
		local best_index = 1
		local best_score = score[open[1]]
		for i = 2, open_count do
			local node_score = score[open[i]]
			if node_score < best_score then
				best_index = i
				best_score = node_score
			end
		end

		local current = open[best_index]
		open[best_index] = open[open_count]
		open[open_count] = nil
		in_open[current] = nil

		local current_pos = current.position
		if current_pos:DistToSqr(end_pos) <= MAX_MOVE_DISTANCE_SQR and not IsWorldBetween(current_pos, end_pos) then
			local path = TrimPathStart(BuildPath(came_from, current, end_pos), start_pos)
			if #path ~= 0 then return path end
			break
		end

		closed[current] = true

		local neighbours = link_type and current:GetLinks(link_type) or current.parents
		local current_cost = cost[current]

		for i = 1, #neighbours do
			local neighbour = neighbours[i]
			if not closed[neighbour] then
				local new_cost = current_cost + current_pos:Distance(neighbour.position)
				local old_cost = cost[neighbour]

				if not old_cost or new_cost < old_cost then
					came_from[neighbour] = current
					cost[neighbour] = new_cost
					score[neighbour] = new_cost + neighbour.position:Distance(end_pos)

					if not in_open[neighbour] then
						in_open[neighbour] = true
						open[#open + 1] = neighbour
					end
				end
			end
		end
	end

	return GetPrimitivePath(start_pos, end_pos)
end


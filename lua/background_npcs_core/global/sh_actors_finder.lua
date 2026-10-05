local bgNPC = bgNPC
local Assert = bgNPC.Assert
local IsValid = IsValid
local istable = istable
local table_HasValueBySeq = table.HasValueBySeq
--

-- ---------------------------------------------------------------------------
-- Actors
-- ---------------------------------------------------------------------------

-- Returns the actor bound to an entity.
-- @param npc entity|nil
-- @return table|nil actor
function bgNPC:GetActor(npc)
	if not IsValid(npc) or not npc.isBgnActor then return nil end
	if npc.GetActor then return npc:GetActor() end
	return npc.BGN_ACTOR_OBJECT
end

function bgNPC:IsActor(npc)
	return self:GetActor(npc) ~= nil
end

function bgNPC:GetFirstActorInList()
	return self.actors[1]
end

function bgNPC:GetActorByUid(uid)
	if uid == nil then return nil end
	return self.actors_by_uid[uid]
end

function bgNPC:GetAll()
	return self.actors
end

-- @param npc_type string|nil actor type, nil - all actors
function bgNPC:Count(npc_type)
	if not npc_type then return #self.actors end
	local list = self.factors[npc_type]
	return list and #list or 0
end

function bgNPC:GetAllByType(npc_type)
	return self.factors[npc_type] or {}
end

local function FilterActors(actors, predicate)
	local result = {}
	for i = 1, #actors do
		local actor = actors[i]
		if predicate(actor) then result[#result + 1] = actor end
	end
	return result
end

function bgNPC:GetAllByTeam(team_data)
	return FilterActors(self.actors, function(actor) return actor:HasTeam(team_data) end)
end

function bgNPC:GetAllByState(state_name)
	return FilterActors(self.actors, function(actor) return actor:HasState(state_name) end)
end

function bgNPC:GetAllNPCs()
	return self.npcs
end

function bgNPC:GetAllNPCsByType(npc_type)
	return self.fnpcs[npc_type] or {}
end

local function FindNearestActor(actors, center, predicate)
	local nearest, nearest_dist

	for i = 1, #actors do
		local actor = actors[i]
		local npc = actor:GetNPC()
		if IsValid(npc) and (not predicate or predicate(actor)) then
			local dist = npc:GetPos():DistToSqr(center)
			if not nearest_dist or dist < nearest_dist then
				nearest = actor
				nearest_dist = dist
			end
		end
	end

	return nearest
end

function bgNPC:GetNear(center)
	Assert.Arg(1, center, 'vector', 'bgNPC:GetNear')
	return FindNearestActor(self.actors, center)
end

function bgNPC:GetNearByType(center, npc_type)
	Assert.Arg(1, center, 'vector', 'bgNPC:GetNearByType')
	Assert.Arg(2, npc_type, 'string', 'bgNPC:GetNearByType')
	return FindNearestActor(self:GetAllByType(npc_type), center)
end

function bgNPC:GetAllByRadius(center, radius)
	Assert.Arg(1, center, 'vector', 'bgNPC:GetAllByRadius')
	Assert.Arg(2, radius, 'number', 'bgNPC:GetAllByRadius')

	local radius_sqr = radius * radius
	return FilterActors(self.actors, function(actor)
		local npc = actor:GetNPC()
		return IsValid(npc) and npc:GetPos():DistToSqr(center) <= radius_sqr
	end)
end

function bgNPC:HasNPC(npc)
	return table_HasValueBySeq(self.npcs, npc)
end

-- Checks whether two actor entities share at least one team.
function bgNPC:IsTeamOnce(npc1, npc2)
	local actor1 = self:GetActor(npc1)
	local actor2 = self:GetActor(npc2)
	if not actor1 or not actor2 then return false end

	local team1 = actor1:GetData().team
	local team2 = actor2:GetData().team
	if not istable(team1) or not istable(team2) then return false end

	for i = 1, #team1 do
		if table_HasValueBySeq(team2, team1[i]) then return true end
	end

	return false
end

-- ---------------------------------------------------------------------------
-- Movement points
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

function bgNPC:GetAllPoints(link_type)
	local map = BGN_NODE:GetMap()
	if not link_type then return map end

	local points = {}
	for i = 1, #map do
		local node = map[i]
		if node and HasLinkType(node, link_type) then points[#points + 1] = node end
	end
	return points
end

function bgNPC:GetAllPointsInRadius(center, radius, link_type)
	Assert.Arg(1, center, 'vector', 'bgNPC:GetAllPointsInRadius')
	Assert.Arg(2, radius, 'number', 'bgNPC:GetAllPointsInRadius')

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

function bgNPC:GetAllIndexPointsInRadius(center, radius, link_type)
	Assert.Arg(1, center, 'vector', 'bgNPC:GetAllIndexPointsInRadius')
	Assert.Arg(2, radius, 'number', 'bgNPC:GetAllIndexPointsInRadius')

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

function bgNPC:GetClosestPointInRadius(center, radius, link_type)
	Assert.Arg(1, center, 'vector', 'bgNPC:GetClosestPointInRadius')
	return PickByDistance(self:GetAllPointsInRadius(center, radius or 500, link_type), center, nil, false)
end

function bgNPC:GetDistantPointInRadius(center, radius, link_type)
	Assert.Arg(1, center, 'vector', 'bgNPC:GetDistantPointInRadius')
	return PickByDistance(self:GetAllPointsInRadius(center, radius or 500, link_type), center, nil, true)
end

function bgNPC:GetClosestPointInChunk(center, link_type)
	Assert.Arg(1, center, 'vector', 'bgNPC:GetClosestPointInChunk')
	return PickByDistance(BGN_NODE:GetChunkNodes(center), center, link_type, false)
end

function bgNPC:GetDistantPointInChunk(center, link_type)
	Assert.Arg(1, center, 'vector', 'bgNPC:GetDistantPointInChunk')
	return PickByDistance(BGN_NODE:GetChunkNodes(center), center, link_type, true)
end

function bgNPC:GetClosestPointToPointInChunk(center, pos, link_type)
	Assert.Arg(1, center, 'vector', 'bgNPC:GetClosestPointToPointInChunk')
	Assert.Arg(2, pos, 'vector', 'bgNPC:GetClosestPointToPointInChunk')
	return PickByDistance(BGN_NODE:GetChunkNodes(center), pos, link_type, false)
end

function bgNPC:GetDistantPointToPointInChunk(center, pos, link_type)
	Assert.Arg(1, center, 'vector', 'bgNPC:GetDistantPointToPointInChunk')
	Assert.Arg(2, pos, 'vector', 'bgNPC:GetDistantPointToPointInChunk')
	return PickByDistance(BGN_NODE:GetChunkNodes(center), pos, link_type, true)
end

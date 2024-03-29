local bgNPC = bgNPC
local table_insert = table.insert
local table_HasValueBySeq = table.HasValueBySeq
local IsValid = IsValid
--

function bgNPC:GetActor(npc)
	if IsValid(npc) and npc.isBgnActor then
		return npc:GetActor()
	end
	return nil
end

function bgNPC:IsActor(npc)
	return self:GetActor(npc) ~= nil
end

function bgNPC:GetFirstActorInList()
	local actors = self:GetAll()
	for i = 1, #actors do
		local actor = actors[i]
		if actor then return actor end
	end
	return nil
end

function bgNPC:GetActorByUid(uid)
	if uid then
		local actors = self:GetAll()
		for i = 1, #actors do
			local actor = actors[i]
			if actor.uid == uid then return actor end
		end
	end
	return nil
end

function bgNPC:GetAllPoints(linkType)
	if not linkType then
		return BGN_NODE:GetMap()
	else
		local points = {}
		local map = BGN_NODE:GetMap()

		for i = 1, #map do
			local v = map[i]
			local links_list = v.links[linkType]

			if not links_list or #links_list == 0 then
				continue
			end

			table_insert(points, v)
		end

		return points
	end
end

function bgNPC:GetAllPointsInRadius(center, radius, linkType)
	radius = radius ^ 2

	local radius_positions = {}
	local map = BGN_NODE:GetMap()

	for i = 1, #map do
		local v = map[i]
		if v.position:DistToSqr(center) <= radius then
			if linkType then
				local links_list = v.links[linkType]
				if not links_list or #links_list == 0 then
					continue
				end
			end

			table_insert(radius_positions, v)
		end
	end

	return radius_positions
end

function bgNPC:GetAllIndexPointsInRadius(center, radius, linkType)
	radius = radius ^ 2

	local radius_positions = {}
	local map = BGN_NODE:GetMap()

	for i = 1, #map do
		local v = map[i]
		if linkType then
			local links_list = v.links[linkType]
			if not links_list or #links_list == 0 then
				continue
			end
		end

		if v.position:DistToSqr(center) <= radius then
			table_insert(radius_positions, i)
		end
	end

	return radius_positions
end

function bgNPC:GetClosestPointInRadius(center, radius, linkType)
	radius = radius or 500

	local point = nil
	local dist = nil
	local radius_points = self:GetAllPointsInRadius(center, radius)

	for i = 1, #radius_points do
		local v = radius_points[i]
		if linkType then
			local links_list = v.links[linkType]
			if not links_list or #links_list == 0 then
				continue
			end
		end

		local calcualte_distance = center:DistToSqr(v.position)

		if dist == nil or calcualte_distance < dist then
			point = v
			dist = calcualte_distance
		end
	end

	return point
end

function bgNPC:GetDistantPointInRadius(center, radius, linkType)
	radius = radius or 500

	local point = nil
	local dist = nil
	local radius_points = self:GetAllPointsInRadius(center, radius)

	for i = 1, #radius_points do
		local v = radius_points[i]
		if linkType then
			local links_list = v.links[linkType]
			if not links_list or #links_list == 0 then
				continue
			end
		end

		local calcualte_distance = center:DistToSqr(v.position)

		if dist == nil or calcualte_distance > dist then
			point = v
			dist = calcualte_distance
		end
	end

	return point
end

function bgNPC:GetClosestPointInChunk(center, linkType)
	local point = nil
	local dist = nil
	local nodes = BGN_NODE:GetChunkNodes(center)

	for i = 1, #nodes do
		local v = nodes[i]
		if linkType then
			local links_list = v.links[linkType]
			if not links_list or #links_list == 0 then
				continue
			end
		end

		local calcualte_distance = center:DistToSqr(v.position)

		if dist == nil or calcualte_distance < dist then
			point = v
			dist = calcualte_distance
		end
	end

	return point
end

function bgNPC:GetDistantPointInChunk(center, linkType)
	local point = nil
	local dist = nil
	local nodes = BGN_NODE:GetChunkNodes(center)

	for i = 1, #nodes do
		local v = nodes[i]
		if linkType then
			local links_list = v.links[linkType]
			if not links_list or #links_list == 0 then
				continue
			end
		end

		local calcualte_distance = center:DistToSqr(v.position)

		if dist == nil or calcualte_distance > dist then
			point = v
			dist = calcualte_distance
		end
	end

	return point
end

function bgNPC:GetClosestPointToPointInChunk(center, pos, linkType)
	local point = nil
	local dist = nil
	local nodes = BGN_NODE:GetChunkNodes(center)

	for i = 1, #nodes do
		local v = nodes[i]
		if linkType then
			local links_list = v.links[linkType]
			if not links_list or #links_list == 0 then
				continue
			end
		end

		local calcualte_distance = pos:DistToSqr(v.position)

		if dist == nil or calcualte_distance < dist then
			point = v
			dist = calcualte_distance
		end
	end

	return point
end

function bgNPC:GetDistantPointToPointInChunk(center, pos, linkType)
	local point = nil
	local dist = nil
	local nodes = BGN_NODE:GetChunkNodes(center)

	for i = 1, #nodes do
		local v = nodes[i]
		if linkType then
			local links_list = v.links[linkType]
			if not links_list or #links_list == 0 then
				continue
			end
		end

		local calcualte_distance = pos:DistToSqr(v.position)

		if dist == nil or calcualte_distance > dist then
			point = v
			dist = calcualte_distance
		end
	end

	return point
end

function bgNPC:GetAll()
	return self.actors
end

function bgNPC:Count(npc_type)
	if not npc_type then
		return #self.actors
	elseif self.factors[npc_type] then
		return #self.factors[npc_type]
	end
	return 0
end

function bgNPC:GetAllByType(npc_type)
	return self.factors[npc_type] or {}
end

function bgNPC:GetAllByTeam(team_data)
	local actors = {}

	for i = 1, #self.actors do
		local actor = self.actors[i]
		if actor:HasTeam(team_data) then
			table_insert(actors, actor)
		end
	end

	return actors
end

function bgNPC:GetAllByState(state_name)
	local actors = {}

	for i = 1, #self.actors do
		local actor = self.actors[i]
		if actor:HasState(state_name) then
			table_insert(actors, actor)
		end
	end

	return actors
end

function bgNPC:GetAllNPCs()
	return self.npcs
end

function bgNPC:GetAllNPCsByType(npc_type)
	return self.fnpcs[npc_type] or {}
end

function bgNPC:GetNear(center)
	local near_actor = nil
	local dist = nil
	local actors = self:GetAll()

	for i = 1, #actors do
		local actor = actors[i]
		local npc = actor:GetNPC()
		if IsValid(npc) then
			local calcualte_distance = npc:GetPos():DistToSqr(center)

			if dist == nil or calcualte_distance < dist then
				dist = calcualte_distance
				near_actor = actor
			end
		end
	end

	return near_actor
end


function bgNPC:GetNearByType(center, npc_type)
	local near_actor = nil
	local dist = nil
	local actors = self:GetAll()

	for i = 1, #actors do
		local actor = actors[i]
		local npc = actor:GetNPC()
		if actor:GetType() == npc_type and IsValid(npc) then
			local calcualte_distance = npc:GetPos():DistToSqr(center)

			if dist == nil or calcualte_distance < dist then
				dist = calcualte_distance
				near_actor = actor
			end
		end
	end

	return near_actor
end

function bgNPC:GetAllByRadius(center, radius)
	radius = radius ^ 2

	local npcs = {}
	local actors = self:GetAll()

	for i = 1, #actors do
		local actor = actors[i]
		local npc = actor:GetNPC()
		if IsValid(npc) and npc:GetPos():DistToSqr(center) <= radius then
			table_insert(npcs, actor)
		end
	end

	return npcs
end

function bgNPC:HasNPC(npc)
	return table_HasValueBySeq(bgNPC:GetAllNPCs(), npc)
end

function bgNPC:IsTeamOnce(npc1, npc2)
	local actor1 = self:GetActor(npc1)
	local actor2 = self:GetActor(npc2)

	if actor1 and actor2 then
		local data1 = actor1:GetData()
		local data2 = actor2:GetData()

		if data1.team and data2.team then
			for i = 1, #data1.team do
				for k = 1, #data2.team do
					if data1.team[i] == data2.team[k] then
						return true
					end
				end
			end
		end
	end

	return false
end
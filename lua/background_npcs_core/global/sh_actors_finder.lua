function bgNPC:GetActor(npc)
	if IsValid(npc) and npc.isBgnActor then
		return npc:GetActor()
	end
	return nil
end

function bgNPC:GetActorByUid(uid)
	if uid then
		local actors = self:GetAll()
		for i = 1, #actors do
			if actors[i].uid == uid then return actors[i] end
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
			if not v.links[linkType] or #v.links[linkType] == 0 then
				goto skip
			end

			table.insert(points, v)

			::skip::
		end

		return points
	end
end


function bgNPC:GetAllPointsInRadius(center, radius, linkType)
	local radius_positions = {}
	local radius = (radius or 500) ^ 2
	local map = BGN_NODE:GetMap()

	for i = 1, #map do
		local v = map[i]
		if v.position:DistToSqr(center) <= radius then
			if linkType and (not v.links[linkType] or #v.links[linkType] == 0) then
				goto skip
			end

			table.insert(radius_positions, v)
		end

		::skip::
	end

	return radius_positions
end

function bgNPC:GetAllIndexPointsInRadius(center, radius, linkType)
	local radius_positions = {}
	local radius = (radius or 500) ^ 2
	local map = BGN_NODE:GetMap()

	for i = 1, #map do
		local v = map[i]
		if linkType and (not v.links[linkType] or #v.links[linkType] == 0) then
			goto skip
		end

		if v.position:DistToSqr(center) <= radius then
			table.insert(radius_positions, i)
		end

		::skip::
	end

	return radius_positions
end

function bgNPC:GetClosestPointInRadius(center, radius, linkType)
	local point = nil
	local dist = nil
	local radius = radius or 500
	local radius_points = self:GetAllPointsInRadius(center, radius)

	for i = 1, #radius_points do
		local v = radius_points[i]
		if linkType and (not v.links[linkType] or #v.links[linkType] == 0) then
			goto skip
		end

		local calcualte_distance = center:DistToSqr(v.position)

		if dist == nil or calcualte_distance < dist then
			point = v
			dist = calcualte_distance
		end

		::skip::
	end

	return point
end

function bgNPC:GetDistantPointInRadius(center, radius, linkType)
	local point = nil
	local dist = nil
	local radius = radius or 500
	local radius_points = self:GetAllPointsInRadius(center, radius)

	for i = 1, #radius_points do
		local v = radius_points[i]
		if linkType and (not v.links[linkType] or #v.links[linkType] == 0) then
			goto skip
		end

		local calcualte_distance = center:DistToSqr(v.position)

		if dist == nil or calcualte_distance > dist then
			point = v
			dist = calcualte_distance
		end

		::skip::
	end

	return point
end

function bgNPC:GetClosestPointInChunk(center, linkType)
	local point = nil
	local dist = nil
	local nodes = BGN_NODE:GetChunkNodes(center)

	for i = 1, #nodes do
		local v = nodes[i]
		if linkType and (not v.links[linkType] or #v.links[linkType] == 0) then
			goto skip
		end

		local calcualte_distance = center:DistToSqr(v.position)

		if dist == nil or calcualte_distance < dist then
			point = v
			dist = calcualte_distance
		end

		::skip::
	end

	return point
end

function bgNPC:GetDistantPointInChunk(center, linkType)
	local point = nil
	local dist = nil
	local nodes = BGN_NODE:GetChunkNodes(center)

	for i = 1, #nodes do
		local v = nodes[i]
		if linkType and (not v.links[linkType] or #v.links[linkType] == 0) then
			goto skip
		end

		local calcualte_distance = center:DistToSqr(v.position)

		if dist == nil or calcualte_distance > dist then
			point = v
			dist = calcualte_distance
		end

		::skip::
	end

	return point
end

function bgNPC:GetClosestPointToPointInChunk(center, pos, linkType)
	local point = nil
	local dist = nil
	local nodes = BGN_NODE:GetChunkNodes(center)

	for i = 1, #nodes do
		local v = nodes[i]
		if linkType and (not v.links[linkType] or #v.links[linkType] == 0) then
			goto skip
		end

		local calcualte_distance = pos:DistToSqr(v.position)

		if dist == nil or calcualte_distance < dist then
			point = v
			dist = calcualte_distance
		end

		::skip::
	end

	return point
end

function bgNPC:GetDistantPointToPointInChunk(center, pos, linkType)
	local point = nil
	local dist = nil
	local nodes = BGN_NODE:GetChunkNodes(center)

	for i = 1, #nodes do
		local v = nodes[i]
		if linkType and (not v.links[linkType] or #v.links[linkType] == 0) then
			goto skip
		end

		local calcualte_distance = pos:DistToSqr(v.position)

		if dist == nil or calcualte_distance > dist then
			point = v
			dist = calcualte_distance
		end

		::skip::
	end

	return point
end

function bgNPC:GetAll()
	return self.actors
end

function bgNPC:GetAllByType(npc_type)
	return self.factors[npc_type] or {}
end

function bgNPC:GetAllByTeam(team_data)
	local actors = {}

	for i = 1, #self.actors do
		local actor = self.actors[i]
		if actor:HasTeam(team_data) then
			table.insert(actors, actor)
		end
	end

	return actors
end

function bgNPC:GetAllByState(state_name)
	local actors = {}

	for i = 1, #self.actors do
		local actor = self.actors[i]
		if actor:HasState(state_name) then
			table.insert(actors, actor)
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
	local npcs = {}
	local radius = radius ^ 2
	local actors = self:GetAll()

	for i = 1, #actors do
		local actor = actors[i]
		local npc = actor:GetNPC()
		if IsValid(npc) and npc:GetPos():DistToSqr(center) <= radius then
			table.insert(npcs, actor)
		end
	end

	return npcs
end

function bgNPC:HasNPC(npc)
	return array.HasValue(bgNPC:GetAllNPCs(), npc)
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
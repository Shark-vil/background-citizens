local Traffic = {}
bgNPC.PedestrianTraffic = Traffic
local STEP = Vector(0, 0, 18)

local function FloorPoint(npc, pos)
	local tr = util.TraceLine({ start = pos + Vector(0, 0, 32), endpos = pos - Vector(0, 0, 96),
		filter = npc, mask = MASK_NPCSOLID })
	if tr.Hit and not tr.StartSolid and tr.HitNormal.z > .65 then return tr.HitPos + Vector(0, 0, 1) end
end

local function CanWalk(npc, a, b)
	local mins, maxs = npc:GetCollisionBounds()
	local tr = util.TraceHull({ start = a + STEP, endpos = b + STEP,
		mins = mins, maxs = maxs, filter = npc, mask = MASK_NPCSOLID })
	if tr.Hit or tr.StartSolid then return false end
	local steps = math.max(1, math.ceil(a:Distance(b) / 48))
	local prev = a
	for i = 1, steps do
		local floor = FloorPoint(npc, LerpVector(i / steps, a, b))
		if not floor or math.abs(floor.z - prev.z) > 24 then return false end
		prev = floor
	end
	return true
end

-- Slab test in the car's local horizontal plane, expanded for the pedestrian hull.
local function CrossesCar(car, a, b, pad)
	a, b = car:WorldToLocal(a), car:WorldToLocal(b)
	local mins, maxs = car:OBBMins(), car:OBBMaxs()
	local lo, hi = 0, 1
	for _, axis in ipairs({ 'x', 'y' }) do
		local d = b[axis] - a[axis]
		local low, high = mins[axis] - pad, maxs[axis] + pad
		if math.abs(d) < .001 then
			if a[axis] < low or a[axis] > high then return false end
		else
			local enter, leave = (low - a[axis]) / d, (high - a[axis]) / d
			lo, hi = math.max(lo, math.min(enter, leave)), math.min(hi, math.max(enter, leave))
			if lo > hi then return false end
		end
	end
	return true
end

function Traffic.Plan(npc, car, goal)
	local start = npc:GetPos()
	local mins, maxs = npc:GetCollisionBounds()
	local pad = math.max(math.abs(mins.x), math.abs(mins.y), maxs.x, maxs.y) + 24
	local low, high = car:OBBMins(), car:OBBMaxs()
	local nodes = { start, goal }
	for _, x in ipairs({ low.x - pad, high.x + pad }) do
		for _, y in ipairs({ low.y - pad, high.y + pad }) do
			local p = car:LocalToWorld(Vector(x, y, 0))
			p.z = start.z
			p = FloorPoint(npc, p)
			if p then nodes[#nodes + 1] = p end
		end
	end
	-- At most six nodes; only test edges the shortest-path search actually needs.
	local costs, previous, closed = { [1] = 0 }, {}, {}
	for _ = 1, #nodes do
		local current
		for i, cost in pairs(costs) do
			if not closed[i] and (not current or cost < costs[current]) then current = i end
		end
		if not current then return end
		if current == 2 then
			local path, i = {}, 2
			while i ~= 1 do table.insert(path, 1, nodes[i]); i = previous[i] end
			return path
		end
		closed[current] = true
		for i, p in ipairs(nodes) do
			if not closed[i] then
				local cost = costs[current] + nodes[current]:Distance(p)
				if (not costs[i] or cost < costs[i]) and CanWalk(npc, nodes[current], p) then
					costs[i], previous[i] = cost, current
				end
			end
		end
	end
end

function Traffic.Update(actor, goal)
	local npc, now = actor.npc, CurTime()
	local detour = actor.dvDetour
	if detour then
		if not IsValid(detour.car) or detour.expires < now
			or detour.car:GetPos():DistToSqr(detour.anchor) > 80 ^ 2
			or (goal and detour.goal and (goal:DistToSqr(detour.goal) > 300 ^ 2
				or (goal - npc:GetPos()):Dot(detour.goal - npc:GetPos()) < 0)) then
			actor.dvDetour = nil
		else
			local target = detour.path[1]
			local tolerance = actor.body:IsNextBot() and 32 or 28
			if npc:GetPos():DistToSqr(target) < tolerance ^ 2 then
				table.remove(detour.path, 1)
				target = detour.path[1]
			end
			if not target then actor.dvDetour = nil; return false end
			if target ~= detour.sent then
				actor.body:MoveTo(target, true)
				detour.sent = target
			end
			return true
		end
	end
	if (actor.dvAvoidNextCheck or 0) > now then return false end
	actor.dvAvoidNextCheck = now + .5
	local pos, car, closest, blocked = npc:GetPos()
	local mins, maxs = npc:GetCollisionBounds()
	local pad = math.max(math.abs(mins.x), math.abs(mins.y), maxs.x, maxs.y) + 16
	for _, ent in ipairs(ents.FindInSphere(pos, 400)) do
		if ent.isBgnVehicle or IsValid(ent.DecentVehicle) then
			local d = ent:NearestPoint(pos):DistToSqr(pos)
			local crosses = goal and CrossesCar(ent, pos, goal, pad)
			if d < 200 ^ 2 and (crosses or d < 120 ^ 2) and (not closest or d < closest) then
				car, closest, blocked = ent, d, crosses
			end
		end
	end
	if car ~= actor.dvAvoidVehicle then
		actor.dvAvoidVehicle = car
		actor.dvYieldedVehicle = nil
		-- 30% ignore road caution so pedestrians can still run into traffic and get hit; solid obstacles still need a path.
		actor.dvIgnoreVehicle = car ~= nil and bgNPC.Util.Chance(30)
	end
	if not car then return false end
	local target = goal
	if not blocked then
		if actor.dvIgnoreVehicle or actor.dvYieldedVehicle == car then return false end
		local away = pos - car:WorldSpaceCenter(); away.z = 0
		if away:LengthSqr() < 1 then away = car:GetRight() end
		target = FloorPoint(npc, pos + away:GetNormalized() * 160)
	end
	if not target then return false end
	local delta = target - pos
	if delta:Length() > 600 then target = pos + delta:GetNormalized() * 600 end
	local path = Traffic.Plan(npc, car, target)
	if not path or #path == 0 then return false end
	if not blocked then actor.dvYieldedVehicle = car end
	actor.dvDetour = { car = car, anchor = car:GetPos(), goal = goal, path = path, expires = now + 10, sent = path[1] }
	actor.body:MoveTo(path[1], true)
	return true
end

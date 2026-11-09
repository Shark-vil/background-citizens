local Traffic = {}
bgNPC.VehicleTraffic = Traffic
local PERIOD = .2
local WAIT = 5
local MAX_NODES = 160

local function PoseKey(p)
	return math.Round(p.pos.x / 40) .. ':' .. math.Round(p.pos.y / 40) .. ':' .. math.Round(math.NormalizeAngle(p.yaw) / 20) .. ':' .. p.dir
end

local function Geometry(ai)
	local car = ai.v
	local low, high, center = car:OBBMins(), car:OBBMaxs(), car:OBBCenter()
	local forward = ai:GetVehicleForward()
	local local_forward = car:WorldToLocalAngles(forward:Angle()):Forward()
	local half = (high - low) * .5
	local filter = ai:GetTraceFilter()
	local wheelbase = math.max(70, (math.abs(local_forward.x) * half.x + math.abs(local_forward.y) * half.y) * 1.3)
	local wheels = car.Wheels
	-- shortcut: other axle layouts use body length; calibrate their wheelbase when testing them.
	if wheels and #wheels == 4 and IsValid(wheels[1]) and IsValid(wheels[2]) and IsValid(wheels[3]) and IsValid(wheels[4]) then
		wheelbase = ((wheels[1]:GetPos() + wheels[2]:GetPos()) * .5):Distance((wheels[3]:GetPos() + wheels[4]:GetPos()) * .5)
	end
	local floor = util.TraceLine({ start = car:WorldSpaceCenter(), endpos = car:WorldSpaceCenter() - Vector(0, 0, 300),
		filter = filter, mask = MASK_NPCSOLID })
	return { half = half, bottom = math.min(low.z - center.z + 18, high.z - center.z - 4), top = high.z - center.z,
		ride = car:WorldSpaceCenter().z - floor.HitPos.z, filter = filter,
		offset = math.AngleDifference(car:GetAngles().y, forward:Angle().y),
		wheelbase = math.max(wheelbase, 1) }
end

-- Sweep the whole footprint, conservatively enclosed in an AABB at the sampled yaw.
-- shortcut: yaw-only planning targets city streets; use 3D poses for recovery on steep ramps.
local function ClearPose(ai, g, a, b)
	if not IsValid(ai) or not IsValid(ai.v) then return false end
	local x, y = 0, 0
	local turn = math.AngleDifference(b.yaw, a.yaw)
	for _, fraction in ipairs({ 0, .5, 1 }) do
		local yaw = math.rad(a.yaw + turn * fraction + g.offset)
		local c, s = math.abs(math.cos(yaw)), math.abs(math.sin(yaw))
		x, y = math.max(x, c * g.half.x + s * g.half.y + 6), math.max(y, s * g.half.x + c * g.half.y + 6)
	end
	local floor = util.TraceLine({ start = b.pos + Vector(0, 0, 48), endpos = b.pos - Vector(0, 0, g.ride + 96),
		filter = g.filter, mask = MASK_NPCSOLID })
	if not floor.Hit or floor.HitNormal.z < .7 or math.abs(floor.HitPos.z + g.ride - a.pos.z) > 24 then return false, 'ground' end
	b.pos.z = floor.HitPos.z + g.ride
	local tr = util.TraceHull({ start = a.pos, endpos = b.pos, mins = Vector(-x, -y, g.bottom),
		maxs = Vector(x, y, g.top), filter = g.filter, mask = MASK_NPCSOLID })
	if tr.Hit or tr.StartSolid then return false, 'collision' end
	for _, dx in ipairs({ -1, 1 }) do
		for _, dy in ipairs({ -1, 1 }) do
			local corner = b.pos + Vector(dx * x, dy * y, 0)
			local ground = util.TraceLine({ start = corner + Vector(0, 0, 48), endpos = corner - Vector(0, 0, g.ride + 48),
				filter = g.filter, mask = MASK_NPCSOLID })
			if not ground.Hit or ground.HitNormal.z < .7 or math.abs(ground.HitPos.z - floor.HitPos.z) > 24 then return false, 'support' end
		end
	end
	return true
end

local function Advance(ai, geometry, pose, steer, direction)
	local yaw, pos = pose.yaw, pose.pos
	local curvature = math.tan(math.rad(ai:GetMaxSteeringAngle() * .8)) / geometry.wheelbase * steer
	for _ = 1, 3 do
		local next_yaw = yaw + math.deg(25 * direction * curvature)
		local heading = math.rad((yaw + next_yaw) * .5)
		local next_pose = { pos = pos + Vector(math.cos(heading), math.sin(heading), 0) * (25 * direction), yaw = next_yaw }
		if not ClearPose(ai, geometry, { pos = pos, yaw = yaw }, next_pose) then return end
		pos, yaw = next_pose.pos, next_yaw
	end
	return { pos = pos, yaw = yaw, dir = direction }
end

function Traffic.Plan(ai, goal, geometry)
	local start = { pos = ai.v:WorldSpaceCenter(), yaw = ai:GetVehicleForward():Angle().y, dir = 1 }
	local first = PoseKey(start)
	local poses, costs, parents, closed = { [first] = start }, { [first] = 0 }, {}, {}
	local heap = bgNPC.AStar.Heap()
	heap:Push(first, start.pos:Distance(goal))
	for iteration = 1, MAX_NODES do
		local key = heap:Pop()
		if not key then return end
		if not closed[key] then
			local pose = poses[key]
			if pose.pos:DistToSqr(goal) < 85 ^ 2 and pose.dir == 1 then
				local path = {}
				while key ~= first do table.insert(path, 1, poses[key]); key = parents[key] end
				return path, iteration
			end
			closed[key] = true
			for _, direction in ipairs({ 1, -1 }) do
				for _, steer in ipairs({ 0, -1, 1 }) do
					local next_pose = Advance(ai, geometry, pose, steer, direction)
					if next_pose then
						local nk = PoseKey(next_pose)
						local cost = costs[key] + 75 + (direction < 0 and 35 or 0) + (direction ~= pose.dir and 80 or 0)
						if not closed[nk] and (not costs[nk] or cost < costs[nk]) then
							poses[nk], costs[nk], parents[nk] = next_pose, cost, key
							heap:Push(nk, cost + next_pose.pos:Distance(goal) * 1.3)
						end
					end
					bgNPC.Tasks.Budget()
					if not IsValid(ai) or not IsValid(ai.v) then return end
				end
			end
		end
	end
end

local function Reserved(ai, path)
	for _, provider in ipairs(bgNPC.DVCars) do
		local other = provider:GetVehicleAI()
		local state = IsValid(other) and other.bgnTraffic
		if other ~= ai and state and state.path and IsValid(other.v) then
			local radius = ai.v:BoundingRadius() + other.v:BoundingRadius()
			for _, a in ipairs(path) do
				for _, b in ipairs(state.path) do
					if a.pos:DistToSqr(b.pos) < radius ^ 2 then return true end
				end
			end
		end
	end
	return false
end

local function Reset(ai, state, now)
	state.mode, state.path, state.safetyBlocked = nil, nil, nil
	state.mission, state.enemy, state.enemyPos = nil, nil, nil
	state.blockedAt, state.nextSafety = nil, nil
	state.anchor, state.progressAt = ai.v:GetPos(), now
	state.hornUntil = nil
	ai:SetHorn(false)
end

local function ScheduledStop(ai, now)
	return ai.WaitForCaller or now < ai.WaitUntilNext or now < ai.Emergency
		or (ai.Preference.StopAtTL and ai:AtTrafficLight())
end

local function Update(provider, now)
	local ai, car = provider:GetVehicleAI(), provider:GetVehicle()
	if not IsValid(ai) or not IsValid(car) or not car.isBgnVehicle then return end
	if not ai.bgnTrafficAttached or not ai:IsValidVehicle() or math.abs(ai:GetMaxSteeringAngle() or 0) < 1 then return end
	local state = ai.bgnTraffic
	if not state then
		state = { anchor = car:GetPos(), progressAt = now }
		ai.bgnTraffic = state
	end
	if state.mode then
		local driver = provider:GetDriver()
		if state.mission and (not driver or not isvector(driver.drive_target_pos) or driver.drive_target_pos:DistToSqr(state.mission) > 300 ^ 2) then
			Reset(ai, state, now)
		elseif state.enemy and (not driver or not IsValid(state.enemy) or driver:GetNearEnemy() ~= state.enemy
			or state.enemy:GetPos():DistToSqr(state.enemyPos) > 400 ^ 2) then
			Reset(ai, state, now)
		end
		if state.waypoint ~= ai.Waypoint or (state.expires and now > state.expires) then Reset(ai, state, now) end
		if state.path then
			if not state.moveAnchor or state.moveAnchor:DistToSqr(car:GetPos()) > 20 ^ 2 then
				state.moveAnchor, state.movedAt = car:GetPos(), now
			elseif now - state.movedAt > 3 and not ScheduledStop(ai, now) then
				Reset(ai, state, now - WAIT)
			end
		end
		return
	end
	if not ai.Waypoint or ScheduledStop(ai, now) then Reset(ai, state, now); return end
	if state.anchor:DistToSqr(car:GetPos()) > 64 ^ 2 then Reset(ai, state, now); return end
	local stuck = now - state.progressAt
	if stuck > 2 and now > (state.nextHorn or 0) then
		ai:SetHorn(true); state.hornUntil, state.nextHorn = now + .6, now + 3
	end
	if stuck < WAIT or now < (state.nextPlan or 0) then return end
	local obstacle = ai.Trace and ai.Trace.Entity
	local leader = IsValid(obstacle) and obstacle.DecentVehicle
	if IsValid(leader) and leader.bgnTraffic and leader.bgnTraffic.path then state.nextPlan = now + 1; return end
	local goal = ai.Waypoint.Target
	state.advance = goal:DistToSqr(car:WorldSpaceCenter()) < 180 ^ 2 and ai.NextWaypoint ~= nil
	if state.advance then goal = ai.NextWaypoint.Target end
	local delta = goal - car:WorldSpaceCenter()
	if delta:Length() > 650 then goal = car:WorldSpaceCenter() + delta:GetNormalized() * 650 end
	state.mode, state.waypoint = 'planning', ai.Waypoint
	local driver = provider:GetDriver()
	state.mission = driver and driver.drive_target_pos
	local enemy = driver and ai.IsTargetExists and not state.mission and driver:GetNearEnemy()
	if IsValid(enemy) then state.enemy, state.enemyPos = enemy, enemy:GetPos() end
	state.geometry = Geometry(ai)
	local path, iterations = Traffic.Plan(ai, goal, state.geometry)
	if not IsValid(ai) or not IsValid(car) then return end
	state.nextPlan = CurTime() + 4
	if path and #path > 0 and state.mode == 'planning' and not ScheduledStop(ai, CurTime())
		and not Reserved(ai, path) and state.waypoint == ai.Waypoint then
		state.mode, state.path, state.index = 'maneuver', path, 1
		state.moveAnchor, state.movedAt = car:GetPos(), CurTime()
		state.expires, state.iterations = CurTime() + 20, iterations
	else
		state.mode = nil
	end
end

local function Drive(ai, state, now)
	if state.mode == 'planning' or ScheduledStop(ai, now) then ai:StopDriving(); return end
	local target = state.path and state.path[state.index]
	if not target then
		if state.advance and state.waypoint == ai.Waypoint then ai:SetupNextWaypoint() end
		Reset(ai, state, now); ai:StopDriving(); return
	end
	local center = ai.v:WorldSpaceCenter()
	if center:DistToSqr(target.pos) < 35 ^ 2 then state.index = state.index + 1; return end
	local speed = ai.v:GetVelocity():Dot(ai:GetVehicleForward())
	local delta = target.pos - center; delta.z = 0
	local steering = math.deg(math.atan2(2 * state.geometry.wheelbase * ai:GetVehicleRight():Dot(delta), delta:LengthSqr()))
	steering = math.Clamp(steering / math.abs(ai:GetMaxSteeringAngle()), -1, 1)
	if now >= (state.nextSafety or 0) then
		state.nextSafety = now + .1
		local start = { pos = center, yaw = ai:GetVehicleForward():Angle().y }
		local distance = target.dir * math.max(25, math.abs(speed) * .3)
		local turn = -distance * math.tan(math.rad(steering * math.abs(ai:GetMaxSteeringAngle()))) / state.geometry.wheelbase
		local heading = math.rad(start.yaw) + turn * .5
		local ahead = { pos = center + Vector(math.cos(heading), math.sin(heading), 0) * distance, yaw = start.yaw + math.deg(turn) }
		local clear, reason = ClearPose(ai, state.geometry, start, ahead)
		state.safetyBlocked, state.blockReason = not clear, reason
		if state.safetyBlocked then state.blockedAt = state.blockedAt or now else state.blockedAt = nil end
	end
	if state.blockedAt and now - state.blockedAt > 2 then Reset(ai, state, now - WAIT); ai:StopDriving(); return end
	local desired = (target.dir < 0 and 80 or 160) / (1 + math.abs(steering))
	ai:SetHandbrake(state.safetyBlocked or speed * target.dir < -10 or math.abs(speed) > desired * 1.3)
	ai:SetSteering(steering)
	ai:SetThrottle(not state.safetyBlocked and math.abs(speed) < desired and target.dir * .6 or 0)
end

function Traffic.Attach(ai)
	if ai.bgnTrafficAttached then return end
	ai.bgnTrafficAttached = true
	local think, trace = ai.Think, ai.DoTrace
	function ai:Think()
		local state = self.bgnTraffic
		local now = CurTime()
		if state and state.hornUntil and now > state.hornUntil then self:SetHorn(false); state.hornUntil = nil end
		if state and state.mode and IsValid(self.v) and not self.v.isBgnVehicle then Reset(self, state, now) end
		if state and state.mode and IsValid(self.v) and ScheduledStop(self, now) then Reset(self, state, now) end
		if state and state.mode and IsValid(self.v) and self.v.isBgnVehicle and self:IsValidVehicle() then
			Drive(self, state, now)
			self:DoLights(); self:SetDriverPosition(); self:NextThink(now)
			return true
		end
		return think(self)
	end
	function ai:DoTrace()
		if CurTime() < (self.bgnNextTrafficTrace or 0) then return end
		local speed = IsValid(self.v) and self.v:GetVelocity():Length() or 0
		self.bgnNextTrafficTrace = CurTime() + math.Clamp(40 / math.max(speed, 1), .05, .2)
		return trace(self)
	end
end

bgNPC.Tasks.Add('BGN_VehicleTraffic', function(yield, wait, budget)
	while true do
		for _, provider in ipairs(bgNPC.DVCars) do
			local ok, err = pcall(Update, provider, CurTime())
			if not ok then
				local ai = provider:GetVehicleAI()
				if IsValid(ai) and IsValid(ai.v) and ai.bgnTraffic then
					Reset(ai, ai.bgnTraffic, CurTime()); ai.bgnTraffic.nextPlan = CurTime() + 4
				end
				ErrorNoHalt('[Background NPCs] Vehicle traffic: ' .. tostring(err) .. '\n')
			end
			budget()
		end
		wait(PERIOD)
	end
end)

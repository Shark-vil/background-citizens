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
  local axle_offset = wheelbase * .5
  local wheels = car.Wheels
  -- shortcut: other axle layouts estimate spacing and rear offset from the body; calibrate when testing them.
  if wheels and #wheels == 4 and IsValid(wheels[1]) and IsValid(wheels[2]) and IsValid(wheels[3]) and IsValid(wheels[4]) then
    wheelbase = ((wheels[1]:GetPos() + wheels[2]:GetPos()) * .5):Distance((wheels[3]:GetPos() + wheels[4]:GetPos()) * .5)
    axle_offset = (car:WorldSpaceCenter() - (wheels[3]:GetPos() + wheels[4]:GetPos()) * .5):Dot(forward)
  end

  local floor = util.TraceLine({
    start = car:WorldSpaceCenter(),
    endpos = car:WorldSpaceCenter() - Vector(0, 0, 300),
    filter = filter,
    mask = MASK_NPCSOLID
  })
  return {
    half = half,
    bottom = math.min(low.z - center.z + 18, high.z - center.z - 4),
    top = high.z - center.z,
    ride = car:WorldSpaceCenter().z - floor.HitPos.z,
    filter = filter,
    offset = math.AngleDifference(car:GetAngles().y, forward:Angle().y),
    wheelbase = math.max(wheelbase, 1),
    axleOffset = axle_offset
  }
end

-- Sweep the whole footprint, conservatively enclosed in an AABB at the sampled yaw.
-- shortcut: yaw-only planning targets city streets; use 3D poses for recovery on steep ramps.
local function ClearPose(ai, g, a, b)
  if not IsValid(ai) or not IsValid(ai.v) then return false end
  local x, y = 0, 0
  local turn = math.AngleDifference(b.yaw, a.yaw)
  for _, fraction in ipairs({0, .5, 1}) do
    local yaw = math.rad(a.yaw + turn * fraction + g.offset)
    local c, s = math.abs(math.cos(yaw)), math.abs(math.sin(yaw))
    x, y = math.max(x, c * g.half.x + s * g.half.y + 6), math.max(y, s * g.half.x + c * g.half.y + 6)
  end

  local floor = util.TraceLine({
    start = b.pos + Vector(0, 0, 48),
    endpos = b.pos - Vector(0, 0, g.ride + 96),
    filter = g.filter,
    mask = MASK_NPCSOLID
  })

  if not floor.Hit or floor.HitNormal.z < .7 or math.abs(floor.HitPos.z + g.ride - a.pos.z) > 24 then return false, 'ground' end
  b.pos.z = floor.HitPos.z + g.ride
  local tr = util.TraceHull({
    start = a.pos,
    endpos = b.pos,
    mins = Vector(-x, -y, g.bottom),
    maxs = Vector(x, y, g.top),
    filter = g.filter,
    mask = MASK_NPCSOLID
  })

  if tr.Hit or tr.StartSolid then return false, 'collision' end
  for _, dx in ipairs({-1, 1}) do
    for _, dy in ipairs({-1, 1}) do
      local corner = b.pos + Vector(dx * x, dy * y, 0)
      local ground = util.TraceLine({
        start = corner + Vector(0, 0, 48),
        endpos = corner - Vector(0, 0, g.ride + 48),
        filter = g.filter,
        mask = MASK_NPCSOLID
      })

      if not ground.Hit or ground.HitNormal.z < .7 or math.abs(ground.HitPos.z - floor.HitPos.z) > 24 then return false, 'support' end
    end
  end
  return true
end

local function Advance(ai, geometry, pose, steer, direction, axle_offset)
  local yaw, pos = pose.yaw, pose.pos
  local curvature = math.tan(math.rad(ai:GetMaxSteeringAngle() * .8)) / geometry.wheelbase * steer
  for _ = 1, 3 do
    local next_yaw = yaw + math.deg(25 * direction * curvature)
    local heading = math.rad((yaw + next_yaw) * .5)
    -- The bicycle model turns about its rear axle; collision poses remain at the body center.
    local rear = pos - Vector(math.cos(math.rad(yaw)), math.sin(math.rad(yaw)), 0) * axle_offset
    local next_pos = rear + Vector(math.cos(heading), math.sin(heading), 0) * (25 * direction) + Vector(math.cos(math.rad(next_yaw)), math.sin(math.rad(next_yaw)), 0) * axle_offset
    local next_pose = {
      pos = next_pos,
      yaw = next_yaw
    }

    if not ClearPose(ai, geometry, {
      pos = pos,
      yaw = yaw
    }, next_pose) then
      return
    end

    pos, yaw = next_pose.pos, next_yaw
  end
  return {
    pos = pos,
    yaw = yaw,
    dir = direction
  }
end

function Traffic.Plan(ai, goal, geometry, goal_direction)
  local start = {
    pos = ai.v:WorldSpaceCenter(),
    yaw = ai:GetVehicleForward():Angle().y,
    dir = 1
  }

  local first = PoseKey(start)
  local poses, costs, parents, closed = {
    [first] = start
  }, {
    [first] = 0
  }, {}, {}

  local heap = bgNPC.AStar.Heap()
  heap:Push(first, start.pos:Distance(goal))
  for iteration = 1, goal_direction and MAX_NODES * 4 or MAX_NODES do
    local key = heap:Pop()
    if not key then return end
    if not closed[key] then
      local pose = poses[key]
      if pose.pos:DistToSqr(goal) < (goal_direction and 35 ^ 2 or 85 ^ 2) and pose.dir == 1 and (not goal_direction or Vector(math.cos(math.rad(pose.yaw)), math.sin(math.rad(pose.yaw)), 0):Dot(goal_direction) > .95) then
        local path = {}
        while key ~= first do
          table.insert(path, 1, poses[key])
          key = parents[key]
        end
        return path, iteration
      end

      closed[key] = true
      for _, direction in ipairs({1, -1}) do
        for _, steer in ipairs({0, -1, 1}) do
          local next_pose = Advance(ai, geometry, pose, steer, direction, goal_direction and geometry.axleOffset or 0)
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

function Traffic.AlternateLanes(ai)
  local dvd, lanes = DecentVehicleDestination, {}
  local origin = ai.v:WorldSpaceCenter()
  local rejected = ai.bgnTraffic.rejectedLanes or {}
  local direction = ai.PrevWaypoint and (ai.Waypoint.Target - ai.PrevWaypoint.Target):GetNormalized() or ai:GetVehicleForward()
  for id, from in ipairs(dvd.Waypoints) do
    if id % 128 == 0 then bgNPC.Tasks.Budget() end -- the whole map's waypoints are scanned
    if dvd.WaypointAvailable(id, ai.Group) then
      for _, next_id in ipairs(from.Neighbors) do
        local to = dvd.Waypoints[next_id]
        if to and (rejected[to] or 0) <= CurTime() and dvd.WaypointAvailable(next_id, ai.Group) then
          local heading = (to.Target - from.Target):GetNormalized()
          local distance = origin:DistToSqr(to.Target)
          if heading:LengthSqr() > .5 and heading:Dot(direction) < .5 and distance > 100 ^ 2 and distance < 650 ^ 2 and (to.Target - origin):Dot(heading) > 100 and math.abs(to.Target.z + ai.bgnTraffic.geometry.ride - origin.z) < 48 then
            lanes[#lanes + 1] = {
              from = from,
              to = to,
              direction = heading,
              distance = distance
            }
          end
        end
      end
    end
  end

  table.sort(lanes, function(a, b) return a.distance < b.distance end)
  return lanes
end

local function Reset(ai, state, now)
  if state.lane then
    state.rejectedLanes = state.rejectedLanes or {}
    state.rejectedLanes[state.lane.to] = now + 30
  end

  state.mode, state.path, state.safetyBlocked, state.lane, state.retryLane = nil, nil, nil, nil, nil
  state.mission, state.enemy, state.enemyPos = nil, nil, nil
  state.blockedAt, state.nextSafety = nil, nil
  state.moveIndex, state.bestDistance, state.moveAnchor = nil, nil, nil
  state.anchor, state.progressAt = ai.v:GetPos(), now
  state.hornUntil = nil
  ai:SetHorn(false)
end

local function ScheduledStop(ai, now)
  return ai.WaitForCaller or now < ai.WaitUntilNext or now < ai.Emergency or (ai.Preference.StopAtTL and ai:AtTrafficLight())
end

local function NeedsRecovery(ai)
  local delta = ai.Waypoint.Target - ai.v:WorldSpaceCenter()
  return (ai.Trace and ai.Trace.Hit) or (ai.TraceWaypoint and ai.TraceWaypoint.Hit) or delta:GetNormalized():Dot(ai:GetVehicleForward()) < .5
end

-- A driver in fear gets away from the attacker by any means: no stops for lights, people or crashes, faster than the limit.
local FLEE_STATES = {'fear', 'run_from_danger', 'dyspnea_danger'}
local FLEE_PREFS = {'StopAtTL', 'StopInfrontofPerson', 'StopEmergency', 'ShouldGoback', 'GiveWay', 'WaitUntilNext'}
local FLEE_SPEED = 1.5
local FLEE_RANGE_SQR = 3000 ^ 2
local function IsFleeing(provider)
  local driver = provider:GetDriver()
  if not driver or not driver:IsAlive() or driver:HasTeam('police') or not driver:HasState(FLEE_STATES) then return false end
  local enemy = driver:GetNearEnemy()
  return IsValid(enemy) and enemy:GetPos():DistToSqr(provider:GetVehicle():GetPos()) <= FLEE_RANGE_SQR
end

local function SetFleeing(ai, on)
  ai.bgnFlee = on or nil
  if on then
    ai.bgnFleeSaved = {}
    for _, key in ipairs(FLEE_PREFS) do
      ai.bgnFleeSaved[key], ai.Preference[key] = ai.Preference[key], false
    end
  elseif ai.bgnFleeSaved then
    for key, value in pairs(ai.bgnFleeSaved) do
      ai.Preference[key] = value
    end

    ai.bgnFleeSaved = nil
  end
end

hook.Add('Decent Vehicle: GetCurrentMaxSpeed', 'BGN_VehicleFlee', function(ai, speed) if ai.bgnFlee then return speed * FLEE_SPEED end end)
local function Update(provider, now)
  local ai, car = provider:GetVehicleAI(), provider:GetVehicle()
  if not IsValid(ai) or not IsValid(car) or not car.isBgnVehicle then return end
  if not ai.bgnTrafficAttached or not ai:IsValidVehicle() or math.abs(ai:GetMaxSteeringAngle() or 0) < 1 then return end
  local state = ai.bgnTraffic
  if not state then
    state = {
      anchor = car:GetPos(),
      progressAt = now
    }

    ai.bgnTraffic = state
  end

  local fleeing = IsFleeing(provider)
  if fleeing ~= (ai.bgnFlee or false) then
    SetFleeing(ai, fleeing)
    Reset(ai, state, now)
  end

  if fleeing then
    ai.Emergency, ai.WaitUntilNext, ai.WaitForCaller = 0, 0, false
    return
  end

  if state.retryLane and state.waypoint ~= ai.Waypoint then Reset(ai, state, now) end
  if state.mode then
    local driver = provider:GetDriver()
    if state.mission and (not driver or not isvector(driver.drive_target_pos) or driver.drive_target_pos:DistToSqr(state.mission) > 300 ^ 2) then
      Reset(ai, state, now)
    elseif state.enemy and (not driver or not IsValid(state.enemy) or driver:GetNearEnemy() ~= state.enemy or state.enemy:GetPos():DistToSqr(state.enemyPos) > 400 ^ 2) then
      Reset(ai, state, now)
    end

    if state.waypoint ~= ai.Waypoint or (state.expires and now > state.expires) then
      state.failedPlans = (state.failedPlans or 0) + 1
      Reset(ai, state, now)
    end

    if state.path then
      local target = state.path[state.index]
      local distance = target and car:WorldSpaceCenter():Distance(target.pos) or 0
      local progress = state.lane and (state.moveIndex ~= state.index or not state.bestDistance or distance < state.bestDistance - 10) or (not state.lane and (not state.moveAnchor or state.moveAnchor:DistToSqr(car:GetPos()) > 20 ^ 2))
      if progress then
        state.moveIndex, state.bestDistance, state.movedAt = state.index, distance, now
        state.moveAnchor = car:GetPos()
      elseif now - state.movedAt > 3 and not ScheduledStop(ai, now) then
        state.failedPlans = (state.failedPlans or 0) + 1
        Reset(ai, state, now)
      end
    end
    return
  end

  if not ai.Waypoint or ScheduledStop(ai, now) then
    Reset(ai, state, now)
    return
  end

  if state.anchor:DistToSqr(car:GetPos()) > 64 ^ 2 then
    state.failedPlans = 0
    Reset(ai, state, now)
    return
  end

  -- Slow progress is still progress; normal driving belongs to DV.
  if car:GetVelocity():LengthSqr() >= 25 ^ 2 then
    Reset(ai, state, now)
    return
  end

  local stuck = now - state.progressAt
  local trace = ai.Trace
  if stuck > 2 and car:GetVelocity():LengthSqr() < 25 ^ 2 and trace and trace.Hit and not trace.HitWorld and IsValid(trace.Entity) and now > (state.nextHorn or 0) then
    ai:SetHorn(true)
    state.hornUntil, state.nextHorn = now + .15, now + math.Rand(8, 14)
  end

  local retry = state.retryLane
  -- A far unseen car does not plan: it waits for a player to come near or for the unseen-car cleanup (sv_vehicle_lod.lua).
  if now < (state.nextPlan or 0) or (not retry and (ai.bgnFarLOD or stuck < WAIT or not NeedsRecovery(ai))) then return end
  local obstacle = ai.Trace and ai.Trace.Entity
  local leader = IsValid(obstacle) and obstacle.DecentVehicle
  if IsValid(leader) and leader.bgnTraffic and leader.bgnTraffic.path then
    state.nextPlan = now + 1
    return
  end

  local goal = retry and retry.to.Target or ai.Waypoint.Target
  state.advance = goal:DistToSqr(car:WorldSpaceCenter()) < 180 ^ 2 and ai.NextWaypoint ~= nil
  if state.advance then goal = ai.NextWaypoint.Target end
  local delta = goal - car:WorldSpaceCenter()
  if delta:Length() > 650 then goal = car:WorldSpaceCenter() + delta:GetNormalized() * 650 end
  state.mode, state.waypoint, state.lane, state.retryLane = 'planning', ai.Waypoint, retry, nil
  local driver = provider:GetDriver()
  state.mission = driver and driver.drive_target_pos
  local enemy = driver and ai.IsTargetExists and not state.mission and driver:GetNearEnemy()
  if IsValid(enemy) then state.enemy, state.enemyPos = enemy, enemy:GetPos() end
  state.geometry = Geometry(ai)
  if retry then goal = retry.to.Target + Vector(0, 0, state.geometry.ride) end
  local path, iterations = Traffic.Plan(ai, goal, state.geometry, retry and retry.direction)
  if not IsValid(ai) or not IsValid(car) then return end
  if not retry and (state.failedPlans or 0) >= 2 and not state.mission and not IsValid(state.enemy) then
    local normal_path, normal_iterations = path, iterations
    local lanes = Traffic.AlternateLanes(ai)
    if not IsValid(ai) or not IsValid(car) or state.mode ~= 'planning' then return end
    for i = 1, math.min(3, #lanes) do
      local lane = lanes[i]
      path, iterations = Traffic.Plan(ai, lane.to.Target + Vector(0, 0, state.geometry.ride), state.geometry, lane.direction)
      if not IsValid(ai) or not IsValid(car) then return end
      if state.mode ~= 'planning' then return end
      if path and #path > 0 and not Reserved(ai, path) then
        state.lane = lane
        break
      end

      path = nil
    end

    if not state.lane then path, iterations = normal_path, normal_iterations end
  end

  state.nextPlan = CurTime() + 4
  if path and #path > 0 and state.mode == 'planning' and not ScheduledStop(ai, CurTime()) and not Reserved(ai, path) and state.waypoint == ai.Waypoint then
    state.mode, state.path, state.index = 'maneuver', path, 1
    state.moveIndex, state.bestDistance, state.movedAt = nil, nil, CurTime()
    state.moveAnchor = car:GetPos()
    state.expires, state.iterations = CurTime() + 20, iterations
  else
    state.failedPlans = (state.failedPlans or 0) + 1
    Reset(ai, state, CurTime())
  end
end

local function Drive(ai, state, now)
  if state.mode == 'planning' or ScheduledStop(ai, now) then
    ai:StopDriving()
    return
  end

  local target = state.path and state.path[state.index]
  if not target then
    if state.lane and state.waypoint == ai.Waypoint then
      ai.Waypoint, ai.NextWaypoint, ai.WaypointList = state.lane.from, state.lane.to, {}
      ai:SetupNextWaypoint()
      state.lane, state.rejectedLanes = nil, nil
    elseif state.advance and state.waypoint == ai.Waypoint then
      ai:SetupNextWaypoint()
    end

    state.failedPlans = 0
    Reset(ai, state, now)
    ai:StopDriving()
    return
  end

  local center = ai.v:WorldSpaceCenter()
  local speed = ai.v:GetVelocity():Dot(ai:GetVehicleForward())
  local tolerance = state.lane and 15 or 35
  local target_forward = target.yaw and Angle(0, target.yaw, 0):Forward() or ai:GetVehicleForward()
  local passed = state.lane and (center - target.pos):Dot(target_forward) * target.dir > 0
  if state.lane and ai:GetVehicleForward():Dot(target_forward) < .9 then passed = false end
  if center:DistToSqr(target.pos) < tolerance ^ 2 or (passed and center:DistToSqr(target.pos) < 75 ^ 2) then
    local next_target = state.path[state.index + 1]
    if state.lane and next_target and next_target.dir ~= target.dir then
      ai:StopDriving()
      if math.abs(speed) > 10 then return end
      -- Replan the gear change from the real pose, after braking drift has settled.
      state.retryLane, state.lane, state.mode, state.path = state.lane, nil, nil, nil
      state.anchor, state.progressAt, state.nextPlan = ai.v:GetPos(), now, 0
      return
    end

    state.index = state.index + 1
    return
  end

  local offset = state.lane and state.geometry.axleOffset or 0
  local delta = target.pos - target_forward * offset - (center - ai:GetVehicleForward() * offset)
  delta.z = 0
  local steering = math.deg(math.atan2(2 * state.geometry.wheelbase * ai:GetVehicleRight():Dot(delta), delta:LengthSqr()))
  steering = math.Clamp(steering / math.abs(ai:GetMaxSteeringAngle()), -1, 1)
  if now >= (state.nextSafety or 0) then
    state.nextSafety = now + .1
    local start = {
      pos = center,
      yaw = ai:GetVehicleForward():Angle().y
    }

    local distance = target.dir * math.max(25, math.abs(speed) * .3)
    local turn = -distance * math.tan(math.rad(steering * math.abs(ai:GetMaxSteeringAngle()))) / state.geometry.wheelbase
    local heading = math.rad(start.yaw) + turn * .5
    local next_yaw = start.yaw + math.deg(turn)
    local rear = center - ai:GetVehicleForward() * offset
    local ahead = {
      pos = rear + Vector(math.cos(heading), math.sin(heading), 0) * distance + Angle(0, next_yaw, 0):Forward() * offset,
      yaw = next_yaw
    }

    local clear, reason = ClearPose(ai, state.geometry, start, ahead)
    state.safetyBlocked, state.blockReason = not clear, reason
    if state.safetyBlocked then
      state.blockedAt = state.blockedAt or now
    else
      state.blockedAt = nil
    end
  end

  if state.blockedAt and now - state.blockedAt > 2 then
    state.failedPlans = (state.failedPlans or 0) + 1
    Reset(ai, state, now)
    ai:StopDriving()
    return
  end

  local desired = (target.dir < 0 and 80 or 160) / (1 + math.abs(steering))
  ai:SetHandbrake(state.safetyBlocked or speed * target.dir < -10 or math.abs(speed) > desired * 1.3)
  ai:SetSteering(steering)
  ai:SetThrottle(not state.safetyBlocked and math.abs(speed) < desired and target.dir * .6 or 0)
end

function Traffic.Attach(ai)
  if ai.bgnTrafficAttached then return end
  ai.bgnTrafficAttached = true
  local think = ai.Think
  function ai:Think()
    local state = self.bgnTraffic
    local now = CurTime()
    if state and state.hornUntil and now > state.hornUntil then
      self:SetHorn(false)
      state.hornUntil = nil
    end

    if state and state.mode and IsValid(self.v) and not self.v.isBgnVehicle then Reset(self, state, now) end
    if state and state.mode and IsValid(self.v) and ScheduledStop(self, now) then Reset(self, state, now) end
    if state and state.retryLane and IsValid(self.v) then
      self:StopDriving()
      self:DoLights()
      self:SetDriverPosition()
      self:NextThink(now)
      return true
    end

    if state and state.mode and IsValid(self.v) and self.Waypoint then
      self:DoTrace()
      if not state.lane and not NeedsRecovery(self) then Reset(self, state, now) end
    end

    if state and state.mode and IsValid(self.v) and self.v.isBgnVehicle and self:IsValidVehicle() then
      Drive(self, state, now)
      self:DoLights()
      self:SetDriverPosition()
      self:NextThink(now)
      return true
    end
    return think(self)
  end
end

bgNPC.Tasks.Add('BGN_VehicleTraffic', function(yield, wait, budget)
  while true do
    for _, provider in ipairs(bgNPC.DVCars) do
      local ok, err = pcall(Update, provider, CurTime())
      if not ok then
        local ai = provider:GetVehicleAI()
        if IsValid(ai) and IsValid(ai.v) and ai.bgnTraffic then
          Reset(ai, ai.bgnTraffic, CurTime())
          ai.bgnTraffic.nextPlan = CurTime() + 4
        end

        ErrorNoHalt('[Background NPCs] Vehicle traffic: ' .. tostring(err) .. '\n')
      end

      budget()
    end

    wait(PERIOD)
  end
end)

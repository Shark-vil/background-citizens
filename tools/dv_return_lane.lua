-- Temporary single-player bridge fixture; run in an isolated lab scene.
assert(game.SinglePlayer() and game.GetMap() == 'gm_bigcity_improved')
local report = { running = true, checks = {}, samples = {} }
local actors, providers, cars = {}, {}, {}
local output = 'bgn_dv_lab/return_lane.json'
local function Save() file.Write(output, util.TableToJSON(report, true)) end
local function Check(ok, message) assert(ok, message); report.checks[#report.checks + 1] = message; Save() end
local function Wait(t) coroutine.yield(t) end
local function Cleanup()
    for _, a in ipairs(actors) do if not a.is_removed then a:Remove() end end
    for _, p in ipairs(providers) do p:Remove(); BGN_VEHICLE:RemoveFromList(p) end
    for _, c in ipairs(cars) do if IsValid(c) then c:Remove() end end
end
local function Crew(car, kind, count)
    local p = BGN_VEHICLE:Instance(car, kind == 'police' and 'police' or 'residents', kind)
    p.passengers_limit = 4; providers[#providers + 1] = p; BGN_VEHICLE:AddToList(p)
    local crew = {}
    for i = 1, count do
        local n = ents.Create('npc_citizen'); n:SetPos(car:GetPos() + Vector(180, i * 90, 0)); n:Spawn()
        local a = bgNPC.Actor.Create(n, kind); actors[#actors + 1] = a; crew[i] = a
        a.data = table.Copy(a.data); a.data.start_random_state, a.data.start_state, a.data.at_random = false, nil, false
        a.eternal = true
        a.mechanics.enemies_controller, a.mechanics.targets_controller = false, false
    end
    Wait(.2)
    for _, a in ipairs(crew) do a.start_think = false; a:EnterVehicle(car) end
    Wait(1)
    return p, crew
end
local routine = coroutine.create(function()
    local road = DecentVehicleDestination.Waypoints[9].Target
    if not BGNReturnLaneOnly then
    local car = bgNPC:SpawnVehicle('simfphys_gta_sa_sultan', road + Vector(0, 0, 50), Angle(0, 90, 0))
    cars[#cars + 1] = car; Wait(1)
    local p, crew = Crew(car, 'police', 2)
    Check(crew[1]:InVehicle() and crew[2]:InVehicle(), 'police crew boards')
    Check(not crew[1]:ShouldExitVehicle(), 'neutral observer does not trigger a police exit')
    for i = 2, 1, -1 do Check(crew[i]:ExitVehicle(true), 'police exits ' .. i) end
    for _, a in ipairs(crew) do a.start_think = true; a:SetState('walk', nil, true) end
    for _ = 1, 40 do
        if crew[1]:InVehicle() and crew[2]:InVehicle() then break end
        Wait(.5)
    end
    report.crew_states = { crew[1]:GetState(), crew[2]:GetState() }
    Check(crew[1]:InVehicle() and crew[2]:InVehicle(), 'driver and passenger return through the normal state/timer')
    Cleanup(); actors, providers, cars = {}, {}, {}
    end
    local car = bgNPC:SpawnVehicle('simfphys_gta_sa_sabre', road + Vector(0, 0, 50), Angle(0, 90, 0))
    cars[#cars + 1] = car; Wait(1)
    local function Motion(enabled)
        car:GetPhysicsObject():EnableMotion(enabled)
        for _, w in pairs(car.Wheels or {}) do if IsValid(w) then w:GetPhysicsObject():EnableMotion(enabled) end end
    end
    Motion(false)
    local p, crew = Crew(car, 'citizen', 1)
    local ai = p:GetVehicleAI(); Check(IsValid(ai), 'civilian driver exists')
    ai.WaitUntilNext, ai.Emergency = 0, 0
    ai.AtTrafficLight = function() return false end
    local forward = ai:GetVehicleForward()
    ai.PrevWaypoint = { Target = road, SpeedLimit = 180 }
    ai.Waypoint = { Target = road + forward * 600, SpeedLimit = 180, Neighbors = {} }
    ai.NextWaypoint, ai.WaypointList = nil, {}
    local setup = ai.SetupNextWaypoint
    function ai:SetupNextWaypoint()
        local lane = self.bgnTraffic and self.bgnTraffic.lane
        if lane and self.Waypoint == lane.from and self.NextWaypoint == lane.to then
            report.handover = { pos = car:GetPos(), distance = car:GetPos():Distance(road),
                direction_dot = lane.direction:Dot(forward) }
            Save()
        end
        return setup(self)
    end
    local blocker = bgNPC:SpawnVehicle('simfphys_gta_sa_admiral', road + forward * 250 + Vector(0, 0, 50), forward:Angle())
    cars[#cars + 1] = blocker; Wait(1)
    blocker:GetPhysicsObject():EnableMotion(false)
    for _, w in pairs(blocker.Wheels or {}) do if IsValid(w) then w:GetPhysicsObject():EnableMotion(false) end end
    ai.bgnTraffic.failedPlans = 2
    ai.bgnTraffic.progressAt, ai.bgnTraffic.nextPlan = CurTime() - 5, 0
    -- Seed two failures at a fixed starting pose; normal driving must not erase them before planning.
    for _ = 1, 30 do
        Wait(.1)
        if ai.bgnTraffic.lane then break end
    end
    Check(ai.bgnTraffic.lane ~= nil, 'repeated failures select an alternative lane')
    Motion(true)
    local selected
    for tick = 1, 300 do
        Wait(.2)
        assert(IsValid(ai) and IsValid(car), 'recovery entities survive')
        local state = ai.bgnTraffic
        if tick % 5 == 0 then
            local t = state.path and state.path[state.index]
            report.samples[#report.samples + 1] = { pos = car:GetPos(), yaw = ai:GetVehicleForward():Angle().y,
                index = state.index, mode = state.mode, lane = state.lane and state.lane.to.Target,
                target = t, failed = state.failedPlans, reason = state.blockReason }
            Save()
        end
        if state.lane then selected = state.lane; report.selected = true end
        if report.handover then
            Check(report.handover.distance > 100, 'car physically reaches the alternate lane')
            report.direction_dot = report.handover.direction_dot
            Check(report.direction_dot < .5, 'new road direction differs')
            report.passed = true; return
        end
    end
    error('alternate-lane recovery did not finish within 60 seconds')
end)
local function Resume()
    local ok, delay = coroutine.resume(routine)
    if not ok then report.error = debug.traceback(routine, tostring(delay)); report.passed = false end
    if not ok or coroutine.status(routine) == 'dead' then report.running = false; Cleanup(); Save()
    else timer.Simple(delay, Resume) end
end
Save(); Resume()
return { running = true }

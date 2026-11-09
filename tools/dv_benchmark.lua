-- Stationary cars above the observer isolate controller/sensor overhead from collisions and road layout.
assert(game.GetMap() == 'gm_bigcity_improved')
local count, baseline = BGNDVBenchCount or 10, BGNDVBenchBaseline == true
local origin = player.GetHumans()[1]:GetPos() + Vector(0, 0, 1000)
local cars, ais, actors, providers = {}, {}, {}, {}
local radius = GetConVar('bgn_spawn_radius'):GetString()
RunConsoleCommand('bgn_spawn_radius', '6000')
local report = { count = count, baseline = baseline, traces = 0, trace_ms = 0, ticks = 0, max_tick_ms = 0 }
local path = 'bgn_dv_lab/bench_' .. count .. (baseline and '_baseline' or '_new') .. '.json'
file.Write(path, util.TableToJSON({ running = true }))
local line, hull = util.TraceLine, util.TraceHull
local function Cleanup()
    util.TraceLine, util.TraceHull = line, hull
    hook.Remove('Tick', 'BGNDVBench.Frame')
    for _, actor in ipairs(actors) do if actor:IsAlive() then actor:Remove() end end
    for _, provider in ipairs(providers) do provider:Remove(); BGN_VEHICLE:RemoveFromList(provider) end
    for _, car in ipairs(cars) do if IsValid(car) then car:Remove() end end
    RunConsoleCommand('bgn_spawn_radius', radius)
end
local function Save(ok, err)
    report.passed, report.error = ok, err
    Cleanup()
    file.Write(path, util.TableToJSON(report, true))
end
local function Measure()
    local ok, err = xpcall(function()
        for _, provider in ipairs(providers) do
            local ai = provider:GetVehicleAI()
            assert(IsValid(ai), 'all benchmark drivers must initialize')
            ai.WaitUntilNext = CurTime() + 60
            ai.Emergency = 0
            ais[ai] = true
        end
        local function Trace(fn, data)
            local tracked = false
            if istable(data.filter) then
                for _, ent in pairs(data.filter) do if ais[ent] then tracked = true; break end end
            end
            local started = SysTime()
            local result = fn(data)
            if tracked then report.traces = report.traces + 1; report.trace_ms = report.trace_ms + (SysTime() - started) * 1000 end
            return result
        end
        util.TraceLine = function(data) return Trace(line, data) end
        util.TraceHull = function(data) return Trace(hull, data) end
        local started, last = SysTime(), SysTime()
        hook.Add('Tick', 'BGNDVBench.Frame', function()
            local now = SysTime()
            report.ticks = report.ticks + 1
            report.max_tick_ms = math.max(report.max_tick_ms, (now - last) * 1000)
            last = now
        end)
        timer.Simple(6, function()
            report.seconds = SysTime() - started
            report.ticks_per_second = report.ticks / report.seconds
            local alive = 0
            for ai in pairs(ais) do if IsValid(ai) then alive = alive + 1 end end
            report.alive = alive
            Save(alive == count, alive ~= count and 'a benchmark driver disappeared' or nil)
        end)
    end, debug.traceback)
    if not ok then Save(false, err) end
end
local i = 0
timer.Create('BGNDVBench.Spawn', .05, count, function()
    local ok, err = xpcall(function()
        i = i + 1
        local pos = origin + Vector(((i - 1) % 6 - 2.5) * 250, (math.floor((i - 1) / 6) - count / 12) * 250, 0)
        local car = bgNPC:SpawnVehicle('simfphys_gta_sa_sabre', pos, Angle())
        assert(IsValid(car)); cars[#cars + 1] = car
        car:GetPhysicsObject():EnableMotion(false)
        if baseline then car.isBgnVehicle = nil end
        local npc = ents.Create('npc_citizen')
        npc:SetPos(pos + Vector(0, 120, 0)); npc:SetModel('models/Humans/Group01/male_07.mdl'); npc:Spawn()
        npc:SetHealth(10000); npc:SetMaxHealth(10000); npc:AddFlags(FL_NOTARGET)
        local actor = bgNPC.Actor.Create(npc, 'citizen')
        actor.data = table.Copy(actor.data); actor.data.start_random_state, actor.data.start_state = false, nil
        actor.data.at_random = false
        actor.mechanics.movement_controller, actor.mechanics.enemies_controller, actor.mechanics.targets_controller = false, false, false
        actor.eternal = true; actors[#actors + 1] = actor
        local provider = BGN_VEHICLE:Instance(car, 'residents', 'citizen')
        providers[#providers + 1] = provider; BGN_VEHICLE:AddToList(provider)
        actor:EnterVehicle(car)
        timer.Simple(.8, function()
            if not IsValid(provider:GetVehicleAI()) then return end
            provider:GetVehicleAI().WaitUntilNext = CurTime() + 60
        end)
        if i == count then timer.Simple(2, Measure) end
    end, debug.traceback)
    if not ok then timer.Remove('BGNDVBench.Spawn'); Save(false, err) end
end)
return { running = true, count = count, baseline = baseline }

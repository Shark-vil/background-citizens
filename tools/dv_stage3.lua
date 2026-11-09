assert(game.GetMap() == 'gm_bigcity_improved')
include('background_npcs_core/modules/dv/sv_vehicle_traffic.lua')
local road = DecentVehicleDestination.Waypoints[1].Target
local direction = Vector(0, -1, 0)
local scenario = BGNDVStage3Scenario or 'blocker'
local baseline = BGNDVStage3Baseline == true
if scenario == 'turn' then road = DecentVehicleDestination.Waypoints[2].Target end
local car = bgNPC:SpawnVehicle('simfphys_gta_sa_sabre', road + Vector(0, 0, 50), scenario == 'turn' and Angle(0, 180, 0) or direction:Angle())
local blocker = scenario ~= 'turn' and bgNPC:SpawnVehicle('simfphys_gta_sa_admiral', road + direction * 350 + Vector(0, 0, 50), direction:Angle())
assert(IsValid(car) and (scenario == 'turn' or IsValid(blocker)))
if baseline then car.isBgnVehicle = nil end -- the same car with the original DV controller only
BGNDVStage3 = { car = car, blocker = blocker, samples = {}, scans = 0, contacts = 0 }
file.Write('bgn_dv_lab/stage3_' .. scenario .. (baseline and '_baseline' or '') .. '.json', util.TableToJSON({ running = true }))
timer.Simple(1, function()
    local s = BGNDVStage3
    if IsValid(blocker) then
        blocker:GetPhysicsObject():EnableMotion(false)
        for _, wheel in pairs(blocker.Wheels or {}) do if IsValid(wheel) then wheel:GetPhysicsObject():EnableMotion(false) end end
    end
    local npc = ents.Create('npc_citizen')
    npc:SetPos(road + Vector(120, 0, 10)); npc:SetModel('models/Humans/Group01/male_07.mdl'); npc:Spawn()
    npc:SetHealth(10000); npc:SetMaxHealth(10000); npc:AddFlags(FL_NOTARGET)
    local actor = bgNPC.Actor.Create(npc, 'citizen')
    actor.data = table.Copy(actor.data); actor.data.start_random_state, actor.data.start_state = false, nil
    actor.data.at_random = false
    actor.mechanics.movement_controller, actor.mechanics.enemies_controller, actor.mechanics.targets_controller = false, false, false
    actor.eternal = true
    local provider = BGN_VEHICLE:Instance(car, 'residents', 'citizen')
    BGN_VEHICLE:AddToList(provider)
    s.actor, s.provider = actor, provider
    actor:EnterVehicle(car)
    local p = player.GetHumans()[1]
    p:SetMoveType(MOVETYPE_NOCLIP); p:GodEnable(); p:SetPos(road + Vector(400, -150, 350))
    p:SetEyeAngles((road + direction * 300 - p:EyePos()):Angle())
    timer.Simple(1, function()
        local ai = provider:GetVehicleAI()
        assert(IsValid(ai), 'DV driver initialized')
        local Traffic = bgNPC.VehicleTraffic
        if not baseline then Traffic.Attach(ai) end
        s.ai, s.started = ai, CurTime()
		local traceLine, traceHull = util.TraceLine, util.TraceHull
		s.traceCalls, s.traceTime = 0, 0
		local function Count(fn, data)
			local tracked = istable(data.filter) and table.HasValue(data.filter, ai)
			local started = SysTime()
			local result = fn(data)
			if tracked then s.traceCalls = s.traceCalls + 1; s.traceTime = s.traceTime + SysTime() - started end
			return result
		end
		util.TraceLine = function(data) return Count(traceLine, data) end
		util.TraceHull = function(data) return Count(traceHull, data) end
		s.restoreTraces = function() util.TraceLine, util.TraceHull = traceLine, traceHull end
        ai.Waypoint = { Target = road + direction * 900, SpeedLimit = 200, Neighbors = {}, bgn_custom = true }
        ai.PrevWaypoint = { Target = road, SpeedLimit = 200 }
        ai.NextWaypoint = { Target = road + direction * 1400, SpeedLimit = 200, Neighbors = {}, bgn_custom = true }
        ai.WaypointList = {}
        if scenario == 'turn' then
            ai.Waypoint.Target = DecentVehicleDestination.Waypoints[3].Target
            ai.NextWaypoint.Target = DecentVehicleDestination.Waypoints[5].Target
            ai.WaypointList = { { Target = DecentVehicleDestination.Waypoints[7].Target, SpeedLimit = 200, Neighbors = {}, bgn_custom = true } }
        end
        ai.WaitUntilNext, ai.Emergency = 0, 0
        hook.Add('Decent Vehicle: Trace', 'BGNDVStage3.Scans', function(dv) if dv == ai then s.scans = s.scans + 1 end end)
        hook.Add('Decent Vehicle: OnCollide', 'BGNDVStage3.Contacts', function(dv, data)
            if dv == ai and data.HitEntity == blocker then s.contacts = s.contacts + 1 end
        end)
        timer.Create('BGNDVStage3.Sample', .2, baseline and 100 or 300, function()
            if not IsValid(car) or not IsValid(ai) then s.restoreTraces(); timer.Remove('BGNDVStage3.Sample'); return end
            local state = ai.bgnTraffic or {}
            s.samples[#s.samples + 1] = { t = CurTime() - s.started, pos = car:GetPos():ToTable(),
                speed = car:GetVelocity():Length(), mode = state.mode or 'normal', index = state.index,
                blocked = state.safetyBlocked, reason = state.blockReason, path = state.path and #state.path, iterations = state.iterations,
                steering = ai.Steering, yaw = ai:GetVehicleForward():Angle().y, target = state.path and state.path[state.index] }
            local delta = car:GetPos() - road
            local arrived = scenario == 'turn' and delta.x < -600 and math.abs(car:GetPos().y - DecentVehicleDestination.Waypoints[7].Target.y) < 200
                or scenario ~= 'turn' and delta:Dot(direction) > 650 and math.abs(delta.x) < 80 and ai:GetVehicleForward():Dot(direction) > .7
            if arrived then
                s.passed, s.elapsed = true, CurTime() - s.started
                timer.Remove('BGNDVStage3.Sample'); ai:StopDriving()
				ai:AddEFlags(EFL_NO_THINK_FUNCTION); car.isBgnVehicle = nil
            end
			if arrived or timer.RepsLeft('BGNDVStage3.Sample') == 0 then s.restoreTraces() end
            file.Write('bgn_dv_lab/stage3_' .. scenario .. (baseline and '_baseline' or '') .. '.json', util.TableToJSON({ passed = s.passed or false,
                elapsed = s.elapsed, scans = s.scans, contacts = s.contacts, trace_calls = s.traceCalls, trace_ms = s.traceTime * 1000, samples = s.samples }, true))
        end)
    end)
end)
return { spawned = true }

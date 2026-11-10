assert(game.GetMap() == 'gm_bigcity_improved', 'use the agreed test map')
include('background_npcs_core/modules/dv/sv_pedestrian_traffic.lua')
include('background_npcs_core/actor/components/sh_movement.lua')
include('background_npcs_core/actor/body/sv_npc_body.lua')
local p = player.GetHumans()[1]
local road = DecentVehicleDestination.Waypoints[1].Target
local car = bgNPC:SpawnVehicle('simfphys_gta_sa_sabre', road + Vector(0, 0, 25), Angle(0, 90, 0))
assert(IsValid(car))
BGNDVStage2 = { car = car, samples = {}, schedules = 0 }
timer.Simple(1, function()
    if not IsValid(car) then return end
    car:GetPhysicsObject():EnableMotion(false)
    for _, wheel in pairs(car.Wheels or {}) do if IsValid(wheel) then wheel:GetPhysicsObject():EnableMotion(false) end end
    local low, high = car:OBBMins(), car:OBBMaxs()
    local start = car:LocalToWorld(Vector(low.x - 120, 0, 0))
    local goal = car:LocalToWorld(Vector(high.x + 180, 0, 0))
    start.z = road.z + 4; goal.z = start.z
    local npc = ents.Create(BGNDVStage2Body or 'npc_citizen')
    npc:SetPos(start); npc:SetModel('models/Humans/Group01/male_07.mdl'); npc:Spawn()
    local actor = bgNPC.Actor.Create(npc, 'citizen', nil, false, true)
    actor.data = table.Copy(actor.data)
    actor.data.start_random_state, actor.data.start_state = false, nil
    actor.eternal = true
    local s = BGNDVStage2
    s.actor, s.start, s.goal = actor, start, goal
    p:SetMoveType(MOVETYPE_NOCLIP); p:GodEnable()
    p:SetPos(road + Vector(250, -500, 220)); p:SetEyeAngles((road - p:EyePos()):Angle())
    timer.Simple(.2, function()
        actor.start_think = false
        actor:SetState('run_from_danger', nil, true)
        actor.walkPos, actor.walkPath = goal, { goal }
        local original = actor.body.MoveTo
        actor.body.MoveTo = function(body, pos, run) s.schedules = s.schedules + 1; return original(body, pos, run) end
        s.planned = bgNPC.PedestrianTraffic.Plan(npc, car, goal)
        s.started = CurTime()
        timer.Create('BGNDVStage2.Sample', .1, 180, function()
            if not IsValid(npc) then return end
            actor:UpdateMovement()
            s.samples[#s.samples + 1] = { pos = npc:GetPos():ToTable(), detour = actor.dvDetour ~= nil, state = actor:GetState() }
            if npc:GetPos():DistToSqr(goal) < 150 ^ 2 then
                s.passed = true; s.elapsed = CurTime() - s.started
                timer.Remove('BGNDVStage2.Sample')
            end
            file.Write('bgn_dv_lab/stage2.json', util.TableToJSON({ passed = s.passed or false, elapsed = s.elapsed,
                schedules = s.schedules, planned = s.planned, samples = s.samples }, true))
        end)
    end)
end)
return { spawned = true, waiting_for_suspension = true }

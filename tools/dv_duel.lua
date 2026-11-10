assert(game.GetMap() == 'gm_bigcity_improved')
include('background_npcs_core/modules/dv/sv_vehicle_traffic.lua')
local road = DecentVehicleDestination.Waypoints[1].Target
local scene = { cars = {}, actors = {}, providers = {}, samples = {}, contacts = 0 }
BGNDVDuel = scene
for i = 1, 2 do
    local pos = road + Vector(0, i == 1 and 0 or -650, 50)
    local car = bgNPC:SpawnVehicle('simfphys_gta_sa_sabre', pos, Angle(0, i == 1 and -90 or 90, 0))
    assert(IsValid(car)); scene.cars[i] = car
end
timer.Simple(1, function()
    for i, car in ipairs(scene.cars) do
        local npc = ents.Create('npc_citizen')
        npc:SetModel('models/Humans/Group01/male_07.mdl'); npc:SetPos(car:GetPos() + Vector(120, 0, 0)); npc:Spawn()
        npc:SetHealth(10000); npc:SetMaxHealth(10000); npc:AddFlags(FL_NOTARGET)
        local actor = bgNPC.Actor.Create(npc, 'citizen')
        actor.data = table.Copy(actor.data); actor.data.start_random_state, actor.data.start_state = false, nil
        actor.data.at_random = false
        actor.mechanics.movement_controller, actor.mechanics.enemies_controller, actor.mechanics.targets_controller = false, false, false
        actor.eternal = true; scene.actors[i] = actor
        local provider = BGN_VEHICLE:Instance(car, 'residents', 'citizen')
        BGN_VEHICLE:AddToList(provider); scene.providers[i] = provider; actor:EnterVehicle(car)
    end
    local p = player.GetHumans()[1]
    p:SetPos(road + Vector(350, -300, 350)); p:SetEyeAngles((road + Vector(0, -300, 0) - p:EyePos()):Angle())
    timer.Simple(1, function()
        scene.started = CurTime()
        for i, provider in ipairs(scene.providers) do
            local ai = provider:GetVehicleAI()
            assert(IsValid(ai))
            local dir = Vector(0, i == 1 and -1 or 1, 0)
            local start = road + Vector(0, i == 1 and 0 or -650, 0)
            ai.Waypoint = { Target = start + dir * 1100, SpeedLimit = 180, Neighbors = {} }
            ai.PrevWaypoint = { Target = start, SpeedLimit = 180 }
            ai.NextWaypoint = { Target = start + dir * 1400, SpeedLimit = 180, Neighbors = {} }
            ai.WaypointList = {}; ai.WaitUntilNext, ai.Emergency = 0, 0
        end
        hook.Add('Decent Vehicle: OnCollide', 'BGNDVDuel.Contacts', function(dv, data)
            if (dv.v == scene.cars[1] and data.HitEntity == scene.cars[2])
                or (dv.v == scene.cars[2] and data.HitEntity == scene.cars[1]) then scene.contacts = scene.contacts + 1 end
        end)
        timer.Create('BGNDVDuel.Sample', .2, 300, function()
            local a, b = scene.cars[1], scene.cars[2]
            if not IsValid(a) or not IsValid(b) then timer.Remove('BGNDVDuel.Sample'); return end
            local first, second = scene.providers[1]:GetVehicleAI(), scene.providers[2]:GetVehicleAI()
            local x, y = IsValid(first) and first.bgnTraffic or {}, IsValid(second) and second.bgnTraffic or {}
            scene.samples[#scene.samples + 1] = { t = CurTime() - scene.started, a = a:GetPos():ToTable(), b = b:GetPos():ToTable(),
                mode_a = x.mode or 'normal', mode_b = y.mode or 'normal' }
            if a:GetPos().y < road.y - 800 and b:GetPos().y > road.y + 150 then
                scene.passed, scene.elapsed = true, CurTime() - scene.started
                for _, provider in ipairs(scene.providers) do
                    local ai = provider:GetVehicleAI()
                    ai:StopDriving(); ai:AddEFlags(EFL_NO_THINK_FUNCTION); provider:GetVehicle().isBgnVehicle = nil
                end
                timer.Remove('BGNDVDuel.Sample')
            end
            file.Write('bgn_dv_lab/duel.json', util.TableToJSON({ passed = scene.passed or false, elapsed = scene.elapsed,
                contacts = scene.contacts, samples = scene.samples }, true))
        end)
    end)
end)
return { running = true }

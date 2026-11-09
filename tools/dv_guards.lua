assert(game.GetMap() == 'gm_bigcity_improved')
local road = DecentVehicleDestination.Waypoints[9].Target
local car = bgNPC:SpawnVehicle('simfphys_gta_sa_sabre', road + Vector(0, 0, 50), Angle(0, 90, 0))
assert(IsValid(car))
local report, walls = {}, {}
file.Write('bgn_dv_lab/guards.json', util.TableToJSON({ running = true }))
timer.Simple(1, function()
    car:GetPhysicsObject():EnableMotion(false)
    local npc = ents.Create('npc_citizen')
    npc:SetPos(road + Vector(140, 0, 10)); npc:SetModel('models/Humans/Group01/male_07.mdl'); npc:Spawn()
    local actor = bgNPC.Actor.Create(npc, 'citizen', nil, false, true)
    actor.data = table.Copy(actor.data); actor.data.start_random_state, actor.data.start_state = false, nil
    actor.eternal = true
    local provider = BGN_VEHICLE:Instance(car, 'residents', 'citizen')
    BGN_VEHICLE:AddToList(provider); actor:EnterVehicle(car)
    timer.Simple(1, function()
        local ai = provider:GetVehicleAI()
        assert(IsValid(ai))
        local traffic = bgNPC.VehicleTraffic
        local light, plan = ai.AtTrafficLight, traffic.Plan
        local function Finish(ok, err)
            traffic.Plan = plan
            for _, wall in ipairs(walls) do if IsValid(wall) then wall:Remove() end end
            if actor:IsAlive() then actor:Remove() end
            provider:Remove(); BGN_VEHICLE:RemoveFromList(provider)
            report.passed, report.error = ok, err
            file.Write('bgn_dv_lab/guards.json', util.TableToJSON(report, true))
        end
        local function Later(delay, fn)
            timer.Simple(delay, function()
                local ok, err = xpcall(fn, debug.traceback)
                if not ok then Finish(false, err) end
            end)
        end
        ai.WaitUntilNext, ai.Emergency = 0, 0
        ai.Preference.StopAtTL = true
        ai.AtTrafficLight = function() return true end
        Later(6, function()
            assert(not ai.bgnTraffic.mode and not ai:GetHorn(), 'red light must not trigger recovery/horn')
            report.red_light = true; ai.AtTrafficLight = light
            ai.WaitForCaller = true
            Later(6, function()
                assert(not ai.bgnTraffic.mode and not ai:GetHorn(), 'taxi caller wait must not trigger recovery')
                report.taxi_wait = true; ai.WaitForCaller = false
                ai.WaitUntilNext = CurTime() + 7
                Later(6, function()
                    assert(not ai.bgnTraffic.mode and not ai:GetHorn(), 'scheduled stop must not trigger recovery')
                    report.scheduled_stop = true
                    local center = car:OBBCenter()
                    for _, offset in ipairs({ Vector(160, 0, 0), Vector(-160, 0, 0), Vector(0, 110, 0), Vector(0, -110, 0) }) do
                        local wall = ents.Create('prop_physics')
                        wall:SetModel('models/hunter/blocks/cube2x2x2.mdl')
                        wall:SetPos(car:LocalToWorld(center + offset)); wall:SetAngles(car:GetAngles()); wall:Spawn()
                        wall:GetPhysicsObject():EnableMotion(false); walls[#walls + 1] = wall
                    end
                    report.no_path_calls = 0
                    traffic.Plan = function(dv, goal, geometry, direction)
                        local path, iterations = plan(dv, goal, geometry, direction)
                        if dv == ai then report.no_path_calls = report.no_path_calls + 1; report.no_path = path == nil end
                        return path, iterations
                    end
                    ai.WaitUntilNext = 0
                    Later(9, function()
                        assert(report.no_path_calls > 0 and report.no_path and not ai.bgnTraffic.mode, 'enclosed car must not receive an impossible path')
                        Finish(true)
                    end)
                end)
            end)
        end)
    end)
end)
return { running = true }

assert(game.GetMap() == 'gm_bigcity_improved')
include('background_npcs_core/spawner/sv_dv_spawner.lua')
local road = DecentVehicleDestination.Waypoints[1].Target
local cars = {}
for i, class in ipairs({ 'simfphys_gta_sa_sabre', 'sim_fphys_pwvolga', 'sim_fphys_dukes', 'sim_fphys_v8elite' }) do
    local car = bgNPC:SpawnVehicle(class, road + Vector(i * 300, 0, 40), Angle(0, 37, 0))
    assert(IsValid(car), class)
    car:GetPhysicsObject():EnableMotion(false)
    cars[class] = car
end
timer.Simple(1, function()
    local report = {}
    local ok, err = xpcall(function()
        for class, car in pairs(cars) do
            assert(IsValid(car) and not car.bgnHeadingPending, 'heading ready: ' .. class)
            local heading = car:LocalToWorldAngles(car.VehicleData.LocalAngForward).y
            local w = car.Wheels
            local axle = (w[1]:GetPos() + w[2]:GetPos() - w[3]:GetPos() - w[4]:GetPos()):Angle().y
            report[class] = { body_error = math.AngleDifference(heading, 37), axle_error = math.AngleDifference(axle, 37) }
            assert(math.abs(report[class].body_error) < 3 and math.abs(report[class].axle_error) < 3, class)
        end
    end, debug.traceback)
    for _, car in pairs(cars) do if IsValid(car) then car:Remove() end end
    file.Write('bgn_dv_lab/headings.json', util.TableToJSON({ passed = ok, error = err, models = report }, true))
end)
return { running = true }

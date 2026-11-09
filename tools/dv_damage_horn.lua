-- Run with tools/dv_lab.py in the temporary single-player lab.
assert(game.SinglePlayer() and game.GetMap() == 'gm_bigcity_improved')
local report = { checks = {}, horns = {}, running = true }
local path = 'bgn_dv_lab/damage_horn.json'
local actors, cars, providers, corpses = {}, {}, {}, {}
local observer = player.GetHumans()[1]
local original = { pos = observer:GetPos(), ang = observer:EyeAngles(), move = observer:GetMoveType() }
local blocker
local function Save() file.Write(path, util.TableToJSON(report, true)) end
local function Check(ok, message) assert(ok, message); report.checks[#report.checks + 1] = message; Save() end
local function Wait(seconds) coroutine.yield(seconds) end
local routine = coroutine.create(function()
    local road = DecentVehicleDestination.Waypoints[9].Target
    local car = bgNPC:SpawnVehicle('simfphys_gta_sa_sabre', road + Vector(0, 0, 50), Angle(0, 90, 0))
    assert(IsValid(car)); cars[1] = car
    Wait(1)
    car:GetPhysicsObject():EnableMotion(false)
    for _, wheel in pairs(car.Wheels or {}) do if IsValid(wheel) then wheel:GetPhysicsObject():EnableMotion(false) end end
    local provider = BGN_VEHICLE:Instance(car, 'residents|npc_decentvehicle|default|4', 'citizen')
    providers[1] = provider; BGN_VEHICLE:AddToList(provider)
    observer:SetMoveType(MOVETYPE_NOCLIP)
    observer:SetPos(road + Vector(350, -400, 200)); observer:SetEyeAngles((road - observer:EyePos()):Angle())
    for i, class in ipairs({'npc_citizen', 'bgn_nextbot'}) do
        local npc = ents.Create(class); npc:SetPos(road + Vector(200, i * 100, 5)); npc:Spawn()
        local a = bgNPC.Actor.Create(npc, 'citizen'); actors[i] = a
        a.data = table.Copy(a.data); a.data.start_random_state, a.data.start_state, a.data.at_random = false, nil, false
        a.mechanics.movement_controller, a.mechanics.enemies_controller, a.mechanics.targets_controller = false, false, false
        a.eternal = true
    end
    Wait(.2)
    for _, a in ipairs(actors) do a.start_think = false; a:GetNPC():SetHealth(100); a:EnterVehicle(car) end
    Wait(1)
    local ai = provider:GetVehicleAI()
    Check(IsValid(ai) and actors[2]:InVehicle(), 'NPC and NextBot boarded')
    ai.WaitUntilNext, ai.Emergency, ai.WaitForCaller = 0, 0, false
    ai.AtTrafficLight = function() return false end
    ai.bgnTraffic.nextPlan = CurTime() + 120
    local setHorn = ai.SetHorn
    local hornOn = false
    function ai:SetHorn(on)
        if on ~= hornOn then report.horns[#report.horns + 1] = { on = on, time = CurTime() }; hornOn = on end
        return setHorn(self, on)
    end
    Wait(4)
    Check(#report.horns == 0, 'stationary car on a clear road stays quiet')
    blocker = ents.Create('prop_physics'); blocker:SetModel('models/hunter/blocks/cube1x1x1.mdl')
    blocker:SetPos(car:WorldSpaceCenter() + ai:GetVehicleForward() * 180); blocker:Spawn()
    blocker:GetPhysicsObject():EnableMotion(false)
    Wait(15)
    local previous, start, pulses = nil, nil, 0
    for _, event in ipairs(report.horns) do
        if event.on then
            Check(not previous or event.time - previous >= 8, 'horn pause is at least eight seconds')
            previous, start, pulses = event.time, event.time, pulses + 1
        elseif start then
            Check(event.time - start < .3, 'horn pulse is shorter than 0.3 seconds'); start = nil
        end
    end
    Check(pulses >= 2 and not ai:GetHorn(), 'real blocker produces occasional short honks')
    blocker:Remove(); blocker = nil
    local count = #report.horns
    Wait(4)
    Check(#report.horns == count, 'cleared road stops the honks')
    ai.WaitUntilNext = CurTime() + 60
    for i = #actors, 1, -1 do
        local a = actors[i]
        Check(a:ExitVehicle(true), 'occupant ' .. i .. ' exits beside the car')
        Wait(.1)
        Check(a:IsAlive() and a:GetPos():Distance(car:GetPos()) < 300, 'exited occupant ' .. i .. ' remains nearby')
    end
    for _, a in ipairs(actors) do a:EnterVehicle(car) end
    Wait(.8)
    Check(actors[1]:InVehicle() and actors[2]:InVehicle(), 'both occupants board again before fatal hits')
    hook.Add('CreateEntityRagdoll', 'BGNDamageHorn', function(owner, ragdoll)
        for _, a in ipairs(actors) do if owner == a:GetNPC() then corpses[#corpses + 1] = ragdoll end end
    end)
    -- Passenger first: the driver's death also removes the controller.
    for i = #actors, 1, -1 do actors[i]:TakeVehicleDamage(1000, observer) end
    Wait(.2)
    Check(#corpses == 2 and IsValid(corpses[1]) and IsValid(corpses[2]), 'both body kinds leave visible corpses')
    Check(actors[1].is_removed and actors[2].is_removed, 'fatal hits retire both actor identities')
    report.passed = true
end)
local function Resume()
    local ok, delay = coroutine.resume(routine)
    if not ok then report.error = debug.traceback(routine, tostring(delay)); report.passed = false end
    if not ok or coroutine.status(routine) == 'dead' then
        report.running = false; hook.Remove('CreateEntityRagdoll', 'BGNDamageHorn')
        for _, a in ipairs(actors) do if not a.is_removed then a:Remove() end end
        for _, p in ipairs(providers) do p:Remove(); BGN_VEHICLE:RemoveFromList(p) end
        for _, c in ipairs(cars) do if IsValid(c) then c:Remove() end end
        for _, r in ipairs(corpses) do if IsValid(r) then r:Remove() end end
        if IsValid(blocker) then blocker:Remove() end
        observer:SetPos(original.pos); observer:SetEyeAngles(original.ang); observer:SetMoveType(original.move)
        Save()
    else timer.Simple(delay, Resume) end
end
Save(); Resume()
return { running = true }

-- Run with tools/dv_lab.py on the temporary single-player bridge.
assert(game.GetMap() == 'gm_bigcity_improved')
local report = { checks = {}, running = true }
local actors, cars, providers = {}, {}, {}
local path = 'bgn_dv_lab/lifecycle.json'
local function Save() file.Write(path, util.TableToJSON(report, true)) end
local function Check(ok, message) assert(ok, message); report.checks[#report.checks + 1] = message; Save() end
local function Wait(seconds) coroutine.yield(seconds) end
local road = DecentVehicleDestination.Waypoints[1].Target
local player = player.GetHumans()[1]
player:SetMoveType(MOVETYPE_NOCLIP); player:GodEnable()
player:SetPos(road + Vector(350, -450, 200)); player:SetEyeAngles((road - player:EyePos()):Angle())
local routine = coroutine.create(function()
    local car = bgNPC:SpawnVehicle('simfphys_gta_sa_sultan', road + Vector(0, 0, 50), Angle())
    assert(IsValid(car), 'test car'); cars[1] = car
    Wait(1)
    car:GetPhysicsObject():EnableMotion(false)
    for _, wheel in pairs(car.Wheels or {}) do if IsValid(wheel) then wheel:GetPhysicsObject():EnableMotion(false) end end
    local provider = BGN_VEHICLE:Instance(car, 'residents|npc_decentvehicle|default|4', 'citizen')
    BGN_VEHICLE:AddToList(provider); providers[1] = provider
    local bodies, weapons = {}, {}
    for i, class in ipairs({'npc_citizen', 'bgn_nextbot', 'npc_citizen'}) do
        local npc = ents.Create(class); npc.bgn_npc_class = class == 'bgn_nextbot' and 'npc_citizen' or nil
        npc:SetPos(road + Vector(160, i * 100, 5)); npc:Spawn()
        npc:SetModel('models/Humans/Group01/male_07.mdl'); npc:SetSkin(0)
        npc:SetHealth(37); npc:SetMaxHealth(73)
        local actor = bgNPC.Actor.Create(npc, 'citizen')
        actor.data.start_random_state, actor.data.start_state, actor.data.at_random = false, nil, false
        actor.mechanics.movement_controller, actor.mechanics.enemies_controller, actor.mechanics.targets_controller = false, false, false
        actor.eternal = true
        actor.body:GiveWeapon('weapon_pistol'); local weapon = actor:GetActiveWeapon()
        assert(IsValid(weapon)); weapon:SetClip1(7)
        if class == 'bgn_nextbot' then npc.clip = 7 end
        actors[i], bodies[i], weapons[i] = actor, npc, weapon
    end
    Wait(.1)
    for i, a in ipairs(actors) do
        a.start_think = false
        local npc=a:GetNPC()
        npc:SetModel('models/Humans/Group01/male_07.mdl'); npc:SetHealth(37); npc:SetMaxHealth(73)
        a.body:GiveWeapon('weapon_pistol'); weapons[i]=a:GetActiveWeapon(); weapons[i]:SetClip1(7)
        if npc.IsBGNNextBot then npc.clip=7 end
    end
    local count = bgNPC.Actors.Count('citizen')
    local watcher = actors[3]
    watcher.enemies, watcher.targets, watcher.enemies_always_visible = {bodies[1]}, {bodies[1]}, {bodies[1]}
    watcher.enemies_count, watcher.targets_count = 1, 1
    watcher.walkTarget = bodies[1]
    for _, a in ipairs(actors) do a:EnterVehicle(car) end
    Wait(.8)
    local models={}
    report.uids, report.saved_weapons = {}, {}; for i,a in ipairs(actors) do
        report.uids[i]=a.uid; models[i]=a.vehicle_body and a.vehicle_body.model
        report.saved_weapons[i]=a.vehicle_body and a.vehicle_body.weapons
    end
    for i,a in ipairs(actors) do
        Check(a:InVehicle() and a:IsAlive(), 'occupant '..i..' boarded')
        Check(not IsValid(bodies[i]) and not IsValid(weapons[i]), 'physical body and weapon '..i..' removed')
        Check(not a:GetNPC():IsNPC() and not a:GetNPC():IsNextBot(), 'occupant '..i..' is only DV anim entity')
        Check(bgNPC.Actors.GetByUid(a.uid)==a and bgNPC.Actors.Get(a:GetNPC())==a, 'actor identity '..i..' retained')
    end
    Check(bgNPC.Actors.Count('citizen')==count, 'population unchanged after simultaneous boarding')
    Check(watcher.enemies[1]==actors[1]:GetNPC() and watcher.targets[1]==actors[1]:GetNPC() and watcher.walkTarget==actors[1]:GetNPC(), 'target references rebound')
    local ai = provider:GetVehicleAI(); ai.WaitUntilNext=CurTime()+60
    Check(watcher.enemies_always_visible[1]==actors[1]:GetNPC(), 'persistent enemy reference rebound')
    actors[2]:TakeVehicleDamage(5, player)
    Check(actors[2]:Health()==32 and IsValid(ai), 'stored occupant health takes damage independently')
    local hull = util.TraceHull
    util.TraceHull = function() return {StartSolid=true,Hit=true} end
    local ok, result = pcall(actors[2].ExitVehicle, actors[2], true)
    util.TraceHull = hull
    Check(ok and result==false and actors[2]:InVehicle(), 'blocked exit keeps occupant seated')
    report.phase='seated'; Save(); Wait(3)
    for i=3,1,-1 do
        local a=actors[i]
        Check(a:ExitVehicle(true), 'occupant '..i..' exits to free ground')
        Wait(.1)
        local npc=a:GetNPC()
        Check(IsValid(npc) and npc:GetClass()==(i==2 and 'bgn_nextbot' or 'npc_citizen'), 'original body kind '..i..' recreated')
        Check(bgNPC.Actors.GetByUid(a.uid)==a and npc:GetModel()==models[i], 'same identity and model '..i..' restored')
        Check(npc:Health()==(i==2 and 32 or 37) and npc:GetMaxHealth()==73, 'health '..i..' restored')
        report.restored_weapon = tostring(a:GetActiveWeapon())
        report.restored_clip = IsValid(a:GetActiveWeapon()) and a:GetActiveWeapon():Clip1()
        Check(IsValid(a:GetActiveWeapon()) and a:GetActiveWeapon():Clip1()==report.saved_weapons[i][1].clip1, 'weapon and clip '..i..' restored')
    end
    report.phase='exited'; Save(); Wait(3)
    Check(bgNPC.Actors.Count('citizen')==count, 'population unchanged after exit')
    for _,a in ipairs(actors) do a:EnterVehicle(car) end
    Wait(.8)
    for _,a in ipairs(actors) do Check(a:InVehicle(), 'repeat boarding '..a.uid) end
    car:Remove(); Wait(.1)
    for _,a in ipairs(actors) do Check(a.is_removed and not bgNPC.Actors.GetByUid(a.uid), 'direct vehicle removal deletes actor '..a.uid) end
    report.phase='removed'; report.passed=true
end)
local function Resume()
    local ok, delay = coroutine.resume(routine)
    if not ok then report.error=debug.traceback(routine,tostring(delay)); report.passed=false end
    if not ok or coroutine.status(routine)=='dead' then
        report.running=false
        for _,a in ipairs(actors) do if not a.is_removed then a:Remove() end end
        for _,p in ipairs(providers) do p:Remove(); BGN_VEHICLE:RemoveFromList(p) end
        for _,c in ipairs(cars) do if IsValid(c) then c:Remove() end end
        Save()
    else timer.Simple(delay,Resume) end
end
Save(); Resume()
BGNLifecycle = {report=report,actors=actors,car=cars[1]}
return {running=true}

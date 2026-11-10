-- Run through tools/dv_lab.py on a local single-player test map.
local base = player.GetHumans()[1]:GetPos() + Vector(200, 0, 30)
local car = bgNPC:SpawnVehicle('Jeep', base, Angle())
assert(IsValid(car), 'native Jeep spawn')
local provider = BGN_VEHICLE:Instance(car, 'police', 'police')
BGN_VEHICLE:AddToList(provider)
local actors = {}
for i, kind in ipairs({ 'citizen', 'gangster', 'police', 'medic' }) do
    local npc = ents.Create(kind == 'police' and 'npc_metropolice' or 'npc_citizen')
    npc:SetPos(base + Vector(0, i * 100, 0)); npc:Spawn()
    local actor = bgNPC.Actor.Create(npc, kind, nil, false, true)
    assert(actor, 'actor ' .. kind)
    actor.eternal = true
    actors[kind] = actor
end
assert(car.bgnPoliceVehicle and provider:CanUse(actors.police))
for _, kind in ipairs({ 'citizen', 'gangster', 'medic' }) do
    local actor = actors[kind]
    actor.last_vehicle = provider
    assert(not provider:CanUse(actor) and not provider:CanBoard(actor) and not provider:CanSeize(actor), kind)
    assert(provider:SetDriver(actor) == false and provider:AddPassenger(actor) == false, kind .. ' direct bypass')
    actor:EnterVehicle(car)
    assert(not actor:InVehicle(), kind .. ' entry')
end
provider:SetGroup('residents')
assert(not provider:CanUse(actors.gangster), 'police ownership survived group change')
provider:SetGroup('police')
local plain = bgNPC:SpawnVehicle('Jeep', base + Vector(400, 0, 0), Angle())
local medical = BGN_VEHICLE:Instance(plain, 'medics|npc_dvbgn_police|ambulance|2', 'medic')
assert(medical:CanUse(actors.medic) and not plain.bgnPoliceVehicle, 'ambulance exemption')
-- Exercise the delayed callback: access changed after the original entry request.
car.bgnPoliceVehicle = nil
actors.citizen:EnterVehicle(car)
car.bgnPoliceVehicle = true
BGNDVStage1 = { actors = actors, car = car, provider = provider, plain = plain }
return { access = true, direct_bypass = false, police_mark = car.bgnPoliceVehicle, pending_delayed_check = true }

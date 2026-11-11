assert(game.SinglePlayer() and GetConVar('hostport'):GetInt() == 27025 and not BGNSeatingTest,
    'run in the isolated single-player seating lab')
local p, S = player.GetHumans()[1], bgNPC.Scenic.Spots
local old_pos, old_ang, old_move = p:GetPos(), p:EyeAngles(), p:GetMoveType()
p:SetMoveType(MOVETYPE_NOCLIP)
local base = assert(S.Floor(Vector(-800, 1000, -11140)))
local original = {}
for _, name in ipairs({ 'bgn_enable', 'bgn_scenic', 'bgn_actor_body', 'bgn_spawn_period' }) do original[name] = GetConVar(name):GetString() end
GetConVar('bgn_spawn_period'):SetString('100000')
local report = { cases = {}, errors = {} }
BGNSeatingTest = report
local actor, chair, item, support, job
local function Clear()
    if actor and actor:IsAlive() then actor:SetState('none', nil, true) actor:Remove() end
    if item then bgNPC.Scenic.Remove(item) end
    if IsValid(chair) then chair:Remove() end
    if IsValid(support) then support:Remove() end
    actor, chair, item, support = nil, nil, nil, nil
end
local function Write()
    file.CreateDir('bgn_seat_lab')
    file.Write('bgn_seat_lab/seating.json', util.TableToJSON(report, true))
end
local function Finish()
    Clear()
    hook.Remove('BGN_OverrideSpawnData', 'BGNSeatingTest')
    for name, value in pairs(original) do GetConVar(name):SetString(value) end
    p:SetPos(old_pos) p:SetEyeAngles(old_ang) p:SetMoveType(old_move)
    report.done, report.passed = true, #report.errors == 0
    Write() BGNSeatingTest = nil
end
local function Protect(fn)
    local ok, err = xpcall(fn, debug.traceback)
    if not ok then report.errors[#report.errors + 1] = err Finish() end
end
hook.Add('BGN_OverrideSpawnData', 'BGNSeatingTest', function(kind, data)
    if kind ~= 'citizen' then return end
    data = table.Copy(data)
    data.models = { job.female and 'models/humans/group01/female_07.mdl' or 'models/humans/group01/male_07.mdl' }
    data.random_model, data.default_models, data.carry_items, data.start_random_state = false, false, false, false
    data.at_random = {}
    return data
end)
local jobs = {}
for _, body in ipairs({ 'npc', 'nextbot' }) do
    for _, model in ipairs({ 'models/props_c17/chair02a.mdl', 'models/props_c17/FurnitureChair001a.mdl' }) do
        for _, yaw in ipairs({ 0, 90, 180, 270 }) do jobs[#jobs + 1] = { body = body, kind = 'prop', yaw = yaw, model = model } end
    end
    jobs[#jobs + 1] = { body = body, kind = 'prop', yaw = 0, distance = 350 }
    jobs[#jobs + 1] = { body = body, kind = 'custom' }
    jobs[#jobs + 1] = { body = body, kind = 'scene_custom' }
    jobs[#jobs + 1] = { body = body, kind = 'scene_prop' }
    for _, female in ipairs({ false, true }) do
        for _, seq in ipairs({ 'd1_t02_Plaza_Sit01_Idle', 'd1_t02_Plaza_Sit02' }) do
            jobs[#jobs + 1] = { body = body, kind = 'ledge', seq = seq, female = female }
        end
    end
end
local index, Next = 0
local function Record()
    local n = actor:GetNPC()
    local entry = { body = job.body, kind = job.kind, yaw = job.yaw, model = job.model, female = job.female, seq = job.seq,
        pos = tostring(n:GetPos()), state = actor:GetState(), passed = true }
    report.cases[#report.cases + 1] = entry Write()
    Clear() timer.Simple(0.2, function() Protect(Next) end)
end
Next = function()
    index = index + 1 job = jobs[index]
    if not job then Finish() return end
    GetConVar('bgn_scenic'):SetString('0')
    GetConVar('bgn_actor_body'):SetString(job.body)
    GetConVar('bgn_enable'):SetString('1')
    local spot, target, old_mask, old_gravity, old_move_type
    if job.kind == 'prop' or job.kind == 'scene_prop' then
        chair = ents.Create('prop_physics') chair:SetModel(job.model or 'models/props_c17/chair02a.mdl')
        chair:SetPos(base + Vector(0, 0, 4)) chair:SetAngles(Angle(0, job.yaw or 0, 0)) chair:Spawn()
        chair:SetPos(base + Vector(0, 0, 2 - chair:OBBMins().z))
        chair:GetPhysicsObject():EnableMotion(false)
        if job.kind == 'scene_prop' then spot = assert(S.Find('chair', chair)) end
        target = chair:GetPos()
    elseif job.kind == 'custom' or job.kind == 'scene_custom' then
        local seat = BGN_SEAT:GetAllSeats()[1] seat:SetSitting(NULL) seat.sitDelay = 0
        spot = assert(S.Find('chair', seat)) target = seat:GetStartSittingPos()
    else
        support = ents.Create('func_brush') support:SetModel('*1') support:SetPos(base + Vector(0, 0, -85))
        support:Spawn() support:SetSolid(SOLID_BSP)
        spot = assert(S.Find('ledge', base + Vector(0, 80, 40), bgNPC.cfg.scenic.ledge_sitting))
        local down = util.TraceLine({ start = spot.pos + Vector(0, 0, 3), endpos = spot.pos - Vector(0, 0, 3), mask = MASK_SOLID_BRUSHONLY })
        assert(down.Hit and math.abs(down.HitPos.z - spot.pos.z) < 2, 'pelvis has direct surface support')
        local front = S.Floor(spot.pos + spot.ang:Forward() * 20)
        assert(front and spot.pos.z - front.z >= 24, 'pose faces the drop')
        target = spot.pos
    end
    p:SetPos(target + Vector(220, 130, 15)) p:SetEyeAngles((target + Vector(0, 0, 35) - p:EyePos()):Angle())
    if job.kind:StartWith('scene_') or job.kind == 'ledge' then
        local scene = table.Copy(bgNPC.cfg.scenic[job.kind == 'ledge' and 'ledge_sitting' or 'chair_sitting'])
        if job.seq then scene.members[1].seq = job.seq end
        item = assert(bgNPC.Scenic.Create(job.kind, scene, spot, nil, p)) actor = item.actors[1]
    else
        actor = assert(bgNPC:SpawnActor('citizen', target + (chair and chair:GetForward() or Vector(-1, 0, 0)) * (job.distance or 120) + Vector(0, 0, 4), false, false))
    end
    actor.eternal = true actor.scenic_debug_item = item or {} actor.skip_auto_carry = true
    actor.data.start_random_state = false actor.data.at_random = {}
    local n = actor:GetNPC()
    old_move_type = n:GetMoveType()
    old_mask = n.loco and n:GetSolidMask() old_gravity = n.loco and n.loco:GetGravity()
    GetConVar('bgn_enable'):SetString('0')
    timer.Simple(0.5, function() Protect(function()
        if job.kind == 'prop' or job.kind == 'custom' then
            assert(actor:SetState(job.kind == 'prop' and 'sit_to_chair' or 'sit_to_chair_2', nil, true), 'seat state entered')
        end
        local deadline = CurTime() + 12
        local function Wait()
            Protect(function()
                assert(actor:IsAlive(), 'actor survives seating')
                local ready = item and actor:HasState('scenic_npc') or (not item and actor:GetStateData().isSit)
                if not ready then assert(CurTime() < deadline, 'actor reached the seat before timeout: pos=' .. tostring(n:GetPos()) .. ', target=' .. tostring(target) .. ', state=' .. actor:GetState() .. ', path=' .. #actor.walkPath .. ', walk=' .. tostring(actor.walkPos)) timer.Simple(0.2, Wait) return end
                local fixed = n:GetPos()
                timer.Simple(1, function() Protect(function()
                    assert(n:GetPos():Distance(fixed) < 1, 'seated body stays in place: ' .. job.body .. '/' .. job.kind .. '/' .. tostring(job.yaw) .. ' delta=' .. n:GetPos():Distance(fixed))
                    if job.kind == 'scene_custom' then assert(n:GetPos():Distance(spot.pos) < 1, 'no physics lift above the bench') end
                    if job.kind == 'ledge' then assert(n:GetPos():Distance(spot.pos - Vector(0, 0, 20)) < 1, 'ledge pose origin stays calibrated') end
                    if job.kind == 'prop' then assert((n.loco and not IsValid(n:GetParent()) or n:GetParent() == chair) and chair.occupied, 'actor sits on the requested prop') end
                    actor:SetState('none', nil, true)
                    if n.loco then assert(n:GetSolidMask() == old_mask and n.loco:GetGravity() == old_gravity and n:GetMoveType() == old_move_type, 'physics restored on exit') end
                    if chair then assert(not chair.occupied, 'chair released on exit') end
                    if spot and spot.seat then assert(not IsValid(spot.seat:GetSitting()), 'custom seat released on exit') end
                    Record()
                end) end)
            end)
        end
        Wait()
    end) end)
end
Protect(Next)
return { pending = true, report = 'bgn_seat_lab/seating.json', cases = #jobs }

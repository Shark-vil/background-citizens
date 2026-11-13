local Siege = bgNPC.Siege
local entries, cooldown = {}, setmetatable({}, {__mode = 'k'})
local NEAR_LIMIT, REAR_DISTANCE = 5, 650
local WAIT_TIME, LIFETIME = 12, 50
local WAIT = {'CombatIdle1', 'pistolangryidle2', 'smg1angryidle1', 'Idle1', 'idle_subtle'}
local KICK = {'kickdoorbaton', 'kickdoor', 'adoorkick', 'melee_gunhit'}
local OPEN = {'Open_door_away', 'buttonfront', 'grenPlace', 'adoorenter'}
local function Sequence(actor, names)
  if not actor.mechanics.animator_controller then return end
  for _, name in ipairs(names) do
    if actor:IsValidSequence(name) and actor:GetNPC():SequenceDuration(actor:GetNPC():LookupSequence(name)) > 0 then return name end
  end
end

Siege.Sequence = Sequence
function Siege.Equipment(actor)
  local kind, names
  if actor.class == 'npc_metropolice' then kind, names = 'manhack', {'deploy'}
  elseif actor.class == 'npc_combine_s' then kind, names = 'grenade', {'grenThrow'}
  else return end
  local sequence = Sequence(actor, names)
  if sequence then return kind, sequence end
end

-- opening: a leaf that has started to swing already counts as open (the weapon follows the opening door at once)
local function Closed(portal, opening)
  for _, door in ipairs(portal.doors) do
    if not IsValid(door) or bgNPC.Doors.held[door] then return true end
    local rotating = door:GetClass() == 'prop_door_rotating'
    local state = door:GetInternalVariable(rotating and 'm_eDoorState' or 'm_toggle_state')
    -- rotating: 1 opening, 2 open; func_door: 2 going up, 0 at top
    local open = rotating and (state == 2 or (opening and state == 1)) or (not rotating and (state == 0 or (opening and state == 2)))
    if not open then return true end
  end
  return false
end

Siege.Closed = Closed
local function CanUseDoors(actor, portal)
  if #portal.doors > 0 and not (Sequence(actor, KICK) or Sequence(actor, OPEN)) then return false end
  for _, door in ipairs(portal.doors) do
    if not IsValid(door) or bgNPC.Doors.held[door] or not bgNPC.Util.CanActorOpenDoor(door) then return false end
  end
  return true
end

function Siege.CanStart(actor, enemy)
  if actor.siege or actor:InVehicle() or not actor.weapon or not IsValid(enemy) or enemy:Health() <= 0
    or (cooldown[enemy] or 0) > CurTime() or not Siege.Equipment(actor) or not Sequence(actor, WAIT) then return end
  local known = actor.enemy_last_position and actor.enemy_last_position[enemy]
  if not known or CurTime() - (actor.enemy_last_seen and actor.enemy_last_seen[enemy] or 0) > 30 then return end
  local portal = Siege.Find(enemy, known)
  if not portal or not CanUseDoors(actor, portal) then return end
  local area = Siege.Area(actor:GetPos())
  if not area or portal.pocket[area:GetID()] or actor:GetPos():DistToSqr(portal.center) > 1000 ^ 2 then return end
  for _, entry in pairs(entries) do
    if entry.enemy == enemy or entry.portal.center:DistToSqr(portal.center) < REAR_DISTANCE ^ 2 then return end
  end
  return portal
end

local function Slot(actor, entry, desired, near)
  local area = Siege.Area(desired)
  if not area or entry.portal.pocket[area:GetID()] then return end
  local pos = area:GetClosestPointOnArea(desired)
  local offset = pos - entry.portal.center
  if offset:Dot(entry.portal.normal) < 64 or (near and offset:LengthSqr() > 600 ^ 2)
    or (not near and offset:LengthSqr() < REAR_DISTANCE ^ 2) then return end
  pos = bgNPC.Doors.Floor(actor, pos, NULL)
  if not pos then return end
  for _, member in pairs(entry.members) do if member.slot:DistToSqr(pos) < 85 ^ 2 then return end end
  return pos
end

-- An actor already inside the pocket is in the target's room, not at the door: it keeps fighting.
function Siege.Inside(actor, entry)
  local area = Siege.Area(actor:GetPos())
  return area ~= nil and entry.portal.pocket[area:GetID()] == true
end

local function Join(actor, entry, near)
  if actor.siege or Siege.Inside(actor, entry) or not actor:IsAlive() or actor:InVehicle() or not actor.weapon or actor:IsMeleeWeapon()
    or not actor:HasEnemy(entry.enemy) or not actor:HasTeam(entry.operator) or not Sequence(actor, WAIT)
    or not actor:HasState({'defense', 'take_cover'}) then return end
  local portal = entry.portal
  for i = 1, 16 do
    local rank = near and i or (entry.rear_count + i)
    local depth = near and (160 + math.floor((rank - 1) / 2) * 105) or (REAR_DISTANCE + 100 + math.floor((rank - 1) / 2) * 110)
    local side = near and (rank % 2 == 1 and -1 or 1) * (portal.width / 2 + 45) or (rank % 2 == 1 and -1 or 1) * 48
    local desired = portal.center + portal.normal * depth + portal.right * side
    desired.z = portal.floor + 2
    local slot = Slot(actor, entry, desired, near)
    if not slot then
      desired = portal.center + portal.normal * depth
      desired.z = portal.floor + 2
      slot = Slot(actor, entry, desired, near)
    end
    if slot then
      local member = {slot = slot, near = near}
      entry.members[actor] = member
      actor:SetState('siege', {entry = entry, member = member})
      if actor:HasState('siege') then
        actor:ShareEnemyMemory(entry.operator, entry.enemy)
        if near then entry.near_count = entry.near_count + 1 else entry.rear_count = rank end
        return true
      end
      entry.members[actor] = nil
      return
    end
  end
  if near then return Join(actor, entry, false) end
  if actor:GetPos():DistToSqr(portal.center) < REAR_DISTANCE ^ 2 then entry.cancelled = true end
end

function Siege.Start(actor)
  local enemy = actor:GetEnemy()
  local portal = Siege.CanStart(actor, enemy)
  if not portal then return end
  local kind, sequence = Siege.Equipment(actor)
  local entry = {portal = portal, enemy = enemy, operator = actor, kind = kind, sequence = sequence,
    known = actor.enemy_last_position[enemy], members = {}, near_count = 0, rear_count = 0,
    expires = CurTime() + LIFETIME, phase = 'position', ready_until = CurTime() + 15}
  if actor.squad then
    entry.group = {}
    for _, member in ipairs(actor.squad.squad.members) do entry.group[member] = true end
  end
  entries[portal.key] = entry -- reserve before another actor can plan against this entrance
  -- The operator enters through the state's pre_start; followers join after it has acquired its slot.
  local desired = portal.center + portal.normal * 160 + portal.right * (portal.width / 2 + 45)
  desired.z = portal.floor + 2
  local pos = Slot(actor, entry, desired, true)
  if not pos then
    desired = portal.center + portal.normal * 160
    desired.z = portal.floor + 2
    pos = Slot(actor, entry, desired, true)
  end
  if not pos then entries[portal.key] = nil return end
  local member = {slot = pos, near = true}
  entry.members[actor], entry.near_count = member, 1
  return entry, member
end

-- Only police have the radio lines.
function Siege.Say(actor, id)
  if actor:IsAlive() and actor:HasTeam('police') then actor:Voice(id) end
end

function Siege.Finish(entry)
  if entry.finished then return end
  entry.finished = true
  local dead = not IsValid(entry.enemy) or entry.enemy:Health() <= 0
  Siege.Say(entry.operator, dead and 'police_siege_clear' or entry.cancelled and 'police_siege_abort' or 'police_siege_withdraw')
  entries[entry.portal.key] = nil
  cooldown[entry.enemy] = CurTime() + 60
  for door, saved in pairs(entry.door_delays or {}) do
    if IsValid(door) then
      door:SetSaveValue(saved.field, saved.delay)
      if saved.delay >= 0 then door:Fire('Close', '', saved.delay) end
      if saved.locked then door:Fire('Lock', '', math.max(0, saved.delay)) end
    end
  end
  for actor in pairs(entry.members) do
    if actor:IsAlive() and actor:HasState('siege') and actor:GetStateData().entry == entry then
      actor:SetState(actor:HasNoEnemies() and 'none' or 'defense', nil, true)
    end
  end
end

function Siege.Detach(actor, data)
  actor.siege = nil
  actor:StopStaticSequence()
  local npc, body = actor:GetNPC(), actor:GetBody()
  if IsValid(npc) and data.capabilities then npc:CapabilitiesAdd(data.capabilities) end
  if body then body:StopMoving() body:SetAlertLevel(actor:HasNoEnemies() and 'idle' or 'combat') end
  if data.entry and not data.entry.finished and not data.left then data.entry.cancelled = true end
end

function Siege.Quiet(actor, data)
  actor.siege = data.entry
  actor:StopWalk()
  local npc = actor:GetNPC()
  actor:GetBody():StopMoving()
  actor:GetBody():SetAlertLevel('alert')
  if npc:IsNPC() then
    local remove = CAP_USE_WEAPONS + CAP_AUTO_DOORS + CAP_OPEN_DOORS
    data.capabilities = bit.band(npc:CapabilitiesGet(), remove)
    npc:CapabilitiesRemove(remove)
  end
end

function Siege.Reach(actor, pos)
  if actor:GetPos():DistToSqr(pos) < 34 ^ 2 then
    actor:StopWalk()
    if actor:GetBody():IsMoving() then actor:GetBody():StopMoving() end
    return true
  end
  if actor:IsAnimationPlayed() then actor:StopStaticSequence() end
  local body = actor:GetBody()
  body:SetAlertLevel('alert')
  body:MoveTo(pos, false)
  if actor:GetNPC():IsNPC() then actor:GetNPC():SetNPCState(NPC_STATE_SCRIPT) end
end

function Siege.Wait(actor)
  if actor:IsAnimationPlayed() then return end
  local npc = actor:GetNPC()
  local portal = actor.siege.portal
  npc:SetAngles(Angle(0, (portal.center - npc:GetPos()):Angle().y, 0))
  return actor:PlayStaticSequence(Sequence(actor, WAIT), true)
end

function Siege.Animate(actor, sequence)
  actor:StopStaticSequence()
  actor:GetBody():StopMoving()
  -- Native deploy/throw events create their own weapons; a prop donor has no NPC event handler.
  return bgNPC.Animator.Play(actor:GetNPC():GetModel(), sequence, actor:GetNPC(), {stop_on_damage = true, require_pvs = false})
end

function Siege.DoorAction(actor, entry)
  local kick, open = Sequence(actor, KICK), Sequence(actor, OPEN)
  entry.kick = kick ~= nil and (open == nil or bgNPC.Util.Chance(35))
  return entry.kick and kick or open
end

function Siege.Open(actor, entry)
  if not CanUseDoors(actor, entry.portal) then return false end
  entry.door_delays = entry.door_delays or {}
  for _, door in ipairs(entry.portal.doors) do
    door.bgNPCOpenDoor = false -- do not let the ordinary opener close the launch corridor later
    if not entry.door_delays[door] then
      local field = door:GetClass() == 'prop_door_rotating' and 'm_flAutoReturnDelay' or 'm_flWait'
      local delay = door:GetInternalVariable(field)
      if isnumber(delay) then
        entry.door_delays[door] = {field = field, delay = delay, locked = bgNPC.Util.IsDoorLocked(door)}
        door:SetSaveValue(field, -1)
      end
    end
    if bgNPC.Util.IsDoorLocked(door) then door:Fire('Unlock') end
    local speed = tonumber(door:GetInternalVariable('m_flSpeed')) or tonumber(door:GetKeyValues().speed)
    if entry.kick and speed and speed > 0 then
      door:Fire('SetSpeed', '900')
      timer.Simple(0.4, function() if IsValid(door) then door:Fire('SetSpeed', tostring(speed)) end end)
    end
    if door:GetClass() == 'prop_door_rotating' then
      door:Fire('OpenAwayFrom', '!activator', 0, actor:GetNPC(), actor:GetNPC())
    else door:Fire('Open', '', 0, actor:GetNPC(), actor:GetNPC()) end
  end
  return true
end

local function ClearHull(a, b, filter)
  local tr = util.TraceHull({start = a, endpos = b, mins = Vector(-4, -4, -4), maxs = Vector(4, 4, 4), mask = MASK_SOLID, filter = filter})
  return not tr.Hit and not tr.StartSolid
end

function Siege.Payload(actor, entry)
  if entry.used or Closed(entry.portal, true) then return false end
  local npc, portal = actor:GetNPC(), entry.portal
  local start = npc:GetPos() + Vector(0, 0, 54)
  local target = Vector(entry.known.x, entry.known.y, entry.known.z)
  local area = Siege.Area(target)
  if not area or not portal.pocket[area:GetID()] then return false end
  target.z = area:GetClosestPointOnArea(target).z + 12
  local velocity
  if entry.kind == 'grenade' then
    local radius = math.max(250, GetConVar('sk_fraggrenade_radius'):GetFloat()) + 48
    for _, other in ipairs(bgNPC.Actors.GetAll()) do
      -- the operator is not checked: it throws from the door and walks back to its slot during the 3.5 s fuse
      if other ~= actor and other:IsAlive() and not actor:HasEnemy(other:GetNPC()) and other:GetPos():DistToSqr(target) < radius ^ 2 then return false end
    end
    for _, ply in ipairs(player.GetHumans()) do
      if not actor:HasEnemy(ply) and ply:GetPos():DistToSqr(target) < radius ^ 2 then return false end
    end
    local gravity, flight = GetConVar('sv_gravity'):GetFloat(), 0.65
    velocity = (target - start) / flight + Vector(0, 0, gravity * flight / 2)
    if velocity:LengthSqr() > 1000 ^ 2 then return false end
    local previous = start
    for i = 1, 16 do
      local t = flight * i / 16
      local pos = start + velocity * t - Vector(0, 0, gravity * t * t / 2)
      if not ClearHull(previous, pos, {npc, entry.enemy}) then return false end
      previous = pos
    end
  elseif not ClearHull(start, portal.center - portal.normal * 64, npc) then return false end
  entry.used = true -- one shared use, even if a late callback or another member asks again
  local ent = ents.Create(entry.kind == 'grenade' and 'npc_grenade_frag' or 'npc_manhack')
  if not IsValid(ent) then return false end
  ent.bgn_siege_owner = npc
  ent:SetOwner(npc)
  ent:SetPos(start)
  ent:SetAngles((-portal.normal):Angle())
  ent:Spawn()
  ent:Activate()
  if entry.kind == 'grenade' then
    local phys = ent:GetPhysicsObject()
    if not IsValid(phys) then ent:Remove() return false end
    phys:SetVelocity(velocity)
    ent:Fire('SetTimer', '3.5')
  else
    -- hostile to every enemy of the operator, friendly to its team, neutral to everyone else
    for _, other in ipairs(bgNPC.Actors.GetAll()) do
      if other:IsAlive() then
        local hostile = actor:HasEnemy(other:GetNPC())
        local relation = hostile and D_HT or actor:HasTeam(other) and D_LI or D_NU
        ent:AddEntityRelationship(other:GetNPC(), relation, 99)
        if not hostile then other:GetBody():SetDisposition(ent, relation) end
      end
    end
    for _, ply in ipairs(player.GetHumans()) do ent:AddEntityRelationship(ply, actor:HasEnemy(ply) and D_HT or D_NU, 99) end
    ent:AddEntityRelationship(entry.enemy, D_HT, 99)
    ent:SetEnemy(entry.enemy)
    ent:UpdateEnemyMemory(entry.enemy, entry.known)
    ent:SetSaveValue('m_vForceMoveTarget', portal.center - portal.normal * 96)
    ent:SetSaveValue('m_fForceMoveTime', CurTime() + 2)
    ent:SetVelocity(-portal.normal * 180)
    timer.Simple(30, function() if IsValid(ent) then ent:Remove() end end)
  end
  entry.payload = ent
  return true
end

local function Update()
  for _, entry in pairs(entries) do
    local enemy, operator = entry.enemy, entry.operator
    local area = IsValid(enemy) and Siege.Area(enemy:GetPos())
    if entry.cancelled or not IsValid(enemy) or enemy:Health() <= 0 or not operator:IsAlive()
      or not operator:HasState('siege') or not operator:HasEnemy(enemy) or not area or not entry.portal.pocket[area:GetID()]
      or CurTime() > entry.expires then Siege.Finish(entry)
    else
      local candidates = {}
      for _, actor in ipairs(bgNPC.Actors.GetAll()) do
        if not actor.siege and actor:GetPos():DistToSqr(entry.portal.center) < 2000 ^ 2 then candidates[#candidates + 1] = actor end
      end
      table.sort(candidates, function(a, b) return a:GetPos():DistToSqr(entry.portal.center) < b:GetPos():DistToSqr(entry.portal.center) end)
      for _, actor in ipairs(candidates) do
        local same_group = not entry.group or entry.group[actor]
        Join(actor, entry, same_group and entry.near_count < NEAR_LIMIT)
      end
      if entry.phase == 'position' then
        local ready = true
        for actor, member in pairs(entry.members) do
          if member.near and actor:GetPos():DistToSqr(member.slot) > 40 ^ 2 then ready = false end
          if not member.near and actor:GetPos():DistToSqr(entry.portal.center) < (REAR_DISTANCE - 34) ^ 2 then ready = false end
        end
        if ready then entry.phase, entry.wait_until = 'wait', CurTime() + WAIT_TIME
        elseif CurTime() > entry.ready_until then Siege.Finish(entry) end
      end
    end
  end
end

timer.Create('BGN_Siege', 0.25, 0, Update)
hook.Add('BGN_PreOpenDoor', 'BGN_Siege', function(actor, door)
  local entry = actor.siege
  if entry then for _, leaf in ipairs(entry.portal.doors) do if leaf == door then return true end end end
end)
hook.Add('EntityTakeDamage', 'BGN_SiegeOwner', function(_, damage)
  local attacker = damage:GetAttacker()
  local inflictor = damage:GetInflictor()
  local owner = IsValid(attacker) and attacker.bgn_siege_owner or nil
  owner = IsValid(owner) and owner or (IsValid(inflictor) and inflictor.bgn_siege_owner)
  if IsValid(owner) then damage:SetAttacker(owner) end
end)
hook.Add('PostEntityTakeDamage', 'BGN_SiegeInterrupt', function(npc, damage, took)
  local actor = bgNPC.Actors.Get(npc)
  if took and damage:GetDamage() > 0 and actor and actor.siege then actor.siege.cancelled = true end
end)
hook.Add('PreCleanupMap', 'BGN_Siege', function() for _, entry in pairs(entries) do Siege.Finish(entry) end end)
hook.Add('BGN_NavProviderChanged', 'BGN_Siege', function() for _, entry in pairs(entries) do Siege.Finish(entry) end end)

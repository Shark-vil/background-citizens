-- Shared door interaction for both body kinds; GOAP chooses it, FSM states execute it.
local Doors = bgNPC.Doors or {}
bgNPC.Doors = Doors
Doors.held = Doors.held or {}
local held = Doors.held
local RADIUS = 400
function Doors.IsClosed(door)
  if not IsValid(door) then return false end
  if door:GetClass() == 'prop_door_rotating' then return door:GetInternalVariable('m_eDoorState') == 0 end
  return door:GetInternalVariable('m_toggle_state') == 1
end

-- Closed geometry is required while the leaf is open; using its current angles puts the actor beside the frame.
local function Geometry(door)
  local class = door:GetClass()
  if class ~= 'prop_door_rotating' and class ~= 'func_door_rotating' then return end
  if IsValid(door:GetParent()) then return end
  local saved = door:GetInternalVariable(class == 'prop_door_rotating' and 'm_angRotationClosed' or 'm_vecAngle1')
  if not saved then return end
  local ang = Angle(saved.x, saved.y, saved.z)
  if math.abs(math.NormalizeAngle(ang.p)) > 5 or math.abs(math.NormalizeAngle(ang.r)) > 5 then return end
  local size, local_center = door:OBBMaxs() - door:OBBMins(), door:OBBCenter()
  local center = door:GetPos() + ang:Forward() * local_center.x - ang:Right() * local_center.y + ang:Up() * local_center.z
  return center, size.x < size.y and ang:Forward() or ang:Right(), size
end

Doors.Geometry = Geometry
local function Floor(actor, pos, door)
  local npc = actor:GetNPC()
  local tr = util.TraceLine({
    start = pos + Vector(0, 0, 36),
    endpos = pos - Vector(0, 0, 64),
    mask = MASK_NPCSOLID,
    filter = {npc, door}
  })

  if not tr.Hit or tr.StartSolid or tr.HitNormal.z < 0.95 then return end
  local mins, maxs = npc:GetCollisionBounds()
  local floor = tr.HitPos + Vector(0, 0, 2 - math.min(mins.z, 0))
  local room = util.TraceHull({
    start = floor,
    endpos = floor,
    mins = mins,
    maxs = maxs,
    mask = MASK_NPCSOLID,
    filter = {npc, door}
  })

  if not room.Hit and not room.StartSolid then return floor end
end

Doors.Floor = Floor
function Doors.Desperate(actor, enemy)
  if not IsValid(enemy) or enemy:Health() <= 0 or actor:InVehicle() or not actor.mechanics.states_controller then return false end
  if actor:GetHealth() < actor:GetMaxHealth() * 0.35 then return true end
  if not actor.weapon and bgNPC.GOAP.sensors.enemy_armed(actor, actor:GetNPC(), enemy) then return true end
  local enemies, allies, pos = 0, 1, actor:GetPos()
  for _, ent in ipairs(actor.enemies) do
    if IsValid(ent) and ent:Health() > 0 and ent:GetPos():DistToSqr(pos) < 1000 ^ 2 then enemies = enemies + 1 end
  end

  if enemies < 2 then return false end
  for _, other in ipairs(bgNPC.Actors.GetAll()) do
    if other ~= actor and other:IsAlive() and other.weapon and actor:HasTeam(other) and not actor:HasEnemy(other:GetNPC()) and other:GetPos():DistToSqr(pos) < 1000 ^ 2 then allies = allies + 1 end
  end
  return enemies > allies
end

function Doors.Sequence(actor)
  for _, name in ipairs({'doorbracer_closed', 'doorbracer_struggle'}) do
    if actor:IsValidSequence(name) then return name end
  end
end

function Doors.Find(actor, enemy)
  if actor:HasTeam('police') or not Doors.Desperate(actor, enemy) or (actor.door_hold_cooldown or 0) > CurTime() or not Doors.Sequence(actor) then return end
  local candidates, origin = {}, actor:GetPos()
  for _, door in ipairs(ents.FindInSphere(origin, RADIUS)) do
    if bgNPC.Util.IsDoor(door) and not held[door] and bgNPC.Util.IsDoorOpen(door) and not bgNPC.Util.IsDoorLocked(door) then
      candidates[#candidates + 1] = {
        door = door,
        dist = origin:DistToSqr(door:GetPos())
      }
    end
  end

  table.SortByMember(candidates, 'dist', true)
  for i = 1, math.min(#candidates, 8) do
    local door = candidates[i].door
    local center, normal, size = Geometry(door)
    if center then
      local side = (enemy:GetPos() - center):Dot(normal) > 0 and -1 or 1
      normal = normal * side -- away from the pursuer
      local base = Vector(center.x, center.y, center.z - size.z / 2)
      local thickness = math.min(size.x, size.y) / 2
      local mins, maxs = actor:GetNPC():GetCollisionBounds()
      local clearance = math.max(math.abs(mins.x), math.abs(mins.y), maxs.x, maxs.y) + 2
      local stand = Floor(actor, base + normal * (thickness + clearance), door)
      -- Stay outside the leaf's sweep while closing, then step up to it.
      local stage = Floor(actor, base + normal * (math.max(size.x, size.y) + clearance + 8), door)
      if stand and stage and math.abs(stage.z - origin.z) < 48 and math.abs(stand.z - origin.z) < 48 then
        local path = util.TraceHull({
          start = stand,
          endpos = stage,
          mins = mins,
          maxs = maxs,
          mask = MASK_NPCSOLID,
          filter = {actor:GetNPC(), door}
        })

        if not path.Hit and not path.StartSolid then
          return {
            door = door,
            center = center,
            normal = normal,
            stand = stand,
            stage = stage,
            ang = Angle(0, (-normal):Angle().y - 35, 0),
            enemy = enemy
          }
        end
      end
    end
  end
end

function Doors.Release(actor)
  for door, entry in pairs(held) do
    if entry.actor == actor then
      held[door] = nil
      if IsValid(door) and entry.locked then door:Fire('Unlock') end
    end
  end
end

function Doors.Reserve(actor, spot)
  if not spot or not IsValid(spot.door) or held[spot.door] then return false end
  spot.actor = actor
  held[spot.door] = spot
  return true
end

function Doors.Close(entry)
  if not IsValid(entry.door) or bgNPC.Util.IsDoorLocked(entry.door) then return false end
  entry.locked = true
  entry.door.bgNPCOpenDoor = false -- cancel the ordinary opener's delayed close/relock
  entry.door:Fire('Lock')
  entry.door:Fire('Close')
  return true
end

function Doors.Blocker(actor, enemy)
  if not actor:HasTeam('police') or not IsValid(enemy) or actor:InVehicle() then return end
  local target = bgNPC.Actors.Get(enemy)
  if not target or not target:HasState('hold_door') then return end
  local entry = target:GetStateData().spot
  if not entry or not entry.bracing or held[entry.door] ~= entry or not IsValid(entry.door) then return end
  if actor:GetPos():DistToSqr(entry.center) > 800 ^ 2 or (actor:GetPos() - entry.center):Dot(entry.normal) >= 0 then return end
  return entry
end

function Doors.Breach(actor, entry)
  if Doors.Blocker(actor, entry.actor:GetNPC()) ~= entry then return false end
  local door, target = entry.door, entry.actor
  local speed = tonumber(door:GetInternalVariable('m_flSpeed')) or tonumber(door:GetKeyValues().speed)
  if not speed or speed <= 0 then return false end
  local state = target:SetState('knocked_down', {
    velocity = entry.normal * 360 + Vector(0, 0, 100),
    resume = entry.resume
  }, true)

  if not state or not target:HasState('knocked_down') then return false end
  door:Fire('SetSpeed', '900')
  if door:GetClass() == 'prop_door_rotating' then
    door:Fire('OpenAwayFrom', '!activator', 0, actor:GetNPC(), actor:GetNPC())
  else
    door:Fire('Open', '', 0, actor:GetNPC(), actor:GetNPC())
  end

  timer.Simple(0.4, function() if IsValid(door) then door:Fire('SetSpeed', tostring(speed)) end end)
  return true
end

hook.Add('AcceptInput', 'BGN_HeldDoor', function(door, input)
  local entry = held[door]
  if not entry or not entry.locked then return end
  input = string.lower(input)
  if input == 'open' or input == 'openawayfrom' or input == 'toggle' or input == 'unlock' then return true end
end)

hook.Add('BGN_PreOpenDoor', 'BGN_HeldDoor', function(_, door) if held[door] then return true end end)
timer.Create('BGN_HeldDoorCleanup', 0.25, 0, function()
  for door, entry in pairs(held) do
    if not entry.actor:IsAlive() or not entry.actor:HasState('hold_door') then
      Doors.Release(entry.actor)
    elseif not IsValid(door) then
      held[door] = nil
    end
  end
end)

hook.Add('PreCleanupMap', 'BGN_HeldDoor', function()
  for _, entry in pairs(held) do
    Doors.Release(entry.actor)
  end
end)

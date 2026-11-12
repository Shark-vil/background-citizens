-- Admin-only placement/inspection for the scenic Tool and console command.
local Scenic = bgNPC.Scenic
local Debug = Scenic.Debug or {
  items = {}
}

Scenic.Debug = Debug
local errors = {
  admin = {
    default = 'This tool requires administrator rights.',
    russian = 'Инструмент доступен только администратору.'
  },
  scene = {
    default = 'Unknown scene.',
    russian = 'Неизвестная сцена.'
  },
  carry_body = {
    default = 'Rations and newspapers require a NextBot body. HL2 NPCs support only the client-side briefcase.',
    russian = 'Паёк и газета требуют тела NextBot. Обычные HL2 NPC поддерживают только клиентский кейс.'
  },
  surface = {
    default = 'Aim at a surface, not the sky.',
    russian = 'Наведитесь на поверхность, а не на небо.'
  },
  door_target = {
    default = 'Aim directly at the door panel, not the floor or wall beside it.',
    russian = 'Наведитесь прямо на полотно двери, а не на пол или стену рядом.'
  },
  door_closed = {
    default = 'The selected door is open or moving. Close it; knocking does not require a lock.',
    russian = 'Выбранная дверь открыта или движется. Закройте её; запирать для стука не нужно.'
  },
  door = {
    default = 'No free floor space beside the selected door.',
    russian = 'Рядом с выбранной дверью нет свободного места на полу.'
  },
  chair = {
    default = 'Aim at a supported, unoccupied chair.',
    russian = 'Наведитесь на подходящий свободный стул.'
  },
  wall = {
    default = 'Aim near the bottom of a wide, flat wall.',
    russian = 'Наведитесь на нижнюю часть широкой ровной стены.'
  },
  floor = {
    default = 'No flat, dry floor with room for the scene.',
    russian = 'Нет ровного сухого пола с местом для сцены.'
  },
  room = {
    default = 'This scene needs an enclosed room with solid walls and ceiling, not an outdoor area.',
    russian = 'Для этой сцены нужна комната со стенами и твёрдым потолком, а не улица.'
  },
  room_space = {
    default = 'The room has insufficient space for every participant and the furniture.',
    russian = 'В комнате недостаточно места для всех участников и мебели.'
  },
  sky = {
    default = 'This scene needs an unobstructed sky above it.',
    russian = 'Для сцены нужно открытое небо над местом спавна.'
  },
  spawn = {
    default = 'The scene is blocked, outside an allowed area, or actor spawning was rejected.',
    russian = 'Место занято, спавн запрещён в этой зоне или создание актора отклонено.'
  },
  door_test = {
    default = 'Aim at a closed, unlocked rotating door not held by another actor.',
    russian = 'Нужна закрытая незапертая распашная дверь, не занятая другим актором.'
  },
}

function Debug.Message(ply, reason)
  return bgNPC.Util.Lang(errors[reason] or errors.spawn, ply)
end

function Debug.Allowed(ply)
  return IsValid(ply) and ply:IsPlayer() and ply:IsAdmin()
end

local function Register(ply, item)
  item.debug_owner = ply
  Debug.items[#Debug.items + 1] = item
  for _, actor in ipairs(item.actors) do
    actor.scenic_debug_item = item
  end

  undo.Create('BGN scenic')
  undo.SetPlayer(ply)
  undo.AddFunction(function() Debug.Remove(ply, item) end)
  undo.Finish('Background NPCs: ' .. item.id)
  return item
end

-- Ownership is retained after actors leave a pose, including through temporary ragdolls/vehicle body replacement.
function Debug.Remove(ply, item)
  if not item or item.debug_owner ~= ply or item.debug_removed then return false end
  item.debug_removed = true
  if item.debug_timer then timer.Remove(item.debug_timer) end
  for _, actor in ipairs(item.actors) do
    if actor:HasState('scenic_npc') and actor:IsAlive() then actor:SetState('none', nil, true) end
    bgNPC.Doors.Release(actor)
    actor:Remove()
    actor.scenic_debug_item = nil
  end

  if IsValid(item.debug_chair) and not item.debug_chair.occupied then item.debug_chair.sitDelay = 0 end
  if item.debug_seat and not IsValid(item.debug_seat:GetSitting()) then item.debug_seat.sitDelay = 0 end
  Scenic.Remove(item)
  table.RemoveByValue(Debug.items, item)
  return true
end

local function DoorPreview(ply, tr)
  local door, spots = tr.Entity, Scenic.Spots
  if not bgNPC.Util.IsDoor(door) then return nil, 'door_target' end
  if bgNPC.Doors.held[door] or bgNPC.Util.IsDoorLocked(door) then return nil, 'door_test' end
  if door:GetClass() ~= 'prop_door_rotating' and door:GetClass() ~= 'func_door_rotating' then return nil, 'door_test' end
  local spot = spots.Find('door', door, {
    gap = 100
  })

  if not spot then return nil, 'door_test' end
  local center = door:LocalToWorld(door:OBBCenter())
  local cop_pos = spots.Floor(Vector(center.x, center.y, spot.pos.z) + spot.ang:Forward() * 140)
  if not cop_pos or not spots.HasRoom(cop_pos) then return nil, 'spawn' end
  return spot, cop_pos
end

local function FindPreview(ply, id, tr)
  if not Debug.Allowed(ply) then return nil, 'admin' end
  if id=='goap_door' and Scenic.Spots.preview then
    local spot, cop_pos=DoorPreview(ply,tr)
    if not spot then return nil, cop_pos end
    if not bgNPC:IsValidSpawnArea('citizen',spot.pos) or not bgNPC:IsValidSpawnArea('police',cop_pos) then return nil,'spawn' end
    return {place='door'},spot,{members={{pos=spot.pos,ang=spot.ang},{pos=cop_pos,ang=spot.ang}}}
  end
  local scene = bgNPC.cfg.scenic[id]
  if not scene then return nil, 'scene' end
  for _, member in ipairs(scene.members) do
    if member.carry and not bgNPC.CarryItems.items[member.carry].npc_model and GetConVar('bgn_actor_body'):GetString() ~= 'nextbot' then return nil, 'carry_body' end
  end

  if not tr.Hit or tr.HitSky then return nil, 'surface' end
  local spots, spot = Scenic.Spots
  if scene.place == 'door' then
    local door = tr.Entity
    if not bgNPC.Util.IsDoor(door) then return nil, 'door_target' end
    if not bgNPC.Doors.IsClosed(door) then return nil, 'door_closed' end
    spot = spots.Find('door', door, scene)
  elseif scene.place == 'chair' then
    spot = spots.Find(scene.place, tr.Entity, scene)
  else
    local seed = spots.Floor(tr.HitPos + tr.HitNormal * (scene.place == 'wall' and 32 or 4))
    if seed then spot = spots.Find(scene.place, seed, scene) end
    if spot and scene.place ~= 'wall' then spot.ang = Angle(0, ply:EyeAngles().y + 180, 0) end
  end

  if not spot then return nil, scene.indoors and 'room' or scene.place end
  local plan = Scenic.Plan(scene, spot, spots.preview)
  if not plan then return nil, scene.indoors and 'room_space' or 'spawn' end
  return scene, spot, plan
end

function Debug.Preview(ply, id, tr, preview)
  local old = Scenic.Spots.preview
  Scenic.Spots.preview = preview == true
  local ok, scene, spot, plan = xpcall(function() return FindPreview(ply, id, tr) end, debug.traceback)
  Scenic.Spots.preview = old
  if not ok then ErrorNoHalt(tostring(scene)) return nil, 'spawn' end
  return scene, spot, plan
end

function Debug.Spawn(ply, id, tr)
  local scene, spot, plan = Debug.Preview(ply, id, tr)
  if not scene then return nil, spot end
  local item = Scenic.Create(id, scene, spot, plan, ply)
  if not item then return nil, 'spawn' end
  item.debug_chair, item.debug_seat = spot.chair, spot.seat
  return Register(ply, item)
end

local function DoorStep(item)
  local holder, officer, door = item.actors[1], item.actors[2], item.door
  if not Debug.Allowed(item.debug_owner) then
    Debug.Remove(item.debug_owner, item)
    return
  end

  if not IsValid(door) or not holder:IsAlive() or not officer:IsAlive() then item.phase = 'ended' end
  if item.phase == 'waiting' then
    local data = holder:GetStateData()
    if holder:HasState('hold_door') and data.spot and data.spot.bracing then
      officer:AddEnemy(holder:GetNPC(), 'defense', true)
      officer:SetState('defense', nil, true)
      item.phase = 'breaching'
    end
  elseif item.phase == 'breaching' and holder:HasState('knocked_down') then
    -- One kick per test: let the holder recover without starting a shootout afterwards.
    officer:RemoveAllEnemies()
    officer:RemoveAllTargets()
    officer:SetState('idle', nil, true)
    item.phase = 'recovering'
  elseif item.phase == 'recovering' and not holder:HasState('knocked_down') then
    item.phase = 'done'
  end

  if CurTime() > item.deadline and item.phase ~= 'done' then item.phase = 'timeout' end
  if item.phase == 'done' or item.phase == 'ended' or item.phase == 'timeout' then timer.Remove(item.debug_timer) end
end

function Debug.DoorTest(ply, tr)
  if not Debug.Allowed(ply) then return nil, 'admin' end
  local spot, cop_pos = DoorPreview(ply, tr)
  if not spot then return nil, cop_pos end
  local door = tr.Entity
  local item = {
    id = 'goap_door',
    actors = {},
    props = {},
    failures = {},
    door = door,
    started = true,
    debug_owner = ply,
    phase = 'preparing',
    deadline = CurTime() + 30
  }

  for i, kind in ipairs({'citizen', 'police'}) do
    local pos = i == 1 and spot.pos or cop_pos
    if not bgNPC:IsValidSpawnArea(kind, pos) then
      Debug.Remove(ply, item)
      return nil, 'spawn'
    end

    local actor = bgNPC:SpawnActor(kind, pos + Vector(0, 0, 4), false, false)
    if not actor then
      Debug.Remove(ply, item)
      return nil, 'spawn'
    end

    actor.data.start_random_state, actor.data.start_state, actor.data.at_random = false, nil, nil
    actor.skip_auto_carry = true
    actor.mechanics.ignore_limit, actor.mechanics.use_vehicle, actor.mechanics.call_for_help = true, false, false
    actor.data.regeneration = false
    item.actors[#item.actors + 1] = actor
  end

  Register(ply, item)
  item.debug_timer = 'BGN_ScenicDoorTest_' .. item.actors[1].uid
  timer.Simple(0.3, function()
    if item.debug_removed then return end
    local holder, officer = item.actors[1], item.actors[2]
    if not Debug.Allowed(ply) or not IsValid(door) or not holder:IsAlive() or not officer:IsAlive() then
      Debug.Remove(ply, item)
      return
    end

    if not bgNPC.Doors.Sequence(holder) then
      item.failures[1] = {
        type = 'citizen',
        model = holder:GetNPC():GetModel(),
        sequences = {'doorbracer_closed', 'doorbracer_struggle'},
        reason = 'sequence'
      }

      item.phase = 'model'
      return
    end

    holder:SetTeam({'scenic_debug_holder'})
    holder.brain, officer.brain = bgNPC.GOAPBrain(holder), bgNPC.GOAPBrain(officer)
    holder:GetNPC():SetHealth(math.max(1, math.floor(holder:GetMaxHealth() * 0.25)))
    holder:AddEnemy(officer:GetNPC(), 'fear', true)
    officer:SetState('scenic_npc', {
      seq = officer:GetNPC():GetSequenceName(officer:GetNPC():GetSequence())
    }, true)

    door:Fire('Open')
    holder:SetState('fear', nil, true)
    item.phase = 'waiting'
    timer.Create(item.debug_timer, 0.2, 0, function() DoorStep(item) end)
  end)
  return item
end

hook.Add('PlayerDisconnected', 'BGN_ScenicDebug', function(ply)
  for i = #Debug.items, 1, -1 do
    local item = Debug.items[i]
    if item.debug_owner == ply then Debug.Remove(ply, item) end
  end
end)

bgNPC.Net.Receive('bgn.debug_preview',function(ply,id)
  if not Debug.Allowed(ply) or not GetConVar('bgn_debug'):GetBool() or not isstring(id) then return end
  if (ply.bgn_preview_next or 0)>CurTime() then return end
  ply.bgn_preview_next=CurTime()+.5
  local tool=ply:GetTool()
  local wep=ply:GetActiveWeapon()
  if not tool or tool.Mode~='bgn_scenic_debug' or not IsValid(wep) or wep:GetClass()~='gmod_tool' then return end
  local tr=ply:GetEyeTrace()
  local scene,spot,plan=Debug.Preview(ply,id,tr,true)
  local positions={}
  if plan then for j,m in ipairs(plan.members) do if j<=8 then positions[#positions+1]={pos=m.pos,ang=m.ang} end end end
  bgNPC.Net.Send('bgn.debug_preview',ply,{id=id,positions=positions,pos=tr.HitPos,valid=scene~=nil,message=scene and '' or Debug.Message(ply,spot),
    point=spot and istable(spot) and spot.pos or nil,normal=tr.HitNormal})
end,{admin=true})

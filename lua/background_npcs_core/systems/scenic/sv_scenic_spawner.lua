--[[
	Scenic NPCs: staged scenes that appear on the map and stay until nobody watches (data: config/states/sh_scenic.lua,
	places: sv_scenic_finders.lua, state: brain/fsm/states/sh_scenic_npc.lua).

	A scene is made of ordinary actors, so an NPC and a NextBot body both work and every reaction of the mod works:
	a shot, a hit or a nearby fight takes an actor out of the scene (it becomes a usual resident), the others stay.

	Console: bgn_scenic_spawn <scene id> puts a scene in front of the admin, bgn_scenic_clear removes all.
--]]
local Scenic = bgNPC.Scenic or {}
bgNPC.Scenic = Scenic
local Spots = Scenic.Spots
local Util = bgNPC.Util
--
local cvar_enable = GetConVar('bgn_scenic')
local cvar_max = GetConVar('bgn_scenic_max')
local cvar_period = GetConVar('bgn_scenic_period')
local cvar_radius = GetConVar('bgn_spawn_radius')
local cvar_block = GetConVar('bgn_spawn_block_radius')
local TRIES = 6 -- seeds checked in one pass
local MIN_DISTANCE_SQR = 400 * 400 -- between two scenes
local START_DELAY = 0.2 -- the actor finishes its own initialization first
local CHECK_PERIOD = 5
local DEFAULT_TTL = 600
local MAX_COOLDOWN = 600
local SPAWN_LIFT = Vector(0, 0, 4)
local STAGE_OFFSETS = {Vector(), Vector(48, 0, 0), Vector(-48, 0, 0), Vector(0, 48, 0), Vector(0, -48, 0), Vector(48, 48, 0), Vector(-48, 48, 0), Vector(48, -48, 0), Vector(-48, -48, 0)}
local active = Scenic.active or {}
Scenic.active = active
-- scene id -> { fails, until }: a scene that finds no place waits longer every time (no doors on the map, no walls...)
local cooldown = {}
-- ---------------------------------------------------------------------------
-- Planning
-- ---------------------------------------------------------------------------
local function ToWorld(spot, offset, yaw)
  local pos = spot.pos + spot.ang:Forward() * offset.x + spot.ang:Right() * offset.y
  pos.z = spot.pos.z + offset.z
  return pos, Angle(0, spot.ang.y + (yaw or 0), 0)
end

-- The members of a scene with the copies of the group: { def, offset, yaw }
local function Roster(scene)
  local roster = {}
  for i, def in ipairs(scene.members) do
    roster[i] = {
      def = def,
      offset = def.pos or vector_origin,
      yaw = def.yaw or 0
    }
  end

  local group = scene.group
  if not group then return roster end
  local template = scene.members[1]
  local count = math.random(group.min, group.max)
  for i = 2, count do
    local offset, yaw = vector_origin, template.yaw or 0
    if group.step then
      offset = group.step * (i - 1) + Vector(0, math.random(-6, 6), 0)
    else
      -- a loose cluster: the first stands in the middle, the others around it
      local around = 360 / (count - 1) * (i - 2) + math.random(-20, 20)
      local dist = group.ring * math.Rand(0.7, 1)
      offset = Vector(math.cos(math.rad(around)) * dist, math.sin(math.rad(around)) * dist, 0)
      yaw = yaw + math.random(-70, 70)
    end

    roster[#roster + 1] = {
      def = template,
      offset = (template.pos or vector_origin) + offset,
      yaw = yaw
    }
  end
  return roster
end

-- @return table|nil plan { members = { { def, pos, ang } }, props = { { model, pos, ang, solid } } }
local function Plan(scene, spot)
  local members = {}
  for _, item in ipairs(Roster(scene)) do
    local def = item.def
    local pos, ang = ToWorld(spot, item.offset, item.yaw)
    local stand = pos
    if spot.ledge then
      pos = pos + Vector(0, 0, -20)
    elseif def.seat then
      pos, ang = spot.stage, spot.ang
      stand = pos
    else
      local floor = Spots.Floor(pos)
      -- one level for the whole scene: no member on the floor below or on a ledge
      -- a body leaning on a wall (a gap under a body width) touches it by design, the finder checked the room
      local tight = (scene.gap or 22) < 18
      if not floor or math.abs(floor.z - spot.pos.z) > 20 or Util.IsVectorInWater(floor) or not (tight or Spots.HasRoom(floor)) then return end
      pos = floor + Vector(0, 0, item.offset.z)
      stand = floor
    end

    if not bgNPC:IsValidSpawnArea(def.type, pos) then return end
    members[#members + 1] = {
      def = def,
      pos = pos,
      stand = stand,
      ang = ang
    }
  end

  if scene.indoors then
    for _, member in ipairs(members) do
      if not Spots.InRoom(member.pos) then return end
    end
  end

  local props = {}
  for _, prop in ipairs(scene.props or {}) do
    local pos, ang = ToWorld(spot, prop.pos, prop.yaw)
    local model = istable(prop.model) and table.Random(prop.model) or prop.model
    if scene.indoors and not Spots.PropFits(model, pos, ang) then return end
    props[#props + 1] = {
      model = model,
      pos = pos,
      ang = ang,
      solid = prop.solid ~= false
    }
  end
  return {
    members = members,
    props = props
  }
end

Scenic.Plan = Plan
-- ---------------------------------------------------------------------------
-- Poses
-- ---------------------------------------------------------------------------
local function PickSequence(actor, list)
  if not list then return end
  if isstring(list) then list = {list} end
  for _, name in ipairs(bgNPC.Table.Shuffle(list)) do
    if actor:IsValidSequence(name) then return name end
  end
end

-- Sits the NPC on the chair or the custom seat of the spot, the way the sit_to_chair states do.
-- @return table|nil what the state has to give back when the actor leaves the scene
local function Sit(actor, spot)
  local npc = actor:GetNPC()
  local back = {
    old_collision = npc:GetCollisionGroup()
  }

  npc:CallOnRemove('BGN_ScenicSeat', function()
    bgNPC.States.Call('scenic_npc', 'stop', actor, 'scenic_npc', {
      back = back
    })
  end)

  if spot.seat then
    spot.seat:SetSitting(npc)
    npc:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
    npc:SetPos(spot.seat:GetPos())
    npc:SetAngles(spot.seat:GetAngles())
    npc:SetCollisionGroup(back.old_collision)
    back.seat = spot.seat
    return back
  end

  local chair, data = spot.chair, spot.chair_data
  if not IsValid(chair) then return end
  local pos = chair:GetPos() + chair:GetForward() * 35
  local ang = chair:GetAngles()
  if data.offsetPosition then pos = data.offsetPosition(npc, chair, pos) end
  if data.offsetAngle then ang = data.offsetAngle(npc, chair, ang) end
  chair.occupied = true
  npc:SetCollisionGroup(COLLISION_GROUP_WORLD)
  npc:SetPos(pos)
  npc:SetAngles(ang)
  if not npc.loco then -- NextBot locomotion must remain unparented.
    npc:SetParent(chair)
  end

  local phys = chair:GetPhysicsObject()
  if IsValid(phys) then phys:EnableMotion(false) end
  back.chair = chair
  return back
end

local function CreateProp(info)
  local prop = ents.Create('prop_dynamic')
  if not IsValid(prop) then return end
  prop:SetModel(info.model)
  prop:SetPos(info.pos)
  prop:SetAngles(info.ang)
  prop:Spawn()
  if info.solid then
    prop:SetSolid(SOLID_VPHYSICS)
  else
    prop:SetCollisionGroup(COLLISION_GROUP_WEAPON)
  end
  return prop
end

-- ---------------------------------------------------------------------------
-- Scene
-- ---------------------------------------------------------------------------
function Scenic.Remove(item)
  if item.removed then return end
  item.removed = true
  for _, actor in ipairs(item.actors) do
    -- only those still on the stage: the ones that left are usual residents now and the remover's business
    if actor:HasState('scenic_npc') then
      if actor:IsAlive() then actor:SetState('none', nil, true) end
      actor:Remove()
    elseif not item.started then
      actor:Remove()
    end
  end

  for _, prop in ipairs(item.props) do
    if IsValid(prop) then prop:Remove() end
  end

  table.RemoveByValue(active, item)
end

local function Start(item, plan, spot)
  if item.removed then return end
  if item.debug_owner and (not IsValid(item.debug_owner) or not item.debug_owner:IsAdmin()) then
    Scenic.Remove(item)
    return
  end

  -- The delayed setup moves actors to their final scene positions: validate again now.
  for _, member in ipairs(plan.members) do
    if not item.debug_owner and not bgNPC:IsHiddenSpawnPosition(member.pos) then
      Scenic.Remove(item)
      return
    end
  end

  item.started = true
  if not item.actors[1] then return end
  local sequences = {}
  for i, actor in ipairs(item.actors) do
    local member = plan.members[i]
    if actor:IsAlive() then sequences[i] = PickSequence(actor, member.def.seq) end
    if item.scene.atomic and not sequences[i] then
      local npc = actor:GetNPC()
      item.failures[#item.failures + 1] = {
        type = member.def.type,
        model = IsValid(npc) and npc:GetModel() or 'removed',
        sequences = member.def.seq,
        reason = 'sequence'
      }

      for _, other in ipairs(item.actors) do
        other:Remove()
      end

      Scenic.Remove(item)
      return
    end
  end

  local playing = 0
  for i, actor in ipairs(item.actors) do
    local npc = actor:GetNPC()
    local member = plan.members[i]
    if actor:IsAlive() and IsValid(npc) then
      local seq = sequences[i]
      -- A brain may start sitting during the setup delay; release its old seat before placing the scene.
      actor:SetState('none', nil, true)
      local back
      if seq and member.def.seat then
        back = Sit(actor, spot)
      else
        npc:SetPos(member.pos)
        npc:SetAngles(member.ang)
        local offset = seq and member.def.seq_offsets and member.def.seq_offsets[seq:lower()]
        if offset then npc:SetPos(member.pos + member.ang:Forward() * offset.x + member.ang:Right() * offset.y + Vector(0, 0, offset.z)) end
      end

      local state
      if member.def.carry and bgNPC.CarryItems.Attach(actor, member.def.carry) then
        state = actor:SetState('walk', nil, true)
      elseif seq and (back or not member.def.seat) then
        if member.def.weapon then actor:PrepareWeapon(member.def.weapon, true) end
        state = actor:SetState('scenic_npc', {
          seq = seq,
          scene = item,
          back = back,
          door = spot.door,
          exit_pos = not back and member.stand or nil,
          seated = spot.ledge or member.def.seat
        }, true)
      end

      if state and (member.def.carry or (actor:HasState('scenic_npc') and actor:IsAnimationPlayed())) then
        playing = playing + 1
      else
        local carry = member.def.carry and bgNPC.CarryItems.items[member.def.carry]
        item.failures[#item.failures + 1] = {
          type = member.def.type,
          model = npc:GetModel(),
          sequences = member.def.seq or (carry and {carry.idle, carry.walk}),
          reason = not seq and 'sequence' or 'setup'
        }

        if actor:HasState('scenic_npc') then
          actor:SetState('none', nil, true)
        elseif back then
          bgNPC.States.Call('scenic_npc', 'stop', actor, 'scenic_npc', {
            back = back
          })
        end

        actor:Remove() -- no sequence for this model, or the chair is gone
      end
    end
  end

  if playing == 0 or (item.scene.atomic and playing < #item.actors) then Scenic.Remove(item) end
end

local function SpawnPosition(member, actors)
  for _, offset in ipairs(STAGE_OFFSETS) do
    local floor = Spots.Floor((member.stand or member.pos) + offset)
    if floor and math.abs(floor.z - (member.stand or member.pos).z) < 20 and Spots.HasRoom(floor) and bgNPC:IsValidSpawnArea(member.def.type, floor) then
      local free = true
      for _, other in ipairs(actors) do
        if other:GetNPC():GetPos():Distance(floor) < 40 then
          free = false
          break
        end
      end

      if free then return floor + SPAWN_LIFT end
    end
  end
end

-- Spawns the scene at the spot.
-- @return table|nil the scene
function Scenic.Create(id, scene, spot, plan, debug_owner)
  if debug_owner ~= nil and (not IsValid(debug_owner) or not debug_owner:IsPlayer() or not debug_owner:IsAdmin()) then return end
  plan = plan or Plan(scene, spot)
  if not plan then return end
  local item = {
    id = id,
    scene = scene,
    pos = spot.pos,
    actors = {},
    props = {},
    failures = {},
    born = CurTime(),
    debug_owner = debug_owner
  }

  for _, member in ipairs(plan.members) do
    -- Use nearby floor for close partners; stacking them upward can put the second one inside a room's ceiling.
    local spawn_pos = SpawnPosition(member, item.actors)
    local actor = spawn_pos and bgNPC:SpawnActor(member.def.type, spawn_pos, false, not debug_owner)
    if not actor then
      for _, spawned in ipairs(item.actors) do
        spawned:Remove()
      end
      return
    end

    local npc = actor:GetNPC()
    npc:SetAngles(member.ang)
    actor.mechanics.ignore_limit = true
    actor.skip_auto_carry = true
    actor.data.start_random_state, actor.data.start_state = false, nil
    item.actors[#item.actors + 1] = actor
  end

  for _, info in ipairs(plan.props) do
    item.props[#item.props + 1] = CreateProp(info)
  end

  active[#active + 1] = item
  timer.Simple(START_DELAY, function() Start(item, plan, spot) end)
  bgNPC.Util.Log('Scene ' .. id .. ' (' .. #item.actors .. ' actors)', 'Scenic')
  return item
end

-- ---------------------------------------------------------------------------
-- Finding a place
-- ---------------------------------------------------------------------------
local function PickScene()
  local total, list = 0, {}
  local now = CurTime()
  for id, scene in pairs(bgNPC.cfg.scenic) do
    local wait = cooldown[id]
    local enabled = GetConVar('bgn_scenic_' .. id)
    if (not enabled or enabled:GetBool()) and not (wait and wait.till > now) then
      local weight = scene.weight or 10
      if weight > 0 then
        list[#list + 1] = {
          id = id,
          weight = weight
        }

        total = total + weight
      end
    end
  end

  local roll = math.random() * total
  for _, entry in ipairs(list) do
    roll = roll - entry.weight
    if roll <= 0 then return entry.id end
  end
end

local function IsFarFromScenes(pos)
  for _, item in ipairs(active) do
    if item.pos:DistToSqr(pos) < MIN_DISTANCE_SQR then return false end
  end
  return true
end

local function Backoff(id, found)
  if found then
    cooldown[id] = nil
    return
  end

  local fails = (cooldown[id] and cooldown[id].fails or 0) + 1
  cooldown[id] = {
    fails = fails,
    till = CurTime() + math.min(MAX_COOLDOWN, 20 * 2 ^ fails)
  }
end

-- Members stand around the spot: each one must be out of sight too, not only the spot itself.
local function MembersHidden(plan)
  for _, member in ipairs(plan.members) do
    if not bgNPC:IsHiddenSpawnPosition(member.pos) then return false end
  end
  return true
end

-- One pass: the scene id (or a random one) at the first seed that fits.
-- @return table|nil the scene
function Scenic.TrySpawn(id)
  local players = player.GetHumans()
  if #players == 0 then return end
  id = id or PickScene()
  local scene = id and bgNPC.cfg.scenic[id]
  if not scene then return end
  local seeds = Spots.Seeds(scene.place, players)
  for i = 1, math.min(TRIES, #seeds) do
    local spot = Spots.Find(scene.place, seeds[i], scene)
    if spot and IsFarFromScenes(spot.pos) then
      local plan = Plan(scene, spot)
      if plan and bgNPC:IsHiddenSpawnPosition(spot.pos) and MembersHidden(plan) then
        local item = Scenic.Create(id, scene, spot, plan)
        if item then
          Backoff(id, true)
          return item
        end
      end
    end
  end

  Backoff(id, false)
end

-- ---------------------------------------------------------------------------
-- Life cycle
-- ---------------------------------------------------------------------------
-- Nobody sees the place and nobody is close.
local function IsUnwatched(pos)
  local block_sqr = cvar_block:GetFloat() ^ 2
  for _, ply in ipairs(player.GetHumans()) do
    if pos:DistToSqr(ply:GetPos()) <= block_sqr or bgNPC.Vision.PlayerCanSeePos(ply, pos) then return false end
  end
  return true
end

local function IsFarFromPlayers(pos)
  local far_sqr = (cvar_radius:GetFloat() * 1.1) ^ 2
  for _, ply in ipairs(player.GetHumans()) do
    if pos:DistToSqr(ply:GetPos()) <= far_sqr then return false end
  end
  return true
end

local function Check(item)
  if item.debug_owner then -- Owned tests live until manual cleanup or the owner disconnects.
    return
  end

  local staying = 0
  for i = #item.actors, 1, -1 do
    local actor = item.actors[i]
    if not actor:IsAlive() then
      table.remove(item.actors, i)
    elseif actor:HasState('scenic_npc') then
      staying = staying + 1
    end
  end

  local far = IsFarFromPlayers(item.pos)
  local done = staying == 0 or CurTime() - item.born > (item.scene.ttl or DEFAULT_TTL)
  if far or (done and IsUnwatched(item.pos)) then Scenic.Remove(item) end
end

bgNPC.Tasks.Add('bgn_scenic', function(yield, wait)
  local next_spawn = 0
  while true do
    wait(CHECK_PERIOD)
    for i = #active, 1, -1 do
      if active[i] then Check(active[i]) end
      yield()
    end

    if cvar_enable:GetBool() and CurTime() >= next_spawn and #active < cvar_max:GetInt() and GetConVar('bgn_enable'):GetBool() then
      next_spawn = CurTime() + cvar_period:GetFloat()
      Scenic.TrySpawn()
    end
  end
end)

-- ---------------------------------------------------------------------------
-- Console
-- ---------------------------------------------------------------------------
function Scenic.Clear()
  for i = #active, 1, -1 do
    Scenic.Remove(active[i])
  end
end

bgNPC.Commands.Register('bgn_scenic_clear', {
  admin = true,
  server = Scenic.Clear,
  help = 'Removes every scenic scene'
})

bgNPC.Commands.Register('bgn_scenic_spawn', {
  admin = true,
  help = 'bgn_scenic_spawn <scene id>: a scene where you look (door scenes require a closed door)',
  autocomplete = function(_, args)
    local list = {}
    for id in pairs(bgNPC.cfg.scenic) do
      list[#list + 1] = 'bgn_scenic_spawn ' .. id
    end
    return list
  end,
  server = function(ply, _, args)
    local id = args[1]
    if not IsValid(ply) then return end
    local item, reason = Scenic.Debug.Spawn(ply, id, ply:GetEyeTrace())
    if not item then bgNPC.Util.Notify(ply, Scenic.Debug.Message(ply, reason), 'error', 6) end
  end,
})

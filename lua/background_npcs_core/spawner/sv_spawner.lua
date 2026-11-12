local table_shuffle = bgNPC.Table.Shuffle
local table_RandomBySeq = bgNPC.Table.Random
-- local math_sqrt = math.sqrt
local Chance = bgNPC.Util.Chance
-- local angle_zero = Angle()
local vector_0_0_50 = Vector(0, 0, 50)
local vector_0_0_1000 = Vector(0, 0, 1000)
-- local clr_bad_spawn_pos = Color(236, 14, 14)
-- local clr_good_spawn_pos = Color(140, 236, 14)
-- local debugoverlay_Sphere = debugoverlay.Sphere
-- local assert = assert
-- local FrameTime = FrameTime
-- local LocalToWorld = LocalToWorld
local cvar_bgn_spawn_radius = GetConVar('bgn_spawn_radius')
local cvar_bgn_spawn_block_radius = GetConVar('bgn_spawn_block_radius')
local spawn_radius = cvar_bgn_spawn_radius:GetFloat()
local block_radius = cvar_bgn_spawn_block_radius:GetFloat()
local spawn_radius_sqrt = spawn_radius ^ 2
local block_radius_sqrt = block_radius ^ 2
--
local function IsValidSpawnFilter(ent)
  if not IsValid(ent) then return false end
  local ent_class = ent:GetClass()
  if not ent:IsPlayer() and not ent:IsNPC() and not ent:IsNextBot() and not ent:IsVehicle() and ent_class ~= 'trigger_hurt' and not string.StartWith(ent_class, 'prop_') then return true end
  return false
end

local BODY_POINTS = {
  Vector(0, 0, 10), -- feet, chest, head
  Vector(0, 0, 40),
  Vector(0, 0, 64)
}

-- Covered only when the ray stops at least this far short of the point: a hit right at it
-- (a curb, a railing, the floor edge) still leaves the body in sight.
local SPAWN_COVER_SQR = 40 ^ 2

-- Is the point behind cover from the player's eyes. The player's own car is ignored: from the driver's seat
-- every ray hit the car body and every spot in front of the windshield counted as hidden.
function bgNPC.IsPointHiddenFrom(ply, point)
  local car = ply:GetVehicle()
  local tr = util.TraceLine({
    start = ply:EyePos(),
    endpos = point,
    mask = MASK_VISIBLE,
    filter = {ply, car, IsValid(car) and car:GetParent() or nil}
  })
  return tr.Hit and not tr.StartSolid and tr.HitPos:DistToSqr(point) > SPAWN_COVER_SQR
end

local function IsNotBlockSpawnPosition(node_position, all_players, target_entity)
  local block_radius_sqr = cvar_bgn_spawn_block_radius:GetFloat() ^ 2
  -- local entities = ents_FindInSphere(node_position, 150)
  -- for e = 1, #entities do
  -- 	local ent = entities[e]
  -- 	if IsValid(ent) and (ent:IsNPC() or ent:IsNextBot() or string.StartWith(ent:GetClass(), 'prop_')) then
  -- 		-- debugoverlay_Sphere(node_position, 10, 1, clr_bad_spawn_pos)
  -- 		return false
  -- 	end
  -- end
  for p = 1, #all_players do
    local ply = all_players[p]
    local ply_pos = ply:GetPos()
    local distance = node_position:DistToSqr(ply_pos)
    if distance <= block_radius_sqr then return false end
    if IsValid(target_entity) and bgNPC.Util.CanSeeEntity(ply, target_entity, true) then return false end
    local in_view = bgNPC.Vision.PlayerCanSeePos(ply, node_position)
    -- Offscreen spots outside the block radius must stay available, as in 1.x.
    if in_view then
      if not util.IsInWorld(node_position) then return false end
      -- the body, not the floor point: a trace to a point on the floor stops on the floor just short of it,
      -- and that counted as "hidden behind something" - actors appeared right in front of the player
      for b = 1, #BODY_POINTS do
        if not bgNPC.IsPointHiddenFrom(ply, node_position + BODY_POINTS[b]) then return false end
      end
    end
  end
  return true
end

local function FindFrontSpawnPosition(points, all_players, target_entity)
  if not Chance(50) then return end
  local checked = {}
  for i = 1, math.min(#points, 32) do
    local pos = points[i]:GetPos()
    local in_view = false
    for p = 1, #all_players do
      if bgNPC.Vision.PlayerCanSeePos(all_players[p], pos) then
        in_view = true
        break
      end
    end

    if in_view then
      checked[i] = true
      if not bgNPC.Util.IsVectorInWater(pos) and IsNotBlockSpawnPosition(pos, all_players, target_entity) then return pos end
    end
  end
  return nil, checked
end

local function FindSpawnLocationProcess(all_players, settings)
  spawn_radius = cvar_bgn_spawn_radius:GetFloat()
  block_radius = cvar_bgn_spawn_block_radius:GetFloat()
  spawn_radius_sqrt = spawn_radius ^ 2
  block_radius_sqrt = block_radius ^ 2
  local desired_position = settings.position
  local teleport_radius = settings.radius or spawn_radius
  local target_entity = settings.target
  local points = bgNPC.Points.GetInRadius(desired_position, teleport_radius, 'walk')
  local points_count = #points
  local nodePosition
  local checked
  if points_count ~= 0 then
    points = table_shuffle(points)
    nodePosition, checked = FindFrontSpawnPosition(points, all_players, target_entity)
    if nodePosition then return nodePosition end
  elseif bgNPC.Points.Count() == 0 then
    spawn_radius = math.Clamp(spawn_radius, 0, 1500)
    block_radius = math.Clamp(block_radius, 0, 600)
    spawn_radius_sqrt = spawn_radius ^ 2
    block_radius_sqrt = block_radius ^ 2
    local dist_x = math.random(block_radius, spawn_radius)
    local dist_y = math.random(block_radius, spawn_radius)
    local dist_z = math.random(0, 100)
    if Chance(50) then dist_x = -dist_x end
    if Chance(50) then dist_y = -dist_y end
    local new_pos = Vector(desired_position.x + dist_x, desired_position.y + dist_y, desired_position.z + dist_z)
    local tr = util.TraceLine({
      start = new_pos + vector_0_0_50,
      endpos = new_pos - vector_0_0_1000,
      filter = function(ent) if IsValid(ent) then return true end end
    })

    if not tr.Hit then return end
    new_pos = tr.HitPos
    if not util.IsInWorld(new_pos) then return end
    if bgNPC.Util.IsVectorInWater(new_pos) then return end
    if not IsNotBlockSpawnPosition(new_pos, all_players, target_entity) then return end
    -- debugoverlay_Sphere(new_pos, 10, 2, clr_good_spawn_pos)
    return new_pos
  end

  for i = 1, points_count do
    -- Failed priority candidates already passed through the same spawn checks.
    if checked and checked[i] then continue end
    local walkNode = points[i]
    nodePosition = walkNode:GetPos()
    if bgNPC.Util.IsVectorInWater(nodePosition) then
      nodePosition = nil
      continue
    end

    if not IsNotBlockSpawnPosition(nodePosition, all_players, target_entity) then
      nodePosition = nil
      continue
    end

    if nodePosition then
      -- debugoverlay_Sphere(nodePosition, 10, 1, clr_good_spawn_pos)
      return nodePosition
    end
  end
end

function bgNPC:ActorIsStuck(actor, position)
  if not actor or not actor:IsAlive() or actor:InVehicle() then return false end
  return bgNPC:NPCIsStuck(actor:GetNPC(), position)
end

function bgNPC:NPCIsStuck(npc, position)
  local obb_min = npc:OBBMins()
  local obb_max = npc:OBBMaxs()
  local origin_center = position or npc:GetPos()
  local min_vector = LocalToWorld(obb_min, angle_zero, origin_center, angle_zero)
  local max_vector = LocalToWorld(obb_max, angle_zero, origin_center, angle_zero)
  -- debugoverlay.Box(origin_center, obb_min, obb_max, 5, Color(233, 147, 34))
  local tr = util.TraceHull({
    start = origin_center,
    endpos = origin_center,
    maxs = obb_max,
    mins = obb_min,
    mask = MASK_SOLID_BRUSHONLY,
    collisiongroup = COLLISION_GROUP_WORLD,
  })

  -- debugoverlay.Box(tr.HitPos, obb_min, obb_max, 5, Color(34, 177, 233))
  if tr and tr.Hit then return true end
  local entities = ents.FindInBox(min_vector, max_vector)
  for i = 1, #entities do
    local ent = entities[i]
    -- a removed entity (the revived actor's ragdoll) stays until the end of the tick
    if ent ~= npc and not ent:IsMarkedForDeletion() and not IsValidSpawnFilter(ent) or ent:IsWorld() then return true end
  end
  return false
end

-- Recheck with current player positions and block radius immediately before spawning or moving.
function bgNPC:IsHiddenSpawnPosition(pos, target)
  return IsNotBlockSpawnPosition(pos, player.GetHumans(), target)
end

function bgNPC:FindSpawnPosition(settings, is_async)
  settings = settings or {}
  local all_players = player.GetHumans()
  local desired_position = settings.position
  if not desired_position then
    -- Per-zone actor concentration ("more police at the police station") is
    -- handled by the dedicated zone-boost spawner (sv_zone_spawner.lua), which
    -- targets specific actor types instead of blindly pulling every spawn
    -- toward whichever area happens to be nearby.
    if #all_players == 0 then return end
    local ply = table_RandomBySeq(all_players)
    desired_position = ply:GetPos()
  end

  settings.position = desired_position
  if not settings.position then return end
  local nodePosition = FindSpawnLocationProcess(all_players, settings)
  if nodePosition and isvector(nodePosition) then return nodePosition end
end

function bgNPC:FindSpawnPositionAsync(settings)
  -- Legacy name: searches never yield between validation and the caller's spawn.
  return self:FindSpawnPosition(settings)
end

do
  local random_models_storage = {}
  local table_HasValueBySeq = bgNPC.Table.HasValue
  function bgNPC:SpawnActor(npc_type, desiredPosition, enableSpawnEffect, require_hidden)
    if player.GetCount() == 0 then return end
    if bgNPC.Util.IsVectorInWater(desiredPosition) then return end
    local npc_data = bgNPC.Config.GetActor(npc_type)
    local is_many_classes = false
    local npc_class
    if istable(npc_data.class) then
      npc_class = table_RandomBySeq(npc_data.class)
      is_many_classes = true
    else
      npc_class = npc_data.class
    end

    if hook.Run('BGN_OnValidSpawnActor', npc_type, npc_data, npc_class, desiredPosition) then return end
    local new_npc_data, new_npc_class = hook.Run('BGN_OverrideSpawnData', npc_type, npc_data, npc_class)
    if new_npc_data then npc_data = new_npc_data end
    if new_npc_class then npc_class = new_npc_class end
    local npc = ents.Create(bgNPC.NextBotBody.ResolveClass(npc_class))
    if not IsValid(npc) then
      MsgN('[Background NPCs] ERROR: Actor with class - ' .. npc_class .. ' cannot be created!')
      return
    end

    npc.bgn_npc_class = npc_class -- the NPC class a NextBot body stands in for
    npc:SetPos(desiredPosition)
    --[[
			ATTENTION! Be careful, this hook is called before the NPC spawns. 
			If you give out a weapon or something similar, it will crash the game!
		--]]
    if hook.Run('BGN_PreSpawnActor', npc, npc_type, npc_data, npc_class, desiredPosition) then
      npc:Spawn()
      timer.Simple(0, function()
        if not IsValid(npc) then return end
        npc:Remove()
      end)
      return
    end

    -- Spawn hooks may move the entity (e.g. a helicopter is lifted above its ground point).
    if require_hidden and not bgNPC:IsHiddenSpawnPosition(npc:GetPos()) then
      npc:Remove()
      return
    end

    npc:SetSpawnEffect(enableSpawnEffect or false)
    -- -- ------------------------------------------------------------------
    -- -- Unsopported iNPC - Artifical Intelligence Module (Improved NPC AI)
    -- -- https://steamcommunity.com/sharedfiles/filedetails/?id=632126111
    -- npc.inpcIgnore = true
    -- -- ------------------------------------------------------------------
    npc:Spawn()
    npc:SetOwner(game.GetWorld())
    npc:Activate()
    npc:PhysWake()
    if bgNPC:NPCIsStuck(npc) then
      timer.Simple(0, function()
        if not IsValid(npc) then return end
        npc:Remove()
      end)
      return
    end

    -- if npc.DropToFloor then npc:DropToFloor() end
    hook.Run('BGN_PostSpawnActor', npc, npc_type, npc_data)
    local skip_set_model = false
    local npcs_list = nil
    do
      local actorData = bgNPC.cfg.actors[npc_type]
      npcs_list = list.Get('NPC')
      for npcClass, actorTypesList in pairs(bgNPC.SpawnMenu.Creator['NPC']) do
        for _, actorType in ipairs(actorTypesList) do
          if actorType == npc_type and table_HasValueBySeq(actorData.class, npcClass) then
            local listData = npcs_list[npcClass]
            if not listData or not listData.Model then
              skip_set_model = true
              break
            end
          end
        end
      end
    end

    if npcs_list and (npc_data.random_model or GetConVar('bgn_all_models_random'):GetBool()) then
      if not random_models_storage[npc_class] then
        random_models_storage[npc_class] = {}
        for k, v in pairs(npcs_list) do
          if v.Model and isstring(v.Model) and v.Class == npc_class then table.insert(random_models_storage[npc_class], v) end
        end
      end

      local models = random_models_storage[npc_class]
      if models and #models ~= 0 then
        local model_info = table_RandomBySeq(models)
        if util.IsValidModel(model_info.Model) then
          npc:SetModel(model_info.Model)
          if model_info.KeyValues and istable(model_info.KeyValues) then
            for key, value in pairs(model_info.KeyValues) do
              npc:SetKeyValue(key, value)
            end
          end
        end
      end
    elseif not skip_set_model and npc_data.models and istable(npc_data.models) then
      local model
      if is_many_classes and npc_data.models[npc_class] then
        model = table_RandomBySeq(npc_data.models[npc_class])
      elseif #npc_data.models ~= 0 then
        model = table_RandomBySeq(npc_data.models)
      end

      if model and util.IsValidModel(model) then
        -- Backward compatibility with the old version of the config
        local default_models = npc_data.default_models or npc_data.defaultModels
        if (not default_models or Chance(80)) and not hook.Run('BGN_PreSetActorModel', model, npc, npc_type, npc_data) then npc:SetModel(model) end
      end
    end

    do
      -- Backward compatibility with the old version of the config
      local random_skin = npc_data.random_skin or npc_data.randomSkin
      if random_skin then
        local skinNumber = math.random(0, npc:SkinCount())
        if not hook.Run('BGN_PreSetActorSkin', skinNumber, npc, npc_type, npc_data) then npc:SetSkin(math.random(0, npc:SkinCount())) end
      end
    end

    do
      -- Backward compatibility with the old version of the config
      local random_bodygroups = npc_data.random_bodygroups or npc_data.randomBodygroups
      if random_bodygroups then
        for _, bodygroup in ipairs(npc:GetBodyGroups()) do
          local id = bodygroup.id
          local value = math.random(0, npc:GetBodygroupCount(id))
          if not hook.Run('BGN_PreSetActorBodygroup', id, value, npc, npc_type, npc_data) then npc:SetBodygroup(id, value) end
        end
      end
    end
    return bgNPC.Actor.Create(npc, npc_type)
  end
end

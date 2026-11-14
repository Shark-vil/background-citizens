--[[
	Plays sequences from other models (player taunts, custom animations) on NPCs.
	Replaces slib "Animator".

	Server creates an invisible prop_dynamic ("animator") with the animation model,
	parented to the NPC. Clients hide the NPC and draw a copy of its model
	bone-merged onto the animator.

	Server:
		Animator.Register(name, model)
		Animator.Play(name_or_model, sequence, entity, settings) -> info | false
			settings.time            override duration
			settings.loop            restart until stopped
			settings.stop_on_damage  stop when the entity takes damage
			settings.not_parent      do not parent the animator to the entity
			settings.require_pvs     default true; false allows server gameplay animations without viewers
		Animator.Stop(entity)
		Animator.IsPlaying(entity)
	Client hook:
		BGN_AnimationStarted(info)  info: name, entity, animator, model, l_hand_bone_index, r_hand_bone_index
--]]
local Net = bgNPC.Net
local Animator = bgNPC.Animator or {}
bgNPC.Animator = Animator
--
local animations = Animator.animations or {}
Animator.animations = animations
-- entity -> info
local active = Animator.active or {}
Animator.active = active
function Animator.Register(name, model)
  animations[name] = Model(model)
end

function Animator.IsPlaying(entity)
  return active[entity] ~= nil
end

function Animator.Get(entity)
  return active[entity]
end

if SERVER then
  local function SyncViewers(info)
    info.viewers = info.viewers or {}
    for _, ply in ipairs(player.GetHumans()) do
      if ply.bgn_ready and ply:TestPVS(info.entity) then
        if not info.viewers[ply] then
          Net.Send('bgn.anim_start', ply, info.entity, info.animator, info.name, info.sequence_id, info.settings.loop and 0 or info.stop_time)
          info.viewers[ply] = true
        end
      else
        info.viewers[ply] = nil
      end
    end

    for ply in pairs(info.viewers) do
      if not IsValid(ply) then info.viewers[ply] = nil end
    end
  end

  local function AnyPlayerInPVS(entity)
    local players = player.GetHumans()
    for i = 1, #players do
      if entity:TestPVS(players[i]) then return true end
    end
    return false
  end

  function Animator.Stop(entity)
    local info = active[entity]
    if not info then return end
    active[entity] = nil
    if IsValid(entity) and info.npc_state and entity:IsCurrentSchedule(SCHED_NPC_FREEZE) then
      local actor = bgNPC.Actors.Get(entity)
      if not actor or not actor.is_animated then
        entity:ClearSchedule()
        if entity:GetNPCState() == NPC_STATE_SCRIPT then entity:SetNPCState(info.npc_state) end
      end
    end

    if IsValid(info.animator) then info.animator:Remove() end
    if IsValid(entity) then Net.Send('bgn.anim_stop', nil, entity) end
  end

  function Animator.Play(name, sequence, entity, settings)
    if not name or not IsValid(entity) or entity:IsDormant() then return false end
    -- hidden (an actor in a car): the client copy would be drawn anyway, on an animator with no visible parent
    if entity:GetNoDraw() then return false end
    settings = settings or {}
    if settings.require_pvs ~= false and not AnyPlayerInPVS(entity) then return false end
    local model = animations[name]
    if not model then
      if not util.IsValidModel(name) then return false end
      model = name
    end

    Animator.Stop(entity)
    local animator = ents.Create('prop_dynamic')
    if not IsValid(animator) then return false end
    animator:SetModel(model)
    animator:SetPos(entity:GetPos())
    animator:SetAngles(entity:GetAngles())
    animator:SetModelScale(entity:GetModelScale())
    -- RENDERMODE_NONE instead of EF_NODRAW: nodraw entities are not sent to clients.
    animator:SetRenderMode(RENDERMODE_NONE)
    animator:DrawShadow(false)
    animator:SetCollisionGroup(COLLISION_GROUP_WORLD)
    if not settings.not_parent then animator:SetParent(entity) end
    animator:Spawn()
    local sequence_id, duration = animator:LookupSequence(sequence)
    if sequence_id == -1 then
      animator:Remove()
      return false
    end

    animator:ResetSequence(sequence_id)
    duration = isnumber(settings.time) and settings.time or duration
    local info = {
      name = name,
      sequence = sequence,
      sequence_id = sequence_id,
      entity = entity,
      animator = animator,
      time = duration,
      stop_time = CurTime() + duration,
      settings = settings,
    }

    active[entity] = info
    SyncViewers(info)
    hook.Run('BGN_AnimationStarted', info)
    return info
  end

  hook.Add('Think', 'BGN_Animator', function()
    local now = CurTime()
    for entity, info in pairs(active) do
      if not IsValid(entity) or not IsValid(info.animator) or entity:Health() <= 0 then
        Animator.Stop(entity)
      elseif info.stop_time <= now then
        if info.settings.loop then
          info.stop_time = now + info.time
          info.animator:ResetSequence(info.sequence_id)
          info.animator:SetCycle(0)
        else
          Animator.Stop(entity)
        end
      elseif entity:IsNPC() and not entity:IsCurrentSchedule(SCHED_NPC_FREEZE) then
        info.npc_state = info.npc_state or entity:GetNPCState()
        entity:SetNPCState(NPC_STATE_SCRIPT)
        entity:SetSchedule(SCHED_NPC_FREEZE)
      end

      if active[entity] == info and (info.next_sync or 0) <= now then
        info.next_sync = now + 0.25
        SyncViewers(info)
      end
    end
  end)

  local function StopOnEvent(entity)
    if active[entity] then Animator.Stop(entity) end
  end

  hook.Add('EntityRemoved', 'BGN_Animator', StopOnEvent)
  hook.Add('OnNPCKilled', 'BGN_Animator', StopOnEvent)
  hook.Add('EntityTakeDamage', 'BGN_Animator', function(entity)
    local info = active[entity]
    if info and info.settings.stop_on_damage then Animator.Stop(entity) end
  end)
else
  local function Cleanup(entity)
    local info = active[entity]
    if not info then return end
    active[entity] = nil
    if IsValid(info.model) then info.model:Remove() end
    if IsValid(info.weapon_model) then info.weapon_model:Remove() end
    if IsValid(info.weapon) then info.weapon:SetNoDraw(false) end
    if IsValid(entity) then entity.RenderOverride = info.render_override end
  end

  local function BoneMergedModel(model, parent, source)
    if not model then -- the entity came without its model yet (NextBots right after spawn)
      return
    end

    local ent = ClientsideModel(model, RENDERGROUP_OPAQUE)
    if not IsValid(ent) then return end
    ent:SetPos(parent:GetPos())
    ent:SetAngles(parent:GetAngles())
    ent:SetParent(parent)
    ent:AddEffects(EF_BONEMERGE + EF_BONEMERGE_FASTCULL)
    if IsValid(source) then
      ent:SetSkin(source:GetSkin())
      ent:SetColor(source:GetColor())
      ent:SetMaterial(source:GetMaterial())
      ent:SetModelScale(source:GetModelScale())
      for index in ipairs(source:GetMaterials()) do
        ent:SetSubMaterial(index - 1, source:GetSubMaterial(index - 1))
      end

      for _, bodygroup in ipairs(source:GetBodyGroups()) do
        ent:SetBodygroup(bodygroup.id, source:GetBodygroup(bodygroup.id))
      end
    end
    return ent
  end

  Net.Receive('bgn.anim_start', function(_, entity, animator, name, _, stop_time)
    if not IsValid(entity) or not IsValid(animator) then return end
    if stop_time and stop_time ~= 0 and stop_time <= CurTime() then return end
    Cleanup(entity)
    local info = {
      name = name,
      entity = entity,
      animator = animator,
      stop_time = stop_time,
      render_override = entity.RenderOverride,
      r_hand_bone_index = animator:LookupBone('ValveBiped.Bip01_R_Hand'),
      l_hand_bone_index = animator:LookupBone('ValveBiped.Bip01_L_Hand'),
    }

    info.model = BoneMergedModel(entity:GetModel(), animator, entity)
    if not IsValid(info.model) then return end
    local weapon = entity.GetActiveWeapon and entity:GetActiveWeapon()
    if IsValid(weapon) and info.r_hand_bone_index then
      info.weapon = weapon
      info.weapon_model = BoneMergedModel(weapon:GetModel(), animator, weapon)
      weapon:SetNoDraw(true)
    end

    animator:SetNoDraw(true)
    entity.RenderOverride = function() end
    active[entity] = info
    hook.Run('BGN_AnimationStarted', info)
  end, {
    wait_entities = true
  })

  Net.Receive('bgn.anim_stop', function(_, entity) Cleanup(entity) end)
  hook.Add('Think', 'BGN_Animator', function()
    for entity, info in pairs(active) do
      if not IsValid(entity) or not IsValid(info.animator) or not IsValid(info.model) or (info.stop_time and info.stop_time ~= 0 and info.stop_time <= CurTime()) then Cleanup(entity) end
    end
  end)
end

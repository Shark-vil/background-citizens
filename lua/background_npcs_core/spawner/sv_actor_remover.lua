--
local fasted_teleport
local bgn_enable
local bgn_actors_teleporter
local max_teleporter
local current_teleport
local player_list
local player_count
hook.Add('BGN_OnKilledActor', 'BGN_ActorRemoveFromData', function(actor) actor:RemoveActor() end)
hook.Add('EntityRemoved', 'BGN_ActorRemoveFromData', function(ent)
  if not ent.isBgnActor then return end
  local actor = bgNPC.Actors.Get(ent) or ent.BGN_ACTOR_OBJECT
  if actor and actor.vehicle_body then
    timer.Simple(0, function()
      if actor.is_removed or actor:GetNPC() ~= ent then return end
      if not actor:ExitVehicle(true) then actor:Remove() end
    end)
    return
  end

  bgNPC.Actors.Unregister(ent)
end)

local function FindExistCarAndEnterThis(actor)
  if not bgNPC:EnterActorInExistVehicle(actor) then return bgNPC:SpawnVehicleWithActor(actor) end
  return true
end

local function TeleportActor(actor, pos)
  if not actor or not bgNPC:IsValidSpawnArea(actor:GetType(), pos) then return end
  if not bgNPC:IsHiddenSpawnPosition(pos, actor:GetNPC()) then return end
  bgNPC:RespawnActor(actor, pos, function(success)
    if not success or not actor:IsAlive() then return end
    actor:RandomState()
    actor.__last_player_interaction = CurTime()
  end)
end

-- states tied to other actors or to a spot: moved away, the others went on talking to empty air
local BUSY_STATES = {'dialogue', 'arrest', 'arrest_surrender', 'medic_revive', 'police_inspect_body', 'sit_to_chair', 'sit_to_chair_2', 'scenic_npc', 'hold_door', 'breach_door', 'knocked_down',}
local cvar_unseen_time = GetConVar('bgn_actor_unseen_time')
local function UpdateLastSeen(actor, players)
  local now = CurTime()
  actor.__last_player_interaction = actor.__last_player_interaction or now
  for _, ply in ipairs(players) do
    if IsValid(ply) and bgNPC.Util.CanSeeEntity(ply, actor:GetNPC(), true) then
      actor.__last_player_interaction = now
      return true
    end
  end
  return false
end

hook.Add('BGN_InitActor', 'BGN_Recycle_LastSeen', function(actor) actor.__last_player_interaction = CurTime() end)
-- Remove the old observer task on script reload; observations never yield inside an actor check.
bgNPC.Tasks.Remove('bgn_actors_last_player_interaction')
timer.Create('BGN_Actors_LastSeen', 0.5, 0, function()
  if not GetConVar('bgn_enable'):GetBool() then return end
  local players = player.GetHumans()
  for _, actor in ipairs(bgNPC.Actors.GetAll()) do
    if actor:IsAlive() and not actor.scenic_debug_item then
      if actor:InVehicle() then
        actor.__last_player_interaction = CurTime()
      else
        UpdateLastSeen(actor, players)
      end
    end
  end
end)

local function CanRecycle(actor, players)
  if UpdateLastSeen(actor, players) then return false end
  return CurTime() - actor.__last_player_interaction >= math.max(0, cvar_unseen_time:GetFloat())
end

local function run_remover_process_async(yield, wait, actors, actors_count)
  local WantedModule = bgNPC.Modules.Get('wanted')
  fasted_teleport = GetConVar('bgn_fasted_teleport'):GetBool()
  bgn_enable = GetConVar('bgn_enable'):GetBool()
  bgn_actors_teleporter = GetConVar('bgn_actors_teleporter'):GetBool()
  max_teleporter = GetConVar('bgn_actors_max_teleports'):GetInt()
  current_teleport = 0
  player_list = player.GetHumans()
  player_count = #player_list
  for i = 1, actors_count do
    yield()
    if not fasted_teleport then yield() end
    player_list = player.GetHumans()
    player_count = #player_list
    local actor = actors[i]
    if not actor or not actor:IsAlive() or actor.scenic_debug_item or actor.eternal or actor.debugger or actor.data.hidden or actor:InVehicle() then continue end
    local npc = actor:GetNPC()
    local npc_type = actor:GetType()
    if not bgn_enable or player_count == 0 or not bgNPC.Config.IsTypeActive(npc_type) then
      if not hook.Run('BGN_PreRemoveNPC', npc) then actor:Remove() end
    else
      if actor.state_lock or actor.conversation or actor:HasState(BUSY_STATES) then continue end
      if not CanRecycle(actor, player_list) then continue end
      if hook.Run('BGN_PreRemoveNPC', npc) then continue end
      local over_limit = false
      if not actor.mechanics.ignore_limit then
        local max_limit = bgNPC.Config.GetTypeLimit(npc_type)
        over_limit = max_limit == 0 or bgNPC.Actors.Count(npc_type) > max_limit
      end

      if over_limit or actor.toRemove or not bgn_actors_teleporter then
        actor:Remove()
      else
        local data = actor:GetData()
        local wanted_level = bgNPC.Config.GetWantedLevel(data)
        if not wanted_level then
          if max_teleporter == current_teleport then break end
          current_teleport = current_teleport + 1
          local is_entered_vehicle = FindExistCarAndEnterThis(actor)
          if not is_entered_vehicle then
            local nodePosition = bgNPC:FindSpawnPositionAsync({
              target = npc
            })

            if nodePosition then TeleportActor(actor, nodePosition) end
          end
        else
          local desiredPosition
          local wanted_list = WantedModule:GetAllWanted()
          for k = 1, #wanted_list do
            local WantedComponent = wanted_list[k]
            local Target = WantedComponent.target
            if IsValid(Target) and WantedComponent.level >= wanted_level then
              desiredPosition = Target:GetPos()
              break
            end
          end

          if not desiredPosition then
            actor:Remove()
          else
            if max_teleporter == current_teleport then break end
            current_teleport = current_teleport + 1
            local is_entered_vehicle = FindExistCarAndEnterThis(actor)
            if not is_entered_vehicle then
              local nodePosition = bgNPC:FindSpawnPositionAsync({
                position = desiredPosition,
                target = npc
              })

              if nodePosition then TeleportActor(actor, nodePosition) end
            end
          end
        end
      end
    end
  end
end

bgNPC.Tasks.Add('bgn_actors_remover_process', function(yield, wait)
  while true do
    local actors = bgNPC.Actors.GetAll()
    local actors_count = #actors
    yield()
    if actors_count == 0 then
      wait(1)
      continue
    end

    run_remover_process_async(yield, wait, actors, actors_count)
  end
end)

hook.Add('BGN_ResetEnemiesForActor', 'BGN_ClearLevelOnlyNPCs', function(actor)
  if not actor:HasTeam('police') then return end
  if actor.eternal then return end
  local wanted_level = bgNPC.Config.GetWantedLevel(actor:GetData())
  if wanted_level then
    local asset = bgNPC.Modules.Get('wanted')
    local wanted_list = asset:GetAllWanted()
    local success = false
    for i = 1, #wanted_list do
      local WantedClass = wanted_list[i]
      local target = WantedClass.target
      if IsValid(target) and WantedClass.level >= wanted_level then
        success = true
        break
      end
    end

    if not success then actor.toRemove = true end
  end
end)

hook.Add('BGN_WantedLevelDown', 'BGN_ClearCurrentlyLevelOnlyNPCs', function(ent, level)
  for _, actor in ipairs(bgNPC.Actors.GetByTeam('police')) do
    local wanted_level = bgNPC.Config.GetWantedLevel(actor:GetData())
    if wanted_level ~= nil and level < wanted_level then actor:RemoveTarget(ent) end
  end
end)

-- A body without a registered actor is a leak (no brain, no label, it would stand there forever, frozen when the
-- LOD had turned its think off). Actor:RemoveActor leaves the entity to the engine, which is right for a death only.
-- Health is not checked: an NPC killed while its think is off (LOD) or frozen by the animator never finishes dying
-- and stands with 0 health. bgn_npc_class marks bodies from the spawner (kept when leaving a car); the body released
-- on boarding is removed by Actor:EnterVehicle itself.
local ORPHAN_GRACE = 3
local developer = GetConVar('developer')
local function IsOrphan(ent)
  local actor = ent.BGN_ACTOR_OBJECT
  if not actor and not ent.bgn_npc_class then return false end
  if not ent:IsNPC() and not ent:IsNextBot() then return false end
  return not actor or actor.is_removed or actor:GetNPC() ~= ent or bgNPC.Actors.GetByUid(actor.uid) ~= actor
end

timer.Create('BGN_RemoveOrphanBodies', 2, 0, function()
  local now = CurTime()
  for _, ent in ipairs(ents.GetAll()) do
    if IsOrphan(ent) then
      ent.bgn_orphan_since = ent.bgn_orphan_since or now
      if now - ent.bgn_orphan_since >= ORPHAN_GRACE then
        if developer:GetInt() > 0 then
          local actor = ent.BGN_ACTOR_OBJECT
          MsgN('[BGN] orphan body removed: ', ent:GetClass(), ' health ', ent:Health(), ' ', actor and tostring(actor:GetType()) .. ' state ' .. tostring(actor:GetState()) or 'no actor')
        end

        ent:Remove()
      end
    else
      ent.bgn_orphan_since = nil
    end
  end
end)

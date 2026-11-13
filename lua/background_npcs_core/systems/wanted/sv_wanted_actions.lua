--
local asset = bgNPC.Modules.Get('wanted')
local enable_wanted_mode = GetConVar('bgn_enable_wanted_mode'):GetBool()
local enable_wanted_police_instantly = GetConVar('bgn_wanted_police_instantly'):GetBool()
local enable_arrest_mode = GetConVar('bgn_arrest_mode'):GetBool()
local impunity_limit = GetConVar('bgn_wanted_impunity_limit'):GetInt()
local impunity_limit_reduction_period = GetConVar('bgn_wanted_impunity_reduction_period'):GetFloat()
local impunity_last_reduction_period = 0
-- local cvar_bgn_spawn_radius = GetConVar('bgn_spawn_radius')
local cvar_detection_radius = GetConVar('bgn_wanted_detection_radius')
local cvar_level_up_period = GetConVar('bgn_wanted_level_up_period')
local cvar_radius_visibility = GetConVar('bgn_spawn_radius_visibility')
-- A wanted actor out of every player's view zone for this long is dropped from the wanted list.
local UNSEEN_RESET_TIME = 15
-- The view zone: the player's field of view within half of bgn_spawn_radius_visibility; obstacles don't matter.
local function InPlayerViewZone(ent)
  local radius_sqr = (cvar_radius_visibility:GetFloat() / 2) ^ 2
  local center = ent:WorldSpaceCenter()
  for _, ply in ipairs(player.GetHumans()) do
    if ply:Alive() and ply:GetPos():DistToSqr(center) <= radius_sqr and bgNPC.Vision.PlayerCanSeePos(ply, center) then return true end
  end
  return false
end

-- @return boolean true if the actor was dropped from the wanted list
local function DropIfUnseen(WantedClass, enemy)
  if enemy:IsPlayer() then return false end
  if InPlayerViewZone(enemy) then
    WantedClass.unseen_since = nil
    return false
  end

  WantedClass.unseen_since = WantedClass.unseen_since or CurTime()
  if CurTime() - WantedClass.unseen_since < UNSEEN_RESET_TIME then return false end
  asset:RemoveWanted(enemy)
  return true
end

hook.Add('BGN_PlayerReady', 'BGN_WantedSync', function(ply)
  for _, wanted in ipairs(asset:GetAllWanted()) do
    if IsValid(wanted.target) then
      bgNPC.Net.Send('bgn_module_wanted_AddWanted', ply, wanted.target, math.max(0, wanted.time_reset - CurTime()))
      bgNPC.Net.Send('bgn_module_wanted_UpdateLevel', ply, wanted.target, wanted.level)
    end
  end
end)

cvars.AddChangeCallback('bgn_enable_wanted_mode', function(_, _, newValue)
  enable_wanted_mode = tonumber(newValue) == 1
  bgNPC.Util.Log('New value for "enable_wanted_mode" - ' .. tostring(enable_wanted_mode), 'Wanted Module')
  local wanted_list = asset:GetAllWanted()
  local wanted_count = #wanted_list
  if wanted_count == 0 then return end
  for i = wanted_count, 1, -1 do
    local WantedClass = wanted_list[i]
    if WantedClass and WantedClass.target then
      asset:RemoveWanted(WantedClass.target)
      bgNPC.Util.Log('Reset wanted for - ' .. tostring(WantedClass.target), 'Wanted Module')
    end
  end
end, 'bgn_wanted_module_cvar_bgn_enable_wanted_mode')

cvars.AddChangeCallback('bgn_wanted_police_instantly', function(_, _, newValue)
  enable_wanted_police_instantly = tonumber(newValue) == 1
  bgNPC.Util.Log('New value for "enable_wanted_police_instantly" - ' .. tostring(enable_wanted_police_instantly), 'Wanted Module')
end, 'bgn_wanted_module_cvar_bgn_wanted_police_instantly')

cvars.AddChangeCallback('bgn_arrest_mode', function(_, _, newValue)
  enable_arrest_mode = tonumber(newValue) == 1
  bgNPC.Util.Log('New value for "enable_arrest_mode" - ' .. tostring(enable_arrest_mode), 'Wanted Module')
end, 'bgn_wanted_module_cvar_bgn_arrest_mode')

cvars.AddChangeCallback('bgn_wanted_impunity_limit', function(_, _, newValue)
  impunity_limit = tonumber(newValue)
  bgNPC.Util.Log('New value for "impunity_limit" - ' .. tostring(impunity_limit), 'Wanted Module')
end, 'bgn_wanted_module_cvar_bgn_wanted_impunity_limit')

cvars.AddChangeCallback('bgn_wanted_impunity_reduction_period', function(_, _, newValue)
  impunity_limit_reduction_period = tonumber(newValue)
  impunity_last_reduction_period = 0
  bgNPC.Util.Log('New value for "impunity_limit_reduction_period" - ' .. tostring(impunity_limit_reduction_period), 'Wanted Module')
  bgNPC.Util.Log('New value for "impunity_last_reduction_period" - ' .. tostring(impunity_last_reduction_period), 'Wanted Module')
end, 'bgn_wanted_module_cvar_bgn_wanted_impunity_reduction_period')

hook.Add('BGN_ConfirmedDamage', 'BGN_WantedModule_UpdateWantedTimeForAttacker', function(attacker, target)
  if asset:HasWanted(attacker) then
    asset:GetWanted(attacker):UpdateWanted()
  elseif asset:HasWanted(target) then
    asset:GetWanted(target):UpdateWanted()
  end
end)

hook.Add('BGN_OnKilledActor', 'BGN_WantedModule_UpdateWantedOnKilledActor', function(actor, attacker)
  if bgNPC.Modes.IsPeaceful() or not enable_wanted_mode or not IsValid(attacker) then return end
  local AttackerActor = bgNPC.Actors.Get(attacker)
  if AttackerActor and AttackerActor:HasTeam('residents') then return end
  if asset:HasWanted(attacker) then
    local WantedClass = asset:GetWanted(attacker)
    WantedClass:UpdateWanted()
    local kills = bgNPC.Statistics.GetSum(attacker)
    if WantedClass.next_kill_update <= kills then WantedClass:LevelUp() end
  else
    if not attacker:IsPlayer() and not AttackerActor then
      if actor:HasTeam('residents') or actor:HasTeam('police') then asset:AddWanted(attacker) end
      return
    end
    local seen, police_seen = false, false
    local actors = bgNPC.Actors.GetAll()
    for i = #actors, 1, -1 do
      local witness = actors[i]
      if witness ~= actor and witness:GetNPC() ~= attacker and bgNPC.Combat.CanWitness(witness, attacker, true) then
        seen = true
        if witness:HasTeam('police') then police_seen = true end
      end
    end
    if not seen then return end
    local current_impunity = (attacker.bgn_wanted_module_impunity or 0) + 1
    if (enable_wanted_police_instantly and actor:HasTeam('police') and police_seen) or (impunity_limit > 0 and current_impunity >= impunity_limit) then
      attacker.bgn_wanted_module_impunity = 0
      bgNPC.Statistics.Reset(attacker)
      asset:AddWanted(attacker)
    elseif impunity_limit > 0 then
      attacker.bgn_wanted_module_impunity = current_impunity
    end
  end
end)

hook.Add('BGN_AddWantedTarget', 'BGN_AddWantedTargetFromResidents', function(target)
  for _, actor in ipairs(bgNPC.Actors.GetAll()) do
    if IsValid(actor:GetNPC()) and actor:HasTeam('police') then
      actor:AddEnemy(target)
      if bgNPC.DebugInspector then bgNPC.DebugInspector.Emit(actor, 'wanted', target, nil, nil, actor:HasEnemy(target)) end
      if actor:HasEnemy(target) and (actor:HasState('idle') or actor:HasState('walk')) then actor:SetState(actor:GetReactionForProtect(target)) end
    end
  end
end)

hook.Add('BGN_RemoveWantedTarget', 'BGN_RemoveWantedTargetFromResidents', function(target)
  for _, actor in ipairs(bgNPC.Actors.GetAll()) do
    if IsValid(actor:GetNPC()) and actor:HasTeam('residents') then actor:RemoveEnemy(target) end
  end

  bgNPC.Statistics.Reset(target)
  -- bgNPC:ResetWantedKillingStatistic(target)
end)

hook.Add('BGN_InitActor', 'BGN_AddWantedTargetsForNewNPCs', function(actor)
  local wanted_list = asset:GetAllWanted()
  local wanted_count = #wanted_list
  if wanted_count == 0 then return end
  if actor:HasTeam('police') then
    for i = 1, wanted_count do
      local enemy = wanted_list[i].target
      actor:AddEnemy(enemy)
      if actor:HasEnemy(enemy) then actor:SetState('defense') end
    end
  end
end)

hook.Add('PlayerDeath', 'BGN_ResetWantedModeForDeceasedPlayer', function(victim, inflictor, attacker)
  if not IsValid(victim) then return end
  if (victim.bgn_wanted_module_impunity or 0) > 0 then victim.bgn_wanted_module_impunity = 0 end
  if not asset:HasWanted(victim) then return end
  asset:RemoveWanted(victim)
end)

local function UpdateWantedAndSetReaction(actor, enemy)
  if actor:HasTeam(enemy) then return end
  -- a wanted player given a second chance to give up (sv_surrender.lua): don't turn the arrest into a fight
  local arrest = bgNPC.Modules.Get('player_arrest')
  if arrest:IsProtected(enemy) or (actor:HasState('arrest') and arrest:CanArrest(enemy)) then return end
  local reaction
  -- Also re-evaluate for actors stuck in "fear" (e.g. were unarmed when they first
  -- reacted): "fear" belongs to the "danger" group too, so without this they would
  -- never be pushed back towards "defense"/"arrest" again for the rest of the chase.
  if not actor:EqualStateGroup('danger') or actor:HasState('fear') then
    reaction = actor:GetReactionForProtect(enemy)
    if reaction == 'arrest' and not enable_arrest_mode then reaction = 'defense' end
    actor:SetState(reaction)
  end

  if reaction == 'arrest' then
    actor:AddTarget(enemy)
  else
    actor:AddEnemy(enemy)
  end
end

timer.Create('BGN_Timer_ResetPlayersImpunityLimit', 1, 0, function()
  if impunity_limit_reduction_period == 0 then return end
  if impunity_last_reduction_period > CurTime() then return end
  impunity_last_reduction_period = CurTime() + impunity_limit_reduction_period
  local targets = player.GetHumans()
  for _, actor in ipairs(bgNPC.Actors.GetAll()) do targets[#targets + 1] = actor:GetNPC() end
  for _, ply in ipairs(targets) do
    if IsValid(ply) then
      local current_impunity = ply.bgn_wanted_module_impunity or 0
      if current_impunity > 0 then ply.bgn_wanted_module_impunity = current_impunity - 1 end
    end
  end
end)

timer.Create('BGN_Timer_CheckingTheWantesStatusOfTargets', 1, 0, function()
  if bgNPC.Modes.IsPeaceful() or not enable_wanted_mode then return end
  -- local spawn_radius = cvar_bgn_spawn_radius:GetFloat()
  local detection_radius = cvar_detection_radius:GetFloat()
  local wanted_list = asset:GetAllWanted()
  local wanted_count = #wanted_list
  if wanted_count == 0 then return end
  local residents = bgNPC.Actors.GetByTeam('residents')
  -- 600 ^ 2
  local min_distance_detect = 360000
  -- 1500 ^ 2
  -- local ray_distance_detect = 2250000
  local ray_distance_detect = detection_radius ^ 2
  for i = wanted_count, 1, -1 do
    local WantedClass = wanted_list[i]
    local enemy = WantedClass.target
    local is_update = false
    if IsValid(enemy) and not DropIfUnseen(WantedClass, enemy) then
      local wait_time = WantedClass.time_reset - CurTime()
      if wait_time < 0 then wait_time = 0 end
      WantedClass:UpdateWaitTime(wait_time)
      for _, actor in ipairs(residents) do
        if actor:IsAlive() then
          local npc = actor:GetNPC()
          local dist = npc:GetPos():DistToSqr(enemy:GetPos())
          if dist <= min_distance_detect then
            UpdateWantedAndSetReaction(actor, enemy)
            is_update = true
          elseif dist <= ray_distance_detect and bgNPC.Vision.HasLineOfSight(npc, enemy, 'wanted') then
            UpdateWantedAndSetReaction(actor, enemy)
            is_update = true
          end
        end
      end

      -- seen by the hunters: the timer stays full
      if is_update then WantedClass:UpdateWanted() end
      -- a wanted actor (not a player) escalates on its own
      local level_up_period = cvar_level_up_period:GetFloat()
      if level_up_period > 0 and not enemy:IsPlayer() then
        local now = CurTime()
        WantedClass.next_auto_level = WantedClass.next_auto_level or now + level_up_period
        if WantedClass.next_auto_level <= now then
          WantedClass.next_auto_level = now + level_up_period
          WantedClass:LevelUp()
        end
      end

      if WantedClass.time_reset < CurTime() then asset:RemoveWanted(enemy) end
    end
  end

  asset:ClearDeath()
end)

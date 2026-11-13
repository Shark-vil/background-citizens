local ASSET = {}
local arrest_targets = {}
function ASSET:AddTarget(target, policeActor)
  if not IsValid(target) or (not target:IsPlayer() and not target:IsNPC() and not target:IsNextBot()) then return false end
  if not policeActor or policeActor:HasTeam(target) or arrest_targets[target] then return false end
  local ArrestComponent = {
    warningTime = CurTime() + GetConVar('bgn_arrest_time_limit'):GetFloat(),
    notify_order_time = 0,
    notify_arrest_time = 0,
    arrest_time = 0,
    detention = false,
    holders = {}, -- the primary officer owns detention; nearby officers only stand ready
    arrested = true,
    victims = {},
    damage_count = 0,
    policeActor = policeActor,
  }

  arrest_targets[target] = ArrestComponent
  return true
end

function ASSET:UpdateArrest(target)
  local ArrestComponent = self:GetTarget(target)
  if not ArrestComponent then return end
  ArrestComponent.warningTime = CurTime() + GetConVar('bgn_arrest_time_limit'):GetFloat()
  ArrestComponent.notify_order_time = 0
  ArrestComponent.notify_arrest_time = 0
  ArrestComponent.arrest_time = 0
  ArrestComponent.detention = false
  ArrestComponent.holders = {}
  ArrestComponent.arrested = true
  ArrestComponent.victims = {}
  ArrestComponent.damage_count = 0
  ArrestComponent.close_police_pos = nil
  ArrestComponent.last_target_pos = nil
end

function ASSET:FoundPoliceInRadius(target, radius)
  radius = radius or 700
  local policeActor
  for _, actor in ipairs(bgNPC.Actors.GetInRadius(target:GetPos(), 700)) do
    if actor:IsAlive() and actor:HasTeam('police') and bgNPC.Util.CanSeeEntity(actor:GetNPC(), target) then
      if not policeActor then
        policeActor = actor
      else
        local TargetPos = target:GetPos()
        local NewActorPos = actor:GetNPC():GetPos()
        local OldActorPos = policeActor:GetNPC():GetPos()
        if NewActorPos:DistToSqr(TargetPos) < OldActorPos:DistToSqr(TargetPos) then policeActor = actor end
      end
    end
  end
  return policeActor
end

function ASSET:UpdatePolice(target)
  local ArrestComponent = self:GetTarget(target)
  if not ArrestComponent then return end
  local policeActor = ArrestComponent.policeActor
  if policeActor and policeActor:IsAlive() then return end
  ArrestComponent.policeActor = self:FoundPoliceInRadius(target)
end

function ASSET:RemoveTarget(target)
  local ArrestComponent = self:GetTarget(target)
  if not ArrestComponent then return end
  if ArrestComponent.policeActor then ArrestComponent.policeActor:RemoveTarget(target) end
  arrest_targets[target] = nil
end

function ASSET:ClearAll()
  arrest_targets = {}
end

function ASSET:HasTarget(target)
  if IsValid(target) and arrest_targets[target] then return true end
  return false
end

function ASSET:GetTarget(target)
  if not IsValid(target) then return end
  return arrest_targets[target]
end

function ASSET:GetAllTargets()
  return arrest_targets
end

-- Escalation is based on confirmed harm, refusal or escape, not every attempted hit.
-- @return boolean
function ASSET:CanArrest(target)
  local ArrestComponent = self:GetTarget(target)
  if not ArrestComponent or not ArrestComponent.arrested then return false end
  if not GetConVar('bgn_arrest_mode'):GetBool() then return false end
  if not ArrestComponent.detention and ArrestComponent.warningTime < CurTime() then return false end
  -- A second chance holds even while wanted, until a confirmed escalation condition.
  if ArrestComponent.surrender then return true end
  return not bgNPC.Modules.Get('wanted'):HasWanted(target)
end

-- A valid arrest needs an officer actually handling it; an NPC must also have surrendered.
function ASSET:IsProtected(target)
  if not self:CanArrest(target) then return false end
  local suspect = bgNPC.Actors.Get(target)
  if suspect and not suspect:HasState('arrest_surrender') then return false end
  local component = self:GetTarget(target)
  for officer in pairs(component.officers or {}) do
    if officer:IsAlive() and officer:HasState('arrest') and officer:HasTarget(target) then return true end
  end
  return false
end

local function IsLawAlly(actor)
  return actor:HasTeam('residents') or actor:HasTeam('police')
end

hook.Add('BGN_SetState', 'BGN_ArrestCeaseFire', function(police, state)
  if state ~= 'arrest' or not police:HasTeam('police') then return end
  local target = police:GetFirstTarget()
  local component = ASSET:GetTarget(target)
  if not component then return end
  component.officers = component.officers or {}
  component.officers[police] = true
  if not ASSET:IsProtected(target) then return end
  for _, actor in ipairs(bgNPC.Actors.GetAll()) do
    if actor:IsAlive() and actor:GetNPC() ~= target and IsLawAlly(actor) then
      local body = actor:GetBody()
      local aiming = body and body:GetEnemy() == target
      local arresting = actor:HasState('arrest')
      local locked = actor:IsStateLock()
      -- Removing the last enemy normally randomizes the state; keep officers on their arrest.
      if arresting then actor:StateLock(true) end
      actor:RemoveEnemy(target)
      actor:StateLock(locked)
      if aiming then actor:ClearSchedule() end
    end
  end
end)

hook.Add('BGN_AddActorEnemy', 'BGN_ArrestCeaseFire', function(actor, enemy) if IsLawAlly(actor) and ASSET:IsProtected(enemy) then return true end end)
hook.Add('EntityTakeDamage', 'BGN_ArrestCeaseFire', function(target, dmginfo)
  if not ASSET:IsProtected(target) then return end
  local attacker = bgNPC.Combat.ResolveVehicleAttacker(dmginfo:GetAttacker(), dmginfo:GetInflictor())
  local actor = bgNPC.Actors.Get(attacker)
  if actor and IsLawAlly(actor) then return true end
end)

function ASSET:NotSubjectToArrest(target)
  local ArrestComponent = self:GetTarget(target)
  if ArrestComponent then
    ArrestComponent.arrested = false
    local actor = ArrestComponent.policeActor
    if actor then
      actor:RemoveAllTargets()
      actor:AddEnemy(target)
      -- lets the state change through the arrest hold (BGN_ArrestHold)
      actor.arrest_release = true
      actor:SetState('defense')
      actor.arrest_release = nil
    end
  end
end

function ASSET:Escalate(target)
  if not GetConVar('bgn_arrest_mode'):GetBool() then return end
  local component = self:GetTarget(target)
  if not component or not component.arrested then return end
  self:NotSubjectToArrest(target)
  if GetConVar('bgn_enable_wanted_mode'):GetBool() and not bgNPC.Modes.IsPeaceful() then bgNPC.Modules.Get('wanted'):AddWanted(target) end
end

function ASSET:RecordDamage(attacker, target)
  local component = self:GetTarget(attacker)
  if not component or not component.arrested then return end
  local victim = bgNPC.Actors.Get(target) or target.BGN_ACTOR_OBJECT
  if not victim then return end
  if victim:HasTeam('police') then
    self:Escalate(attacker)
    return
  end

  if component.policeActor and bgNPC.Combat.IsAttackingEnemy(component.policeActor, target, attacker) then return end
  if bgNPC.Modules.Get('first_attacker'):IsFirstAttacker(target, attacker) then return end
  if not component.victims[victim.uid] then
    component.victims[victim.uid] = true
    component.damage_count = component.damage_count + 1
  end

  if component.damage_count > 3 or target:Health() < victim:GetMaxHealth() * .3 then self:Escalate(attacker) end
end

function ASSET:CheckCompliance(target, officer)
  if not GetConVar('bgn_arrest_mode'):GetBool() then return end
  local component = self:GetTarget(target)
  if not component or not component.arrested or component.policeActor ~= officer then return end
  local pos, police_pos = target:GetPos(), officer:GetNPC():GetPos()
  if pos:DistToSqr(police_pos) <= 250 ^ 2 then
    component.close_police_pos = police_pos
  elseif component.close_police_pos and component.last_target_pos and pos:DistToSqr(component.last_target_pos) > 0 and pos:DistToSqr(component.close_police_pos) > 250 ^ 2 then
    -- Use the last close officer position too: an officer stepping away cannot cause an escape.
    self:Escalate(target)
    return
  end

  component.last_target_pos = pos
  if not component.detention and component.warningTime < CurTime() and GetConVar('bgn_arrest_mode'):GetBool() then self:Escalate(target) end
end

local function ArrestKill(attacker, inflictor)
  attacker = bgNPC.Combat.ResolveVehicleAttacker(attacker, inflictor)
  if IsValid(attacker) then ASSET:Escalate(attacker) end
end

hook.Add('BGN_OnKilledActor', 'BGN_ArrestKill', function(_, attacker) ArrestKill(attacker) end)
hook.Add('OnNPCKilled', 'BGN_ArrestKill', function(_, attacker, inflictor) ArrestKill(attacker, inflictor) end)
hook.Add('PlayerDeath', 'BGN_ArrestKill', function(_, inflictor, attacker) ArrestKill(attacker, inflictor) end)
timer.Create('BGN_ArrestCompliance', .25, 0, function()
  local targets = {}
  for target in pairs(arrest_targets) do
    targets[#targets + 1] = target
  end

  for _, target in ipairs(targets) do
    if not IsValid(target) or target:Health() <= 0 then
      ASSET:RemoveTarget(target)
      arrest_targets[target] = nil
    else
      local component = ASSET:GetTarget(target)
      local previous = component.policeActor
      ASSET:UpdatePolice(target)
      if component.policeActor ~= previous then component.close_police_pos, component.last_target_pos = nil, nil end
      if component.policeActor then ASSET:CheckCompliance(target, component.policeActor) end
    end
  end
end)

-- An actor gives up to the officer: the same chain as the arrest state (the suspect surrenders, the officer arrests).
-- Both must be on foot, the officer steps out of its car here.
-- @return boolean false when the suspect is already an arrest target
function ASSET:Surrender(suspect, police)
  local npc = suspect:GetNPC()
  if not self:AddTarget(npc, police) then return false end
  if police:InVehicle() then police:ExitVehicle() end
  suspect:RemoveAllTargets()
  suspect:AddTarget(police:GetNPC())
  suspect:SetState('arrest_surrender', nil, true)
  police:RemoveAllTargets()
  police:AddTarget(npc)
  police:SetState('arrest', nil, true)
  return true
end

hook.Add('PlayerDeath', 'BGN_ArrestModule_ClearDataOnPlayerDeath', function(victim, inflictor, attacker) ASSET:RemoveTarget(victim) end)
hook.Add('BGN_RemoveWantedTarget', 'BGN_ArrestModule_ClearByWanted', function(target) ASSET:RemoveTarget(target) end)
hook.Add('BGN_ActorEntityChanged', 'BGN_ArrestRebind', function(_, old, ent) if arrest_targets[old] then arrest_targets[ent], arrest_targets[old] = arrest_targets[old], nil end end)
hook.Add('PostCleanupMap', 'BGN_ArrestModule_ClearPlayerOnCleanupMap', function() ASSET:ClearAll() end)
list.Set('BGN_Modules', 'player_arrest', ASSET)

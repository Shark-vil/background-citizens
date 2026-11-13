--
local ASSET = {}
local first_attackers = {}
local FORGET_TIME = 60
function ASSET:RecordDamage(attacker, target)
  if not bgNPC.Combat.IsAttacker(attacker) or not bgNPC.Combat.IsAttacker(target) or attacker == target or bgNPC.Combat.IsIgnored(attacker) then return end
  if attacker:Health() <= 0 or target:Health() <= 0 then return end
  local a, t = hook.Run('BGN_Module_FirstAttackerValidator', attacker, target)
  if IsValid(a) then attacker = a end
  if IsValid(t) then target = t end
  local attacker_actor, target_actor = bgNPC.Actors.Get(attacker), bgNPC.Actors.Get(target)
  if attacker_actor and target_actor and attacker_actor:HasTeam(target_actor) then return end
  local now = CurTime()
  for _, data in ipairs(first_attackers) do
    if (data.attacker == attacker and data.victim == target) or (data.attacker == target and data.victim == attacker) then
      data.last_damage = now
      return
    end
  end
  first_attackers[#first_attackers + 1] = {attacker = attacker, victim = target, last_damage = now, last_contact = now}
end

function ASSET:IsFirstAttacker(attacker, victim)
  for i = 1, #first_attackers do
    local data = first_attackers[i]
    if data and data.attacker == attacker and data.victim == victim then return true end
  end
  return false
end

function ASSET:ClearDeath()
  local now = CurTime()
  for i = #first_attackers, 1, -1 do
    local data = first_attackers[i]
    if not IsValid(data.attacker) or not IsValid(data.victim) or data.attacker:Health() <= 0 or data.victim:Health() <= 0 then
      table.remove(first_attackers, i)
    else
      if bgNPC.Vision.HasLineOfSight(data.attacker, data.victim, 'conflict') or bgNPC.Vision.HasLineOfSight(data.victim, data.attacker, 'conflict') then data.last_contact = now end
      if now - math.max(data.last_damage, data.last_contact) >= FORGET_TIME then table.remove(first_attackers, i) end
    end
  end
end

function ASSET:RemoveAttacker(ent)
  for i = #first_attackers, 1, -1 do
    if first_attackers[i].attacker == ent or first_attackers[i].victim == ent then table.remove(first_attackers, i) end
  end
end

function ASSET:GetData()
  return first_attackers
end

local function ConfirmDamage(target, attacker, amount, inflictor)
  if amount <= 0 or not bgNPC.Combat.IsAttacker(target) then return end
  attacker = bgNPC.Combat.ResolveVehicleAttacker(attacker, inflictor)
  if not bgNPC.Combat.IsAttacker(attacker) or attacker == target or bgNPC.Combat.IsIgnored(attacker) then return end
  local actor = bgNPC.Actors.Get(target)
  if actor and actor:HasState('brawl') and actor:GetStateData().enemy == attacker then return end
  ASSET:RecordDamage(attacker, target)
  if bgNPC.Modes.IsFriend() and (attacker:IsPlayer() or target:IsPlayer()) then return end
  bgNPC.Modules.Get('player_arrest'):RecordDamage(attacker, target)
  hook.Run('BGN_ConfirmedDamage', attacker, target, amount)
end

hook.Add('PostEntityTakeDamage', 'BGN_FoundFirstAttacker', function(target, damage, took)
  if took then ConfirmDamage(target, damage:GetAttacker(), damage:GetDamage(), damage:GetInflictor()) end
end)
hook.Add('BGN_PostVehicleDamage', 'BGN_FoundFirstAttacker', function(actor, attacker, amount) ConfirmDamage(actor:GetNPC(), attacker, amount) end)
hook.Add('BGN_ActorEntityChanged', 'BGN_FirstAttackerRebind', function(_, old, ent)
  ent.bgn_wanted_module_impunity, old.bgn_wanted_module_impunity = old.bgn_wanted_module_impunity, nil
  for _, data in ipairs(first_attackers) do
    if data.attacker == old then data.attacker = ent end
    if data.victim == old then data.victim = ent end
  end
end)
hook.Add('PostCleanupMap', 'BGN_FirstAttackerModule_ClearAttackersList', function() first_attackers = {} end)
for _, event in ipairs({'PlayerDeath', 'PlayerSilentDeath', 'OnNPCKilled', 'EntityRemoved', 'BGN_PlayerArrest', 'BGN_RemoveWantedTarget'}) do
  hook.Add(event, 'BGN_FirstAttackerReset', function(ent) ASSET:RemoveAttacker(ent) end)
end
timer.Create('BGN_ModuleTimer_FirstAttacker', 1, 0, function() ASSET:ClearDeath() end)
list.Set('BGN_Modules', 'first_attacker', ASSET)

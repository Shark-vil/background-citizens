local Combat, Actors = bgNPC.Combat, bgNPC.Actors
local suspects=setmetatable({}, {__mode="k"})
-- Rebuild the lookup on reload without discarding officers' gameplay memory.
for _,officer in ipairs(Actors.GetAll() or {}) do
  for suspect in pairs(officer.police_harm or {}) do suspects[suspect]=true end
end

-- Witness-local memory: one entry per suspect, one count per distinct allied actor.
function Combat.CanPoliceUseStunstick(officer, suspect)
  if not IsValid(suspect) then return false end
  if bgNPC.Modules.Get('wanted'):HasWanted(suspect) or suspect.bgn_has_killed or bgNPC.Statistics.GetSum(suspect)>0 then return false end
  local harm=officer.police_harm and officer.police_harm[suspect]
  return not harm or (not harm.critical and harm.count<=5)
end

function Combat.ResetPoliceThreat(suspect)
  if suspect == nil then return end
  local remembered=suspects[suspect]
  suspects[suspect]=nil
  suspect.bgn_has_killed, suspect.bgn_last_attack, suspect.bgn_wanted_module_impunity = nil, nil, nil
  bgNPC.Statistics.Reset(suspect)
  if not remembered then return end
  for _, officer in ipairs(Actors.GetAll()) do
    if officer.police_harm then officer.police_harm[suspect]=nil end
  end
end

local function WitnessedHarm(victim,attacker,amount)
  if amount<=0 or not IsValid(victim) then return end
  local allied=Actors.Get(victim) or victim.BGN_ACTOR_OBJECT
  local suspect=Combat.ResolveVehicleAttacker(attacker)
  if not allied or not IsValid(suspect) or suspect==victim or not Combat.IsAttacker(suspect) then return end
  for _,officer in ipairs(Actors.GetInRadius(victim:GetPos(),2500)) do
    if officer:IsAlive() and officer:HasTeam('police') and officer:HasTeam(allied) and not officer:HasTeam(suspect) then
      local npc=officer:GetNPC()
      if npc==victim or bgNPC.Vision.HasLineOfSight(npc,suspect,'witness') or bgNPC.Vision.HasLineOfSight(npc,victim,'witness') then
        suspects[suspect]=true
        officer.police_harm=officer.police_harm or {}
        local harm=officer.police_harm[suspect] or {victims={},count=0,critical=false}
        officer.police_harm[suspect]=harm
        if not harm.victims[allied.uid] then harm.victims[allied.uid]=true harm.count=harm.count+1 end
        if allied:GetMaxHealth()>0 and victim:Health()<=allied:GetMaxHealth()*.3 then harm.critical=true end
      end
    end
  end
end
hook.Add('PostEntityTakeDamage','BGN_PoliceWitnessedHarm',function(victim,dmg,took)
  if took then WitnessedHarm(victim,dmg:GetAttacker(),dmg:GetDamage()) end
end)
hook.Add('BGN_PostVehicleDamage','BGN_PoliceWitnessedHarm',function(actor,attacker,amount)
  WitnessedHarm(actor:GetNPC(),attacker,amount)
end)

hook.Add('PlayerDeath','BGN_PoliceThreatReset',Combat.ResetPoliceThreat)
hook.Add('PlayerSilentDeath','BGN_PoliceThreatReset',Combat.ResetPoliceThreat)
hook.Add('OnNPCKilled','BGN_PoliceThreatReset',Combat.ResetPoliceThreat)
hook.Add('EntityRemoved','BGN_PoliceThreatReset',function(ent)
  if suspects[ent] or ent.bgn_has_killed or ent.bgn_last_attack or bgNPC.Statistics.GetSum(ent)>0 then Combat.ResetPoliceThreat(ent) end
end)
hook.Add('BGN_RemoveWantedTarget','BGN_PoliceThreatReset',Combat.ResetPoliceThreat)
hook.Add('BGN_ActorEntityChanged','BGN_PoliceThreatRebind',function(_,old,npc)
  if suspects[old] then suspects[npc],suspects[old]=true,nil end
  for _,officer in ipairs(Actors.GetAll()) do
    local memory=officer.police_harm
    if memory and memory[old] then memory[npc],memory[old]=memory[old],nil end
  end
end)
hook.Add('BGN_ResetAllKillingStatistic','BGN_PoliceThreatCleanup',function()
  suspects=setmetatable({}, {__mode='k'})
  for _,officer in ipairs(Actors.GetAll()) do officer.police_harm=nil end
  for _,ent in ipairs(ents.GetAll()) do ent.bgn_has_killed,ent.bgn_last_attack=nil,nil end
end)

--
local TeamParentModule
local cvar_team_damage = GetConVar('bgn_team_damage')
hook.Add('EntityTakeDamage', 'BGN_ActorTakeDamageEvent', function(target, dmginfo)
  -- stepping out of a moving car: its own car must not run the actor over (a fast one killed the officer on exit)
  if target.bgn_exit_guard and target.bgn_exit_guard.until_time > CurTime() and dmginfo:GetAttacker() == target.bgn_exit_guard.car then return true end
  local occupant = bgNPC.Actors.Get(target)
  if occupant and occupant.vehicle_body then
    occupant:TakeVehicleDamage(dmginfo:GetDamage(), dmginfo:GetAttacker(), dmginfo:GetInflictor())
    return true
  end

  if not target:IsPlayer() and not target:IsNPC() and not target:IsNextBot() then return end
  local attacker = bgNPC.Combat.ResolveVehicleAttacker(dmginfo:GetAttacker(), dmginfo:GetInflictor())
  if not bgNPC.Combat.IsAttacker(attacker) then return end
  if bgNPC.Combat.IsIgnored(attacker) or attacker.bgNPCIgnore or attacker == target then return end
  local hit_actor = bgNPC.Actors.Get(target)
  local attacker_actor = bgNPC.Actors.Get(attacker)
  if hit_actor and attacker_actor and attacker_actor:InVehicle() and not hit_actor:InVehicle() then
    if hit_actor:HasTeam('police') then
      bgNPC.OffenderFromRamming(attacker, dmginfo, target)
    elseif hit_actor:IsCivilian() then
      bgNPC.OffenderFromRamming(attacker, dmginfo)
    end
  end

  -- the arrest state lets go only of an attacked officer
  if hit_actor and not hit_actor:HasTeam(attacker) then hit_actor.last_attacked_at, hit_actor.last_attacker = CurTime(), attacker end
  local result
  if target:IsNPC() or target:IsNextBot() then
    result = hook.Run('BGN_TakeDamageFromNPC', attacker, target, dmginfo)
  elseif target:IsPlayer() then
    result = hook.Run('BGN_TakeDamageFromPlayer', attacker, target, dmginfo)
  end

  if isbool(result) then return result end
end)

hook.Add('BGN_TakeDamageFromNPC', 'BGN_NPCDamageReaction', function(attacker, target, dmginfo)
  local ActorTarget = bgNPC.Actors.Get(target)
  local ActorAttacker = bgNPC.Actors.Get(attacker)
  TeamParentModule = TeamParentModule or bgNPC.Modules.Get('team_parent')
  -- a fist fight with this player (sv_conversation.lua): the hit lands, nobody calls the police for it
  if ActorTarget and ActorTarget:HasState('brawl') and ActorTarget:GetStateData().enemy == attacker then return end
  if ActorTarget ~= nil then
    if attacker:IsPlayer() then
      if TeamParentModule:HasParent(attacker, ActorTarget) or ActorTarget:HasTeam('player') then
        if bgNPC.cfg.EnablePlayerKilledTeamActors then return end
        return true
      end
    elseif ActorAttacker ~= nil then
      if ActorTarget:HasTeam(ActorAttacker) then
        ActorTarget:RemoveEnemy(attacker)
        ActorAttacker:RemoveEnemy(target)
        -- nil lets the damage through without a reaction
        if not cvar_team_damage:GetBool() then return true end
        return
      end
    end

    -- Stray hit: the shooter fights someone else. A civilian runs instead of answering.
    local stray = ActorAttacker ~= nil and ActorAttacker:EnemiesCount() > 0 and not ActorAttacker:HasEnemy(target)
    local reaction
    if stray and ActorTarget:IsCivilian() then
      reaction = 'fear'
      ActorTarget:StayOutOfFight()
    else
      reaction = ActorTarget:GetReactionForDamage(attacker)
    end

    ActorTarget:SetReaction(reaction)
    local hook_result = hook.Run('BGN_PreReactionTakeDamage', attacker, target, reaction, dmginfo)
    if isbool(hook_result) then return hook_result end
    reaction = ActorTarget:GetLastReaction()
    if ActorTarget:EqualStateGroup('calm') then
      if reaction == 'ignore' or reaction == 'none' then return true end
      -- if reaction == 'ignore' then return true end
      ActorTarget:RemoveAllTargets()
      ActorTarget:SetState(reaction)
    end

    ActorTarget:AddEnemy(attacker, reaction)
  end
  return hook.Run('BGN_PostReactionTakeDamage', attacker, target, reaction, dmginfo)
end)

hook.Add('BGN_TakeDamageFromPlayer', 'BGN_PlayerDamageReaction', function(attacker, target, dmginfo)
  local ActorAttacker = bgNPC.Actors.Get(attacker)
  TeamParentModule = TeamParentModule or bgNPC.Modules.Get('team_parent')
  if ActorAttacker ~= nil then
    if TeamParentModule:HasParent(target, ActorAttacker) or ActorAttacker:HasTeam('player') then return true end
    if not ActorAttacker:HasEnemy(target) then return true end
  end

  local hook_result = hook.Run('BGN_PreReactionTakeDamage', attacker, target, nil, dmginfo)
  if isbool(hook_result) then return hook_result end
  return hook.Run('BGN_PostReactionTakeDamage', attacker, target, nil, dmginfo)
end)

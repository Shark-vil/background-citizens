--
hook.Add('BGN_ConfirmedDamage', 'BGN_ActorsReactionToDamageAnotherActor', function(hit_attacker, hit_target)
  local actors = bgNPC.Actors.GetInRadius(hit_attacker:GetPos(), 2500)
  for i = 1, #actors do
    local actor = actors[i]
    -- per witness: the swap below must not leak into the next iteration
    local attacker, target = hit_attacker, hit_target
    local npc = actor:GetNPC()
    if npc == target or npc == attacker then continue end
    if not bgNPC.Combat.CanWitness(actor, attacker) then continue end
    local is_team_target = actor:HasTeam(target)
    local is_team_attacker = actor:HasTeam(attacker)
    if is_team_target and is_team_attacker then continue end
    if not is_team_target and not is_team_attacker and not actor:HasTeam('residents') and not actor:HasTeam('police') then continue end
    if not is_team_target and is_team_attacker then
      local save_attacker = attacker
      attacker = target
      target = save_attacker
    end

    local enemy = bgNPC.Combat.ResolveEnemy(actor, target, attacker)
    if not IsValid(enemy) then continue end
    -- picked after the witness check: a planning brain plans per pick
    local reaction = actor:GetReactionForProtect(enemy)
    actor:SetReaction(reaction)
    local hook_result = hook.Run('BGN_PreDamageToAnotherActor', actor, attacker, target, reaction)
    if hook_result then continue end
    reaction = actor:GetLastReaction()
    -- blocked by the fight delay (Actor:GetReactionForProtect): no enemy, busy or not, like the other callers
    if actor.protect_blocked_enemy == enemy then continue end
    if actor:EqualStateGroup('calm') then
      if reaction == 'ignore' or reaction == 'none' then continue end
      -- if reaction == 'ignore' then continue end
      actor:RemoveAllTargets()
      actor:SetState(reaction)
    end

    actor:AddEnemy(enemy, reaction)
    hook.Run('BGN_PostDamageToAnotherActor', actor, attacker, target, reaction)
  end
end)

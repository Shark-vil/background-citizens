-- Stands still with an idle animation for 10-30 seconds. Metropolice hold a stunstick meanwhile.
bgNPC.States.Register('idle', 'calm', {
  start = function(actor, state, data)
    local delay = math.random(10, 30)
    data.delay = CurTime() + delay
    if actor.carry_item then -- let the native carried-item idle keep the hands occupied
      return
    end

    if actor.class == 'npc_metropolice' then
      local suspect = actor:GetNearEnemy()
      if IsValid(suspect) and not bgNPC.Combat.CanPoliceUseStunstick(actor, suspect) then return end
      actor:GetBody():GiveWeapon('weapon_stunstick')
      actor:PlayStaticSequence('plazathreat' .. math.random(1, 2), true, delay)
    else
      actor:PlayStaticSequence('LineIdle0' .. math.random(1, 4), true, delay)
    end
  end,
  update = function(actor, state, data)
    if data.delay > CurTime() then return end
    if actor.class == 'npc_metropolice' then actor:GetBody():RemoveActiveWeapon() end
    actor:RandomState()
  end
})

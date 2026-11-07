hook.Add('BGN_StealFinish', 'BGN_DarkRp_StealMoney', function(actor, target, success)
   if not success then return end
   if engine.ActiveGamemode() ~= 'darkrp' then return end

   local moneyCount = target:getDarkRPVar('money')
   if moneyCount <= 0 then return end

   local moneySteal = math.random(10, 100)
   if moneyCount < moneySteal then moneySteal = moneyCount end

   target:addMoney(-moneySteal)

   local npc = actor:GetNPC()
   npc.bgn_moneySteal = ((npc.bgn_moneySteal or 0) + moneySteal)
end)

hook.Add('BGN_PreReactionTakeDamage', 'BGN_DarkRp_DropStealMoney', function(attacker, target)
   if engine.ActiveGamemode() ~= 'darkrp' then return end
   if not target.bgn_is_stealer then return end

   if attacker:IsNPC() then
      local actor = bgNPC.Actors.Get(attacker)
      if actor == nil or not actor:HasTeam('police') then return end
   elseif not attacker:IsPlayer() then return end

   local moneySteal = (target.bgn_moneySteal or 0)
   if moneySteal ~= 0 then
      DarkRP.createMoneyBag(target:GetPos() + target:GetUp() * 10 + target:GetForward() * 20, moneySteal)
      target.bgn_moneySteal = 0
   end
end)
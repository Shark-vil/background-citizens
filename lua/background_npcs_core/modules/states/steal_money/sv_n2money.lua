hook.Add('BGN_StealFinish', 'BGN_nMoney2_StealMoney', function(actor, target, success)
   if not success then return end

   local moneyCount = tonumber(target:GetNWString('WalletMoney', '0'))
   if moneyCount <= 0 then return end

   local moneySteal = math.random(10, 100)
   if moneyCount < moneySteal then moneySteal = moneyCount end

   target:SetNWString(tostring(moneyCount - moneySteal))

   local npc = actor:GetNPC()
   npc:slibSetVar('nMoney2Steal', npc:slibGetVar('nMoney2Steal', 0) + moneySteal)
end)

hook.Add('BGN_PreReactionTakeDamage', 'BGN_nMoney2_DropStealMoney', function(attacker, target)
   if not target:slibGetVar('is_stealer') then return end
   
   if attacker:IsNPC() then
      local actor = bgNPC:GetActor(attacker)
      if actor == nil or not actor:HasTeam('police') then return end
   elseif not attacker:IsPlayer() then return end

   local moneySteal = target:slibGetVar('nMoney2Steal', 0)
   if moneySteal ~= 0 then
      local dropped_ent = ents.Create("ent_money")
      dropped_ent:SetPos(target:GetPos() + target:GetUp() * 10 + target:GetForward() * 20)
      dropped_ent:Spawn()
      dropped_ent:SetNWString("DroppedMoneyAmount", tostring(moneySteal))
      target:slibSetVar('nMoney2Steal', 0)
   end
end)
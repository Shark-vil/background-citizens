timer.Create('BGN_Timer_BanditsAutoRegen', 1, 0, function()
   for _, actor in ipairs(bgNPC:GetAllByTeam('bandits')) do
      if actor:IsAlive() then
         local npc = actor:GetNPC()
         local max_health = npc:GetMaxHealth()
         local health = npc:Health()
         local add_health = math.random(1, 5)
         local new_health = health + add_health

         if health < max_health and new_health <= max_health then
            npc:SetHealth(new_health)
         end
      end
   end
end)
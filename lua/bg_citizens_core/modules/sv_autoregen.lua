timer.Create('BGN_Timer_BanditsAutoRegen', 5, 0, function()
   for _, actor in ipairs(bgNPC:GetAllByTeam('bandits')) do
      if actor:IsAlive() then
         local npc = actor:GetNPC()
         local max_health = npc:GetMaxHealth()
         local health = npc:Health()
         local add_health = math.random(0, 5)

         if add_health ~= 0 then
            local new_health = health + add_health

            if health < max_health and new_health <= max_health then
               npc:SetHealth(new_health)
            end
         end
      end
   end
end)
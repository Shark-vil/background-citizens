timer.Create('BGN_ZombieModeAutoEnableDefense', 1, 0, function()
   for _, zombie in ipairs(bgNPC:GetAll()) do
      if zombie:IsAlive() and zombie:GetData().zombie_mode then
         local npc = zombie:GetNPC()
         local enemies = ents.FindInSphere(npc:GetPos(), 2500)

         for _, enemy in ipairs(enemies) do
            if zombie:HasEnemy(enemy) then goto skip_enemies end
            if not enemy:IsPlayer() and not enemy:IsNPC() then goto skip_enemies end

            local actor = bgNPC:GetActor(enemy)
            if actor then 
               if actor:HasTeam(zombie) then goto skip_enemies end
               if not actor:HasEnemy(npc) then actor:AddEnemy(npc) end
               
               if actor:HasState(bgNPC.cfg.npcs_states['calmly']) then
                  local reaction = actor:GetReactionForDamage()
                  if reaction and table.HasValue(bgNPC.cfg.npcs_states['danger'], reaction) then
                     actor:SetState(reaction)
                  else
                     actor:SetState('fear')
                  end
               end
            end

            if enemy:IsNPC() and enemy:Disposition(npc) ~= D_HT then
               enemy:AddEntityRelationship(npc, D_HT, 99)
            end

            zombie:AddEnemy(enemy)

            ::skip_enemies::
         end

         if #zombie.enemies > 0 and not zombie:HasState('zombie') then
            zombie:SetState('zombie')
         end
      end
   end
end)
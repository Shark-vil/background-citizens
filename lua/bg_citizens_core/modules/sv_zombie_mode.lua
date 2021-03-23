timer.Create('BGN_ZombieModeAutoEnableDefense', 1, 0, function()
   for _, zombie in ipairs(bgNPC:GetAll()) do
      if zombie:IsAlive() and zombie:GetData().zombie_mode then
         local npc = zombie:GetNPC()
         local enemies = ents.FindInSphere(npc:GetPos(), 2500)

         for _, enemy in ipairs(enemies) do
            if (enemy:IsPlayer() or enemy:IsNPC()) and not zombie:HasTeam(enemy) then

               if npc:IsNPC() and npc:Disposition(enemy) ~= D_HT then
                  npc:AddEntityRelationship(enemy, D_HT, 99)
               end

               if enemy:IsNPC() and enemy:Disposition(npc) ~= D_HT then
                  enemy:AddEntityRelationship(npc, D_HT, 99)
               end

               local actor = bgNPC:GetActor(enemy)
               if actor then   
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

               zombie:AddEnemy(enemy)
               zombie:SetState('defense', {
                  disableWeapon = true,
                  disableMoveAway = true
               })
            end
         end
      end
   end
end)
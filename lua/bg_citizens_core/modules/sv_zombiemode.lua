hook.Add("BGN_InitActor", "BGN_ZombieModeSetEnemyFromActor", function(actor)
   timer.Simple(0.5, function()
      if not actor or not actor:IsAlive() then return end
      if not actor:GetData().zombieMode then return end

      for _, zombie in ipairs(bgNPC:GetAll()) do
         if zombie ~= actor and not actor:HasTeam(zombie) then
            actor:AddEnemy(zombie:GetNPC())
            if zombie:GetData().zombieMode then
               zombie:AddEnemy(actor:GetNPC())
            end
         end
      end
   
      for _, ply in ipairs(player.GetAll()) do
         if not actor:HasTeam(ply) then
            actor:AddEnemy(ply)
         end
      end
   end)
end)

hook.Add("PlayerSpawn", "BGN_ZombieModeSetEnemy", function(ply)
   timer.Simple(0.5, function()
      if not IsValid(ply) then return end

      for _, zombie in ipairs(bgNPC:GetAll()) do
         if zombie:GetData().zombieMode and not zombie:HasTeam(ply) then
            zombie:AddEnemy(ply)
         end
      end
   end)
end)

timer.Create('BGN_ZombieModeAutoEnableDefense', 1, 0, function()
   for _, zombie in ipairs(bgNPC:GetAll()) do
      if zombie:IsAlive() and zombie:GetData().zombieMode then
         local npc = zombie:GetNPC()
         local enemies = ents.FindInSphere(npc:GetPos(), 1000)

         for _, enemy in ipairs(enemies) do
            if zombie:HasEnemy(enemy) and bgNPC:NPCIsViewVector(npc, enemy:GetPos()) and 
               bgNPC:IsTargetRay(npc, enemy)
            then
               zombie:SetState('defense', {
                  disableWeapon = true,
                  disableMoveAway = true
               })
            end
         end
      end
   end
end)
hook.Add("BGN_ResetEnemiesForActor", "BGN_SetDefaultStateIfEnemiesDeath", function(actor)
	if not actor:IsAlive() then return end

   if not actor:GetData().wanted_level then
      local npc = actor:GetNPC()
      local wep = npc:GetActiveWeapon()
      if IsValid(wep) then
         wep:Remove()
      end
   end

   actor:RandomState()
end)

timer.Create('BGN_ActorEnemyController', 1, 0, function()
   local actors = bgNPC:GetAll()
   for i = 1, #actors do
      local actor = actors[i]
      if actor:IsAlive() then
         actor:EnemiesRecalculate()
      end
   end
end)

hook.Add('PlayerDeath', 'BGN_ActorEnemyPlayerDeathRemove', function(victim)
   bgNPC.killing_statistic[victim] = {}

   local actors = bgNPC:GetAll()
   for i = 1, #actors do
      local actor = actors[i]
      if actor:HasEnemy(victim) then actor:RemoveEnemy(victim) end
   end
end)

hook.Add('OnNPCKilled', 'BGN_ActorEnemyNPCDeathRemove', function(victim)
   local actors = bgNPC:GetAll()
   for i = 1, #actors do
      local actor = actors[i]
      if actor:HasEnemy(victim) then actor:RemoveEnemy(victim) end
   end
end)
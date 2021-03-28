hook.Add("BGN_ResetEnemiesForActor", "BGN_SetDefaultStateIfEnemiesDeath", function(actor)
	if not actor:IsAlive() then return end

	local npc = actor:GetNPC()
	local wep = npc:GetActiveWeapon()
	if IsValid(wep) then
		wep:Remove()
	end

	 actor:RandomState()
end)

timer.Create('BGN_ActorEnemyController', 1, 0, function()
   for _, actor in ipairs(bgNPC:GetAll()) do
      if actor:IsAlive() then
         actor:EnemiesRecalculate()
      end
   end
end)

hook.Add('PlayerDeath', 'BGN_ActorEnemyPlayerDeathRemove', function(victim)
   bgNPC.killing_statistic[victim] = {}

   for _, actor in ipairs(bgNPC:GetAll()) do
      if actor:HasEnemy(victim) then actor:RemoveEnemy(victim) end
   end
end)

hook.Add('OnNPCKilled', 'BGN_ActorEnemyNPCDeathRemove', function(victim)
   for _, actor in ipairs(bgNPC:GetAll()) do
      if actor:HasEnemy(victim) then actor:RemoveEnemy(victim) end
   end
end)
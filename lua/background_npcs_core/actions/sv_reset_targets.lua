-- hook.Add("PlayerDeath", "BGN_ClearingTargetsForNPCsInThePlayerDeath", function(victim, inflictor, attacker)
-- 	bgNPC.killing_statistic[victim] = {}
	
-- 	for _, actor in ipairs(bgNPC:GetAll()) do
-- 		actor:RemoveTarget(victim)
-- 	end
-- end)

-- hook.Add("BGN_ResetTargetsForActor", "BGN_SetDefaultStateIfTargetDeath", function(actor)
-- 	if not actor:IsAlive() then return end

-- 	local npc = actor:GetNPC()
-- 	local wep = npc:GetActiveWeapon()
-- 	if IsValid(wep) then
-- 		wep:Remove()
-- 	end

-- 	 actor:RandomState()
-- end)

-- timer.Create('BGN_Timer_ResetFearAndDefenseStateIfNoEnemies', 1, 0, function()
-- 	for _, actor in ipairs(bgNPC:GetAll()) do
-- 		actor:RecalculationTargets()
-- 	end
-- end)
hook.Add('BGN_ResetEnemiesForActor', 'BGN_SetDefaultStateIfEnemiesDeath', function(actor)
	if not actor:IsAlive() then return end
	actor:FoldWeapon()
	actor:RandomState()
end)

async.Add('BGN_ActorEnemyController', function(yield, wait)
	while true do
		local actors = bgNPC:GetAll()

		for i = 1, #actors do
			local actor = actors[i]

			if actor and actor:IsAlive() then
				actor:EnemiesRecalculate()
			end

			yield()
		end

		wait(1)
	end
end)

hook.Add('PlayerDeath', 'BGN_ActorEnemyPlayerDeathRemove', function(victim)
	bgNPC:ResetKillingStatistic(victim)

	local actors = bgNPC:GetAll()

	for i = 1, #actors do
		local actor = actors[i]

		if actor and actor:HasEnemy(victim) then
			actor:RemoveEnemy(victim)
		end
	end
end)

hook.Add('OnNPCKilled', 'BGN_ActorEnemyNPCDeathRemove', function(victim)
	local actors = bgNPC:GetAll()

	for i = 1, #actors do
		local actor = actors[i]

		if actor and actor:HasEnemy(victim) then
			actor:RemoveEnemy(victim)
		end
	end
end)
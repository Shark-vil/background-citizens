local function IsIndifference(percent)
	return math.random(1, 100) < percent
end

hook.Add('BGN_PostReactionTakeDamage', 'BGN_ActorsReactionToDamageAnotherActor', function(attacker, target)
	local actors = bgNPC:GetAllByRadius(target:GetPos(), 2500)
	for i = 1, #actors do
		local actor = actors[i]
		if IsIndifference(10) or (actor:HasTeam(target) and actor:HasTeam(attacker)) then
			goto skip
		end

		local reaction = actor:GetReactionForProtect()

		actor:SetReaction(reaction)

		local npc = actor:GetNPC()
		if npc == target then
			goto skip
		end

		if not bgNPC:IsTargetRay(npc, attacker) and not bgNPC:IsTargetRay(npc, target) then
			goto skip
		end

		local hook_result = hook.Run('BGN_PreDamageToAnotherActor', actor, attacker, target, reaction) 
		if hook_result then
			goto skip
		end

		if actor:InCalmlyState() then
			local last_reaction = actor:GetLastReaction()
			if last_reaction == 'ignore' then goto skip end

			actor:RemoveAllTargets()
			actor:SetState(last_reaction, nil, true)
		end

		local enemy = bgNPC:GetEnemyFromActorByTarget(actor, target, attacker)
		if enemy and IsValid(enemy) then
			actor:AddEnemy(enemy, reaction)
		end

		hook.Run('BGN_PostDamageToAnotherActor', actor, attacker, target, reaction)

		::skip::
	end
end)
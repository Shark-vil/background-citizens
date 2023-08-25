local bgNPC = bgNPC
local hook_Run = hook.Run
--

hook.Add('BGN_PostReactionTakeDamage', 'BGN_ActorsReactionToDamageAnotherActor', function(attacker, target)
	local actors = bgNPC:GetAllByRadius(target:GetPos(), 2500)
	for i = 1, #actors do
		local actor = actors[i]
		if actor:HasTeam(target) and actor:HasTeam(attacker) then continue end

		local reaction = actor:GetReactionForProtect()
		actor:SetReaction(reaction)

		local npc = actor:GetNPC()
		if npc == target then continue end
		if not bgNPC:IsTargetRay(npc, attacker) and not bgNPC:IsTargetRay(npc, target) then continue end

		local hook_result = hook_Run('BGN_PreDamageToAnotherActor', actor, attacker, target, reaction)
		if hook_result then continue end

		reaction = actor:GetLastReaction()

		if actor:EqualStateGroup('calm') then
			if reaction == 'ignore' then continue end
			actor:RemoveAllTargets()
			-- actor:SetState(reaction, nil, true)
		end

		local enemy = bgNPC:GetEnemyFromActorByTarget(actor, target, attacker)
		if enemy and IsValid(enemy) then
			actor:AddEnemy(enemy, reaction)
		end

		actor:SetState(reaction)

		hook_Run('BGN_PostDamageToAnotherActor', actor, attacker, target, reaction)
	end
end)
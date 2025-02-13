local bgNPC = bgNPC
local hook_Run = hook.Run
--
local WantedModule

hook.Add('BGN_PostReactionTakeDamage', 'BGN_ActorsReactionToDamageAnotherActor', function(attacker, target)
	local actors = bgNPC:GetAllByRadius(target:GetPos(), 2500)
	WantedModule = WantedModule or bgNPC:GetModule('wanted')
	for i = 1, #actors do
		local actor = actors[i]
		local npc = actor:GetNPC()
		if npc == target or npc == attacker then continue end
		local is_team_target = actor:HasTeam(target)
		local is_team_attacker = actor:HasTeam(attacker)
		if is_team_target and is_team_attacker then continue end
		if not is_team_target and is_team_attacker then
			local save_attacker = attacker
			attacker = target
			target = save_attacker
		end
		local actor_attacker = bgNPC:GetActor(attacker)
		if actor_attacker and not actor_attacker:HasEnemy(target) then continue end

		local reaction = actor:GetReactionForProtect()
		actor:SetReaction(reaction)

		if not WantedModule:HasWanted(attacker)
			and not bgNPC:IsTargetRay(npc, attacker)
			and not bgNPC:IsTargetRay(npc, target)
		then
			continue
		end

		local hook_result = hook.Run('BGN_PreDamageToAnotherActor', actor, attacker, target, reaction)
		if hook_result then continue end

		reaction = actor:GetLastReaction()

		if actor:EqualStateGroup('calm') then
			if reaction == 'ignore' or reaction == 'none' then continue end
			-- if reaction == 'ignore' then continue end
			actor:RemoveAllTargets()
			actor:SetState(reaction)
		end

		local enemy = bgNPC:GetEnemyFromActorByTarget(actor, target, attacker)
		if enemy and IsValid(enemy) then
			actor:AddEnemy(enemy, reaction)
		end

		hook_Run('BGN_PostDamageToAnotherActor', actor, attacker, target, reaction)
	end
end)
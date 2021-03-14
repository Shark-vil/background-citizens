hook.Add('BGN_PostReactionTakeDamage', 'BGN_ActorsReactionToDamageAnotherActor', 
function(attacker, target, dmginfo)
	for _, actor in ipairs(bgNPC:GetAllByRadius(target:GetPos(), 2500)) do
		if actor:HasTeam(target) and actor:HasTeam(attacker) then
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

		if actor:HasState(bgNPC.cfg.npcs_states['calmly']) then
			actor:RemoveAllTargets()
			actor:SetState(actor:GetLastReaction())
		end

		hook.Run('BGN_PostDamageToAnotherActor', actor, attacker, target, reaction)

		::skip::
	end
end)

hook.Add("BGN_PostDamageToAnotherActor", "BGN_AddActorsTargetByProtectOrFearActions", 
function(actor, attacker, target, reaction)
	if reaction == 'ignore' then return end
	local asset = bgNPC:GetModule('first_attacker')
	
	if target:IsNPC() then
		if attacker:IsPlayer() and actor:HasTeam(attacker) then
			actor:AddEnemy(target, reaction)
			return
		end

		local ActorTarget = bgNPC:GetActor(target)
		if ActorTarget ~= nil and actor:HasTeam(ActorTarget) then
			actor:AddEnemy(attacker, reaction)
			return
		end

		local ActorAttacker = bgNPC:GetActor(attacker)
		if ActorAttacker ~= nil and actor:HasTeam(ActorAttacker) then
			actor:AddEnemy(target, reaction)
			return
		end

		if ActorTarget ~= nil and attacker:IsPlayer() and actor:HasTeam('residents') then
			if ActorTarget:GetState() == 'impingement' or bgNPC:IsEnemyTeam(target, 'residents')
				or asset:IsFirstAttacker(target, attacker)
			then
				actor:AddEnemy(target, reaction)
			else
				actor:AddEnemy(attacker, reaction)
			end
		end
	elseif target:IsPlayer() then
		if attacker:IsPlayer() and actor:HasTeam(attacker) then
			actor:AddEnemy(target, reaction)
			return
		elseif actor:HasTeam(target) then
			actor:AddEnemy(attacker, reaction)
			return
		end

		local ActorAttacker = bgNPC:GetActor(attacker)
		if ActorAttacker ~= nil then
			if actor:HasTeam(ActorAttacker) then
				actor:AddEnemy(target, reaction)
				return
			end

			if actor:HasTeam('residents') then
				if ActorAttacker:GetState() == 'impingement' or bgNPC:IsEnemyTeam(attacker, 'residents')
					or asset:IsFirstAttacker(attacker, target)
				then
					actor:AddEnemy(attacker, reaction)
				end
			end
		elseif actor:HasTeam('residents') then
			actor:AddEnemy(attacker, reaction)
		end
	end
end)
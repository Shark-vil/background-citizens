hook.Add('BGN_PostReactionTakeDamage', 'BGN_ActorsReactionToDamageAnotherActor', 
function(attacker, target, dmginfo)
	for _, actor in ipairs(bgNPC:GetAllByRadius(target:GetPos(), 2500)) do
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
		if hook_result ~= nil then
			if isbool(hook_result) and not hook_result then
				goto skip
			end

			if isstring(hook_result) then
				reaction = hook_result
			end
		end

		local state = actor:GetState()
		if state == 'idle' or state == 'walk' or state == 'arrest' then
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
		if attacker:IsPlayer() and actor:HasTeam('player') then
			actor:AddTarget(target)
			return
		end

		local ActorTarget = bgNPC:GetActor(target)
		if ActorTarget ~= nil and actor:HasTeam(ActorTarget) then
			actor:AddTarget(attacker)
			return
		end

		local ActorAttacker = bgNPC:GetActor(attacker)
		if ActorAttacker ~= nil and actor:HasTeam(ActorAttacker) then
			actor:AddTarget(target)
			return
		end

		if ActorTarget ~= nil and attacker:IsPlayer() and actor:HasTeam('residents') then
			if ActorTarget:GetState() == 'impingement' or bgNPC:IsEnemyTeam(target, 'residents')
				or asset:IsFirstAttacker(target, attacker)
			then
				actor:AddTarget(target)
			else
				actor:AddTarget(attacker)
			end
		end
	elseif target:IsPlayer() then
		if actor:HasTeam('player') then
			actor:AddTarget(attacker)
			return
		end

		local ActorAttacker = bgNPC:GetActor(attacker)
		if ActorAttacker ~= nil then
			if actor:HasTeam(ActorAttacker) then
				actor:AddTarget(target)
				return
			end

			if actor:HasTeam('residents') then
				if ActorAttacker:GetState() == 'impingement' or bgNPC:IsEnemyTeam(attacker, 'residents')
					or asset:IsFirstAttacker(attacker, target)
				then
					actor:AddTarget(attacker)
				end
			end
		elseif actor:HasTeam('residents') then
			actor:AddTarget(attacker)
		end
	end
end)
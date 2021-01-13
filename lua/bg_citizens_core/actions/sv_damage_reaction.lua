hook.Add('BGN_PostReactionTakeDamage', 'BGN_ActorsReactionToDamageAnotherActor', function(attacker, target, dmginfo)
	local ActorTarget = bgNPC:GetActor(target)
	local ActorAttacker = bgNPC:GetActor(attacker)

	for _, actor in ipairs(bgNPC:GetAllByRadius(target:GetPos(), 2500)) do
		local reaction = actor:GetReactionForProtect()
		local targetFromActor = NULL

		if actor == ActorTarget or reaction == 'ignore' then
			goto skip
		end

		if target:IsNPC() then
			if attacker:IsPlayer() then
				if actor:GetType() == 'police' then
					if bgNPC:IsEnemyTeam(target, 'residents') or bgNPC:IsWanted(target) then
						targetFromActor = target
					else
						targetFromActor = attacker
					end
				elseif target:Disposition(attacker) ~= D_HT then
					targetFromActor = attacker
				end
			elseif attacker:IsNPC() then
				if ActorAttacker ~= nil and actor:HasTeam(ActorAttacker) then
					targetFromActor = target
				else
					targetFromActor = attacker
				end
			end
		elseif target:IsPlayer() then
			if attacker:IsNPC() and attacker:Disposition(target) == D_HT then
				if ActorAttacker ~= nil then
					if actor:HasTeam(ActorAttacker) then
						targetFromActor = target
					else
						targetFromActor = attacker
					end
				else
					targetFromActor = attacker
				end
			end
		end

		if IsValid(targetFromActor) then
			local hook_result = hook.Run('BGN_DamageToAnotherActor', actor, attacker, target, reaction)
			if hook_result ~= nil then
				if isbool(hook_result) and not hook_result then
					goto skip
				end

				if isstring(hook_result) then
					reaction = hook_result
				end
			end

			actor:AddTarget(targetFromActor)

			local state = actor:GetState()
			if state == 'idle' or state == 'walk' then
				actor:SetState(reaction)
			end
		end

		::skip::
	end
end)
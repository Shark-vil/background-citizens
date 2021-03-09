local TeamParentModule = bgNPC:GetModule('team_parent')

hook.Add('EntityTakeDamage', 'BGN_ActorTakeDamageEvent', function(target, dmginfo)
	if not target:IsPlayer() and not target:IsNPC() then return end

	local attacker = dmginfo:GetAttacker()
	if not attacker:IsPlayer() and not attacker:IsNPC() then return end
	if attacker.bgNPCIgnore or attacker == target then return end

	local ActorTarget = bgNPC:GetActor(target)
	local ActorAttacker = bgNPC:GetActor(attacker)
	local reaction

	if target:IsNPC() then
		if ActorTarget ~= nil then
			if attacker:IsPlayer() then
				if TeamParentModule:HasParent(attacker, ActorTarget) or ActorTarget:HasTeam('player') then
					if bgNPC.cfg.EnablePlayerKilledTeamActors then return end
					return true
				end
			elseif attacker:IsNPC() and ActorAttacker ~= nil then
				if ActorTarget:HasTeam(ActorAttacker) then
					ActorTarget:RemoveTarget(attacker)
					ActorAttacker:RemoveTarget(target)
					return true
				end
			end

			reaction = ActorTarget:GetReactionForDamage()
			
			ActorTarget:SetReaction(reaction)

			local hook_result = hook.Run('BGN_PreReactionTakeDamage', attacker, target, dmginfo, reaction)
			if isbool(hook_result) then
				return hook_result
			end

			if ActorTarget:HasState(bgNPC.cfg.npcs_states['calmly']) then
				ActorTarget:RemoveAllTargets()
				ActorTarget:SetState(ActorTarget:GetLastReaction())
			end

			ActorTarget:AddTarget(attacker)
		end

		hook.Run('BGN_PostReactionTakeDamage', attacker, target, dmginfo, reaction)
	elseif target:IsPlayer() then
		if ActorAttacker ~= nil then
			if TeamParentModule:HasParent(target, ActorAttacker) or ActorAttacker:HasTeam('player') then
				return true
			end

			if not ActorAttacker:HasTarget(target) then
				return
			end
		end

		local hook_result = hook.Run('BGN_PreReactionTakeDamage', attacker, target, dmginfo)
		if isbool(hook_result) then
			return hook_result
		end

		hook.Run('BGN_PostReactionTakeDamage', attacker, target, dmginfo)
	end
end)
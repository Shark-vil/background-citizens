local bgNPC = bgNPC
local hook = hook
local CurTime = CurTime
local isbool = isbool
--
local TeamParentModule = bgNPC:GetModule('team_parent')

hook.Add('EntityTakeDamage', 'BGN_ActorTakeDamageEvent', function(target, dmginfo)
	target.__BGN_DelayTakeDamageTime = target.__BGN_DelayTakeDamageTime or 0

	if target.__BGN_DelayTakeDamageTime > CurTime() then return end
	target.__BGN_DelayTakeDamageTime = CurTime() + 1

	if not target:IsPlayer() and not target:IsNPC() and not target:IsNextBot() then return end

	local attacker = dmginfo:GetAttacker()
	if not attacker:IsPlayer() and not attacker:IsNPC() and not attacker:IsNextBot() then return end
	if attacker.bgNPCIgnore or attacker == target then return end

	local result

	if target:IsNPC() or target:IsNextBot() then
		result = hook.Run('BGN_TakeDamageFromNPC', attacker, target)
	elseif target:IsPlayer() then
		result = hook.Run('BGN_TakeDamageFromPlayer', attacker, target)
	end

	if isbool(result) then return result end
end)

hook.Add('BGN_TakeDamageFromNPC', 'BGN_NPCDamageReaction', function(attacker, target)
	local ActorTarget = bgNPC:GetActor(target)
	local ActorAttacker = bgNPC:GetActor(attacker)

	if ActorTarget ~= nil then
		if attacker:IsPlayer() then
			if TeamParentModule:HasParent(attacker, ActorTarget) or ActorTarget:HasTeam('player') then
				if bgNPC.cfg.EnablePlayerKilledTeamActors then return end
				return true
			end
		elseif ActorAttacker ~= nil and attacker:IsNPC() then
			if ActorTarget:HasTeam(ActorAttacker) then
				ActorTarget:RemoveEnemy(attacker)
				ActorAttacker:RemoveEnemy(target)
				return true
			end
		end

		local reaction = ActorTarget:GetReactionForDamage()
		ActorTarget:SetReaction(reaction)

		local hook_result = hook.Run('BGN_PreReactionTakeDamage', attacker, target, reaction)
		if isbool(hook_result) then
			return hook_result
		end

		reaction = ActorTarget:GetLastReaction()

		if ActorTarget:EqualStateGroup('calm') then
			if reaction == 'ignore' then return end
			ActorTarget:RemoveAllTargets()
			ActorTarget:SetState(reaction, nil, true)
		end

		ActorTarget:AddEnemy(attacker, reaction)
	end

	hook.Run('BGN_PostReactionTakeDamage', attacker, target, reaction)
end)

hook.Add('BGN_TakeDamageFromPlayer', 'BGN_PlayerDamageReaction', function(attacker, target)
	local ActorAttacker = bgNPC:GetActor(attacker)
	if ActorAttacker ~= nil then
		if TeamParentModule:HasParent(target, ActorAttacker) or ActorAttacker:HasTeam('player') then
			return true
		end

		if not ActorAttacker:HasEnemy(target) then
			return
		end
	end

	local hook_result = hook.Run('BGN_PreReactionTakeDamage', attacker, target)
	if isbool(hook_result) then
		return hook_result
	end

	hook.Run('BGN_PostReactionTakeDamage', attacker, target)
end)
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
	if not target:IsNPC() and not target:IsNextBot() and not target:IsPlayer() then return end
	if actor:HasTeam(attacker) and actor:HasTeam(target) then return end

	local asset = bgNPC:GetModule('first_attacker')

	if actor:HasTeam(attacker) then
		actor:AddEnemy(target, reaction)
	elseif actor:HasTeam(target) and bgNPC:IsEnemyTeam(attacker, actor:GetData().team) then
		actor:AddEnemy(attacker, reaction)
	elseif asset:IsFirstAttacker(target, attacker) then
		actor:AddEnemy(target, reaction)
	else
		if attacker:IsPlayer() then
			if target:IsNextBot() or (target:IsNPC() and target:Disposition(attacker) == D_HT) then
				actor:AddEnemy(target, reaction)
			else
				actor:AddEnemy(attacker, reaction)
			end
		else
			actor:AddEnemy(attacker, reaction)
		end
	end
end)
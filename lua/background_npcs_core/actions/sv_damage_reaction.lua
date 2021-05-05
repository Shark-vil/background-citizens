hook.Add('BGN_PostReactionTakeDamage', 'BGN_ActorsReactionToDamageAnotherActor', 
function(attacker, target)
	local actors = bgNPC:GetAllByRadius(target:GetPos(), 2500)
	for i = 1, #actors do
		local actor = actors[i]
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

	local asset = bgNPC:GetModule('first_attacker')
	
	if actor:HasTeam(attacker) then
		actor:AddEnemy(target, reaction)
		return
	end

	if not bgNPC:GetActor(target) then
		if target:IsNPC() and attacker:IsPlayer() and target:Disposition(attacker) ~= D_HT then
			actor:AddEnemy(attacker, reaction)
			return
		end
	end

	local AttackerActor = bgNPC:GetActor(attacker)

	if asset:IsFirstAttacker(target, attacker) or bgNPC:IsEnemyTeam(actor, target) then
		actor:AddEnemy(target, reaction)
	elseif AttackerActor and bgNPC:IsEnemyTeam(AttackerActor, target) then
		actor:AddEnemy(target, reaction)
	else
		actor:AddEnemy(attacker, reaction)
	end
end)
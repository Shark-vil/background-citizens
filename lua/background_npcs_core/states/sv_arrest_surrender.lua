local ArrestModule = bgNPC:GetModule('player_arrest')

bgNPC:SetStateAction('arrest_surrender', 'danger', {
	pre_start = function(actor)
		local npc = actor:GetNPC()
		if IsValid(npc) and not ArrestModule:HasTarget(npc) then
			local target = actor:GetFirstTarget()
			if IsValid(target) then
				actor:AddEnemy(target)
				actor:RemoveTarget(target)
			end
			return 'defense'
		end
	end,
	start = function(actor, state, data)
		data.check_target_time = CurTime() + 2

		for _, police in ipairs(bgNPC:GetAll()) do
			if police and police:IsAlive() and police:HasTeam('police') then
				police:RemoveEnemy(actor.npc)
			end
		end
	end,
	update = function(actor, state, data)
		if not actor:IsAnimationPlayed() then
			actor:PlayStaticSequence('Fear_Reaction', true)
		end

		local target = actor:GetFirstTarget()
		if IsValid(target) then
			if data.check_target_time < CurTime() then
				local TargetActor = bgNPC:GetActor(target)
				if not TargetActor or not TargetActor:HasState('arrest') then
					actor:RemoveTarget(target)
				end
				data.check_target_time = CurTime() + 2
			end
		else
			actor:RemoveTarget(target)
		end
	end,
	not_stop = function(actor, state, data, new_state, new_data)
		return actor:TargetsCount() > 0
	end
})
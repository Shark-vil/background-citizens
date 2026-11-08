local ArrestModule = bgNPC.Modules.Get('player_arrest')

bgNPC.States.Register('arrest_surrender', 'danger', {
	pre_start = function(actor)
		local npc = actor:GetNPC()
		if IsValid(npc) and not ArrestModule:HasTarget(npc) then
			local target = actor:GetFirstTarget()
			if IsValid(target) then
				actor:GetBody():SetDisposition(target, D_FR)
				actor:AddEnemy(target)
				actor:RemoveTarget(target)
			end
			return 'retreat'
		end
	end,
	start = function(actor, state, data)
		data.check_target_time = CurTime() + 2
		data.arrest_limit_time = CurTime() + 30

		for _, police in ipairs(bgNPC.Actors.GetAll()) do
			if police and police:IsAlive() and police:HasTeam('police') then
				police:RemoveEnemy(actor.npc)
			end
		end
	end,
	update = function(actor, state, data)
		if actor:HasNoTargets() then
			actor:RandomState()
			return
		end

		if not actor:IsAnimationPlayed() then
			actor:PlayStaticSequence('Fear_Reaction', true)
		end

		local target = actor:GetFirstTarget()
		if not IsValid(target) then
			actor:RemoveTarget(target)
		elseif actor:CheckMoveUpdate('state_arrest_surrender', 2) then -- false between checks: the target stays
			local TargetActor = bgNPC.Actors.Get(target)
			if not TargetActor or not TargetActor:HasState('arrest') or data.arrest_limit_time < CurTime() then
				actor:RemoveTarget(target)
				actor:AddEnemy(target)
				actor:SetState('retreat')
			end
		end
	end
})
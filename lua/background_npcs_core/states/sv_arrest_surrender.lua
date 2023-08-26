local ArrestModule = bgNPC:GetModule('player_arrest')

bgNPC:SetStateAction('arrest_surrender', 'danger', {
	pre_start = function(actor)
		local npc = actor:GetNPC()
		if IsValid(npc) and not ArrestModule:HasTarget(npc) then
			local target = actor:GetFirstTarget()
			if IsValid(target) then
				npc:AddEntityRelationship(target, D_FR, 50)
				actor:AddEnemy(target)
				actor:RemoveTarget(target)
			end
			return 'retreat'
		end
	end,
	start = function(actor, state, data)
		data.check_target_time = CurTime() + 2
		data.arrest_limit_time = CurTime() + 30

		for _, police in ipairs(bgNPC:GetAll()) do
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
		local npc = actor:GetNPC()
		if IsValid(target) and IsValid(npc) then
			if data.check_target_time < CurTime() then
				local TargetActor = bgNPC:GetActor(target)
				if not TargetActor or not TargetActor:HasState('arrest') or data.arrest_limit_time < CurTime() then
					actor:RemoveTarget(target)
					actor:AddEnemy(target)
					actor:SetState('retreat')
				end
				data.check_target_time = CurTime() + 2
			end
		else
			actor:RemoveTarget(target)
		end
	end
})
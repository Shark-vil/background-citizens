bgNPC:SetStateAction('fear', 'danger', {
	start = function(actor)
		local enemy = actor:GetNearEnemy()
		if not IsValid(enemy) then return end

		local npc = actor:GetNPC()
		local dist = enemy:GetPos():DistToSqr(npc:GetPos())
		if dist <= 490000 and math.random(0, 10) > 5 then
			actor:FearScream()
		end

		actor:WalkToPos(nil)
	end,
	update = function(actor)
		local enemy = actor:GetNearEnemy()
		if not IsValid(enemy) or enemy:Health() <= 0 then return end

		local npc = actor:GetNPC()
		local data = actor:GetStateData()
		data.call_for_help = data.call_for_help or CurTime() + math.random(25, 40)

		local dist = npc:GetPos():DistToSqr(enemy:GetPos())
		if dist < 40000 then -- 200 ^ 2
			if data.call_for_help < CurTime() and math.random(0, 100) <= 2 then
				actor:CallForHelp(enemy)
				data.call_for_help = CurTime() + math.random(25, 40)
			end
		else
			actor:SetState('run_from_danger', {
				dyspnea_delay = CurTime() + math.random(10, 20)
			})
		end
	end,
	not_stop = function(actor, state, data, new_state, new_data)
		return actor:EnemiesCount() > 0 and not actor:HasStateGroup(new_state, 'danger')
	end
})

timer.Create('BGN_Timer_FearStateAnimationController', 0.3, 0, function()
	for _, actor in ipairs(bgNPC:GetAllByState('fear')) do
		if actor:IsAlive() then
			local data = actor:GetStateData()
			data.animation_type = data.animation_type or 0
			data.update_animation = data.update_animation or 0

			if data.update_animation < CurTime() then
				data.update_animation = CurTime() + 2
				data.animation_type = math.random(0, 100)
			end

			local animation_twitching = math.random(0, 100)

			if data.animation_type > 30 then
				if animation_twitching >= 10 then
					actor:PlayStaticSequence('Fear_Reaction_Idle', true)
				else
					actor:PlayStaticSequence('Fear_Reaction', true)
				end
			else
				if animation_twitching >= 10 then
					actor:PlayStaticSequence('cower_Idle', true)
				else
					actor:PlayStaticSequence('cower', true)
				end
			end
		end
	end
end)
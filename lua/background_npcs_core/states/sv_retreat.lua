local asset = bgNPC:GetModule('wanted')

bgNPC:SetStateAction('retreat', 'danger', {
	update = function(actor)
		local npc = actor:GetNPC()
		local data = actor:GetStateData()
		data.delay = data.delay or 0
		data.update_point_delay = data.update_point_delay or CurTime() + 5
		data.cooldown = data.cooldown or CurTime() + 20
		local enemy = actor:GetNearEnemy()

		if IsValid(enemy) and bgNPC:IsTargetRay(npc, enemy) then
			data.cooldown = CurTime() + 20
		end

		if not asset:HasWanted(npc) and data.cooldown < CurTime() then
			actor:RandomState()
			return
		end

		if data.update_point_delay < CurTime() then
			local position

			if IsValid(enemy) then
				local dist = enemy:GetPos():DistToSqr(npc:GetPos())
				if dist <= 36000 and actor.weapon then
					actor:SetState('defense')
					return
				end

				position = actor:GetDistantPointToPoint(enemy:GetPos(), 1000)
			else
				position = actor:GetDistantPointInRadius(1000)
			end

			if position then
				actor:WalkToPos(position, 'run')
				data.update_point_delay = CurTime() + 5
			end
		end
	end,
	not_stop = function(actor, state, data, new_state, new_data)
		return actor:EnemiesCount() > 0 and not actor:HasStateGroup(new_state, 'danger')
	end
})
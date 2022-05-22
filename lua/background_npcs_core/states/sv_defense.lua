bgNPC:SetStateAction('defense', 'danger', {
	pre_start = function(actor)
		if not actor.weapon then return 'fear' end
	end,
	start = function(actor)
		if actor:HasTeam('police') then
			local enemy = actor:GetNearEnemy()
			local npc = actor:GetNPC()
			if IsValid(enemy) and enemy:GetPos():DistToSqr(npc:GetPos()) < 250000 then
				npc:EmitSound('npc/metropolice/vo/defender.wav', 300, 100, 1, CHAN_AUTO)
			end
		end
	end,
	update = function(actor)
		local enemy = actor:GetNearEnemy()
		if not IsValid(enemy) then return end

		local npc = actor:GetNPC()
		local data = actor:GetStateData()

		data.delay = data.delay or 0

		if data.delay < CurTime() then
			if not data.disableWeapon then actor:PrepareWeapon() end

			local current_distance = npc:GetPos():DistToSqr(enemy:GetPos())
			if current_distance > 490000 then
				if enemy:IsPlayer() and enemy:InVehicle() then
					actor:WalkToTarget(enemy:GetVehicle(), 'run')
				else
					actor:WalkToTarget(enemy, 'run')
				end
			else
				local node

				if not actor:IsMeleeWeapon() and current_distance < 202500 and bgNPC:IsTargetRay(npc, enemy) then
					node = bgNPC:GetDistantPointInRadius(npc:GetPos() + npc:GetForward() * -1000, 500)
					if node then
						actor:WalkToTarget()
						actor:WalkToPos(node:GetPos(), 'run')
					end
				end

				if not node then
					actor:WalkToTarget(enemy, 'run')
					if slib.chance(50) then npc:SetSchedule(SCHED_MOVE_AWAY_FROM_ENEMY) end
				end
			end

			data.delay = CurTime() + 3
		end
	end,
	not_stop = function(actor, state, data, new_state, new_data)
		return actor:EnemiesCount() > 0 and not actor:HasStateGroup(new_state, 'danger')
	end
})
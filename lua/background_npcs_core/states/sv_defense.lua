local WantedModule = bgNPC:GetModule('wanted')

bgNPC:SetStateAction('defense', {
	pre_start = function(actor)
		if not actor.weapon then return 'fear' end
	end,
	state = function(actor)
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

		if data.delay < CurTime() or enemy:IsNPC() or enemy:IsPlayer() then
			local killingSumm = bgNPC:GetKillingStatisticSumm(enemy)

			if not data.disableWeapon then
				data.notGun = data.notGun or true
				data.notGunDelay = data.notGunDelay or CurTime() + 15

				local EnemyActor = bgNPC:GetActor(enemy)
				if EnemyActor and EnemyActor:HasTeam('zombie') then
					data.notGun = false
				end

				if data.notGun then
					if data.notGunDelay < CurTime() or killingSumm > 0 or enemy:IsNextBot()
						or (enemy:IsNPC() and IsValid(enemy:GetActiveWeapon()))
					then
						data.notGun = false
					end
				end

				if data.notGun and actor:HasTeam('police') and not WantedModule:HasWanted(enemy) then
					if enemy:GetPos():DistToSqr(npc:GetPos()) <= 160000 then
						actor:PrepareWeapon('weapon_stunstick', true)
					else
						actor:PrepareWeapon()
					end
				else
					actor:PrepareWeapon()
				end
			end

			local current_distance = npc:GetPos():DistToSqr(enemy:GetPos())

			if current_distance <= 90000 and bgNPC:IsTargetRay(npc, enemy) then
				if actor:IsMeleeWeapon() then
					actor:WalkToTarget(enemy, 'run')
				else
					if current_distance <= 22500 then
						local node = actor:GetDistantPointInRadius(1000)
						if node then
							actor:WalkToPos(node:GetPos(), 'run')
						else
							actor:WalkToTarget()
							npc:SetSchedule(SCHED_MOVE_AWAY_FROM_ENEMY)
						end
					end
				end
			else
				if enemy:IsPlayer() and enemy:InVehicle() then
					actor:WalkToTarget(enemy:GetVehicle(), 'run')
				else
					actor:WalkToTarget(enemy, 'run')
				end
			end

			data.delay = CurTime() + 3
		end
	end,
	not_stop = function(actor, state, data, new_state, new_data)
		return actor:EnemiesCount() > 0 and not actor:HasDangerState(new_state)
	end
})
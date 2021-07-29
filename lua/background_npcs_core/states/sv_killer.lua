local MeleeWeapon = { 'weapon_crowbar', 'weapon_stunstick' }

bgNPC:SetStateAction('killer', {
	start = function(actor)
		if actor.eternal then
			actor:GetData().not_eternal = true
			return
		end
		actor.eternal = true
	end,
	stop = function(actor)
		if actor:GetOldStateData().not_eternal then return end
		actor.eternal = false
	end,
	update = function(actor)
		local enemy = actor:GetEnemy()
		if not IsValid(enemy) or enemy:Health() <= 0 then
			actor:SetState('retreat')
			return
		end
		
		local npc = actor:GetNPC()
		npc:SetHealth(100)
		local data = actor:GetStateData()

		data.delay = data.delay or 0
		data.isAttack = data.isAttack or false
		data.runDelay = data.runDelay or -1

		if enemy:IsPlayer() and enemy:InVehicle() then
			enemy = enemy:GetVehicle()
		end

		local current_distance = npc:GetPos():DistToSqr(enemy:GetPos())

		if data.delay < CurTime() then
			if not data.isAttack then
				if current_distance >= 250000 then
					if data.runDelay == -1 then
						if math.random(0, 100) <= 10 then
							data.runDelay = CurTime() + math.random(10, 30)
						end

						actor:WalkToTarget(enemy)
					else
						if data.runDelay < CurTime() then
							data.runDelay = -1
						else
							actor:WalkToTarget(enemy, 'run')
						end
					end
				else
					data.isAttack = true
				end
			else
				if current_distance <= 90000 and bgNPC:IsTargetRay(npc, enemy) then
					bgNPC:SetActorWeapon(actor)
		
					local isMeleeWeapon = false
					local npcWeapon = npc:GetActiveWeapon()
					if IsValid(npcWeapon) then
						isMeleeWeapon = table.HasValueBySeq(MeleeWeapon, npcWeapon:GetClass())
					end
		
					if isMeleeWeapon then
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
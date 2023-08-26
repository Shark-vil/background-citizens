local Vector = Vector
local math_random = math.random
local IsValid = IsValid
local CurTime = CurTime
--

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
		local enemy = bgNPC:GetTacticalGroupGetNearEnemy(actor)

		if not IsValid(enemy) then enemy = actor:GetNearEnemy() end
		if not IsValid(enemy) then
			if actor:HasNoEnemies() then actor:RandomState() end
			return
		end

		local npc = actor:GetNPC()
		local npc_pos = npc:GetPos()
		local enemy_pos = enemy:GetPos()
		local data = actor:GetStateData()

		data.delay = data.delay or 0

		if data.delay < CurTime() then
			if not data.disableWeapon then actor:PrepareWeapon() end

			local current_distance = npc_pos:DistToSqr(enemy_pos)
			if current_distance > 490000 then
				if enemy:IsPlayer() and enemy:InVehicle() then
					actor:WalkToTarget(enemy:GetVehicle(), 'run')
				else
					actor:WalkToTarget(enemy, 'run')
				end
			else
				local node
				local is_melee_weapon = actor:IsMeleeWeapon()

				if not is_melee_weapon and current_distance < 250000 and bgNPC:IsTargetRay(npc, enemy) then
					node = bgNPC:GetDistantPointInRadius(npc_pos + npc:GetForward() * -500, 500)
					actor:WalkToTarget()
					if node then
						actor:WalkToPos(node:GetPos(), 'run')
					else
						local fallback_enemy_position = enemy_pos + enemy:GetForward() * -200
						local fallback_position = npc_pos + npc:GetForward() * -200

						fallback_enemy_position = fallback_enemy_position + Vector(math_random(0, 200), math_random(0, 200), 0)
						fallback_position = fallback_position + Vector(math_random(0, 200), math_random(0, 200), 0)

						if enemy_pos:DistToSqr(fallback_enemy_position) > enemy_pos:DistToSqr(fallback_position) then
							actor:WalkToPos(fallback_enemy_position, 'run')
						else
							actor:WalkToPos(fallback_position, 'run')
						end
					end
				end

				if #actor.walkPath == 0 and not is_melee_weapon then
					npc:SetSchedule(SCHED_MOVE_AWAY_FROM_ENEMY)
				end
			end

			data.delay = CurTime() + 3
		end
	end
})
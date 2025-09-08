local IsValid = IsValid
local CurTime = CurTime
local math_random = math.random
local Vector = Vector
--

bgNPC:SetStateAction('run_from_danger', 'danger', {
	update = function(actor)
		if actor:HasNoEnemies() then
			actor:RandomState()
			return
		end

		local data = actor:GetStateData()
		local enemy = actor:GetNearEnemy()
		data.call_for_help = data.call_for_help or CurTime() + math_random(20, 30)
		if not IsValid(enemy) or enemy:Health() <= 0 then return end
		if not data.skip_update_delay and not actor:CheckMoveUpdate('state_run_from_danger', 5) then return end
		data.skip_update_delay = false
		local npc = actor:GetNPC()
		local npc_pos = npc:GetPos()
		local enemy_pos = enemy:GetPos()
		local dist = npc_pos:DistToSqr(enemy_pos)
		if data.call_for_help < CurTime() then
			actor:CallForHelp(enemy)
			data.call_for_help = CurTime() + math_random(20, 30)
		end

		if dist > 1000000 and (not data.dyspnea_delay or data.dyspnea_delay < CurTime()) then
			actor:SetState('dyspnea_danger')
		elseif dist < 40000 and (enemy:IsPlayer() or slib.chance(10)) and enemy:slibIsViewVector(npc_pos) then
			actor:SetState('fear')
		else
			local min, max = 1000, 2000
			local position = actor:GetDistantPointToPoint(enemy_pos, math_random(min, max))
			if position then
				actor:WalkToPos(position, 'run')
			elseif #actor.walkPath == 0 then
				min, max = 500, 1000
				for i = 1, 5 do
					position = npc_pos + Vector(math_random(min, max), math_random(min, max), 0)
					if position:DistToSqr(enemy_pos) > dist then
						actor:WalkToPos(position, 'run')
						if #actor.walkPath ~= 0 then break end
					end
				end
			end
		end
	end,
	not_stop = function(actor, state, data, new_state, new_data)
		return actor:EnemiesCount() > 0 and not actor:HasStateGroup(new_state, 'danger')
	end
})
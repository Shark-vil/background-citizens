bgNPC:SetStateAction('zombie', 'danger', {
	update = function(actor)
		local enemy = actor:GetNearEnemy()
		if not IsValid(enemy) then return end

		local npc = actor:GetNPC()
		local data = actor:GetStateData()

		data.delay = data.delay or 0

		if enemy:IsPlayer() and enemy:InVehicle() then
			enemy = enemy:GetVehicle()
		end

		if data.delay < CurTime() then
			if npc:GetPos():DistToSqr(enemy:GetPos()) > 160000 then
				actor:WalkToTarget(enemy, 'run')
			end
			data.delay = CurTime() + 3
		end
	end,
	not_stop = function(actor, state, data, new_state, new_data)
		return actor:EnemiesCount() > 0 and not actor:HasStateGroup(new_state, 'danger')
	end
})
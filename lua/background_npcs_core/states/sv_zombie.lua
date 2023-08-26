hook.Add('BGN_OnValidSpawnActor', 'BGN_ZombieSpawnLocation', function(npc_type, _, _, desiredPosition)
	if npc_type ~= 'zombie' then return end

	local humans_count_on_range = 0

	for _, actor in ipairs(bgNPC:GetAll()) do
		if not actor or not actor:IsAlive() then continue end

		local npc = actor:GetNPC()
		if npc:GetPos():DistToSqr(desiredPosition) > 250000 then continue end
		humans_count_on_range = humans_count_on_range + 1
		if humans_count_on_range == 5 then return true end
	end

	for _, ply in ipairs(player.GetAll()) do
		if not ply:Alive() or ply:GetPos():DistToSqr(desiredPosition) > 250000 then continue end
		humans_count_on_range = humans_count_on_range + 1
		if humans_count_on_range == 5 then return true end
	end
end)

bgNPC:SetStateAction('zombie', 'danger', {
	update = function(actor)
		local enemy = actor:GetNearEnemy()
		if not IsValid(enemy) then
			actor:RandomState()
			return
		end

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
	end
})
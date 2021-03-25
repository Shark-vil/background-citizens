local MeleeWeapon = { 'weapon_crowbar', 'weapon_stunstick' }

bgNPC:SetStateAction('killer', function(actor)
	local enemy = actor:GetEnemy()
	if not IsValid(enemy) or enemy:Health() <= 0 then
      actor:SetState('retreat')
      return
   end
	
	local npc = actor:GetNPC()
	local data = actor:GetStateData()

	data.delay = data.delay or 0

	if enemy:IsPlayer() and enemy:InVehicle() then
		enemy = enemy:GetVehicle()
	end

	if data.delay < CurTime() then
		bgNPC:SetActorWeapon(actor)

		local current_distance = npc:GetPos():DistToSqr(enemy:GetPos())

		if current_distance <= 90000 and not bgNPC:IsTargetRay(npc, enemy) then
			local isMeleeWeapon = false
			local npcWeapon = npc:GetActiveWeapon()
			if IsValid(npcWeapon) then
				isMeleeWeapon = table.HasValue(MeleeWeapon, npcWeapon:GetClass())
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

		data.delay = CurTime() + 3
	end
end)
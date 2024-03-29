hook.Add('BGN_SetState', 'BGN_SetImpingementState', function(actor, state)
	if state ~= 'impingement' or not actor:IsAlive() then return end

	local npc = actor:GetNPC()

	local target_from_zone = ents.FindInSphere(npc:GetPos(), 500)
	local targets = {}

	for _, ent in pairs(target_from_zone) do
		if bgNPC:IsTargetRay(npc, ent) then
			if ent:IsPlayer() then
				table.insert(targets, ent)
			end

			if ent:IsNPC() and ent ~= npc then
				local ActorTarget = bgNPC:GetActor(ent)
				if ActorTarget ~= nil and not actor:HasTeam(ActorTarget) then
					table.insert(targets, ent)
				end
			end
		end
	end

	local target = table.RandomBySeq(targets)
	if IsValid(target) then
		actor:AddEnemy(target)
	else
		actor:RandomState()
	end
end)

bgNPC:SetStateAction('impingement', 'assault', {
	update = function(actor)
		local enemy = actor:GetNearEnemy()
		if not IsValid(enemy) then
			actor:RandomState()
			return
		end

		local npc = actor:GetNPC()
		local data = actor:GetStateData()

		data.delay = data.delay or 0

		if data.delay < CurTime() then
			actor:PrepareWeapon()

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
				actor:WalkToTarget(enemy, 'run')
			end

			data.delay = CurTime() + 5
		end
	end
})
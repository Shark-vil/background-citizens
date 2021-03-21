hook.Add("BGN_SetNPCState", "BGN_SetImpingementState", function(actor, state)
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

	local target = table.Random(targets)
	if IsValid(target) then
		actor:AddEnemy(target)
	else
		actor:RandomState()
	end
end)

local asset = bgNPC:GetModule('wanted')
hook.Add("PreRandomState", "BGN_ChangeImpingementToRetreat", function(actor)
	if (asset:HasWanted(actor:GetNPC()) or actor:HasState('impingement')) and actor:TargetsCount() == 0 then
		actor:SetState('retreat')
		return true
	end
end)

bgNPC:SetStateAction('impingement', function(actor)
	local enemy = actor:GetEnemy()
	if not IsValid(enemy) then return end
	
	local npc = actor:GetNPC()
	local data = actor:GetStateData()

	data.delay = data.delay or 0

	if enemy:IsPlayer() and enemy:InVehicle() then
		enemy = enemy:GetVehicle()
	end

	if data.delay < CurTime() then
		bgNPC:SetActorWeapon(actor)

		local current_distance = npc:GetPos():DistToSqr(enemy:GetPos())

		if current_distance <= 62500 then
			actor:WalkToTarget()
			npc:SetSchedule(SCHED_MOVE_AWAY_FROM_ENEMY)
		else
			actor:WalkToTarget(enemy, 'run')
		end

		data.delay = CurTime() + 3
	end
end)
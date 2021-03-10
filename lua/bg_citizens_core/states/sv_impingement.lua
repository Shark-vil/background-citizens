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
		actor:AddTarget(target)
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
	local target = actor:GetNearTarget()
	if not IsValid(target) then return end
	
	local npc = actor:GetNPC()
	local data = actor:GetStateData()

	data.delay = data.delay or 0
	data.state_timeout = data.state_timeout or CurTime() + 20

	if data.state_timeout < CurTime() then
		actor:RemoveTarget(target)
		data.state_timeout = CurTime() + 20
	elseif npc:Disposition(target) ~= D_HT then
		npc:AddEntityRelationship(target, D_HT, 99)
	end

	if target:IsPlayer() and target:InVehicle() then
		target = target:GetVehicle()
	end

	if npc:GetTarget() ~= target then
		npc:SetTarget(target)
	end

	if data.delay < CurTime() then
		bgNPC:SetActorWeapon(actor)

		local current_distance = npc:GetPos():DistToSqr(target:GetPos())

		if current_distance <= 500 ^ 2 then
			actor:WalkToPos(nil)
			npc:SetSchedule(SCHED_MOVE_AWAY_FROM_ENEMY)
		else
			actor:WalkToPos(target:GetPos(), 'run')
		end

		data.delay = CurTime() + 3
	end
end)


hook.Add('BGN_PostReactionTakeDamage', 'BGN_UpdateResetImpingementTimer', function(attacker, target, dmginfo)
	local actor = bgNPC:GetActor(attacker)
	if actor == nil or not actor:HasState('impingement') then return end

	actor:GetStateData().state_timeout = CurTime() + 20
end)
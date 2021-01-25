hook.Add("BGN_SetNPCState", "BGN_SetImpingementState", function(actor, state)
	if state ~= 'impingement' or not actor:IsAlive() then return end
	
	local npc = actor:GetNPC()

	local target_from_zone = ents.FindInSphere(npc:GetPos(), 500)
	local targets = {}

	for _, ent in pairs(target_from_zone) do
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

	local target = table.Random(targets)
	if IsValid(target) then
		actor:AddTarget(target)
	else
		actor:RandomState()
	end
end)

timer.Create('BGN_Timer_ImpingementController', 0.5, 0, function()
	for _, actor in ipairs(bgNPC:GetAll()) do
		if not actor:IsAlive() then goto skip end

		local state = actor:GetState()
		if state ~= 'impingement' then goto skip end

		local target = actor:GetNearTarget()
		if not IsValid(target) then goto skip end
		
		local npc = actor:GetNPC()
		local data = actor:GetStateData()
		
		if npc:Disposition(target) ~= D_HT then
			npc:AddEntityRelationship(target, D_HT, 99)
		end

		if target:IsPlayer() and target:InVehicle() then
			target = target:GetVehicle()
			
			if npc:GetTarget() ~= target then
				npc:SetTarget(target)
			end
		end

		data.delay = data.delay or 0

		if data.delay < CurTime() then
			bgNPC:SetActorWeapon(actor)

			local point = nil
			local current_distance = npc:GetPos():DistToSqr(target:GetPos())

			if current_distance > 500 ^ 2 then
				if math.random(0, 10) > 4 then
					point = actor:GetClosestPointToPosition(target:GetPos())
				else
					point = target:GetPos()
				end
			end

			if point ~= nil then
				npc:SetSaveValue("m_vecLastPosition", point)
				npc:SetSchedule(SCHED_FORCED_GO_RUN)
			elseif current_distance <= 500 ^ 2 then
				npc:SetSchedule(SCHED_MOVE_AWAY_FROM_ENEMY)
			end

			data.delay = CurTime() + 3
		end
		
		::skip::
	end
end)
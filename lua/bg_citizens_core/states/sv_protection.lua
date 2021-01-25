hook.Add("BGN_PreSetNPCState", "BGN_PlaySoundForDefenseState", function(actor, state)
	if not actor:HasTeam('police') then return end
	if state ~= 'defense' or not actor:IsAlive() then return end
	if math.random(0, 10) > 1 then return end
	
	local target = actor:GetNearTarget()
	if not IsValid(target) then return end

	local npc = actor:GetNPC()
	if target:GetPos():DistToSqr(npc:GetPos()) > 250000 then return end
	
	npc:EmitSound('npc/metropolice/vo/defender.wav', 300, 100, 1, CHAN_AUTO)
end)

timer.Create('BGN_Timer_DefenseController', 0.5, 0, function()
	for _, actor in ipairs(bgNPC:GetAll()) do
		if not actor:IsAlive() then goto skip end

		local state = actor:GetState()
		if state ~= 'defense' then goto skip end

		local target = actor:GetNearTarget()
		if not IsValid(target) then goto skip end
		
		local npc = actor:GetNPC()
		local data = actor:GetStateData()
		
		if npc:Disposition(target) ~= D_HT then
			npc:AddEntityRelationship(target, D_HT, 99)
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
local asset = bgNPC:GetModule('wanted')

timer.Create('BGN_Timer_RetreatController', 0.5, 0, function()
	for _, actor in ipairs(bgNPC:GetAllByState('retreat')) do
		if not actor:IsAlive() then goto skip end
		
		local npc = actor:GetNPC()
		local data = actor:GetStateData()

		data.delay = data.delay or 0
		data.cooldown = data.cooldown or CurTime() + 20
      data.target_point = data.target_point or actor:GetFarPointInRadius(1500)

		if data.delay < CurTime() then
			if actor:TargetsCount() ~= 0 then
				actor:SetState(actor:GetReactionForDamage())
				goto skip
			end

			local current_distance = npc:GetPos():DistToSqr(data.target_point)

			if current_distance > 500 ^ 2 then
            local point = data.target_point
				if math.random(0, 10) >= 2 then
					point = actor:GetClosestPointToPosition(data.target_point)
				end

            npc:SetSaveValue("m_vecLastPosition", point)
            npc:SetSchedule(SCHED_FORCED_GO_RUN)
   
            data.delay = CurTime() + 3
			else
				if not asset:HasWanted(actor:GetNPC()) or data.cooldown < CurTime() then
            	actor:RandomState()
				else
					data.target_point = actor:GetFarPointInRadius(1500)
				end
         end
		end
		
		::skip::
	end
end)
local asset = bgNPC:GetModule('wanted')

timer.Create('BGN_Timer_RetreatController', 0.5, 0, function()
	for _, actor in ipairs(bgNPC:GetAllByState('retreat')) do
		if not actor:IsAlive() then goto skip end
		
		local npc = actor:GetNPC()
		local data = actor:GetStateData()

		data.delay = data.delay or 0
		data.updatePoint = data.updatePoint or 0
		data.cooldown = data.cooldown or CurTime() + 20
      data.target_point = data.target_point or actor:GetFarPointInRadius(1500)

		if data.delay < CurTime() then
			-- if actor:TargetsCount() ~= 0 then
			-- 	actor:SetState(actor:GetReactionForDamage())
			-- 	goto skip
			-- end

			local target = actor:GetNearTarget()
			if IsValid(target) and bgNPC:IsTargetRay(npc, target) then
				data.cooldown = CurTime() + 20
			end

			if not asset:HasWanted(npc) and data.cooldown < CurTime() then
				actor:RandomState()
				goto skip
			end

			data.updatePoint = data.updatePoint + 1
			if data.updatePoint > 10 then
				data.target_point = actor:GetFarPointInRadius(1500)
				data.updatePoint = 0
			end

			actor:WalkToPos(data.target_point, 'run')
			data.delay = CurTime() + 1.5
		end
		
		::skip::
	end
end)
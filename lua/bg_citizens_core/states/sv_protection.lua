timer.Create('BGN_Timer_DefenseController', 0.5, 0, function()
	for _, actor in ipairs(bgNPC:GetAll()) do
		local npc = actor:GetNPC()
		if IsValid(npc) then
			local state = actor:GetState()
			local data = actor:GetStateData()

			if state == 'defense' and actor:TargetsCount() ~= 0  then
				local target = actor:GetNearTarget()

				if not IsValid(target) then
					actor:RecalculationTargets()
				else
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
				end
			end
		end
	end
end)
bgNPC:SetStateAction('sit_to_chair_2', {
	update = function(actor)
		local npc = actor:GetNPC()
		local data = actor:GetStateData()
		data.oldCollisionGroup = data.oldCollisionGroup or npc:GetCollisionGroup()
		local seat = data.seat
		if data.isSit then return end

		if data.delay < CurTime() then
			data.isStand = true
			actor:SetState('walk')
			seat:SetSitting(NULL)
		else
			local start_pos = seat:GetStartSittingPos()
			actor:WalkToPos(start_pos)

			-- 40 ^ 2 
			if npc:GetPos():DistToSqr(start_pos) <= 1600 then
				actor:WalkToPos(nil)
				data.isSit = true
				data.old_pos = npc:GetPos()
				local sitTime = math.random(5, 120)
				npc:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
				npc:SetPos(seat:GetPos())
				npc:SetAngles(seat:GetAngles())
				npc:SetCollisionGroup(data.oldCollisionGroup)

				actor:PlayStaticSequence('Idle_To_Sit_Chair', false, nil, function()
					actor:PlayStaticSequence('Sit_Chair', true, sitTime, function()
						actor:PlayStaticSequence('Sit_Chair_To_Idle', false, nil, function()
							if not IsValid(npc) then return end
							local data = actor:GetStateData()
							if data.isStandAnimation then return end
							data.isStandAnimation = true
							npc:SetAngles(Angle(0, 0, 0))
							npc:SetPos(data.old_pos)
							-- npc:SetCollisionGroup(data.oldCollisionGroup)
							npc:PhysWake()
							data.isStand = true
							seat.sitDelay = CurTime() + 15
							actor:SetState(data.next_state or 'walk')
							seat:SetSitting(NULL)
						end)
					end)
				end)
			end
		end
	end
})
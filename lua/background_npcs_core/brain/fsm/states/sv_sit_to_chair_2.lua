local function FindCustomChair(actor)
	local npc = actor:GetNPC()
	local npc_pos = npc:GetPos()
	local seats = {}

	for _, seat in ipairs(BGN_SEAT:GetAllSeats()) do
		if seat.sitDelay and seat.sitDelay > CurTime() then continue end

		if not IsValid(seat:GetSitting()) and seat:GetPos():DistToSqr(npc_pos) < 250000 then
			for _, ent in ipairs(ents.FindInSphere(seat:GetPos(), 10)) do
				if ent:IsPlayer() then continue end
			end

			table.insert(seats, seat)
		end
	end

	if #seats ~= 0 then
		return bgNPC.Table.Random(seats)
	end
end

bgNPC.States.Register('sit_to_chair_2', 'calm', {
	pre_start = function(actor, state, data)
		local npc = actor:GetNPC()

		local seat = FindCustomChair(actor)
		if not seat then return true end

		return state, {
			seat = seat,
			delay = CurTime() + math.random(10, 30),
			isSit = false,
			isMove = false,
			isStand = false,
			oldCollisionGroup = npc:GetCollisionGroup()
		}
	end,
	update = function(actor, state, data)
		local npc = actor:GetNPC()
		local seat = data.seat
		if data.isSit then return end

		if data.delay < CurTime() then
			data.isStand = true
			actor:SetState('walk')
			seat:SetSitting(NULL)
		else
			local start_pos = seat:GetStartSittingPos()
			actor:WalkToPos(start_pos)

			-- the walk counts as finished within 150 units (sh_movement), so sit from that distance too
			if npc:GetPos():DistToSqr(start_pos) <= 22500 then
				actor:WalkToPos(nil)
				data.isSit = true
				data.old_pos = npc:GetPos()
				local sitTime = math.random(5, 120)
				-- a physical nextbot inside the bench is pushed up onto it by the engine: no solid mask and no gravity while sitting
				npc:SetCollisionGroup(COLLISION_GROUP_WORLD)
				if npc.loco then
					data.oldSolidMask, data.oldGravity = npc:GetSolidMask(), npc.loco:GetGravity()
					npc:SetSolidMask(0)
					npc.loco:SetGravity(0)
				end
				npc:SetPos(seat:GetPos())
				npc:SetAngles(seat:GetAngles())

				actor:PlayStaticSequence('Idle_To_Sit_Chair', false, nil, function()
					actor:PlayStaticSequence('Sit_Chair', true, sitTime, function()
						actor:PlayStaticSequence('Sit_Chair_To_Idle', false, nil, function()
							if not IsValid(npc) or data.isStandAnimation then return end
							data.isStandAnimation = true
							data.isStand = true
							actor:SetState(data.next_state or 'walk')
						end)
					end)
				end)
			end
		end
	end,
	stop = function(actor, state, data)
		local npc = actor:GetNPC()
		if IsValid(npc) and data.isSit then
			npc:SetCollisionGroup(data.oldCollisionGroup)
			if data.oldSolidMask then
				npc:SetSolidMask(data.oldSolidMask)
				npc.loco:SetGravity(data.oldGravity)
			end
			-- in front of the bench, not inside it
			if data.isStandAnimation then npc:SetPos(data.seat:GetStartSittingPos()) end
		end
		if IsValid(npc) and not data.isStandAnimation then
			if data.old_pos then
				npc:SetAngles(Angle(0, 0, 0))
				npc:SetPos(data.old_pos)
			end
			npc:SetCollisionGroup(data.oldCollisionGroup)
			npc:PhysWake()
			local seat = data.seat
			if seat then
				seat.sitDelay = CurTime() + 15
				seat:SetSitting(NULL)
			end
		end
	end
})
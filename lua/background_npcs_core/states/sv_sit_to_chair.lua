local function FindChair(actor)
	local npc = actor:GetNPC()
	local npc_pos = npc:GetPos()
	local entities = ents.FindInSphere(npc_pos, 500)
	local chair = NULL
	local cahirId = -1

	for _, ent in ipairs(entities) do
		if not IsValid(ent) or not ent:GetClass():StartWith('prop_') then goto skip end

		local ent_model = ent:GetModel()
		if not ent_model then goto skip end

		ent_model = ent_model:lower()

		for id, chair_data in ipairs(bgNPC.cfg.sit_chairs) do
			for _, model in ipairs(chair_data.models) do
				if model:lower() == ent_model and not ent.occupied then
					if ent.sitDelay == nil or ent.sitDelay < CurTime() then
						local ang = ent:GetAngles()

						if math.abs(ang.x) < 10 and math.abs(ang.z) < 10 then
							return ent, id
						end
					end
				end
			end
		end

		::skip::
	end
end

local function FindCustomChair(actor)
	local npc = actor:GetNPC()
	local npc_pos = npc:GetPos()
	local seats = {}

	for _, seat in ipairs(BGN_SEAT:GetAllSeats()) do
		if seat.sitDelay and seat.sitDelay > CurTime() then goto skip end

		if not IsValid(seat:GetSitting()) and seat:GetPos():DistToSqr(npc_pos) < 250000 then
			for _, ent in ipairs(ents.FindInSphere(seat:GetPos(), 10)) do
				if ent:IsPlayer() then goto skip end
			end

			table.insert(seats, seat)
		end

		::skip::
	end

	if #seats ~= 0 then
		return table.RandomBySeq(seats)
	end
end

bgNPC:SetStateAction('sit_to_chair', 'calm', {
	pre_start = function(actor, state, data)
		local chair, cahirId = FindChair(actor, state, data)

		if IsValid(chair) and cahirId then
			chair.occupied = true
			return state, {
				chair = chair,
				chairDataId = cahirId,
				delay = CurTime() + math.random(10, 30),
				isSit = false,
				isMove = false,
				isStand = false,
			}
		else
			local seat = FindCustomChair(actor)
			if not seat then return true end

			seat:SetSitting(npc)

			return 'sit_to_chair_2', {
				seat = seat,
				delay = CurTime() + math.random(10, 30),
				isSit = false,
				isMove = false,
				isStand = false,
			}
		end
	end,
	update = function(actor, state, data)
		local npc = actor:GetNPC()
		data.oldCollisionGroup = data.oldCollisionGroup or npc:GetCollisionGroup()
		local chair = data.chair
		local chairData = bgNPC.cfg.sit_chairs[data.chairDataId]

		if not IsValid(chair) then
			actor:ResetSequence()
			npc:SetAngles(Angle(0, 0, 0))
			npc:SetCollisionGroup(data.oldCollisionGroup)
			npc:PhysWake()
			data.isStand = true
			actor:SetState('walk')
		elseif not data.isSit and data.delay < CurTime() then
			data.isStand = true
			actor:SetState('walk')
			chair.occupied = false
		else
			local phys = chair:GetPhysicsObject()

			if not data.isMove then
				actor:WalkToPos(chair:GetPos() + (chair:GetForward() * 35))
				data.isMove = true
			end

			-- 60 ^ 2 
			if not data.isSit and npc:GetPos():DistToSqr(chair:GetPos()) <= 3600 then
				actor:WalkToPos(nil)
				data.isSit = true
				local sitTime = math.random(5, 120)
				local new_pos = chair:GetPos() + (chair:GetForward() * 35)
				local new_angle = chair:GetAngles()

				if chairData.offsetPosition ~= nil then
					new_pos = chairData.offsetPosition(npc, chair, new_pos)
				end

				if chairData.offsetAngle ~= nil then
					new_angle = chairData.offsetAngle(npc, chair, new_angle)
				end

				npc:SetCollisionGroup(COLLISION_GROUP_WORLD)
				npc:SetPos(new_pos)
				npc:SetAngles(new_angle)
				npc:SetParent(chair)

				if IsValid(phys) then
					phys:EnableMotion(false)
				end

				actor:PlayStaticSequence('Idle_To_Sit_Chair', false, nil, function()
					actor:PlayStaticSequence('Sit_Chair', true, sitTime, function()
						actor:PlayStaticSequence('Sit_Chair_To_Idle', false, nil, function()
							if not IsValid(npc) then return end
							local data = actor:GetStateData()
							if data.isStandAnimation then return end
							data.isStandAnimation = true
							data.isStand = true
							actor:SetState('walk')
						end)
					end)
				end)
			end
		end
	end,
	stop = function(actor, state, data)
		local data = actor:GetStateData()
		local npc = actor:GetNPC()
		if IsValid(npc) then
			npc:SetParent(nil)
			if IsValid(chair) then
				npc:SetAngles(Angle(0, chair:GetAngles().y, 0))
			else
				npc:SetAngles(Angle(0, 0, 0))
			end
			npc:SetPos(npc:GetPos() + npc:GetForward() * 15)
			npc:SetCollisionGroup(data.oldCollisionGroup)
			npc:PhysWake()
			local chair = data.chair
			if chair and IsValid(chair) then
				chair.sitDelay = CurTime() + 15
				chair.occupied = false
			end
		end
	end,
	not_stop = function(actor, state, data)
		return ( actor:EnemiesCount() == 0 and not data.isStand and IsValid(data.chair) )
	end
})
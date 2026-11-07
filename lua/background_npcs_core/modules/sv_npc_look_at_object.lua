--

local function ParseEntitiesForActorAsync(actor)
	local npc = actor:GetNPC()
	local npc_pos = npc:GetPos()
	local entities = ents.FindInSphere(npc_pos, 1000)

	for k = 1, #entities do
		local ent = entities[k]

		coroutine.yield()

		if not IsValid(ent) then
			continue
		end

		local ent_pos = ent:GetPos()

		coroutine.yield()

		if not IsValid(npc) then break end

		if not bgNPC.Vision.NPCCanSeePos(npc, ent_pos, 85) then
			continue
		end

		local diff = (ent_pos - npc_pos):Angle().y - npc:GetAngles().y

		if diff < -180 then
			diff = diff + 360
		end

		if diff > 180 then
			diff = diff - 360
		end

		diff = math.abs(diff)

		local dist = npc_pos:Distance(ent_pos)
		hook.Run('BGN_ActorVisibleAtObject', actor, ent, dist, diff)

		if npc:IsNPC() then
			local tr = util.TraceLine({
				start = npc:GetShootPos(),
				endpos = npc:GetShootPos() + npc:GetForward() * 1000,
				filter = function(trace_entity)
					if trace_entity ~= npc then return true end
				end
			})

			if tr.Hit and IsValid(ent) and actor:IsAlive() then
				hook.Run('BGN_ActorLookAtObject', actor, ent, dist, diff)
			end
		end
	end
end

bgNPC.Tasks.Add('BGN_Timer_ActorLookAtObject', function()
	while true do
		local actors = bgNPC.Actors.GetAll()

		for i = 1, #actors do
			local actor = actors[i]
			if actor and actor:IsAlive() then
				ParseEntitiesForActorAsync(actor)
			end
			coroutine.yield()
		end

		coroutine.yield()
	end
end)
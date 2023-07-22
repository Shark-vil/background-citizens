local bgNPC = bgNPC
local ents_FindInSphere = ents.FindInSphere
local util_TraceLine = util.TraceLine
local hook_Run = hook.Run
local math_abs = math.abs
local IsValid = IsValid
local coroutine_yield = coroutine.yield
--

local function ParseEntitiesForActorAsync(actor)
	local npc = actor:GetNPC()
	local npc_pos = npc:GetPos()
	local entities = ents_FindInSphere(npc_pos, 1000)

	for k = 1, #entities do
		local ent = entities[k]

		coroutine_yield()

		if not IsValid(ent) then
			continue
		end

		local ent_pos = ent:GetPos()

		coroutine_yield()

		if not IsValid(npc) then break end

		if not bgNPC:NPCIsViewVector(npc, ent_pos, 70) then
			continue
		end

		local diff = (ent_pos - npc_pos):Angle().y - npc:GetAngles().y

		if diff < -180 then
			diff = diff + 360
		end

		if diff > 180 then
			diff = diff - 360
		end

		diff = math_abs(diff)

		local dist = npc_pos:Distance(ent_pos)
		hook_Run('BGN_ActorVisibleAtObject', actor, ent, dist, diff)

		if npc:IsNPC() then
			local tr = util_TraceLine({
				start = npc:GetShootPos(),
				endpos = npc:GetShootPos() + npc:GetForward() * 1000,
				filter = function(trace_entity)
					if trace_entity ~= npc then return true end
				end
			})

			if tr.Hit and IsValid(ent) and actor:IsAlive() then
				hook_Run('BGN_ActorLookAtObject', actor, ent, dist, diff)
			end
		end
	end
end

async.Add('BGN_Timer_ActorLookAtObject', function()
	while true do
		local actors = bgNPC:GetAll()

		for i = 1, #actors do
			local actor = actors[i]
			if actor and actor:IsAlive() then
				ParseEntitiesForActorAsync(actor)
			end
			coroutine_yield()
		end

		coroutine_yield()
	end
end)
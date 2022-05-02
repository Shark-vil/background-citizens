local bgNPC = bgNPC
local IsValid = IsValid
local CurTime = CurTime
--
async.Add('BGN_MovementProcess', function(yield, wait)
	local current_pass = 0

	while true do
		local actors = bgNPC:GetAll()

		for i = 1, #actors do
			local actor = actors[i]
			if not actor then continue end

			local npc = actor:GetNPC()
			if not IsValid(npc) or npc:IsEFlagSet(EFL_NO_THINK_FUNCTION) then continue end

			if actor:InVehicle() then
				if actor.walkUpdatePathDelay < CurTime() then
					if IsValid(actor.walkTarget) then
						actor:WalkToTarget(actor.walkTarget)
					end

					actor.walkUpdatePathDelay = CurTime() + 5
				end
			else
				if IsValid(actor.walkTarget) and actor.walkUpdatePathDelay < CurTime() then
					local walkPath = bgNPC:FindWalkPath(npc:GetPos(), actor.walkTarget:GetPos(), nil, actor.pathType)

					if #walkPath ~= 0 then
						actor.walkPath = walkPath
					end

					actor.walkUpdatePathDelay = CurTime() + 10
					yield()
				end
			end

			actor:UpdateMovement()

			if current_pass >= 1 / slib.deltaTime then
				current_pass = 0
				yield()
			end

			current_pass = current_pass + 1
		end

		yield()
	end
end)
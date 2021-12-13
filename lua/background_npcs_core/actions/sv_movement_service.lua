local bgNPC = bgNPC
local IsValid = IsValid
local CurTime = CurTime
--

async.Add('MovementProcess', function(yield, wait)
	local actors = bgNPC:GetAll()

	for i = 1, #actors do
		local actor = actors[i]
		local npc = actor:GetNPC()

		if npc:IsEFlagSet(EFL_NO_THINK_FUNCTION) then continue end

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
		yield()
	end
end)
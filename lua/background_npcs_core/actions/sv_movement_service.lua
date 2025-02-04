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
			if actor then
				local npc = actor:GetNPC()
				if IsValid(npc) then
					if actor:InVehicle() then
						if IsValid(actor.walkTarget) and actor.walkUpdatePathDelay < CurTime() then
							actor:WalkToTarget(actor.walkTarget)
							actor.walkUpdatePathDelay = CurTime() + 5
						end
					else
						if IsValid(actor.walkTarget) and actor.walkUpdatePathDelay < CurTime() then
							local walkPath = bgNPC:FindWalkPath(npc:GetPos(), actor.walkTarget:GetPos(), nil, actor.pathType)

							if #walkPath ~= 0 then
								actor.walkPath = walkPath
							end

							actor.walkUpdatePathDelay = CurTime() + 10
						end
					end

					actor.targetsUpdateDelay = actor.targetsUpdateDelay or 0
					if actor.targetsUpdateDelay < CurTime() then
						actor:EnemiesRecalculate()
						actor:RecalculationTargets()
						actor.targetsUpdateDelay = CurTime() + 5
					end

					actor:UpdateMovement()

					if actor.checkMoveUpdateData then
						for tag, _ in pairs(actor.checkMoveUpdateData) do
							if actor.checkMoveUpdateData[tag].time < CurTime() then
								actor.checkMoveUpdateData[tag].state = true
							end
						end
					end

					if current_pass >= 1 / slib.deltaTime then
						current_pass = 0
						yield()
					end

					current_pass = current_pass + 1
				end
			end
		end

		yield()
	end
end)
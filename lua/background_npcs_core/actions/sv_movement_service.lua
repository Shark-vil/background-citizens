local bgNPC = bgNPC
local IsValid = IsValid
local GetConVar = GetConVar
local CurTime = CurTime
local coroutine_resume = coroutine.resume
local coroutine_create = coroutine.create
local coroutine_yield = coroutine.yield
--

local function MovementProcess()
	local max_pass = GetConVar('bgn_movement_checking_parts'):GetInt()
	local current_pass = 0
	local actors = bgNPC:GetAll()

	for i = 1, #actors do
		local actor = actors[i]
		local npc = actor:GetNPC()

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
			end
		end

		actor:UpdateMovement()
		current_pass = current_pass + 1

		if max_pass == current_pass then
			current_pass = 0
			coroutine_yield()
		end
	end
end

local thread

hook.Add('Think', 'BGN_MovementService', function()
	if not thread or not coroutine_resume(thread) then
		thread = coroutine_create(MovementProcess)
		coroutine_resume(thread)
	end
end)
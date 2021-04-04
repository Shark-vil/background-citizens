local function MovementProcess()
   local max_pass = GetConVar('bgn_movement_checking_parts'):GetInt()
   local current_pass = 0
   local actors = bgNPC:GetAll()
   
   for i = 1, #actors do
      local actor = actors[i]
      if IsValid(actor.walkTarget) and actor.walkUpdatePathDelay < CurTime() then
         local npc = actor:GetNPC()
         local walkPath = bgNPC:FindWalkPath(npc:GetPos(), actor.walkTarget:GetPos(), nil, actor.pathType)
         if #walkPath ~= 0 then
            actor.walkPath = walkPath
         end
         actor.walkUpdatePathDelay = CurTime() + 10
      end

      actor:UpdateMovement()

      current_pass = current_pass + 1
      if max_pass == current_pass then
         coroutine.yield()
         current_pass = 0
      end
   end
end

local thread
hook.Add('Think', 'BGN_MovementService', function()
	if not thread or not coroutine.resume(thread) then
		thread = coroutine.create(MovementProcess)
		coroutine.resume(thread)
	end
end)
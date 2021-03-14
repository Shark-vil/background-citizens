timer.Create('BGN_MovementService', 0.1, 0, function()
   for _, actor in ipairs(bgNPC:GetAll()) do
      if IsValid(actor.walkTarget) and actor.walkUpdatePathDelay < CurTime() then
         local npc = actor:GetNPC()
         local walkPath = bgNPC:FindWalkPath(npc:GetPos(), actor.walkTarget:GetPos())
         if #walkPath ~= 0 then
            actor.walkPath = walkPath
         end
         actor.walkUpdatePathDelay = CurTime() + 10
      end

      actor:UpdateMovement()
   end
end)
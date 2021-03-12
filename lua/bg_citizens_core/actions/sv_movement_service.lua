timer.Create('BGN_MovementService', 0.5, 0, function()
   for _, actor in ipairs(bgNPC:GetAll()) do
      -- if actor.walkTargetPos and actor.walkUpdatePathDelay < CurTime() then
      --    local npc = actor:GetNPC()
      --    local walkPath = bgNPC:FindWalkPath(npc:GetPos(), actor.walkTargetPos)
      --    if #walkPath == 0 then
      --       goto skip
      --    end
   
      --    actor.walkPath = walkPath
      --    actor.walkUpdatePathDelay = CurTime() + 10
      -- end

      actor:UpdateMovement()

      ::skip::
   end
end)
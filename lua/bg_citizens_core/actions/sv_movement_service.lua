timer.Create('BGN_MovementService', 0.1, 0, function()
   for _, actor in ipairs(bgNPC:GetAll()) do
      actor:UpdateMovement()
   end
end)
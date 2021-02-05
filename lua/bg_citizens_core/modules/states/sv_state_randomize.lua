timer.Create('BGN_Timer_StateRandomize', bgNPC.cfg.RandomStateAssignmentPeriod, 0, function()
   for _, actor in ipairs(bgNPC:GetAll()) do
      if actor:IsAlive() and actor:TargetsCount() == 0 and not actor:IsStateLock() then
         actor:RandomState()
      end
   end
end)
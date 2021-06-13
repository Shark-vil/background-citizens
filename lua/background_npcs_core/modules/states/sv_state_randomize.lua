timer.Create('BGN_Timer_StateRandomize', bgNPC.cfg.RandomStateAssignmentPeriod, 0, function()
   for _, actor in ipairs(bgNPC:GetAll()) do
      if actor:IsAlive() and not actor:IsStateLock() and actor.state_delay < CurTime()
         and actor:EnemiesCount() == 0 and actor:TargetsCount() == 0
      then
         actor:RandomState()
      end
   end
end)
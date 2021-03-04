hook.Add('PostCleanupMap', 'BGN_DV_FixRoutesAutoLoadPostCleanupMap', function()
   local HOOKS_DATA = hook.GetTable()
   if HOOKS_DATA['InitPostEntity'] then
      if HOOKS_DATA['InitPostEntity']['Decent Vehicle: Load waypoints'] then
         local func = HOOKS_DATA['InitPostEntity']['Decent Vehicle: Load waypoints']
         func()
      end
   end
end)
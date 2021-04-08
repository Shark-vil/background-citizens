hook.Add('PostCleanupMap', 'BGN_DV_FixRoutesAutoLoadPostCleanupMap', function()
   local HOOKS_DATA = hook.GetTable()
   if HOOKS_DATA['InitPostEntity']  then
      local func = HOOKS_DATA['InitPostEntity']['Decent Vehicle: Load waypoints']
      if func then func() end
   end
end)
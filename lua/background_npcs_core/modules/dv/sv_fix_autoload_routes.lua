hook.Add('PostCleanupMap', 'BGN_DV_FixRoutesAutoLoadPostCleanupMap', function()
   local hook_function = hook.Get('InitPostEntity', 'Decent Vehicle: Load waypoints')
   if hook_function then hook_function() end
end)
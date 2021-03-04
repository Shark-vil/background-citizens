hook.Add('PostCleanupMap', 'BGN_DV_FixRoutesAutoLoadPostCleanupMap', function()
   hook.Run("InitPostEntity", "Decent Vehicle: Load waypoints")
end)
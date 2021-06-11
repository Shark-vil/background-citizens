local function init_dv_waypoints()
   if not DecentVehicleDestination then return end

   local hook_function = hook.Get('InitPostEntity', 'Decent Vehicle: Load waypoints')
   if hook_function then
      hook_function()
   else
      MsgN('[Background NPCs] Failed to call the function of loading the waypoints of DV')
   end
end
hook.Add('PostCleanupMap', 'BGN_DV_FixRoutesAutoLoadPostCleanupMap', init_dv_waypoints)
hook.Add('InitPostEntity', 'BGN_DV_RoutesAutoLoadAfterInitEntities', init_dv_waypoints)
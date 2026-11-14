hook.Add('PostCleanupMap', 'BGN_ResetAllGlobalTablesAndVariables', function()
  bgNPC.Config.ClearCache()
  bgNPC.Actors.ResetStorage()
end)

cvars.AddChangeCallback('bgn_enable', function(convar_name, value_old, value_new) if tonumber(value_new) == 0 then bgNPC.Config.ClearCache() end end)

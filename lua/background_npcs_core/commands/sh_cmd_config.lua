scommand.Register('bgn_config_reload').OnShared(function()
   bgNPC:ClearActorsConfig()
end).Access( { isAdmin = true } )
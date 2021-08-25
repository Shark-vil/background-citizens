local function cmd_config_reload()
   bgNPC:ClearActorsConfig()
end
slib.RegisterGlobalCommand('bgn_config_reload', cmd_config_reload, cmd_config_reload)
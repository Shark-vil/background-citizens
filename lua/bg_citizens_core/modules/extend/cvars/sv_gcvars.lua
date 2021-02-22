util.AddNetworkString('bgn_gcvars_register_from_client')
util.AddNetworkString('bgn_gcvars_register_all_from_client')
util.AddNetworkString('bgn_gcvars_change_from_server')
util.AddNetworkString('bgn_gcvars_change_from_client')

net.Receive('bgn_gcvars_change_from_server', function(len, ply)
   if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end

   local cvar_name = net.ReadString()
   local value = net.ReadFloat()
   local cvar = GetConVar(cvar_name)

   if bgNPC.GlobalCvars[cvar_name] ~= nil and tobool(cvar) and cvar:GetFloat() ~= value then
      RunConsoleCommand(cvar_name, value)
      bgNPC.GlobalCvars[cvar_name].value = value

      bgNPC:Log('Update cvar [' .. cvar_name .. ']: ' .. value, 'Cvars')

      net.Start('bgn_gcvars_change_from_client')
      net.WriteString(cvar_name)
      net.WriteFloat(value)
      net.SendOmit(ply)
   end
end)

hook.Add("SlibPlayerFirstSpawn", "BGN_SyncPlayerGlobalConvars", function(ply)
   bgNPC:Log('First cvars sync', 'Cvars')

   net.Start('bgn_gcvars_register_all_from_client')
   net.WriteTable(bgNPC.GlobalCvars)
   net.Send(ply)
end)
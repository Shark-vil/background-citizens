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

function bgNPC:RegisterGlobalCvar(cvar_name, value, flag, helptext, min, max)
   if bgNPC.GlobalCvars[cvar_name] == nil then
      helptext = helptext or ''

      CreateConVar(cvar_name, value, flag, helptext, min, max)

      bgNPC.GlobalCvars[cvar_name] = {
         value = GetConVar(cvar_name):GetFloat(),
         flag = flag,
         helptext = helptext,
         min = min,
         max = max
      }
   end
end

hook.Add("BGN_PlayerIsLoaded", "BGN_SyncPlayerGlobalConvars", function(ply)
   net.Start('bgn_gcvars_register_all_from_client')
   net.WriteTable(bgNPC.GlobalCvars)
   net.Send(ply)
end)
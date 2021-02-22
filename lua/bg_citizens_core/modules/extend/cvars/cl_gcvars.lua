local cvar_locker = {}
local cvar_locker_another = {}

net.Receive('bgn_gcvars_register_all_from_client', function()
   bgNPC.GlobalCvars = net.ReadTable()
   for cvar_name, cvar_data in pairs(bgNPC.GlobalCvars) do
      if not tobool(GetConVar(cvar_name)) then
         CreateConVar(cvar_name, cvar_data.value, cvar_data.flag, cvar_data.helptext, cvar_data.min, cvar_data.max)
      else
         RunConsoleCommand(cvar_name, cvar_data.value)
      end
      
      bgNPC:Log('Sync [' .. cvar_name .. ']: ' .. cvar_data.value, 'Cvars')

      cvar_locker[cvar_name] = cvar_locker[cvar_name] or false

      cvars.AddChangeCallback(cvar_name, function(convar_name, value_old, value_new)
         if value_old == value_new then return end
         
         if not cvar_locker_another[convar_name] then
            if not LocalPlayer():IsAdmin() and not LocalPlayer():IsSuperAdmin() then
               if not cvar_locker[convar_name] then
                  bgNPC:Log('Bad sync access [' .. cvar_name .. ']', 'Cvars')

                  cvar_locker[convar_name] = true
                  timer.Remove('bgn_timer_back_cvar_' .. convar_name)

                  timer.Create('bgn_timer_back_cvar_' .. convar_name, 0.1, 1, function()
                     if not cvar_locker[convar_name] then return end
                     RunConsoleCommand(convar_name, value_old)

                     bgNPC:Log('Back cvar [' .. cvar_name .. ']: ' .. value_old, 'Cvars')

                     timer.Remove('bgn_timer_reset_back_cvar_' .. convar_name)
                     timer.Create('bgn_timer_reset_back_cvar_' .. convar_name, 0.1, 1, function()
                        if not cvar_locker[convar_name] then return end
                        cvar_locker[convar_name] = false
                     end)
                  end)
               end
               return
            end
         end

         bgNPC.GlobalCvars[convar_name].value = value_new
         bgNPC:Log('Update global cvar [' .. convar_name .. ']: ' .. value_new, 'Cvars')
         
         if cvar_locker[convar_name] or cvar_locker_another[convar_name] then return end

         bgNPC:Log('Send to server  [' .. convar_name .. ']', 'Cvars')
         net.Start('bgn_gcvars_change_from_server')
         net.WriteString(convar_name)
         net.WriteFloat(value_new)
         net.SendToServer()
      end)
   end
end)

net.Receive('bgn_gcvars_change_from_client', function()
   local cvar_name = net.ReadString()
   local value = net.ReadFloat()

   cvar_locker_another[cvar_name] = true
   RunConsoleCommand(cvar_name, value)
   bgNPC:Log('Another sync [' .. cvar_name .. ']: ' .. value, 'Cvars')

   timer.Create('bgn_timer_reset_cvar_another_locker_' .. cvar_name, 0.2, 1, function()
      if not cvar_locker_another[cvar_name] then return end
      cvar_locker_another[cvar_name] = false
   end)
end)
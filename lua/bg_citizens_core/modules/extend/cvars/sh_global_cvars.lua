bgNPC.GlobalCvars = bgNPC.GlobalCvars or {}

if SERVER then
	util.AddNetworkString('bgn_gcvars_register_from_client')
	util.AddNetworkString('bgn_gcvars_register_all_from_client')
	util.AddNetworkString('bgn_gcvars_change_from_server')

	net.Receive('bgn_gcvars_change_from_server', function(len, ply)
		if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end

		local cvar_name = net.ReadString()
		local value = net.ReadFloat()

		if bgNPC.GlobalCvars[cvar_name] ~= nil and tobool(GetConVar(cvar_name)) then
			RunConsoleCommand(cvar_name, value)
			bgNPC.GlobalCvars[cvar_name].value = value
		end
	end)

	function bgNPC:RegisterGlobalCvar(cvar_name, value, flag, helptext, min, max)
		if bgNPC.GlobalCvars[cvar_name] == nil then
			flag = flag or FCVAR_NONE
			helptext = helptext or ''

			CreateConVar(cvar_name, value, flag, helptext, min, max)
			bgNPC.GlobalCvars[cvar_name] = {
				value = value,
				flag = flag,
				helptext = helptext,
				min = min,
				max = max
			}
		end
	end

	hook.Add("PlayerSpawn", "BGN_SyncPlayerGlobalConvars", function(ply)
		if ply.bgNPCGlobalConvarSync then return end
		
		timer.Simple(3, function()
			if not IsValid(ply) then
				bgNPC:Log('Failed to sync global cvars', 'Global Cvars')
				return
			end

			-- net.Start('bgn_gcvars_register_all_from_client')
			-- net.WriteTable(bgNPC.GlobalCvars)
			-- net.Send(ply)
		end)

		ply.bgNPCGlobalConvarSync = true
	end)
else
	local cvar_locker = {}
	net.Receive('bgn_gcvars_register_all_from_client', function()
		bgNPC.GlobalCvars = net.ReadTable()
		for cvar_name, cvar_data in pairs(bgNPC.GlobalCvars) do
			if not tobool(GetConVar(cvar_name)) then
				CreateConVar(cvar_name, cvar_data.value, cvar_data.flag, 
					cvar_data.helptext, cvar_data.min, cvar_data.max)
					
				cvar_locker[cvar_name] = cvar_locker[cvar_name] or false
	
				cvars.AddChangeCallback(cvar_name, function(convar_name, value_old, value_new)
					if not LocalPlayer():IsAdmin() and not LocalPlayer():IsSuperAdmin() then
						if not cvar_locker[cvar_name] then
							cvar_locker[cvar_name] = true
							timer.Create('bgn_timer_back_cvar_' .. cvar_name, 0.1, 1, function()
								if not cvar_locker[cvar_name] then return end
								RunConsoleCommand(cvar_name, value_old)
								timer.Create('bgn_timer_reset_back_cvar_' .. cvar_name, 0.1, 1, function()
									if not cvar_locker[cvar_name] then return end
									cvar_locker[cvar_name] = false
								end)
							end)
						end
						return
					end

					bgNPC.GlobalCvars[cvar_name].value = value_new
	
					net.Start('bgn_gcvars_change_from_server')
					net.WriteString(cvar_name)
					net.WriteFloat(value_new)
					net.SendToServer()
				end)
			end
		end
	end)
end
bgNPC.GlobalCvars = bgNPC.GlobalCvars or {}

if SERVER then
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

			net.Start('bgn_gcvars_change_from_client')
			net.WriteString(cvar_name)
			net.WriteFloat(value)
			net.SendOmit(ply)
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
		
		timer.Simple(2.5, function()
			if not IsValid(ply) then
				bgNPC:Log('Failed to sync global cvars', 'Global Cvars')
				return
			end

			net.Start('bgn_gcvars_register_all_from_client')
			net.WriteTable(bgNPC.GlobalCvars)
			net.Send(ply)
		end)

		ply.bgNPCGlobalConvarSync = true
	end)
else
	local cvar_locker = {}
	local cvar_locker_another = {}

	net.Receive('bgn_gcvars_register_all_from_client', function()
		bgNPC.GlobalCvars = net.ReadTable()
		for cvar_name, cvar_data in pairs(bgNPC.GlobalCvars) do
			CreateConVar(cvar_name, cvar_data.value, cvar_data.flag, 
					cvar_data.helptext, cvar_data.min, cvar_data.max)

			RunConsoleCommand(cvar_name, cvar_data.value)
			bgNPC:Log('Sync [' .. cvar_name .. ']: ' .. cvar_data.value, 'Cvars')

			cvar_locker[cvar_name] = cvar_locker[cvar_name] or false

			cvars.AddChangeCallback(cvar_name, function(convar_name, value_old, value_new)
				if value_old == value_new then return end
				
				if not cvar_locker_another[convar_name] then
					if not LocalPlayer():IsAdmin() and not LocalPlayer():IsSuperAdmin() then
						if not cvar_locker[convar_name] then
							cvar_locker[convar_name] = true
							timer.Remove('bgn_timer_back_cvar_' .. convar_name)

							timer.Create('bgn_timer_back_cvar_' .. convar_name, 0.1, 1, function()
								if not cvar_locker[convar_name] then return end
								RunConsoleCommand(convar_name, value_old)

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
end
cvars.AddChangeCallback('bgn_max_npc', function(cvar_name, old_value, new_value)
	if old_value == new_value then return end

	bgNPC:Log('Change max npcs on map: ' .. new_value, 'Cvars')
	timer.Remove('BGNCvarSyncTypeAfterChangeMaxNPC')

	timer.Create('BGNCvarSyncTypeAfterChangeMaxNPC', 0.5, 1, function()
		for npcType, v in pairs(bgNPC.cfg.npcs_template) do
			timer.Remove('BGNCvarSyncType_' .. npcType)
			
			timer.Create('BGNCvarSyncType_' .. npcType, 1, 1, function()
				local type_cvar_name = 'bgn_npc_type_max_' .. npcType
				local fullness = bgNPC:GetFullness(npcType)

				bgNPC:Log('Update new fullness from [' .. npcType .. ']: ' .. fullness, 'Cvars')
				RunConsoleCommand(type_cvar_name, fullness)
		
				net.Start('bgn_gcvars_change_from_client')
				net.WriteString(type_cvar_name)
				net.WriteFloat(fullness)
				net.Broadcast()
			end)
		end
	end)
end)
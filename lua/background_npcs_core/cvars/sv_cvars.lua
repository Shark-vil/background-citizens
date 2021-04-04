cvars.AddChangeCallback('bgn_max_npc', function(cvar_name, old_value, new_value)
	if old_value == new_value then return end

	for npcType, v in pairs(bgNPC.cfg.npcs_template) do
		local type_cvar_name = 'bgn_npc_type_max_' .. npcType
		local fullness = bgNPC:GetFullness(npcType)
		RunConsoleCommand(type_cvar_name, fullness)
	end
end)
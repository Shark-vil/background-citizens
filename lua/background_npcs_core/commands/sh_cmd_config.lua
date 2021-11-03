scommand.Create('bgn_config_reload').OnShared(function()
	bgNPC:ClearActorsConfig()
end).Access( { isAdmin = true } ).Broadcast().Register()

scommand.Create('bgn_config_view').OnShared(function(_, _, args)
	local actor_type = args[1]
	if not bgNPC.cfg.npcs_template[actor_type] then return end
	PrintTable(bgNPC:GetActorConfig(actor_type))
end).AutoComplete(function(cmd)
	local actors_type_list = {}

	for actor_type, _ in pairs(bgNPC.cfg.npcs_template) do
		table.insert(actors_type_list, cmd .. ' "' .. actor_type .. '"')
	end

	return actors_type_list
end).Access( { isAdmin = true } ).Register()
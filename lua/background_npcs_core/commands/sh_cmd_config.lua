scommand.Create('bgn_config_reload').OnShared(function()
	bgNPC:ClearActorsConfig()
end).Access( { isAdmin = true } ).Broadcast().Register()

scommand.Create('bgn_config_view').OnShared(function(_, _, args)
	local actor_type = args[1]
	if not bgNPC.cfg.actors[actor_type] then return end
	PrintTable(bgNPC:GetActorConfig(actor_type))
end).AutoComplete(function(cmd)
	local actors_type_list = {}

	for actor_type, _ in pairs(bgNPC.cfg.actors) do
		table.insert(actors_type_list, cmd .. ' "' .. actor_type .. '"')
	end

	return actors_type_list
end).Access( { isAdmin = true } ).Register()

scommand.Create('bgn_print_spawned_actors_count').OnClient(function(_, _, args)
	print(bgNPC:Count(args[1]))
end).AutoComplete(function(cmd)
	local actors_type_list = {}

	for actor_type, _ in pairs(bgNPC.cfg.actors) do
		table.insert(actors_type_list, cmd .. ' "' .. actor_type .. '"')
	end

	return actors_type_list
end).Access( { isAdmin = true } ).Register()
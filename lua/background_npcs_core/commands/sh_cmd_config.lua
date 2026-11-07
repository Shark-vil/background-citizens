local function ActorTypesAutoComplete(cmd)
	local list = {}
	for actor_type in pairs(bgNPC.cfg.actors) do
		list[#list + 1] = cmd .. ' "' .. actor_type .. '"'
	end
	return list
end

local function ConfigReload()
	bgNPC.Config.ClearCache()
end

bgNPC.Commands.Register('bgn_config_reload', {
	admin = true,
	broadcast = true,
	server = ConfigReload,
	client = ConfigReload,
})

local function ConfigView(_, _, args)
	local actor_type = args[1]
	if not bgNPC.cfg.actors[actor_type] then return end
	PrintTable(bgNPC.Config.GetActor(actor_type))
end

bgNPC.Commands.Register('bgn_config_view', {
	admin = true,
	server = ConfigView,
	client = ConfigView,
	autocomplete = ActorTypesAutoComplete,
})

local function PrintActorsCount(_, _, args)
	print(bgNPC.Actors.Count(args[1]))
end

bgNPC.Commands.Register('bgn_print_spawned_actors_count', {
	admin = true,
	server = PrintActorsCount,
	client = PrintActorsCount,
	autocomplete = ActorTypesAutoComplete,
})

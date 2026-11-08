--
cvars.AddChangeCallback('bgn_max_npc', function(cvar_name, old_value, new_value)
	if old_value == new_value then return end

	for npcType, v in pairs(bgNPC.cfg.actors) do
		local type_cvar_name = 'bgn_npc_type_max_' .. npcType
		local fullness = bgNPC.Config.GetFullness(npcType)
		RunConsoleCommand(type_cvar_name, fullness)
	end
end)

-- server cvars of the modules: every change is announced to all players like the synchronized ones
for _, name in ipairs({
	'bgn_actor_body', 'bgn_lod_near_radius', 'bgn_brain', 'bgn_tasks_budget_ms',
	'bgn_nav_generator_max_nodes', 'bgn_nav_provider',
}) do
	bgNPC.CVars.Watch(name)
end

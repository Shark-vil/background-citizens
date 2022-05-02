if bgNPC.cfg.npcs_template and istable(bgNPC.cfg.npcs_template) then
	for actor_type, actor_data in pairs(bgNPC.cfg.npcs_template) do
		if isstring(actor_type) and istable(actor_data) and not bgNPC.cfg.actors[actor_type] then
			bgNPC.cfg.actors[actor_type] = actor_data
		end
	end
end
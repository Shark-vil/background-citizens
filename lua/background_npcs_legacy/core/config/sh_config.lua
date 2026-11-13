function bgNPC.cfg:SetActor(actorType, data)
	if not isstring(actorType) or not istable(data) then return end
	if not data.class then return end

	bgNPC.cfg.actors[actorType] = data
	bgNPC.cfg.npcs_template[actorType] = data
end

function bgNPC.cfg:EditActor(actorType, data)
	if not isstring(actorType) or not istable(data) then return end

	bgNPC.cfg.actors[actorType] = bgNPC.cfg.actors[actorType] or {}
	table.Merge(bgNPC.cfg.actors[actorType], data)
end
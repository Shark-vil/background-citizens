function bgNPC.cfg:SetActor(actorType, data)
	bgNPC.cfg.actors[actorType] = data
end

function bgNPC.cfg:EditActor(actorType, data)
	bgNPC.cfg.actors[actorType] = bgNPC.cfg.actors[actorType] or {}
	table.Merge(bgNPC.cfg.actors[actorType], data)
end
TOOL.AddToMenu = false
TOOL.Category = 'Background NPCs'
TOOL.Name = 'Actor spawner'

function TOOL:LeftClick(tr)
	local actorType = self.actorType

	if not actorType then return false end
	if not bgNPC or not bgNPC.cfg or not bgNPC.cfg.actors then return false end
	if not bgNPC.cfg.actors[actorType] then return false end

	if SERVER then
		local actor = bgNPC:SpawnActor(actorType, tr.HitPos + Vector(0, 0, 10))
		if not actor then return false end

		local npc = actor:GetNPC()
		if not IsValid(npc) then return false end

		actor:RandomState()
		actor.eternal = true

		DoPropSpawnedEffect(npc)

		local ply = self:GetOwner()

		undo.Create('Actor')
		undo.SetPlayer(ply)
		undo.AddEntity(npc)
		undo.Finish('Actor ( ' .. actorType .. ' )')

		ply:AddCleanup('npcs', npc)
	end

	return true
end

if CLIENT then
	local tool_class = 'tool.bgn_actor_spawner'

	language.Add(tool_class .. '.name', 'Actor spawner')
	language.Add(tool_class .. '.desc', 'Spawns NPCs selected via the spawnmenu')
	language.Add(tool_class .. '.left', 'Spawn NPCs at the clicked location on the map')
end
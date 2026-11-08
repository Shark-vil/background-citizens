-- iNPC integration ("iNPC - Artificial Intelligence Upgrade" and its forks).
-- iNPC takes over every "npc_*" each tick (factions, patrols, relationships, schedules)
-- unless the NPC has "inpcIgnore" set, the same flag it uses for VJ Base NPCs.
-- Actors are driven by Background NPCs, so iNPC must leave them alone.

hook.Add('BGN_InitActor', 'BGN_iNPC_IgnoreActors', function(actor)
	local npc = actor:GetNPC()
	if IsValid(npc) then npc.inpcIgnore = true end
end)

hook.Add('OnNPCKilled', 'BGN_OnKilledActor', function(npc, attacker, inflictor)
	local actor = bgNPC:GetActor(npc)

	if not actor then return end

	hook.Run('BGN_OnKilledActor', actor, attacker)
end)


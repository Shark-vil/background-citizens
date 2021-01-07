hook.Add("OnNPCKilled", "BGN_OnKilledActor", function(npc, attacker, inflictor)
    local actor = bgCitizens:GetActor(npc)
    if actor ~= nil then
        hook.Run('BGN_OnKilledActor', actor, attacker)
    end
end)
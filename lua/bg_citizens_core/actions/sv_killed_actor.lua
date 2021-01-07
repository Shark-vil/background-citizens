hook.Add("OnNPCKilled", "bgCitizens_OnNPCKilled", function(npc, attacker, inflictor)
    local actor = bgCitizens:GetActor(npc)
    if actor ~= nil then
        hook.Run('bgCitizens_OnKilledActor', actor, attacker)
    end
end)
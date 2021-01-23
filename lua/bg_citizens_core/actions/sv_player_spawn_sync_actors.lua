hook.Add("PlayerSpawn", "BGN_SyncActorsOnPlayerSpawn", function(ply)
    if ply.BGN_SyncActorsOnPlayerSpawn then return end
    
    timer.Simple(3, function()
        if not IsValid(ply) then return end

        local sync_time = 1

        for _, actor in ipairs(bgNPC:GetAll()) do
            if actor:IsAlive() then
                local type = actor:GetType()
                local npc = actor:GetNPC()
                bgNPC:TemporaryVectorVisibility(npc, 3)

                timer.Simple(sync_time, function()
                    if not IsValid(npc) then return end

                    net.InvokeAll('bgn_add_actor_from_client', type, npc)

                    timer.Simple(1, function()
                        if not IsValid(npc) then return end

                        actor:SyncData()
                    end)
                end)
                
                sync_time = sync_time + 0.05
            end
        end
    end)

    ply.BGN_SyncActorsOnPlayerSpawn = true
end)
hook.Add("PlayerSpawn", "BGN_SyncActorsOnPlayerSpawn", function(ply)
    if ply.BGN_SyncActorsOnPlayerSpawn then return end
    
    timer.Simple(4, function()
        if not IsValid(ply) then return end

        local period = 0.01
        local sync_time = period

        for _, actor in ipairs(bgNPC:GetAll()) do
            timer.Simple(sync_time, function()
                if actor == nil or not actor:IsAlive() then return end
                actor:SyncData()
            end)
            sync_time = sync_time + period
        end
    end)

    ply.BGN_SyncActorsOnPlayerSpawn = true
end)
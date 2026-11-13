local bgNPC = bgNPC
--
async.Add('BGN_ThinkProcess', function(yield, wait)
    while true do
        local actors = bgNPC:GetAll()
        for i = 1, #actors do
            local actor = actors[i]
            if actor and actor.start_think and actor:IsAlive() then
                actor:Think()
                yield()
            end
        end

        yield()
    end
end)
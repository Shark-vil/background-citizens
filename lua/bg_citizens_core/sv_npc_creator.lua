timer.Create('bgCitizensCreator', GetConVar('bg_citizens_spawn_period'):GetFloat(), 0, function()
    local bg_citizens_enable = GetConVar('bg_citizens_enable'):GetInt()

    if bg_citizens_enable <= 0 then
        return
    end

    local bg_citizens_max_npc = GetConVar('bg_citizens_max_npc'):GetInt()
    
    bgCitizens:ClearRemovedNPCs()

    if #bgCitizens:GetAll() < bg_citizens_max_npc then
        for _, npc_data in ipairs(bgCitizens.npc_classes) do
            local count = table.Count(bgCitizens:GetAllNPCsByType(npc_data.type))
            local max = math.Round(((npc_data.fullness / 100) * bg_citizens_max_npc))

            if max <= 0 or count > max then
                goto skip
            end

            bgCitizens:SpawnActor(npc_data.type)

            ::skip::
        end
    end
end)

hook.Add("Think", "bgCitizensLoopAnimatorController", function()
    for _, actor in ipairs(bgCitizens:GetAll()) do
        local npc = actor:GetNPC()
        if IsValid(npc) then
            if actor:IsAnimationPlayed() then
                npc:SetNPCState(NPC_STATE_SCRIPT)
                npc:SetSchedule(SCHED_SLEEP)

                -- print(tostring(actor.anim_is_loop) .. ' - ' .. actor.anim_name)
                if actor:IsLoopSequence() then
                    if actor:IsSequenceLoopFinished() then
                        actor:ResetSequence()
                    elseif actor:IsSequenceFinished() then
                        npc:ResetSequenceInfo()
                        npc:SetSequence(npc:LookupSequence(actor.anim_name))
                    end
                elseif actor:IsSequenceFinished() then
                    actor:ResetSequence()
                end

                -- print(actor.anim_name)
            end
        end
    end
end)

-- hook.Remove("Tick", "bgCitizensLoopAnimatorController")
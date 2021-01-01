hook.Add('Think', 'bgCitizens_StateProtectionAction', function()
    for _, actor in pairs(bgCitizens:GetAll()) do
        local npc = actor:GetNPC()
        if IsValid(npc) then
            local state = actor:GetState()

            for _, stData in pairs(actor:GetStateData()) do
                if state == 'defense' and IsValid(stData.target) then
                    bgCitizens:SetActorWeapon(actor)

                    if npc:Disposition(stData.target) ~= D_HT then
                        npc:AddEntityRelationship(stData.target, D_HT, 99)
                    end

                    if npc:GetTarget() ~= stData.target then
                        npc:SetTarget(stData.target)
                    end

                    if stData.delay < CurTime() then
                        npc:SetSaveValue("m_vecLastPosition", stData.target:GetPos())
                        npc:SetSchedule(SCHED_FORCED_GO_RUN)
                        stData.delay = CurTime() + 5
                    end
                end
            end
        end
    end
end)
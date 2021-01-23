timer.Create('BGN_Timer_CallingPoliceController', 0.5, 0, function()
    for _, actor in ipairs(bgNPC:GetAll()) do
        local npc = actor:GetNPC()
        if IsValid(npc) then
            local state = actor:GetState()
            local data = actor:GetStateData()

            if state == 'calling_police' then
                if not GetConVar('bgn_enable_wanted_mode'):GetBool() 
                    or #bgNPC:GetAllByType('police') == 0 
                then
                    actor:Fear()
                    goto skip
                end

                local target = actor:GetNearTarget()
                if IsValid(target) then
                    if npc:GetPos():DistToSqr(target:GetPos()) < 90000 then -- 300 ^ 2
                        actor:Fear()
                        goto skip
                    end
                end

                if data.calling_time == nil then
                    data.calling_time = CurTime() + 15
                    npc:EmitSound('buttons/button19.wav', 500, 100, 1, CHAN_AUTO)
                else
                    local asset = bgNPC:GetModule('wanted')

                    if data.calling_time < CurTime() then
                        for _, enemy in pairs(actor.targets) do
                            if IsValid(enemy) then
                                if asset:HasWanted(enemy) then
                                    local c_Wanted = asset:GetWanted(enemy)
                                    c_Wanted:UpdateWanted(enemy)
                                else
                                    asset:AddWanted(enemy)
                                end
                            end
                        end

                        npc:EmitSound('buttons/combine_button1.wav', 500, 100, 1, CHAN_AUTO)
                        actor:Fear()
                    else
                        if not actor:HasSequence('Crouch_IdleD') then
                            actor:SetNextSequence('Crouch_To_Stand')
                            actor:PlayStaticSequence('Crouch_IdleD', true, 8)
                        end

                        data.btn_click_delay = data.btn_click_delay or 0
                        if data.btn_click_delay < CurTime() then
                            npc:EmitSound('buttons/button18.wav', 450, 100, 1, CHAN_AUTO)
                            data.btn_click_delay = CurTime() + 1
                        end
                    end
                end
            end
        end

        ::skip::
    end
end)
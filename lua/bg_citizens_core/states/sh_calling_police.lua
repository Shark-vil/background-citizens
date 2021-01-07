if SERVER then
    hook.Add("BGN_PostSpawnNPC", "BGN_AddWantedTargetsForNewNPCs", function(actor)
        if #bgNPC.wanted == 0 then return end
        if actor:GetType() == 'police' or actor:GetType() == 'citizen' then
            for _, enemy in pairs(bgNPC.wanted) do
                actor:AddTarget(enemy)
            end
        end
    end)

    hook.Add("PlayerDeath", "BGN_ResetWantedModeForDeceasedPlayer", function(victim, inflictor, attacker)
        if bgNPC:GetEntityVariable(victim, 'is_wanted', false) then

            bgNPC:SetEntityVariable(victim, 'is_wanted', false)
            bgNPC:SetEntityVariable(victim, 'wanted_time', 0)
            bgNPC:SetEntityVariable(victim, 'wanted_time_reset', 0)

            table.RemoveByValue(bgNPC.wanted, victim)
        end
    end)

    timer.Create('BGN_Timer_CheckingTheWantesStatusOfTargets', 1, 0, function()
        local polices = bgNPC:GetAllByType('police')
        local citizens = bgNPC:GetAllByType('citizen')

        local witnesses = {}
        table.Inherit(witnesses, polices)
        table.Inherit(witnesses, citizens)

        for i = #bgNPC.wanted, 1, -1 do
            local enemy = bgNPC.wanted[i]
            if not IsValid(enemy) then
                table.remove(bgNPC.wanted, i)
            elseif enemy:IsPlayer() then
                local wanted_time = bgNPC:GetEntityVariable(enemy, 'wanted_time_reset', 0)
                local wait_time = wanted_time - CurTime()
                if wait_time < 0 then wait_time = 0 end

                bgNPC:SetEntityVariable(enemy, 'wanted_time', math.Round(wait_time))
                
                for _, actor in ipairs(witnesses) do
                    local npc = actor:GetNPC()
                    if IsValid(npc) and table.HasValue(actor.targets, enemy) then
                        local dist = npc:GetPos():DistToSqr(enemy:GetPos())

                        if dist <= 360000 then -- 600 ^ 2
                            bgNPC:SetEntityVariable(enemy, 'wanted_time_reset', 
                                CurTime() + bgNPC.wanted_time)

                            bgNPC:SetEntityVariable(enemy, 'wanted_time', bgNPC.wanted_time)

                            goto skip
                        end

                        if dist <= 640000 then -- 800 ^ 2
                            local tr = util.TraceLine({
                                start = npc:EyePos(),
                                endpos = enemy:EyePos(),
                                filter = function(ent) 
                                    if ent ~= npc then
                                        return true
                                    end
                                end
                            })

                            if tr.Hit and IsValid(tr.Entity) and tr.Entity == enemy then
                                bgNPC:SetEntityVariable(enemy, 'wanted_time_reset', 
                                    CurTime() + bgNPC.wanted_time)

                                bgNPC:SetEntityVariable(enemy, 'wanted_time', bgNPC.wanted_time)

                                goto skip
                            end
                        end
                    end
                end

                local wanted_time_reset = bgNPC:GetEntityVariable(enemy, 'wanted_time_reset', 0)
                
                if wanted_time_reset < CurTime() then
                    for _, actor in ipairs(bgNPC:GetAll()) do
                        actor:RemoveTarget(enemy)
                    end

                    bgNPC:SetEntityVariable(enemy, 'is_wanted', false)
                    bgNPC:SetEntityVariable(enemy, 'wanted_time_reset', 0)
                    bgNPC:SetEntityVariable(enemy, 'wanted_time', 0)

                    bgNPC.killing_statistic[enemy] = {}

                    table.remove(bgNPC.wanted, i)
                end
            end

            ::skip::
        end
    
        for _, actor in pairs(polices) do
            if #bgNPC.wanted == 0 then
                break
            end
            
            if actor:GetState() ~= 'defense' then
                actor:Defense()
            end
        end

        for _, actor in pairs(citizens) do
            if #bgNPC.wanted == 0 then
                break
            end
    
            if actor:GetState() ~= 'fear' then
                actor:Fear()
            end
        end
    end)

    timer.Create('BGN_Timer_CallingPoliceController', 0.5, 0, function()
        for _, actor in pairs(bgNPC:GetAll()) do
            local npc = actor:GetNPC()
            if IsValid(npc) then
                local state = actor:GetState()
                local data = actor:GetStateData()
    
                if state == 'calling_police' then
                    if not bgNPC.wanted_mode then
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
                        if data.calling_time < CurTime() then
                            for _, enemy in pairs(actor.targets) do
                                if IsValid(enemy) and not table.HasValue(bgNPC.wanted, enemy) then
                                    local ActorEnemy = bgNPC:GetActor(enemy)
                                    if ActorEnemy == nil or ActorEnemy:GetType() ~= 'police' then
                                        table.insert(bgNPC.wanted, enemy)
                                        
                                        bgNPC:SetEntityVariable(enemy, 'is_wanted', true)

                                        bgNPC:SetEntityVariable(enemy, 'wanted_time_reset', 
                                            CurTime() + bgNPC.wanted_time)

                                        bgNPC:SetEntityVariable(enemy, 'wanted_time', 
                                            bgNPC.wanted_time)
                                    end
                                end
                            end

                            for _, ActorPolice in pairs(bgNPC:GetAllByType('police')) do
                                for _, enemy in pairs(actor.targets) do
                                    ActorPolice:AddTarget(enemy)
                                end
                        
                                if ActorPolice:GetState() ~= 'defense' then
                                    ActorPolice:Defense()
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
else
    local color_text = Color(82, 223, 255)
    local color_black = Color(0, 0, 0)

    hook.Add('HUDPaint', 'BGN_DrawWantedText', function()
        if not bgNPC:GetEntityVariable(LocalPlayer(), 'is_wanted', false) then return end

        local timeleft = bgNPC:GetEntityVariable(LocalPlayer(), 'wanted_time', 
            bgNPC.wanted_time)
        
        if timeleft < 0 then timeleft = 0 end
        
		surface.SetFont("Trebuchet24")
		surface.SetTextColor(255, 0, 0)
		surface.SetTextPos(30, 30) 
        surface.DrawText('YOU WANTED! The search will end in ' .. timeleft .. ' seconds...')
	end)

    local halo_color = Color(0, 60, 255)
    hook.Add("PreDrawHalos", "BGN_RenderOutlineOnNPCCallingPolice", function()
        local npcs = {}

        for _, actor in ipairs(bgNPC:GetAll()) do
            local npc = actor:GetNPC()
            if IsValid(npc) then
                if actor:GetState() == 'calling_police' then
                    if npc:GetPos():DistToSqr(LocalPlayer():GetPos()) < 6250000 then -- 2500 ^ 2
                        table.insert(npcs, npc)
                    end
                end
            end
        end

        if #npcs ~= 0 then
            halo.Add(npcs, halo_color, 3, 3, 2)
        end
    end)

    hook.Add('PostDrawOpaqueRenderables', 'BGN_RenderTextAboveNPCCallingPolice', function()	
        for _, actor in ipairs(bgNPC:GetAll()) do
            local npc = actor:GetNPC()
            if IsValid(npc) then
                if actor:GetState() == 'calling_police' then
                    if npc:GetPos():DistToSqr(LocalPlayer():GetPos()) < 6250000 then -- 2500 ^ 2
                        local angle = LocalPlayer():EyeAngles()
                        angle:RotateAroundAxis(angle:Forward(), 90)
                        angle:RotateAroundAxis(angle:Right(), 90)
                
                        cam.Start3D2D(npc:GetPos() + npc:GetForward() + npc:GetUp() * 78, angle, 0.25)
                            draw.SimpleTextOutlined('Calling police...', 
                                "DermaLarge", 0, -15, color_text, 
                                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
                        cam.End3D2D()
                    end
                end
            end
        end
	end)
end
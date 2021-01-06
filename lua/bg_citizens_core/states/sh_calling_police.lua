if SERVER then
    hook.Add("bgCitizens_PostSpawnNPC", "bgCitizens_AddWantedTargetsFromPolice", function(actor)
        if #bgCitizens.wanted == 0 then return end
        if actor:GetType() == 'police' or actor:GetType() == 'citizen' then
            for _, enemy in pairs(bgCitizens.wanted) do
                actor:AddTarget(enemy)
            end
        end
    end)

    hook.Add("PlayerDeath", "bgCitizens_WantedResetDeath", function(victim, inflictor, attacker)
        if victim:GetNWBool('bgCitizenWanted') then
            victim:SetNWBool('bgCitizenWanted', false)
            victim.bgCitizenWantedReset = 0
            bgCitizens.killing_statistic[victim] = {}
            table.RemoveByValue(bgCitizens.wanted, victim)
        end
    end)

    timer.Create('bgCitizens_WantedChecker', 1, 0, function()
        local polices = bgCitizens:GetAllByType('police')
        local citizens = bgCitizens:GetAllByType('citizen')

        local witnesses = {}
        table.Inherit(witnesses, polices)
        table.Inherit(witnesses, citizens)

        for i = #bgCitizens.wanted, 1, -1 do
            local enemy = bgCitizens.wanted[i]
            if not IsValid(enemy) then
                table.remove(bgCitizens.wanted, i)
            elseif enemy:IsPlayer() then
                local to_end_time = enemy.bgCitizenWantedReset - CurTime()
                if to_end_time < 0 then to_end_time = 0 end

                enemy:SetNWInt('bgCitizenWantedReset', math.Round(to_end_time))
                
                for _, actor in ipairs(witnesses) do
                    local npc = actor:GetNPC()
                    if IsValid(npc) and table.HasValue(actor.targets, enemy) then
                        local dist = npc:GetPos():DistToSqr(enemy:GetPos())

                        if dist <= 360000 then -- 600 ^ 2
                            enemy.bgCitizenWantedReset = CurTime() + bgCitizens.wanted_time
                            enemy:SetNWInt('bgCitizenWantedReset', bgCitizens.wanted_time)
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
                                enemy.bgCitizenWantedReset = CurTime() + bgCitizens.wanted_time
                                enemy:SetNWInt('bgCitizenWantedReset', bgCitizens.wanted_time)
                                goto skip
                            end
                        end
                    end
                end
                
                if enemy.bgCitizenWantedReset < CurTime() then
                    for _, actor in ipairs(bgCitizens:GetAll()) do
                        actor:RemoveTarget(enemy)
                    end

                    if enemy:IsPlayer() then
                        enemy:SetNWBool('bgCitizenWanted', false)
                    end

                    enemy.bgCitizenWantedReset = 0
                    table.remove(bgCitizens.wanted, i)
                end
            end

            ::skip::
        end
    
        for _, actor in pairs(polices) do
            if #bgCitizens.wanted == 0 then
                break
            end
            
            if actor:GetState() ~= 'defense' then
                actor:SetState('defense', {
                    delay = 0
                })
            end
        end

        for _, actor in pairs(citizens) do
            if #bgCitizens.wanted == 0 then
                break
            end
    
            if actor:GetState() ~= 'fear' then
                actor:SetState('fear', {
                    delay = 0
                })
            end
        end
    end)

    timer.Create('bgCitizens_CallingPolice', 0.5, 0, function()
        for _, actor in pairs(bgCitizens:GetAll()) do
            local npc = actor:GetNPC()
            if IsValid(npc) then
                local state = actor:GetState()
                local data = actor:GetStateData()
    
                if state == 'calling_police' then
                    if not bgCitizens.wanted_mode then
                        actor:SetState('fear', {
                            delay = 0
                        })
                        goto skip
                    end

                    local target = actor:GetNearTarget()     
                    if IsValid(target) then
                        if npc:GetPos():DistToSqr(target:GetPos()) < 90000 then -- 300 ^ 2
                            actor:SetState('fear', {
                                delay = 0
                            })
                            goto skip
                        end
                    end
    
                    if data.calling_time == nil then
                        data.calling_time = CurTime() + 15
                        npc:EmitSound('buttons/button19.wav', 500, 100, 1, CHAN_AUTO)
                    else
                        if data.calling_time < CurTime() then
                            for _, enemy in pairs(actor.targets) do
                                if IsValid(enemy) and not table.HasValue(bgCitizens.wanted, enemy) then
                                    local ActorEnemy = bgCitizens:GetActor(enemy)
                                    if ActorEnemy == nil or ActorEnemy:GetType() ~= 'police' then
                                        table.insert(bgCitizens.wanted, enemy)
                                        if enemy:IsPlayer() then
                                            enemy:SetNWBool('bgCitizenWanted', true)
                                        end
                                        enemy.bgCitizenWantedReset = CurTime() + bgCitizens.wanted_time
                                        enemy:SetNWInt('bgCitizenWantedReset', bgCitizens.wanted_time)
                                    end
                                end
                            end

                            for _, ActorPolice in pairs(bgCitizens:GetAllByType('police')) do
                                for _, enemy in pairs(actor.targets) do
                                    ActorPolice:AddTarget(enemy)
                                end
                        
                                if ActorPolice:GetState() ~= 'defense' then
                                    ActorPolice:SetState('defense', {
                                        delay = 0
                                    })
                                end
                            end

                            npc:EmitSound('buttons/combine_button1.wav', 500, 100, 1, CHAN_AUTO)

                            actor:SetState('fear', {
                                delay = 0
                            })
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

    hook.Add('HUDPaint', 'bgCitizensWantedTextDrawing', function()
        if not LocalPlayer():GetNWBool('bgCitizenWanted') then return end

        local to_end_time = LocalPlayer():GetNWInt('bgCitizenWantedReset')
        
		surface.SetFont("Trebuchet24")
		surface.SetTextColor(255, 0, 0)
		surface.SetTextPos(30, 30) 
		surface.DrawText('YOU WANTED! The search will end in '..to_end_time..' seconds...')
	end)

    local halo_color = Color(0, 60, 255)
    hook.Add("PreDrawHalos", "bgCitizensCallingPoliceHalpDrawing", function()
        local npcs = {}

        for _, actor in ipairs(bgCitizens:GetAll()) do
            local npc = actor:GetNPC()
            if IsValid(npc) then
                if actor:GetState() == 'calling_police' then
                    if npc:GetPos():DistToSqr(LocalPlayer():GetPos()) < 4000000 then -- 2000 ^ 2
                        table.insert(npcs, npc)
                    end
                end
            end
        end

        if #npcs ~= 0 then
            halo.Add(npcs, halo_color, 3, 3, 2)
        end
    end)

    hook.Add('PostDrawOpaqueRenderables', 'bgCitizensCallingPoliceTextDrawing', function()	
        for _, actor in ipairs(bgCitizens:GetAll()) do
            local npc = actor:GetNPC()
            if IsValid(npc) then
                if actor:GetState() == 'calling_police' then
                    if npc:GetPos():DistToSqr(LocalPlayer():GetPos()) < 4000000 then -- 2000 ^ 2
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
if SERVER then
    local function SetWantedVariables(target)
        local wanted_time = GetConVar('bgn_wanted_time'):GetFloat()

        bgNPC:SetEntityVariable(target, 'is_wanted', true)
        bgNPC:SetEntityVariable(target, 'wanted_time_reset', CurTime() + wanted_time)
        bgNPC:SetEntityVariable(target, 'wanted_time', wanted_time)
    end

    function bgNPC:AddWanted(target)
        if not table.HasValue(bgNPC.wanted, target) then
            SetWantedVariables(target)
            table.insert(bgNPC.wanted, target)
            hook.Run('BGN_AddWantedTarget', target)
            net.InvokeAll('bgn_add_wanted_target', target)
        end
    end

    function bgNPC:UpdateWanted(target)
        if self:IsWanted(target) then
            SetWantedVariables(target)
        end
    end

    function bgNPC:IsWanted(target)
        return table.HasValue(bgNPC.wanted, target)
    end

    function bgNPC:RemoveWanted(target)
        if not IsValid(target) then return end
        bgNPC:SetEntityVariable(target, 'is_wanted', false)
        bgNPC:SetEntityVariable(target, 'wanted_time_reset', 0)
        bgNPC:SetEntityVariable(target, 'wanted_time', 0)

        bgNPC.killing_statistic[target] = {}

        table.RemoveByValue(bgNPC.wanted, target)
        hook.Run('BGN_RemoveWantedTarget', target)
        net.InvokeAll('bgn_remove_wanted_target', target)
    end

    function bgNPC:ClearWanted()
        for _, target in ipairs(bgNPC.wanted) do
            self:RemoveWanted(target)
        end
    end

    hook.Add("BGN_AddWantedTarget", "BGN_AddWantedTargetFromResidents", function(target)
        for _, actor in ipairs(bgNPC:GetAll()) do
            if IsValid(actor:GetNPC()) and actor:HasTeam('residents') then
                actor:AddTarget(target)

                if actor:HasState('idle') or actor:HasState('walk') then
                    actor:SetState(actor:GetReactionForProtect())
                end
            end
        end
    end)

    hook.Add("BGN_RemoveWantedTarget", "BGN_RemoveWantedTargetFromResidents", function(target)
        for _, actor in ipairs(bgNPC:GetAll()) do
            if IsValid(actor:GetNPC()) and actor:HasTeam('residents') then
                actor:RemoveTarget(target)
            end
        end
    end)

    hook.Add("BGN_PostSpawnNPC", "BGN_AddWantedTargetsForNewNPCs", function(actor)
        if #bgNPC.wanted == 0 then return end
        if actor:HasTeam('residents') then
            for _, enemy in pairs(bgNPC.wanted) do
                actor:AddTarget(enemy)

                if actor:HasState('idle') or actor:HasState('walk') then
                    actor:SetState(actor:GetReactionForProtect())
                end
            end
        end
    end)

    hook.Add("PlayerDeath", "BGN_ResetWantedModeForDeceasedPlayer", function(victim, inflictor, attacker)
        if bgNPC:IsWanted(victim) then
            bgNPC:RemoveWanted(victim)
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
                            bgNPC:UpdateWanted(enemy)
                            actor:AddTarget(enemy)
                            if actor:HasState('idle') or actor:HasState('walk') then
                                actor:SetState(actor:GetReactionForProtect())
                            end
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
                                bgNPC:UpdateWanted(enemy)
                                actor:AddTarget(enemy)
                                if actor:HasState('idle') or actor:HasState('walk') then
                                    actor:SetState(actor:GetReactionForProtect())
                                end
                                goto skip
                            end
                        end
                    end
                end

                local wanted_time_reset = bgNPC:GetEntityVariable(enemy, 'wanted_time_reset', 0)
                
                if wanted_time_reset < CurTime() then
                    bgNPC:RemoveWanted(enemy)
                end
            end

            ::skip::
        end
    end)
else
    net.RegisterCallback('bgn_add_wanted_target', function(ply, target)
        if IsValid(target) then
            table.insert(bgNPC.wanted, target)
        end
    end)

    net.RegisterCallback('bgn_remove_wanted_target', function(ply, target)
        if IsValid(target) then
            table.RemoveByValue(bgNPC.wanted, target)
        end
    end)

    local wanted_halo_color = Color(240, 34, 34)
    hook.Add("PreDrawHalos", "BGN_RenderOutlineOnNPCCallingPolice", function()
        if #bgNPC.wanted == 0 then return end
        for _, ent in ipairs(bgNPC.wanted) do
            if IsValid(ent) then
                halo.Add(ent, wanted_halo_color, 3, 3, 2)
            end
        end
    end)

    local color_text = Color(82, 223, 255)
    local color_black = Color(0, 0, 0)

    hook.Add('HUDPaint', 'BGN_DrawWantedText', function()
        if not bgNPC:GetEntityVariable(LocalPlayer(), 'is_wanted', false) then return end

        local timeleft = bgNPC:GetEntityVariable(LocalPlayer(), 'wanted_time', 
            GetConVar('bgn_wanted_time'):GetFloat())
        
        if timeleft < 0 then timeleft = 0 end
        
		surface.SetFont("Trebuchet24")
		surface.SetTextColor(255, 0, 0)
		surface.SetTextPos(30, 30) 
        surface.DrawText('YOU ARE WANTED! The search will end in ' .. timeleft .. ' seconds...')
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
function bgCitizens:IsFearNPC(npc)
    if IsValid(npc) and npc:IsNPC() then
        local schedule = npc:GetCurrentSchedule()
        if npc:IsCurrentSchedule(SCHED_RUN_FROM_ENEMY) 
            or npc:IsCurrentSchedule(SCHED_WAKE_ANGRY)
            or schedule == 159
        then
            return true
        end
    end
    return false
end

function bgCitizens:SetActorWeapon(actor)
    local weapons = actor:GetData().weapons
    if weapons ~= nil and #weapons ~= 0 then
        local npc = actor:GetNPC()
        local active_weapon = npc:GetActiveWeapon()

        if IsValid(active_weapon) and table.HasValue(weapons, active_weapon:GetClass()) then
            return
        end

        local select_weapon = table.Random(weapons)

        local wep = NULL
        local weapons = npc:GetWeapons()
        local isExist = false
        for _, weapon in ipairs(weapons) do
            local weapon_class = weapon:GetClass()
            if weapon_class == select_weapon then
                wep = weapon
                isExist = true
                break
            end
        end

        if not isExist then
            wep = npc:Give(select_weapon)
        end

        wep:SetClip2(1000)
        npc:SelectWeapon(select_weapon)
    end
end
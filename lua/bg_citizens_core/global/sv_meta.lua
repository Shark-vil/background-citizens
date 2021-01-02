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

        local weapon = npc:GetWeapon(select_weapon)
        if not IsValid(weapon) then
            weapon = npc:Give(select_weapon)
        end

        npc:SelectWeapon(select_weapon)
    end
end

function bgCitizens:IsEnemyTeam(npc, team_name)
    for _, actor in ipairs(self:GetAll()) do
        if IsValid(npc) and IsValid(actor:GetNPC()) then
            if actor:HasTeam(team_name) and npc:Disposition(actor:GetNPC()) == D_HT then
                return true
            end
        end
    end
    return false
end

function bgCitizens:SpawnActor(type)
    local bg_citizens_spawn_radius 
        = GetConVar('bg_citizens_spawn_radius'):GetFloat()

    local bg_citizens_spawn_radius_visibility 
        = GetConVar('bg_citizens_spawn_radius_visibility'):GetFloat() ^ 2

    local bg_citizens_spawn_radius_raytracing 
        = GetConVar('bg_citizens_spawn_radius_raytracing'):GetFloat() ^ 2

    local bg_citizens_spawn_block_radius
        = GetConVar('bg_citizens_spawn_block_radius'):GetFloat() ^ 2

    for _, data in ipairs(bgCitizens.npc_classes) do
        if data.type == type then
            local points_close = {}
            local players = player.GetAll()

            if #players == 0 then return end

            do
                local ply = table.Random(players)
                if IsValid(ply) then
                    points_close = bgCitizens:GetAllPointsInRadius(ply:GetPos(), 
                        bg_citizens_spawn_radius)
                end
            end

            if #points_close == 0 then
                return
            end

            local pos = table.Random(points_close).pos
        
            for _, ent in ipairs(ents.FindInSphere(pos, 100)) do
                if IsValid(ent) and (ent:IsNPC() or ent:IsPlayer()) then
                    return
                end
            end

            for _, ply in ipairs(players) do
                local distance = pos:DistToSqr(ply:GetPos())
                if distance < bg_citizens_spawn_radius_visibility 
                    and bgCitizens:PlayerIsViewVector(ply, pos)
                then
                    if distance <= bg_citizens_spawn_block_radius then
                        return
                    end
                    
                    if bg_citizens_spawn_radius_raytracing ~= 0 
                        and bg_citizens_spawn_radius_raytracing < distance
                    then
                        local tr = util.TraceLine({
                            start = ply:EyePos(),
                            endpos = pos,
                            filter = function(ent)
                                if IsValid(ent) and ent ~= ply 
                                    and not ent:IsVehicle() and ent:IsWorld() 
                                    and string.sub(ent:GetClass(), 1, 5) ~= 'prop_'
                                then
                                    return true
                                end
                            end
                        })

                        if not tr.Hit then
                            return
                        end
                    else
                        return
                    end
                end
            end

            if hook.Run('bgCitizens_PreValidSpawnNPC', data) ~= nil then
                return
            end

            local npc = ents.Create(data.class)
            npc:SetPos(pos)
            npc:SetSpawnEffect(true)

            --[[
                ATTENTION! Be careful, this hook is called before the NPC spawns. If you give out a weapon or something similar, it will crash the game!
            --]]
            if hook.Run('bgCitizens_PreSpawnNPC', npc, data) ~= nil then
                if IsValid(npc) then npc:Remove() end
                return
            end

            npc:Spawn()

            local entities = {}
            table.Merge(entities, bgCitizens:GetAllNPCs())
            table.Merge(entities, player.GetAll())

            for _, ent in ipairs(entities) do
                if IsValid(ent) then
                    if ent:IsPlayer() then
                        npc:AddEntityRelationship(ent, D_NU, 99)
                    elseif ent:IsNPC() then
                        local actor = bgCitizens:GetActor(ent)
                        if actor ~= nil and actor:HasTeam(data.team) then
                            npc:AddEntityRelationship(ent, D_LI, 99)
                            ent:AddEntityRelationship(npc, D_LI, 99)
                        else
                            npc:AddEntityRelationship(ent, D_NU, 99)
                            ent:AddEntityRelationship(npc, D_NU, 99)
                        end
                    end
                end
            end
            -- end)

            local actor = BG_NPC_CLASS:Instance(npc, data)
            actor:SetDefaultState()

            bgCitizens:AddNPC(actor)

            -- npc:SetNWString('bgCitizenType', data.type)

            hook.Run('bgCitizens_PostSpawnNPC', actor)

            return
        end
    end
end
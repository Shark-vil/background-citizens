if CLIENT then
    net.RegisterCallback('bgn_add_actor_from_client', function(ply, id, npc)
        if IsValid(npc) then
            local actor = BG_NPC_CLASS:Instance(npc, bgNPC.npc_classes[id])
            bgNPC:AddNPC(actor)
            if actor:GetState() == 'none' then
                actor:Walk()
            end
        end
    end)
else
    function bgNPC:SpawnActor(type)
        local bg_citizens_spawn_radius 
            = GetConVar('bg_citizens_spawn_radius'):GetFloat()
    
        local bg_citizens_spawn_radius_visibility 
            = GetConVar('bg_citizens_spawn_radius_visibility'):GetFloat() ^ 2
    
        local bg_citizens_spawn_radius_raytracing 
            = GetConVar('bg_citizens_spawn_radius_raytracing'):GetFloat() ^ 2
    
        local bg_citizens_spawn_block_radius
            = GetConVar('bg_citizens_spawn_block_radius'):GetFloat() ^ 2
    
        for id, data in ipairs(bgNPC.npc_classes) do
            if data.type == type then
                local points_close = {}
                local players = player.GetAll()
    
                if #players == 0 then return end
    
                do
                    local ply = table.Random(players)
                    if IsValid(ply) then
                        points_close = bgNPC:GetAllPointsInRadius(ply:GetPos(), 
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
                        and bgNPC:PlayerIsViewVector(ply, pos)
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
    
                if hook.Run('BGN_OnValidSpawnNPC', data) ~= nil then
                    return
                end
    
                local npc = ents.Create(data.class)
                npc:SetPos(pos)
                -- npc:SetSpawnEffect(true)
                
                --[[
                    ATTENTION! Be careful, this hook is called before the NPC spawns. If you give out a weapon or something similar, it will crash the game!
                --]]
                if hook.Run('BGN_PreSpawnNPC', npc, data) ~= nil then
                    if IsValid(npc) then npc:Remove() end
                    return
                end
    
                npc:Spawn()
    
                if data.models then
                    local model = table.Random(data.models)
                    if util.IsValidModel(model) then
                        if data.defaultModels then
                            if math.random(0, 10) <= 5 then
                                npc:SetModel(model)
                            end
                        else
                            npc:SetModel(model)
                        end
                    end
                end
    
                local entities = {}
                table.Merge(entities, bgNPC:GetAllNPCs())
                table.Merge(entities, player.GetAll())
    
                for _, ent in ipairs(entities) do
                    if IsValid(ent) then
                        if ent:IsPlayer() then
                            npc:AddEntityRelationship(ent, D_NU, 99)
                        elseif ent:IsNPC() and bgNPC:GetActor(ent) ~= nil then
                            npc:AddEntityRelationship(ent, D_NU, 99)
                            ent:AddEntityRelationship(npc, D_NU, 99)
                        end
                    end
                end
                -- end)
    
                local actor = BG_NPC_CLASS:Instance(npc, data)
                actor:Walk()
    
                bgNPC:AddNPC(actor)
    
                timer.Simple(1, function()
                    if not IsValid(npc) then return end
                    net.InvokeAll('bgn_add_actor_from_client', id, npc)
                end)
    
                hook.Run('BGN_PostSpawnNPC', actor)
    
                return
            end
        end
    end
end

function bgNPC:AddNPC(actor)    
    table.insert(self.actors, actor)

    local npc = actor:GetNPC()
    table.insert(self.npcs, npc)

    local type = actor:GetType()
    self.factors[type] = self.factors[type] or {}
    table.insert(self.factors[type], actor)

    self.fnpcs[type] = self.fnpcs[type] or {}
    table.insert(self.fnpcs[type], npc)
end

function bgNPC:ClearRemovedNPCs()
    for i = #self.actors, 1, -1 do
        local npc = self.actors[i]:GetNPC()
        if not IsValid(npc) or npc:Health() <= 0 then
            table.remove(self.actors, i)
        end
    end

    for i = #self.npcs, 1, -1 do
        local npc = self.npcs[i]
        if not IsValid(npc) or npc:Health() <= 0 then
            table.remove(self.npcs, i)
        end
    end

    for key, data in pairs(self.factors) do
        for i = #data, 1, -1 do
            local npc = data[i]:GetNPC()
            if not IsValid(npc) or npc:Health() <= 0 then
                table.remove(self.factors[key], i)
            end
        end
    end

    for key, data in pairs(self.fnpcs) do
        for i = #data, 1, -1 do
            local npc = data[i]
            if not IsValid(npc) or npc:Health() <= 0 then
                table.remove(self.fnpcs[key], i)
            end
        end
    end
end
function bgCitizens:PlayerIsViewVector(ply, pos)
    local DirectionAngle = math.pi / 80 -- 90
    local EntityDifference = pos - ply:EyePos()
    local EntityDifferenceDot = ply:GetAimVector():Dot(EntityDifference) / EntityDifference:Length()
    local IsView = EntityDifferenceDot > DirectionAngle
    if IsView then
        return true
    end
    return false
end

function bgCitizens:NPCIsViewVector(npc, pos)
	local directionAngCos = math.pi / 90
    local aimVector = npc:GetAimVector()
    local entVector = pos - npc:GetShootPos() 
    local angCos = aimVector:Dot(entVector) / entVector:Length()
    return angCos >= directionAngCos
end

function bgCitizens:AddNPC(npc_object)
    table.insert(self.npcs, npc_object)

    local type = npc_object:GetType()
    self.fnpcs[type] = self.fnpcs[type] or {}
    table.insert(self.fnpcs[type], npc_object)
end

function bgCitizens:GetAll()
    return self.npcs
end

function bgCitizens:GetAllByType(type)
    return self.fnpcs[type] or {}
end

function bgCitizens:GetAllNPCs()
    local npcs = {}
    for _, actor in pairs(self:GetAll()) do
        local npc = actor:GetNPC()
        if IsValid(npc) then
            table.insert(npcs, npc)
        end
    end
    return npcs
end

function bgCitizens:GetAllNPCsByType(type)
    local npcs = {}
    for _, actor in pairs(self:GetAllByType(type)) do
        local npc = actor:GetNPC()
        if IsValid(npc) then
            table.insert(npcs, npc)
        end
    end
    return npcs
end

function bgCitizens:HasNPC(npc)
    for _, bgNPC in pairs(bgCitizens:GetAllNPCs()) do
        if bgNPC == npc then
            return true
        end
    end
    return false
end

function bgCitizens:GetActor(npc)
    for _, actor in pairs(bgCitizens:GetAll()) do
        if actor:GetNPC() == npc then
            return actor
        end
    end
    return nil
end

function bgCitizens:ClearRemovedNPCs()
    do
        local new_table = {}
        for _, object in pairs(bgCitizens.npcs) do
            local npc = object:GetNPC()
            if IsValid(npc) and npc:Health() > 0 then
                table.insert(new_table, object)
            end
        end

        self.npcs = new_table
    end

    do
        local new_table = {}
        for key, data in pairs(self.fnpcs) do
            for _, object in pairs(data) do
                local npc = object:GetNPC()
                if IsValid(npc) and npc:Health() > 0 then
                    new_table[key] = new_table[key] or {}
                    table.insert(new_table[key], object)
                end
            end
        end
        self.fnpc = new_table
    end
end
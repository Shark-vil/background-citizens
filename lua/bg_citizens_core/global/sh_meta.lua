bgCitizens.wanted = {}

function bgCitizens:PlayerIsViewVector(ply, pos)
    local DirectionAngle = math.pi / 90 -- 90
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

function bgCitizens:GetAllPointsInRadius(center, radius)
    local radius_positions = {}
    radius = radius ^ 2

    for _, v in ipairs(bgCitizens.points) do
        if v.pos:DistToSqr(center) <= radius then
            table.insert(radius_positions, v)
        end
    end

    return radius_positions
end

function bgCitizens:GetAll()
    return self.npcs
end

function bgCitizens:GetAllByType(type)
    return self.fnpcs[type] or {}
end

function bgCitizens:GetAllByRadius(center, radius)
    local npcs = {}
    radius = radius ^ 2
    
    for _, actor in ipairs(self.npcs) do
        local npc = actor:GetNPC()
        if IsValid(npc) and npc:GetPos():DistToSqr(center) <= radius then
            table.insert(npcs, actor)
        end
    end
    return npcs
end

function bgCitizens:GetAllNPCs()
    local npcs = {}
    for _, actor in ipairs(self.npcs) do
        local npc = actor:GetNPC()
        if IsValid(npc) then
            table.insert(npcs, npc)
        end
    end
    return npcs
end

function bgCitizens:GetAllNPCsByType(type)
    local npcs = {}
    for _, actor in ipairs(self:GetAllByType(type)) do
        local npc = actor:GetNPC()
        if IsValid(npc) then
            table.insert(npcs, npc)
        end
    end
    return npcs
end

function bgCitizens:HasNPC(npc)
    for _, bgNPC in ipairs(bgCitizens:GetAllNPCs()) do
        if bgNPC == npc then
            return true
        end
    end
    return false
end

function bgCitizens:GetActor(npc)
    for _, actor in ipairs(bgCitizens:GetAll()) do
        if actor:GetNPC() == npc then
            return actor
        end
    end
    return nil
end

function bgCitizens:ClearRemovedNPCs()
    do
        local new_table = {}
        for _, object in ipairs(bgCitizens.npcs) do
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
            for _, object in ipairs(data) do
                local npc = object:GetNPC()
                if IsValid(npc) and npc:Health() > 0 then
                    new_table[key] = new_table[key] or {}
                    table.insert(new_table[key], object)
                end
            end
        end
        self.fnpcs = new_table
    end

    -- for key, data in pairs(self.fnpcs) do
    --     print('['.. key .. '] ' .. tostring(#data))
    -- end
end

function bgCitizens:IsTeamOnce(npc1, npc2)
    local actor1 = self:GetActor(npc1)
    local actor2 = self:GetActor(npc2)
    if actor1 ~= nil and actor2 ~= nil then
        local data1 = actor1:GetData()
        local data2 = actor2:GetData()

        if data1.team ~= nil and data2.team ~= nil then
            for _, team_1 in ipairs(data1.team) do
                for _, team_2 in ipairs(data2.team) do
                    if team_1 == team_2 then
                        return true
                    end
                end
            end
        end
    end

    return false
end
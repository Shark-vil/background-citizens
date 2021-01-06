function bgCitizens:GetActor(npc)
    for _, actor in ipairs(bgCitizens:GetAll()) do
        if actor:GetNPC() == npc then
            return actor
        end
    end
    return nil
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
    return self.actors
end

function bgCitizens:GetAllByType(type)
    return self.factors[type] or {}
end

function bgCitizens:GetAllNPCs()
    return self.npcs
end

function bgCitizens:GetAllNPCsByType(type)
    return self.fnpcs[type] or {}
end

function bgCitizens:GetAllByRadius(center, radius)
    local npcs = {}
    radius = radius ^ 2
    
    for _, actor in ipairs(self:GetAll()) do
        local npc = actor:GetNPC()
        if IsValid(npc) and npc:GetPos():DistToSqr(center) <= radius then
            table.insert(npcs, actor)
        end
    end

    return npcs
end

function bgCitizens:HasNPC(npc)
    return table.HasValue(bgCitizens:GetAllNPCs(), npc)
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
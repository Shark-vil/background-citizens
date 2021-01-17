function bgNPC:GetActor(npc)
    for _, actor in ipairs(bgNPC:GetAll()) do
        if actor:GetNPC() == npc then
            return actor
        end
    end
    return nil
end

function bgNPC:GetAllPointsInRadius(center, radius)
    local radius_positions = {}
    radius = radius ^ 2

    for _, v in ipairs(bgNPC.points) do
        if v.pos:DistToSqr(center) <= radius then
            table.insert(radius_positions, v)
        end
    end

    return radius_positions
end

function bgNPC:GetAll()
    return self.actors
end

function bgNPC:GetAllByType(type)
    return self.factors[type] or {}
end

function bgNPC:GetAllNPCs()
    return self.npcs
end

function bgNPC:GetAllNPCsByType(type)
    return self.fnpcs[type] or {}
end

function bgNPC:GetNear(center)
    local near_actor = nil
    local dist = nil
    
    for _, actor in ipairs(self:GetAll()) do
        local npc = actor:GetNPC()
        if IsValid(npc) then
            if dist == nil then
                dist = npc:GetPos():DistToSqr(center)
                near_actor = actor
            else
                local new_dist = npc:GetPos():DistToSqr(center)
                if new_dist < dist then
                    dist = new_dist
                    near_actor = actor
                end
            end
        end
    end

    return near_actor
end


function bgNPC:GetNearByType(center, type)
    local near_actor = nil
    local dist = nil
    
    for _, actor in ipairs(self:GetAll()) do
        local npc = actor:GetNPC()
        if actor:GetType() == type and IsValid(npc) then
            if dist == nil then
                dist = npc:GetPos():DistToSqr(center)
                near_actor = actor
            else
                local new_dist = npc:GetPos():DistToSqr(center)
                if new_dist < dist then
                    dist = new_dist
                    near_actor = actor
                end
            end
        end
    end

    return near_actor
end

function bgNPC:GetAllByRadius(center, radius)
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

function bgNPC:HasNPC(npc)
    return table.HasValue(bgNPC:GetAllNPCs(), npc)
end

function bgNPC:IsTeamOnce(npc1, npc2)
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
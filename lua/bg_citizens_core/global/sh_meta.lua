if CLIENT then
    net.Receive('bgCitizensAddActorFromClient', function()
        local id = net.ReadInt(10)
        local npc = net.ReadEntity()

        if IsValid(npc) then
            local actor = BG_NPC_CLASS:Instance(npc, bgCitizens.npc_classes[id])
            bgCitizens:AddNPC(actor)
        end
    end)
end

function bgCitizens:PlayerIsViewVector(ply, pos, radius)
    radius = radius or 90
    local DirectionAngle = math.pi / radius -- 90
    local EntityDifference = pos - ply:EyePos()
    local EntityDifferenceDot = ply:GetAimVector():Dot(EntityDifference) / EntityDifference:Length()
    local IsView = EntityDifferenceDot > DirectionAngle
    if IsView then
        return true
    end
    return false
end

function bgCitizens:NPCIsViewVector(npc, pos, radius)
    radius = radius or 90
	local directionAngCos = math.pi / radius
    local aimVector = npc:GetAimVector()
    local entVector = pos - npc:GetShootPos() 
    local angCos = aimVector:Dot(entVector) / entVector:Length()
    return angCos >= directionAngCos
end

function bgCitizens:AddNPC(actor)    
    table.insert(self.actors, actor)

    local npc = actor:GetNPC()
    table.insert(self.npcs, npc)

    local type = actor:GetType()
    self.factors[type] = self.factors[type] or {}
    table.insert(self.factors[type], actor)

    self.fnpcs[type] = self.fnpcs[type] or {}
    table.insert(self.fnpcs[type], npc)
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

function bgCitizens:GetActor(npc)
    for _, actor in ipairs(bgCitizens:GetAll()) do
        if actor:GetNPC() == npc then
            return actor
        end
    end
    return nil
end

function bgCitizens:ClearRemovedNPCs()
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
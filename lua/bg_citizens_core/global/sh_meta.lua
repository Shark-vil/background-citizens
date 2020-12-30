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
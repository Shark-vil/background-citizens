function bgNPC:PlayerIsViewVector(ply, pos, radius)
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

function bgNPC:NPCIsViewVector(npc, pos, radius)
    radius = radius or 90
	local directionAngCos = math.pi / radius
    local aimVector = npc:GetAimVector()
    local entVector = pos - npc:GetShootPos() 
    local angCos = aimVector:Dot(entVector) / entVector:Length()
    return angCos >= directionAngCos
end
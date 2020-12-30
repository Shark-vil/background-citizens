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
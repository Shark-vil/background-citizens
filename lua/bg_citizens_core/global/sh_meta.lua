function bgNPC:Log(message, tag)
    if not bgNPC.cfg.debugMode then return end
    if tag ~= nil then
        MsgN('[Background NPCs][' .. tostring(tag) .. '] ' .. tostring(message))
    else
        MsgN('[Background NPCs] ' .. tostring(message))
    end
end

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

function bgNPC:GetModule(module_name)
    return list.Get('BGN_Modules')[module_name]
end

function bgNPC:IsTargetRay(watcher, ent)
    if not IsValid(ent) then return false end
    local center_pos = LocalToWorld(ent:OBBCenter(), Angle(), ent:GetPos(), Angle())

    local tr = util.TraceLine({
        start = watcher:EyePos(),
        endpos = center_pos,
        filter = function(e)
            if e ~= watcher then
                return true
            end
        end
    })

    if not tr.Hit or tr.Entity ~= ent then
        return false
    end

    return true
end
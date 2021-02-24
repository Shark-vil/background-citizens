function bgNPC:Log(message, tag)
	if not GetConVar('bgn_debug'):GetBool() then return end
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

function bgNPC:EntityIsViewVector(ent, pos, radius)
	if not IsValid(ent) then return false end

	radius = radius or 90
	local directionAngCos = math.pi / radius
	local aimVector = ent:GetAimVector()
	local entVector = pos - ent:GetShootPos() 
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
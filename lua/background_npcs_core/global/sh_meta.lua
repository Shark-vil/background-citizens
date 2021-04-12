local actors_config_cache = {}

function bgNPC:ClearActorsConfig()
	table.Empty(actors_config_cache)
end

function bgNPC:GetActorConfig(actor_type)
	if actors_config_cache[actor_type] then
		return actors_config_cache[actor_type]
	else
		if not bgNPC.cfg.npcs_template[actor_type] then return end
		local data = table.Copy(bgNPC.cfg.npcs_template[actor_type])

		if data.inherit and data.inherit ~= actor_type then
			local inherit_data = bgNPC.cfg.npcs_template[data.inherit]
			if inherit_data then
				if inherit_data.inherit then
					inherit_data = bgNPC:GetActorConfig(data.inherit)
				end

				for ik, iv in pairs(inherit_data) do
					if ik ~= 'inherit' then
						local exist = false

						for k, _ in pairs(data) do
							if k == ik then
								exist = true
								break
							end
						end

						if not exist then
							data[ik] = iv
						end
					end
				end
			end
		end

		for k, v in pairs(data) do
			if isstring(v) and string.StartWith(v, '@') then
				local inherit_actor_type = string.sub(v, 2)
				if inherit_actor_type ~= actor_type then
					local inherit_data = bgNPC.cfg.npcs_template[inherit_actor_type]

					if inherit_data.inherit then
						inherit_data = bgNPC:GetActorConfig(data.inherit)
					end

					if inherit_data and inherit_data[k] ~= nil then
						data[k] = inherit_data[k]
					else
						data[k] = nil
					end
				end
			end
		end

		actors_config_cache[actor_type] = data

		return actors_config_cache[actor_type]
	end
end

function bgNPC:Log(message, tag)
	if not GetConVar('bgn_debug'):GetBool() then return end
	if tag ~= nil then
		MsgN('[Background NPCs][' .. tostring(tag) .. '] ' .. tostring(message))
	else
		MsgN('[Background NPCs] ' .. tostring(message))
	end
end

function bgNPC:PlayerIsViewVector(ply, pos, radius)
	if not IsValid(ply) then return false end

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

function bgNPC:NPCIsViewVector(ent, pos, radius)
	if ent:IsNextBot() then return true end
	if not IsValid(ent) or ent:Health() <= 0 then return false end

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
	if not IsValid(watcher) or watcher:Health() <= 0 then return false end
	if not IsValid(ent) or ent:Health() <= 0 then return false end

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
		return false, tr.Entity
	end

	return true, tr.Entity
end

function bgNPC:GetActivePlayerTool(tool_name, ply)
	local ply = ply
	if not ply then
		if SERVER then return end
		ply = LocalPlayer()
	end

	local tool = ply:GetTool()
	if not tool or not tool.GetMode or tool:GetMode() ~= tool_name then return end
	return tool
end
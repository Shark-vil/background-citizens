local actors_config_cache = {}

function bgNPC:ClearActorsConfig()
	actors_config_cache = {}
end

function bgNPC:GetActorConfig(actor_type)
	if actors_config_cache[actor_type] then
		return actors_config_cache[actor_type]
	else
		if not bgNPC.cfg.npcs_template[actor_type] then return end
		local data = table.Copy(bgNPC.cfg.npcs_template[actor_type])

		if data.inherit and data.inherit ~= actor_type then
			local inherit_data = bgNPC:GetActorConfig(data.inherit)
			if inherit_data then
				bgNPC:Log('Data Inherit - ' .. data.inherit, 'GetActorConfig')

				for inherit_key, inherit_value in pairs(inherit_data) do
					if inherit_key ~= 'inherit' then
						local exists_data_key = false

						for data_key, _ in pairs(data) do
							if data_key == inherit_key then
								exists_data_key = true
								break
							end
						end

						if not exists_data_key then
							data[inherit_key] = inherit_value
							if istable(inherit_value) then
								bgNPC:Log(actor_type .. ' inherit ' .. data.inherit .. ' key  - ' ..
									inherit_key .. ' : ' .. table.ToString(inherit_value), 'GetActorConfig')
							else
								bgNPC:Log(actor_type .. ' inherit ' .. data.inherit .. ' key  - ' ..
									inherit_key .. ' : ' .. tostring(inherit_value), 'GetActorConfig')
							end
						end
					end
				end
			end
		end

		for k, v in pairs(data) do
			if isstring(v) and string.StartWith(v, '@') then
				local inherit_groups = string.Explode('@', string.Replace(v, ' ', ''))

				for _, inherit_actor_type in ipairs(inherit_groups) do
					if #inherit_actor_type ~= 0 and inherit_actor_type ~= actor_type then
						local inherit_data = bgNPC.cfg.npcs_template[inherit_actor_type]

						if inherit_data and inherit_data.inherit then
							inherit_data = bgNPC:GetActorConfig(data.inherit)
						end

						if inherit_data and inherit_data[k] ~= nil then
							if data[k] == nil or isstring(data[k]) then
								data[k] = inherit_data[k]
							elseif data[k] ~= nil and istable(data[k]) and istable(inherit_data[k]) then
								for another_key, another_value in pairs(inherit_data[k]) do
									if isnumber(another_key) then
										table.insert(data, another_value)
									elseif data[another_key] == nil then
										data[another_key] = another_value
									end
								end
							end
						elseif data[k] ~= nil and isstring(data[k]) then
							if string.StartWith(data[k], '@') then
								data[k] = nil
							end
						end
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
	return ply:slibIsViewVector(pos, radius)
end

function bgNPC:NPCIsViewVector(ent, pos, radius)
	if not ent:IsNPC() or ent:IsNextBot() then return true end
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

local npcs_template_copy = table.Copy(bgNPC.cfg.npcs_template)
timer.Create('BGN_FixedNpcsTemplateConfig', .1, 0, function()
	local npcs_template = bgNPC.cfg.npcs_template
	if not npcs_template or not istable(npcs_template) or table.Count(npcs_template) == 0 then
		ErrorNoHalt('[Background NPCs] Something broke the NPC templates configuration. The table has been restored.')
		bgNPC.cfg.npcs_template = table.Copy(npcs_template_copy)
	end
end)
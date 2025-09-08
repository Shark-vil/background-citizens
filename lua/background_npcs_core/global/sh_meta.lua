local IsValid = IsValid
local pairs = pairs
local ipairs = ipairs
local istable = istable
local unpack = unpack
local isstring = isstring
local string_StartWith = string.StartWith
local table_Copy = table.Copy
local table_HasValueBySeq = table.HasValueBySeq
-- local table_ToString = table.ToString
local string_Replace = string.Replace
local string_Explode = string.Explode
local table_insert = table.insert
--
local cvar_bgn_debug = GetConVar('bgn_debug')
local actors_config_cache = {}

function bgNPC:ClearActorsConfig()
	actors_config_cache = {}
end

function bgNPC:GetActorConfig(actor_type)
	if actors_config_cache[actor_type] then
		return actors_config_cache[actor_type]
	else
		if not bgNPC.cfg.actors[actor_type] then return end
		local data = table_Copy(bgNPC.cfg.actors[actor_type])

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
							-- if istable(inherit_value) then
							-- 	bgNPC:Log(actor_type .. ' inherit ' .. data.inherit .. ' key  - ' ..
							-- 		inherit_key .. ' : ' .. table_ToString(inherit_value), 'GetActorConfig')
							-- else
							-- 	bgNPC:Log(actor_type .. ' inherit ' .. data.inherit .. ' key  - ' ..
							-- 		inherit_key .. ' : ' .. tostring(inherit_value), 'GetActorConfig')
							-- end
						end
					end
				end
			end
		end

		for k, v in pairs(data) do
			if isstring(v) and string_StartWith(v, '@') then
				local inherit_groups = string_Explode('@', string_Replace(v, ' ', ''))

				for _, inherit_actor_type in ipairs(inherit_groups) do
					if #inherit_actor_type ~= 0 and inherit_actor_type ~= actor_type then
						local inherit_data = bgNPC.cfg.actors[inherit_actor_type]

						if inherit_data and inherit_data.inherit then
							inherit_data = bgNPC:GetActorConfig(data.inherit)
						end

						if inherit_data and inherit_data[k] ~= nil then
							if data[k] == nil or isstring(data[k]) then
								data[k] = inherit_data[k]
							elseif data[k] ~= nil and istable(data[k]) and istable(inherit_data[k]) then
								for another_key, another_value in pairs(inherit_data[k]) do
									if isnumber(another_key) then
										table_insert(data, another_value)
									elseif data[another_key] == nil then
										data[another_key] = another_value
									end
								end
							end
						elseif data[k] ~= nil and isstring(data[k]) then
							if string_StartWith(data[k], '@') then
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
	if not cvar_bgn_debug:GetBool() then return end
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

function bgNPC:CanAnyActorSeeEntity(ent, ...)
	if not IsValid(ent) or not isentity(ent) then return false end

	local exclude_actors = unpack(...)
	local exclude_actors_is_valid = exclude_actors and #exclude_actors ~= 0
	local actors = bgNPC:GetAll()
	for i = 1, #actors do
		local actor = actors[i]
		if actor and actor:IsAlive() then
			if exclude_actors_is_valid and table_HasValueBySeq(exclude_actors_is_valid, actor) then
				continue
			end
			local npc = actor:GetNPC()
			if IsValid(npc) and npc:slibIsTraceEntity(ent, 1000, true) then
				return true, actor
			end
		end
	end

	return false
end

function bgNPC:CanActorsSeeEntity(ent)
	if not IsValid(ent) or not isentity(ent) then return false end

	local actors = bgNPC:GetAll()
	local valid_actors = {}
	local valid_actors_count = 0

	for i = 1, #actors do
		local actor = actors[i]
		if actor and actor:IsAlive() then
			local npc = actor:GetNPC()
			if IsValid(npc) and npc:slibIsTraceEntity(ent, 1000, true) then
				valid_actors_count = valid_actors_count + 1
				valid_actors[valid_actors_count] = actor
			end
		end
	end

	return valid_actors_count ~= 0, valid_actors
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
	if not tool_name or not isstring(tool_name) then return end

	if not IsValid(ply) then
		if SERVER then return end
		ply = LocalPlayer()
	end

	local tool = ply:GetTool()
	if not tool or not isfunction(tool.GetMode) or tool:GetMode() ~= tool_name then return end
	return tool
end

do
	local npcs_template_copy = table_Copy(bgNPC.cfg.actors)
	function bgNPC:ResetConfiguration()
		bgNPC.cfg.actors = table_Copy(npcs_template_copy)
	end
end
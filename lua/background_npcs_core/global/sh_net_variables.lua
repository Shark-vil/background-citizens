local entity_variables = {}
local variables = {}

if SERVER then
	-- Entity
	function bgNPC:SetEntityVariable(ent, key, data, not_delay)
		not_delay = not_delay or false

		entity_variables[ent] = entity_variables[ent] or {}
		entity_variables[ent][key] = data

		if not not_delay then
			bgNPC:TemporaryVectorVisibility(ent, 3)
			timer.Simple(1.5, function()
				if not IsValid(ent) then return end
				snet.InvokeAll('bgn_citizens_add_entity_variable', ent, key, data)
			end)
		else
			bgNPC:TemporaryVectorVisibility(ent)
			snet.InvokeAll('bgn_citizens_add_entity_variable', ent, key, data)
		end
	end

	-- Global
	function bgNPC:SetGlobalVariable(key, data)
		variables[key] = data
		snet.InvokeAll('bgn_citizens_add_global_variable', key, data)
	end
else
	-- Entity
	snet.RegisterCallback('bgn_citizens_add_entity_variable', function(ply, ent, key, data)
		if not IsValid(ent) then
			bgNPC:Log('Error synchronizing entity variables. The data was sent too sooner or later.', 'Network')
			return
		end

		entity_variables[ent] = entity_variables[ent] or {}
		entity_variables[ent][key] = data
	end)

	snet.RegisterCallback('bgn_citizens_remove_entity_variable', function(ply, ent, key)
		if not IsValid(ent) then
			bgNPC:Log('Error synchronizing entity variables. The data was sent too sooner or later.', 'Network')
			return
		end

		entity_variables[ent] = entity_variables[ent] or {}
		entity_variables[ent][key] = nil
	end)

	-- Global
	snet.RegisterCallback('bgn_citizens_add_global_variable', function(ply, key, data)
		variables[key] = data
	end)

	snet.RegisterCallback('bgn_citizens_remove_global_variable', function(ply, key)
		variables[key] = nil
	end)
end

-- Entity
function bgNPC:RemoveEntityVariable(ent, key, not_delay)
	not_delay = not_delay or false
	
	entity_variables[ent] = entity_variables[ent] or {}
	entity_variables[ent][key] = nil

	if SERVER then
		if not not_delay then
			bgNPC:TemporaryVectorVisibility(ent, 3)
			timer.Simple(1.5, function()
				if not IsValid(ent) then return end
				snet.InvokeAll('bgn_citizens_remove_entity_variable', ent, key)
			end)
		else
			bgNPC:TemporaryVectorVisibility(ent)
			snet.InvokeAll('bgn_citizens_remove_entity_variable', ent, key)
		end
	end
end

function bgNPC:GetEntityVariable(ent, key, default)
	if not IsValid(ent) then
		return default
	end
	entity_variables[ent] = entity_variables[ent] or {}
	return entity_variables[ent][key] or default
end

-- Global
function bgNPC:RemoveGlobalVariable(key)
	variables[key] = nil
	if SERVER then
		snet.InvokeAll('bgn_citizens_remove_global_variable', key)
	end
end

function bgNPC:GetGlobalVariable(ent, key, default)
	return variables[key] or default
end
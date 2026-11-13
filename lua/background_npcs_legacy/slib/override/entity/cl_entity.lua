local snet = slib.Components.Network
local IsValid = IsValid
--

snet.Callback('slib_entity_variable_set', function (_, ent, key, value)
	slib.DebugLog('Set ', ent, ' variable [ ', key, ' : ', value, ' ]')
	ent:slibSetVar(key, value)
end).Validator(SNET_ENTITY_VALIDATOR)

snet.Callback('slib_entity_variable_del', function (_, ent, key)
	slib.DebugLog('Delete ', ent, ' variable [ ', key, ' ]')
	ent:slibSetVar(key, nil)
end).Validator(SNET_ENTITY_VALIDATOR)

snet.RegisterCallback('snet_entity_tool_call_client_rpc', function(ply, ent, tool_mode, func_name, ...)
	if not ent or not IsValid(ent) or ent:GetClass() ~= 'gmod_tool' then return end

	local args = { ... }

	timer.Simple(func_name == 'Deploy' and .5 or .1, function()
		local tool = ply:GetTool()
		if not tool or tool:GetMode() ~= tool_mode then return end

		local func = tool[func_name]
		if not func then return end

		func(tool, unpack(args))
	end)
end)

snet.Callback('snet_entity_call_client_rpc', function(ply, ent, func_name, ...)
	if not ent or not IsValid(ent) then return end

	local func = ent[func_name]
	if not func then return end

	func(ent, ...)
end).Validator(SNET_ENTITY_VALIDATOR)
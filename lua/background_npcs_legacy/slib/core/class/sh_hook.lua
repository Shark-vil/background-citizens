local unpack = unpack
local pairs = pairs
--
local Class = {}

function Class.Get(hook_type, hook_name)
	local hooks_data = hook.GetTable()

	if hook_type and hooks_data[hook_type] then
		if hook_type and hook_name then
			return hooks_data[hook_type][hook_name]
		else
			return hooks_data[hook_type]
		end
	end

	return nil
end

function Class.Exists(hook_type, hook_name)
	return Class.Get(hook_type, hook_name) ~= nil
end

function Class.SafeRun(hook_type, ...)
	local result = nil
	local args = { ... }

	slib.def({
		try = function()
			result = { hook.Run(hook_type, unpack(args)) }
		end,
		catch = function(ex)
			slib.Error(ex)
		end
	})

	if result == nil then return end

	return unpack(result)
end

function Class.Add(...)
	return hook.Add(...)
end

function Class.Call(...)
	return hook.Call(...)
end

function Class.GetTable(...)
	return hook.GetTable(...)
end

function Class.Remove(...)
	return hook.Remove(...)
end

function Class.Run(...)
	return hook.Run(...)
end

function Class.SetHandler(hook_type, hook_name, handler)
	if not isstring(hook_type) or not isstring(hook_name) or not isfunction(handler) then
		return
	end

	local hooks_data = Class.Get(hook_type)
	if not istable(hooks_data) then return end

	local hook_function = hooks_data[hook_name]
	if not isfunction(hook_function) then return end

	hook.Add(hook_type, hook_name, function(...)
		local args = { handler(...) }
		if args and #args ~= 0 then return unpack(args) end
		return hook_function(...)
	end)
end

function Class.SetHandlerAll(hook_type, handler)
	if not isstring(hook_type) or not isfunction(handler) then
		return
	end

	local hooks_data = Class.Get(hook_type)
	if not istable(hooks_data) then return end

	for hook_name, hook_function in pairs(hooks_data) do
		hook.Add(hook_type, hook_name, function(...)
			local args = { handler(...) }
			if args and #args ~= 0 then return unpack(args) end
			return hook_function(...)
		end)
	end
end

slib.SetComponent('Hook', Class)
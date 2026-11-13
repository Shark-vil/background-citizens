local snet = slib.Components.Network
local assert = assert
local isfunction = isfunction
local isnumber = isnumber
--
local callback_storage = {}

function snet.GetCallbackList()
	return callback_storage
end

function snet.GetCallback(name)
	return callback_storage[name]
end

function snet.Callback(name, func, is_safe)
	local private = {}
	private.name = name
	-- The hook will appear in the list only after calling registration if set - true
	private.is_safe = is_safe or false
	private.callback_options = nil

	function private.SetParam(key, value)
		if private.is_safe then
			private.callback_options = private.callback_options or {}
			private.callback_options[key] = value
		else
			callback_storage[private.name] = callback_storage[private.name] or {}
			callback_storage[private.name][key] = value
		end
	end

	local obj = {}
	private.SetParam('execute', func)

	function obj.Protect()
		private.SetParam('isAdmin', true)
		return obj
	end

	function obj.Validator(func_validator)
		assert(isfunction(func_validator), 'The variable "func_validator" must be a function!')
		private.SetParam('validator', func_validator)
		return obj
	end

	function obj.AutoDestroy()
		private.SetParam('auto_destroy', true)
		return obj
	end

	function obj.Period(delay, limit, warning)
		assert(isnumber(delay), 'The variable "delay" must be a number!')
		assert(isnumber(limit), 'The variable "limit" must be a number!')

		if warning ~= nil then
			assert(isfunction(warning), 'The variable "warning" must be a function!')
		end

		private.SetParam('limits', {
			delay = delay,
			limit = limit,
			warning = warning
		})

		return obj
	end

	function obj.Register()
		if private.callback_options then
			callback_storage[private.name] = private.callback_options
		end
		return obj
	end

	return obj
end

-- Outdated method for backward compatibility
function snet.RegisterCallback(name, func, auto_destroy, is_admin)
	local callback = snet.Callback(name, func, true)
	if auto_destroy then callback.AutoDestroy() end
	if is_admin then callback.Protect() end
	callback.Register()
	return callback
end

function snet.RemoveCallback(name)
	callback_storage[name] = nil
end
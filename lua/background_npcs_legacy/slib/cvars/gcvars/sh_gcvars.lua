local gcvars = slib.Components.GlobalCvar
local AccessComponent = slib.Components.Access
local isnumber = isnumber
local isbool = isbool
local istable = istable
local isstring = isstring
local GetConVar = GetConVar
local pairs = pairs
local table_remove = table.remove
--

function gcvars.Update(cvar_name, value)
	if cvar_name and slib.Storage.GlobalCvar[cvar_name] then
		local data = slib.Storage.GlobalCvar[cvar_name]
		data.value = value ~= nil and tostring(value) or GetConVar(cvar_name):GetString()
	else
		for cvar_name_key, _ in pairs(slib.Storage.GlobalCvar) do
			gcvars.Update(cvar_name_key)
		end
	end
end

function gcvars.Register(cvar_name, value, flag, helptext, min, max, access_data)
	local public = {}

	function public.Access(cvar_access_data)
		if not slib.Storage.GlobalCvar[cvar_name] or not cvar_access_data then return end
		slib.Storage.GlobalCvar[cvar_name].access = AccessComponent:Make(cvar_access_data)
	end

	if slib.Storage.GlobalCvar[cvar_name] == nil then
		if not isnumber(value) and not isbool(value) and not isstring(value) then return end

		do
			local new_flag = flag

			if (isnumber(flag) and flag == FCVAR_REPLICATED) or (istable(flag) and not table.isArray(flag)) then
				new_flag = FCVAR_NONE
			elseif istable(flag) then
				for i = #new_flag, 1, -1 do
					local flag_value = new_flag[i]
					if not isnumber(flag_value) or flag_value == FCVAR_REPLICATED then
						table_remove(new_flag, i)
					end
				end

				if #new_flag == 0 then
					new_flag = FCVAR_NONE
				end
			end

			flag = new_flag
		end

		helptext = helptext or ''
		CreateConVar(cvar_name, value, flag, helptext, min, max)

		slib.Storage.GlobalCvar[cvar_name] = {
			value = GetConVar(cvar_name):GetString(),
			flag = flag,
			helptext = helptext,
			min = min,
			max = max,
			access = access_data and AccessComponent:Make(access_data) or access_data,
		}

		slib.DebugLog('Register global cvar - ', cvar_name)

		cvars.AddChangeCallback(cvar_name, function(_, old_value, new_value)
			if old_value == new_value then return end

			local cvar_data = slib.Storage.GlobalCvar[cvar_name]
			if not cvar_data then return end

			timer.Remove('slib.SystemTimer.Cvars.OnChange.' .. cvar_name)

			timer.Create('slib.SystemTimer.Cvars.OnChange.' .. cvar_name, 0.5, 1, function()
				if SERVER then
					slib.DebugLog('Change cvaer on serverside. Update cvar - ', cvar_name, ' (', value, ')')

					gcvars.Update(cvar_name, new_value)
					snet.InvokeAll('slib_gcvars_server_update_success', cvar_name, old_value, new_value)
				end

				-- if SERVER then
				-- 	hook.Run('slib.OnChangeGlobalCvar', cvar_name, old_value, new_value)
				-- end

				hook.Run('slib.OnChangeGlobalCvar', cvar_name, old_value, new_value)
			end)
		end, 'slib_GlobalCvars_OnChange_' .. cvar_name)
	end

	return public
end

do
	local cvars_watchers

	if CLIENT then
		cvars_watchers = {}
	end

	function slib.GlobalCvarAddChangeCallback(name, callback, identifier)
		assert(slib.Storage.GlobalCvar[name] ~= nil, 'CVAR should be a global CVAR slib')
		assert(isstring(name), 'name must be a string')
		assert(isstring(identifier) or not identifier, 'identifier must be a string or nil')

		if CLIENT then
			cvars_watchers[name] = cvars_watchers[name] or {}

			if not isstring(identifier) then
				cvars_watchers[name]['array'] = cvars_watchers[name]['array'] or {}
				table.insert(cvars_watchers[name]['array'], callback)
			else
				cvars_watchers[name]['dictionary'] = cvars_watchers[name]['dictionary'] or {}
				cvars_watchers[name]['dictionary'][identifier] = callback
			end
		end

		if SERVER then
			cvars.AddChangeCallback(name, function(convar_name, value_old, value_new)
				if callback and isfunction(callback) then callback(convar_name, value_old, value_new) end
				snet.InvokeAll('slib.Server.GlobalCvarAddChangeCallback', name, convar_name, value_old, value_new, identifier)
			end, identifier)
		end
	end

	if SERVER then
		function slib.GlobalCvarRegisterChangeCallback(name, identifier)
			slib.GlobalCvarAddChangeCallback(name, nil, identifier)
		end
	end

	if CLIENT then
		snet.RegisterCallback('slib.Server.GlobalCvarAddChangeCallback', function(_, name, convar_name, value_old, value_new, identifier)
			if not cvars_watchers[name] then return end

			local convar = GetConVar(convar_name)
			if not convar then return end

			-- if convar:GetString() == tostring(value_new) then return end

			if isstring(identifier) and cvars_watchers[name]['dictionary'] then
				local callback = cvars_watchers[name]['dictionary'][identifier]
				if not callback or not isfunction(callback) then return end
				callback(convar_name, value_old, value_new)
				return
			end

			if not cvars_watchers[name]['array'] then return end

			local callbacks = cvars_watchers[name]['array']
			local callbacks_count = #callbacks
			if callbacks_count == 0 then return end

			for i = 1, callbacks_count do
				local callback = cvars_watchers[name]['array'][i]
				if callback and isfunction(callback) then
					callback(convar_name, value_old, value_new)
				end
			end
		end)
	end
end

-- do
-- 	local cvars_watchers = {}

-- 	function slib.AddChangeCallback(name, callback, identifier)
-- 		assert(isstring(name), 'name must be a string')
-- 		assert(isfunction(callback), 'callback must be a function')
-- 		assert(isstring(identifier) or not identifier, 'identifier must be a string or nil')

-- 		cvars_watchers[name] = cvars_watchers[name] or {}
-- 		cvars_watchers[name]['array'] = cvars_watchers[name]['array'] or {}
-- 		cvars_watchers[name]['dictionary'] = cvars_watchers[name]['dictionary'] or {}

-- 		if not identifier then
-- 			table.insert(cvars_watchers[name]['array'], callback)
-- 		else
-- 			cvars_watchers[name]['dictionary'][identifier] = callback
-- 		end

-- 		cvars.AddChangeCallback(name, function(convar_name, value_old, value_new)
-- 			callback(convar_name, value_old, value_new)
-- 			if SERVER then
-- 				timer.Create('slib.Timer.Server.AddChangeCallback.' .. convar_name, 1.5, 1, function()
-- 					snet.InvokeAll('slib.Server.AddChangeCallback', convar_name, value_old, value_new, identifier)
-- 				end)
-- 			end
-- 		end, identifier)
-- 	end

-- 	if CLIENT then
-- 		snet.RegisterCallback('slib.Server.AddChangeCallback', function(_, convar_name, value_old, value_new, identifier)
-- 			if not cvars_watchers[name] then return end

-- 			local convar = GetConVar(convar_name)
-- 			if not convar or convar:GetString() == tostring(value_new) then return end

-- 			if identifier then
-- 				local callback = cvars_watchers[name]['dictionary'][convar_name]
-- 				if not callback then return end
-- 				callback(convar_name, value_old, value_new)
-- 				return
-- 			end

-- 			local callbacks = cvars_watchers[name]['array']
-- 			local callbacks_count = #callbacks
-- 			if callbacks_count == 0 then return end

-- 			for i = 1, callbacks_count do
-- 				local callback = cvars_watchers[name]['array'][i]
-- 				if callback then
-- 					callback(convar_name, value_old, value_new)
-- 				end
-- 			end
-- 		end)
-- 	end
-- end
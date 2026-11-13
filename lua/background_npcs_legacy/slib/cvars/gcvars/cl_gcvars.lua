local access = slib.Components.Access
local gcvars = slib.Components.GlobalCvar
local RunConsoleCommand = RunConsoleCommand
--
local cvar_locker = {}

local function LockCvar(cvar_name)
	cvar_locker[cvar_name] = true
end

local function UnlockCvar(cvar_name)
	cvar_locker[cvar_name] = false
end

local function IsLock(cvar_name)
	if cvar_locker[cvar_name] then return true end
	return false
end

local function ChangeValue(cvar_name, value)
	if not isstring(cvar_name) or value == nil then return end
	if GetConVar(cvar_name):GetString() == tostring(value) then return end

	LockCvar(cvar_name)
	RunConsoleCommand(cvar_name, value)
	gcvars.Update(cvar_name, value)
end

hook.Add('slib.OnChangeGlobalCvar', 'slib.OnChangeByClient', function(cvar_name, old_value, new_value)
	if IsLock(cvar_name) then
		UnlockCvar(cvar_name)
		return
	end

	local cvar_data = slib.Storage.GlobalCvar[cvar_name]

	if not access.IsValid(LocalPlayer(), cvar_data.access) then
		ChangeValue(cvar_name, old_value)

		local text = slib.language({
			['default'] = 'Insufficient rights to make changes',
			['russian'] = 'Недостаточно прав для внесения изменений'
		})

		notification.AddLegacy(text, NOTIFY_ERROR, 4)

		surface.PlaySound('buttons/combine_button_locked.wav')

		return
	end

	gcvars.Update(cvar_name)

	snet.InvokeServer('slib_gcvars_change_from_server', cvar_name, new_value)
end)

snet.RegisterCallback('slib_gcvars_client_player_sync', function(_, sync_data)
	for _, v in ipairs(sync_data) do
		ChangeValue(v.cvar_name, v.cvar_value)
	end
end)

snet.RegisterCallback('slib_gcvars_server_update_success', function(_, cvar_name, old_value, new_value)
	hook.Run('slib.OnChangeGlobalCvar', cvar_name, old_value, new_value)

	ChangeValue(cvar_name, new_value)

	cvar_name = tostring(cvar_name)
	new_value = tostring(new_value)

	slib.DebugLog('[SUCCESS] Server update cvar - ', cvar_name, ' (', new_value, ')')

	local cvar_data = slib.Storage.GlobalCvar[cvar_name]
	if not cvar_data or not access.IsValid(LocalPlayer(), cvar_data.access) then
		return
	end

	local text = slib.language({
		['default'] = 'New value for "' .. cvar_name .. '" - ' .. new_value,
		['russian'] = 'Новое значение для "' .. cvar_name .. '" - ' .. new_value
	})

	notification.AddLegacy(text, NOTIFY_GENERIC, 4)

	surface.PlaySound('UI/buttonclick.wav')
end)

snet.RegisterCallback('slib_gcvars_server_update_error', function(_, cvar_name, value)
	ChangeValue(cvar_name, value)

	cvar_name = tostring(cvar_name)
	value = tostring(value)

	slib.DebugLog('[ERROR] Server update cvar - ', cvar_name, ' (', value, ')')

	local text = slib.language({
		['default'] = 'Cancel value for "' .. cvar_name .. '" - ' .. value,
		['russian'] = 'Отмена значения для "' .. cvar_name .. '" - ' .. value
	})

	notification.AddLegacy(text, NOTIFY_ERROR, 4)

	surface.PlaySound('Resource/warning.wav')
end)
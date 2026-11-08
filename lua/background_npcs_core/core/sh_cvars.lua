--[[
	Server settings that admins can change from the client menus. Replaces slib "scvar".

	The cvar exists in both realms. The server value is the real one and is
	pushed to every client; when an admin changes the client copy (spawn menu
	panels bind to it by name), the change is sent to the server. Changes by
	non-admins are reverted.

		bgNPC.CVars.Register(name, default, help)
		bgNPC.CVars.OnChange(name, function(name, old, new) end, id)  -- both realms
		bgNPC.CVars.Watch(name)  -- client: a notice to this player only when a local cvar changes

	Every change of a server cvar is announced to all players (the server confirms what it really holds, so a
	lost or refused change is visible too); a change of a client cvar is announced to its player only.
--]]

local Net = bgNPC.Net
local CVars = bgNPC.CVars or {}
bgNPC.CVars = CVars

--

local registered = CVars.registered or {}
CVars.registered = registered
local listeners = CVars.listeners or {}
CVars.listeners = listeners

local function Notify(name, old_value, new_value)
	local list = listeners[name]
	if not list then return end
	for _, func in pairs(list) do
		func(name, old_value, new_value)
	end
end

function CVars.OnChange(name, func, id)
	listeners[name] = listeners[name] or {}
	listeners[name][id or (#listeners[name] + 1)] = func
end

function CVars.IsRegistered(name)
	return registered[name] == true
end

if SERVER then
	function CVars.Register(name, default, help)
		if registered[name] then return end
		registered[name] = true

		CreateConVar(name, tostring(default), FCVAR_ARCHIVE, help or '')
		cvars.AddChangeCallback(name, function(_, old_value, new_value)
			if old_value == new_value then return end
			Notify(name, old_value, new_value)
			Net.Send('bgn.cvar', nil, name, new_value)
		end, 'BGN_CVars')
	end

	-- a server cvar that is not synchronized (CreateConVar in a module): only the notice goes to the players
	local watched = {}
	function CVars.Watch(name)
		if watched[name] or registered[name] then return end
		watched[name] = true
		cvars.AddChangeCallback(name, function(_, old_value, new_value)
			if old_value ~= new_value then Net.Send('bgn.cvar_note', nil, name, new_value) end
		end, 'BGN_CVarWatch')
	end

	Net.Receive('bgn.cvar_set', function(ply, name, value)
		if not registered[name] or value == nil then return end
		value = tostring(value)
		-- nothing to change: tell the sender what the server holds, quietly (its copy may be stale)
		if GetConVar(name):GetString() == value then
			Net.Send('bgn.cvar', ply, name, value, true)
			return
		end
		RunConsoleCommand(name, value)
	end, { admin = true })

	hook.Add('BGN_PlayerReady', 'BGN_CVarsSync', function(ply)
		local values = {}
		for name in pairs(registered) do
			values[name] = GetConVar(name):GetString()
		end
		Net.Send('bgn.cvar_sync', ply, values)
	end)
else
	-- name -> value we are setting ourselves, so its change callback is not sent back
	local expected = {}

	local function Apply(name, value)
		local cvar = GetConVar(name)
		if not cvar or cvar:GetString() == value then return end
		expected[name] = value
		RunConsoleCommand(name, value)
	end

	-- One notice per cvar: a slider sends many changes, the last value is shown
	local function Toast(name, value)
		timer.Create('BGN_CVarToast_' .. name, 0.4, 1, function()
			notification.AddLegacy(bgNPC.Util.Lang({
				default = 'Setting changed: ' .. name .. ' = ' .. value,
				russian = 'Настройка изменена: ' .. name .. ' = ' .. value,
			}), NOTIFY_GENERIC, 4)
			surface.PlaySound('UI/buttonclick.wav')
		end)
	end

	local watched = {}
	function CVars.Watch(name)
		if watched[name] or registered[name] then return end
		watched[name] = true
		cvars.AddChangeCallback(name, function(_, old_value, new_value)
			if old_value ~= new_value then Toast(name, new_value) end
		end, 'BGN_CVarWatch')
	end

	function CVars.Register(name, default, help)
		if registered[name] then return end
		registered[name] = true

		CreateConVar(name, tostring(default), FCVAR_NONE, help or '')
		cvars.AddChangeCallback(name, function(_, old_value, new_value)
			if old_value == new_value then return end

			if expected[name] == new_value then
				expected[name] = nil
				Notify(name, old_value, new_value)
				return
			end

			local ply = LocalPlayer()
			if IsValid(ply) and (ply:IsAdmin() or ply:IsSuperAdmin()) then
				Net.SendToServer('bgn.cvar_set', name, new_value)
				return
			end

			Apply(name, old_value)
			notification.AddLegacy(bgNPC.Util.Lang({
				default = 'Insufficient rights to make changes',
				russian = 'Недостаточно прав для внесения изменений',
			}), NOTIFY_ERROR, 4)
			surface.PlaySound('buttons/combine_button_locked.wav')
		end, 'BGN_CVars')
	end

	Net.Receive('bgn.cvar', function(_, name, value, silent)
		if not registered[name] then return end
		Apply(name, value)
		if not silent then Toast(name, value) end
	end)

	Net.Receive('bgn.cvar_note', function(_, name, value) Toast(name, value) end)

	Net.Receive('bgn.cvar_sync', function(_, values)
		for name, value in pairs(values) do
			if registered[name] then Apply(name, value) end
		end
	end)
end

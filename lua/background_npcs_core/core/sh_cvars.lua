--[[
	Server settings that admins can change from the client menus. Replaces slib "scvar".

	The cvar exists in both realms. The server value is the real one and is
	pushed to every client; when an admin changes the client copy (spawn menu
	panels bind to it by name), the change is sent to the server. Changes by
	non-admins are reverted.

		bgNPC.CVars.Register(name, default, help)
		bgNPC.CVars.OnChange(name, function(name, old, new) end, id)  -- both realms

	Notices of the changes live in core/sh_notice.lua (loaded first): a server cvar is announced to all players
	after the server applied it, a client cvar to its player only.
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
		bgNPC.Notice.Watch(name)
		cvars.AddChangeCallback(name, function(_, old_value, new_value)
			if old_value == new_value then return end
			Notify(name, old_value, new_value)
			Net.Send('bgn.cvar', nil, name, new_value)
		end, 'BGN_CVars')
	end

	Net.Receive('bgn.cvar_set', function(ply, name, value)
		if not registered[name] or value == nil then return end
		value = tostring(value)
		-- nothing to change: tell the sender what the server holds, quietly (its copy may be stale)
		if GetConVar(name):GetString() == value then
			Net.Send('bgn.cvar', ply, name, value)
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
	local confirmed = {}

	local function Apply(name, value)
		local cvar = GetConVar(name)
		if not cvar then return end
		local old_value = confirmed[name] or cvar:GetString()
		confirmed[name] = value
		if cvar:GetString() ~= value then
			expected[name] = value
			RunConsoleCommand(name, value)
		end
		-- The admin's local copy may already match; its listeners still need the server confirmation.
		if old_value ~= value then Notify(name, old_value, value) end
	end

	function CVars.Register(name, default, help)
		if registered[name] then return end
		registered[name] = true

		CreateConVar(name, tostring(default), FCVAR_NONE, help or '')
		confirmed[name] = GetConVar(name):GetString()
		cvars.AddChangeCallback(name, function(_, old_value, new_value)
			if old_value == new_value then return end

			if expected[name] == new_value then
				expected[name] = nil
				return
			end

			local ply = LocalPlayer()
			if IsValid(ply) and (ply:IsAdmin() or ply:IsSuperAdmin()) then
				Net.SendToServer('bgn.cvar_set', name, new_value)
				return
			end

			Apply(name, confirmed[name] or old_value)
			notification.AddLegacy(bgNPC.Util.Lang({
				default = 'Insufficient rights to make changes',
				russian = 'Недостаточно прав для внесения изменений',
			}), NOTIFY_ERROR, 4)
			surface.PlaySound('buttons/combine_button_locked.wav')
		end, 'BGN_CVars')
	end

	Net.Receive('bgn.cvar', function(_, name, value)
		if registered[name] then Apply(name, value) end
	end)

	Net.Receive('bgn.cvar_sync', function(_, values)
		for name, value in pairs(values) do
			if registered[name] then Apply(name, value) end
		end
	end)
end

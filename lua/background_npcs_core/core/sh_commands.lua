--[[
	Console commands that run on the server and then on clients. Replaces slib "scommand".

		bgNPC.Commands.Register('bgn_example', {
			admin = true,          -- only admins (and the server console)
			broadcast = true,      -- run "client" on every client, not only on the caller
			server = function(ply, cmd, args) end,
			client = function(ply, cmd, args) end,
			help = 'Help text',
			autocomplete = function(cmd, args) return {} end,
		})

	Typed on a client, the command is forwarded to the server first.
--]]

local Net = bgNPC.Net
local Commands = bgNPC.Commands or {}
bgNPC.Commands = Commands

--

local list = Commands.list or {}
Commands.list = list

local function HasAccess(command, ply)
	if not command.admin or not IsValid(ply) then return true end
	return ply:IsAdmin() or ply:IsSuperAdmin()
end

local function RunOnServer(command, ply, cmd, args)
	if not HasAccess(command, ply) then return end
	if command.server then command.server(ply, cmd, args) end

	if not command.client then return end
	if command.broadcast then
		Net.Send('bgn.command', nil, cmd, args)
	elseif IsValid(ply) then
		Net.Send('bgn.command', ply, cmd, args)
	end
end

function Commands.Register(name, command)
	list[name] = command

	concommand.Add(name, function(ply, cmd, args)
		if SERVER then
			RunOnServer(command, ply, cmd, args)
		elseif HasAccess(command, ply) then
			Net.SendToServer('bgn.command', cmd, args)
		end
	end, command.autocomplete, command.help)
end

if SERVER then
	Net.Receive('bgn.command', function(ply, cmd, args)
		local command = list[cmd]
		if command then RunOnServer(command, ply, cmd, args or {}) end
	end)
else
	Net.Receive('bgn.command', function(_, cmd, args)
		local command = list[cmd]
		if command and command.client then command.client(LocalPlayer(), cmd, args or {}) end
	end)
end

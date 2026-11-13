local Component = slib.Components.GlobalCommand
local AccessComponent = slib.Components.Access
slib.Storage.ConsoleCommands = slib.Storage.ConsoleCommands or {}

if CLIENT then
	snet.RegisterCallback('slib_global_commands_client_rpc', function(ply, cmd, args)
		local command = slib.Storage.ConsoleCommands[cmd]
		if not command or not command.IsAccess(ply) then return end

		command.RunClientCommand(ply, cmd, args)
	end)
else
	snet.Callback('slib_global_commands_server_rpc', function(ply, cmd, args)
		local command = slib.Storage.ConsoleCommands[cmd]
		if not command or not command.IsAccess(ply) then return end

		command.RunServerCommand(ply, cmd, args)

		if command.broadcast then
			snet.InvokeAll('slib_global_commands_client_rpc', cmd, args)
		else
			snet.Invoke('slib_global_commands_client_rpc', ply, cmd, args)
		end
	end)
end

function Component.Create(_name, _autoComplete, _helpText, _flags, _access)
	local private = {}
	private.name = _name
	private.broadcast = false
	private.client_callback = nil
	private.server_callback = nil
	private.autoComplete = _autoComplete or nil
	private.helpText = _helpText or nil
	private.flags = _flags or 0
	private.access = _access and AccessComponent:Make( _access ) or _access

	function private.RunServerCommand(ply, cmd, args)
		if not private.server_callback or not isfunction(private.server_callback) then return end
		private.server_callback(ply, cmd, args)
	end

	function private.RunClientCommand(ply, cmd, args)
		if not private.client_callback or not isfunction(private.client_callback) then return end
		private.client_callback(ply, cmd, args)
	end

	function private.IsAccess(ply)
		if IsValid(ply) and private.access then
			return AccessComponent.IsValid(ply, private.access)
		end
		return true
	end

	local public = {}

	function public.OnServer(func)
		private.server_callback = func
		return public
	end

	function public.OnClient(func)
		private.client_callback = func
		return public
	end

	function public.Broadcast()
		private.broadcast = true
		return public
	end

	function public.OnShared(func)
		public.OnServer(func)
		public.OnClient(func)
		return public
	end

	function public.AutoComplete(autoComplete)
		private.autoComplete = autoComplete
		return public
	end

	function public.HelpText(text)
		private.helpText = text
		return public
	end

	function public.Flags(flags)
		private.flags = flags
		return public
	end

	function public.Access(access)
		private.access = access and AccessComponent:Make( access ) or access
		return public
	end

	function public.Register()
		local name = private.name
		local autoComplete = private.autoComplete
		local helpText = private.helpText
		local flags = private.flags

		slib.Storage.ConsoleCommands[name] = private

		concommand.Add(name, function(ply, cmd, args)
			if not private.IsAccess(ply) then return end

			if SERVER then
				private.RunServerCommand(ply, cmd, args)

				if private.broadcast then
					snet.InvokeAll('slib_global_commands_client_rpc', cmd, args)
				elseif IsValid(ply) then
					snet.Invoke('slib_global_commands_client_rpc', ply, cmd, args)
				end
			else
				snet.InvokeServer('slib_global_commands_server_rpc', cmd, args)
			end
		end, autoComplete, helpText, flags)

		return public
	end

	return public
end
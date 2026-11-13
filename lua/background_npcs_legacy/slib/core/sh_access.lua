local Component = {}

function Component:Make(data)
	data = data or {}

	local private = {}
	private.custom = data.custom
	private.usergroups = data.usergroups
	private.teams = data.teams
	private.steamids = data.steamids
	private.steamids64 = data.steamids64
	private.nicknames = data.nicknames
	private.isAdmin = data.isAdmin
	private.isSuperAdmin = data.isSuperAdmin

	function private.Parse(access_data, func)
		if not isfunction(func) then return end
		if istable(access_data) then
			for k, v in ipairs(access_data) do
				if func(v) then return true end
			end
			return false
		else
			return func(access_data)
		end
	end

	function private.IsValidCustom(ply, func)
		if isfunction(func) and func(ply) then return true end
	end

	function private.IsValidUserGroup(ply, usergroup)
		if IsValid(ply) and ply:GetUserGroup() == usergroup then return true end
	end

	function private.IsValidTeam(ply, team_id)
		if IsValid(ply) and ply:Team() == team_id then return true end
	end

	function private.IsValidSteamID(ply, steamid)
		if IsValid(ply) and ply:SteamID() == steamid then return true end
	end

	function private.IsValidSteamID64(ply, steamid64)
		if IsValid(ply) and ply:SteamID64() == steamid64 then return true end
	end

	function private.IsValidNickName(ply, nickname)
		if IsValid(ply) and ply:Nick() == nickname then return true end
	end

	function private.IsValidAdmin(ply)
		if IsValid(ply) and (game.SinglePlayer() or ply:IsAdmin()) then return true end
	end

	function private.IsValidSuperAdmin(ply)
		if IsValid(ply) and (game.SinglePlayer() or ply:IsSuperAdmin()) then return true end
	end

	local public = {}
	public.IsAccessComponent = true

	function public.IsValid(ply)
		slib.DebugLog('Start valid access checker from ', ply)

		if private.custom then
			slib.DebugLog('Valid type - custom')

			local result = private.Parse(private.custom, function(func)
				return private.IsValidCustom(ply, func)
			end)

			if result then return true end
		end

		if private.usergroups then
			slib.DebugLog('Valid type - usergroups')

			local result = private.Parse(private.usergroups, function(usergroup)
				return private.IsValidUserGroup(ply, usergroup)
			end)

			if result then return true end
		end

		if private.teams then
			slib.DebugLog('Valid type - teams')

			local result = private.Parse(private.teams, function(team_id)
				return private.IsValidTeam(ply, team_id)
			end)

			if result then return true end
		end

		if private.steamids then
			slib.DebugLog('Valid type - steamids')

			local result = private.Parse(private.steamids, function(steamid)
				return private.IsValidSteamID(ply, steamid)
			end)

			if result then return true end
		end

		if private.steamids64 then
			slib.DebugLog('Valid type - steamids64')

			local result = private.Parse(private.steamids64, function(steamid64)
				return private.IsValidSteamID64(ply, steamid64)
			end)

			if result then return true end
		end

		if private.nicknames then
			slib.DebugLog('Valid type - nicknames')

			local result = private.Parse(private.nicknames, function(nickname)
				return private.IsValidNickName(ply, nickname)
			end)

			if result then return true end
		end

		if private.isAdmin then
			slib.DebugLog('Valid type - isAdmin')

			if private.IsValidAdmin(ply) then return true end
		end

		if private.isSuperAdmin then
			slib.DebugLog('Valid type - isSuperAdmin')

			if private.IsValidSuperAdmin(ply) then return true end
		end

		slib.DebugLog('Stop valid access checker from ', ply)

		return false
	end

	return public
end

function Component.IsValid(ply, access)
	if not access or not istable(access) then return true end

	slib.DebugLog('IsValid component: ', ply, ', ', table.ToString(access))

	if not access.IsAccessComponent or not access.IsValid then
		slib.DebugLog('IsValid component dynamic created')
		return Component:Make(access).IsValid(ply)
	else
		slib.DebugLog('IsValid component exists')
		return access.IsValid(ply)
	end
end

slib.Components.Access = Component
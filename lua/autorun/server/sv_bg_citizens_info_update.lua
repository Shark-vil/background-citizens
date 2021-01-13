util.AddNetworkString('bgn_player_initial_info_block')

local is_informated = {}

hook.Add('PlayerSpawn', 'BGN_PlayerSpawnInitInfoBlock', function(ply)
	if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end

	if table.HasValue(is_informated, ply) then return end

	timer.Simple(4, function()
		if not IsValid(ply) then return end

		net.Start('bgn_player_initial_info_block')
		net.Send(ply)
	end)

	table.insert(is_informated, ply)
end)
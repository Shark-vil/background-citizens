local isentity = isentity
local table_insert = table.insert
--

function slib.GetAllLoadedPlayers()
	return slib.Storage.LoadedPlayers
end

function slib.PlayerIsNetReady(ply)
	if not ply or not ply.snet_ready then return false end
	return true
end

function slib.ListPlayerParse(player_list)
	local players = {}

	for i = 1, #player_list do
		local ply = player_list[i]

		if ply and isentity(ply) and ply:IsPlayer() and not ply:IsBot() then
			table_insert(players, ply)
		end
	end

	return players
end


function slib.ListFastPlayerParse(player_list)
	local players = {}

	for i = 1, #player_list do
		local ply = player_list[i]

		if ply and not ply:IsBot() then
			table_insert(players, ply)
		end
	end

	return players
end
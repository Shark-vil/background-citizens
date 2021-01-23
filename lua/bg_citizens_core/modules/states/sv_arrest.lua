local ASSET = {}
local arrest_players = {}

function ASSET:AddPlayer(ply)
	if IsValid(ply) and ply:IsPlayer() and arrest_players[ply] == nil then
		local c_Arrest = {
			delayIgnore = CurTime() + GetConVar('bgn_arrest_time_limit'):GetFloat(),
			notify_delay = 0,
			not_arrest = false,
			count = 1
		}
		
		arrest_players[ply] = c_Arrest
		return true
	end
	return false
end

function ASSET:RemovePlayer(ply)
	arrest_players[ply] = nil
end

function ASSET:ClearAll()
	table.Empty(arrest_players)
end

function ASSET:HasPlayer(ply)
	if IsValid(ply) and arrest_players[ply] ~= nil then
		return true
	end
	return false
end

function ASSET:GetPlayer(ply)
	return arrest_players[ply]
end

function ASSET:GetAllPlayers()
	return arrest_players
end

hook.Add("PlayerDeath", "BGN_ArrestModule_ClearDataOnPlayerDeath", function(victim, inflictor, attacker)
	ASSET:RemovePlayer(victim)
end)

hook.Add('PostCleanupMap', 'BGN_ArrestModule_ClearPlayerOnCleanupMap', function()
	ASSET:ClearAll()
end)

list.Set('BGN_Modules', 'player_arrest', ASSET)
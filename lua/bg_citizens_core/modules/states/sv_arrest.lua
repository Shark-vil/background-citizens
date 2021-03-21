local ASSET = {}
local arrest_players = {}

function ASSET:AddPlayer(ply, policeActor)
	if IsValid(ply) and ply:IsPlayer() and policeActor and arrest_players[ply] == nil then
		local ArrestComponent = {
			warningTime = CurTime() + GetConVar('bgn_arrest_time_limit'):GetFloat(),
			notify_order_time = 0,
			notify_arrest_time = 0,
			arrest_time = 0,
			detention = false,
			arrested = true,
			damege_count = 1,
			is_look_police = false,
			policeActor = policeActor
		}
		
		arrest_players[ply] = ArrestComponent
		return true
	end
	return false
end

function ASSET:RemovePlayer(ply)
	if arrest_players[ply] == nil then return end
	
	local ArrestComponent = self:GetPlayer(ply)
	if ArrestComponent.policeActor then
		ArrestComponent.policeActor:RemoveTarget(ply)
	end
	
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

function ASSET:NotSubjectToArrest(ply)
	local ArrestComponent = self:GetPlayer(ply)
	if ArrestComponent then
		ArrestComponent.arrested = false
		
		local actor = ArrestComponent.policeActor
		if actor then
			actor:RemoveAllTargets()
			actor:AddEnemy(ply)
			actor:SetState('defense')
		end
	end
end

hook.Add("PlayerDeath", "BGN_ArrestModule_ClearDataOnPlayerDeath", function(victim, inflictor, attacker)
	ASSET:RemovePlayer(victim)
end)

hook.Add("BGN_RemoveWantedTarget", "BGN_ArrestModule_ClearByWanted", function(target)
	ASSET:RemovePlayer(target)
end)

hook.Add('PostCleanupMap', 'BGN_ArrestModule_ClearPlayerOnCleanupMap', function()
	ASSET:ClearAll()
end)

list.Set('BGN_Modules', 'player_arrest', ASSET)
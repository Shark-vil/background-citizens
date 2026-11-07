--[[
	Hook "BGN_PlayerReady"(ply): the player has fully loaded and can receive network messages.
	Runs on the server and on every client. Replaces slib "slib.FirstPlayerSpawn".
		bgNPC.Util.IsPlayerReady(ply)
--]]

local bgNPC = bgNPC
local Net = bgNPC.Net
local IsValid = IsValid
--

function bgNPC.Util.IsPlayerReady(ply)
	return IsValid(ply) and ply.bgn_ready == true
end

if SERVER then
	Net.Receive('bgn.player_ready', function(ply)
		if ply.bgn_ready then return end
		ply.bgn_ready = true
		hook.Run('BGN_PlayerReady', ply)
		Net.Send('bgn.player_ready', nil, ply)
	end)
else
	hook.Add('InitPostEntity', 'BGN_PlayerReady', function()
		Net.SendToServer('bgn.player_ready')
	end)

	Net.Receive('bgn.player_ready', function(_, ply)
		if not IsValid(ply) or ply.bgn_ready then return end
		ply.bgn_ready = true
		hook.Run('BGN_PlayerReady', ply)
	end, { wait_entities = true })
end

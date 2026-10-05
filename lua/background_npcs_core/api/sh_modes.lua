local bgNPC = bgNPC
local Util = bgNPC.Util
local Modes = bgNPC.Modes
--

local function IsCVarEnabled(name)
	local cvar = Util.GetCVar(name)
	return cvar ~= nil and cvar:GetBool()
end

-- Actors never fight. See modules/modes/sv_peaceful_mode.lua
function Modes.IsPeaceful()
	return IsCVarEnabled('bgn_peaceful_mode')
end

-- Actors take the player's side in every fight. See modules/modes/sv_friend_and_aggressive_mode.lua
function Modes.IsFriend()
	return IsCVarEnabled('bgn_friend_mode')
end

-- All actors are hostile towards players.
function Modes.IsAggressive()
	return IsCVarEnabled('bgn_agressive_mode')
end

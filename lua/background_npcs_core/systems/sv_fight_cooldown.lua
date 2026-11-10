--[[
	Delay between skirmishes (cvar "bgn_fight_cooldown", seconds, default 60, 0 = off: every witness may step in, as before).
	The first "defense" reaction of the at_protect table (actors protecting their own) opens a window of that length
	around the place of the skirmish (RADIUS). While it lasts, an at_protect call against ANOTHER attacker in that area
	is ignored (Actor:GetReactionForProtect returns 'ignore' and the call for help adds no enemy). Actors joining the
	skirmish that opened the window (same attacker) are not blocked, nor is anything outside the area or after the
	window. Only an attacker that is one of our actors is delayed: a player and any NPC or NextBot of another mod
	(not an actor) always get their reaction, the delay only spaces out fights between actors.
--]]

local FightCooldown = {}
bgNPC.FightCooldown = FightCooldown

local RADIUS_SQR = 2500 ^ 2
local cvar = GetConVar('bgn_fight_cooldown')

local windows = {}

-- @return boolean false when a skirmish with another attacker started here less than "bgn_fight_cooldown" seconds ago
function FightCooldown.Allow(actor, enemy)
	local delay = cvar:GetFloat()
	if delay <= 0 or enemy:IsPlayer() or not bgNPC.Actors.Get(enemy) then return true end

	local now, pos = CurTime(), actor:GetNPC():GetPos()
	local blocked
	for i = #windows, 1, -1 do
		local window = windows[i]
		if window.expires <= now or not IsValid(window.enemy) then
			table.remove(windows, i)
		elseif window.pos:DistToSqr(pos) <= RADIUS_SQR then
			if window.enemy == enemy then return true end
			blocked = true
		end
	end
	if blocked then return false end

	windows[#windows + 1] = { enemy = enemy, pos = pos, expires = now + delay }
	return true
end

hook.Add('PostCleanupMap', 'BGN_FightCooldown_Reset', function() table.Empty(windows) end)

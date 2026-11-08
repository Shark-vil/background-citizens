--[[
	Ghost crowd (EXPERIMENTAL): sends navigation points around a player to the client side crowd
	(systems/cl_ghost_crowd.lua). The server has no ghosts, it only answers point requests.
--]]

local REQUEST_PERIOD = 2
local MAX_RADIUS = 10000
local MAX_POINTS = 1500

bgNPC.Net.Receive('bgn_ghost_crowd_points', function(ply, radius)
	if not isnumber(radius) or (ply.bgn_ghost_points_next or 0) > CurTime() then return end
	ply.bgn_ghost_points_next = CurTime() + REQUEST_PERIOD

	-- Centered on the player's real position, the client only picks the radius
	local points = bgNPC.Nav.GetPointsInRadius(ply:GetPos(), math.Clamp(radius, 0, MAX_RADIUS), 'walk', MAX_POINTS)

	while #points > MAX_POINTS do
		local i = math.random(#points)
		points[i] = points[#points]
		points[#points] = nil
	end

	bgNPC.Net.Send('bgn_ghost_crowd_points', ply, points)
end)

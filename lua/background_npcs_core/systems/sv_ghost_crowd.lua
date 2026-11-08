--[[
	Ghost crowd (EXPERIMENTAL): sends navigation points around a player to the client side crowd
	(systems/cl_ghost_crowd.lua). The server has no ghosts, it only answers point requests.

	Answers are cached per map cell and radius, so players standing near each other (or one player walking
	back and forth) share one navigation query.
--]]

local REQUEST_PERIOD = 2
local MAX_RADIUS = 10000
local MAX_POINTS = 1500
local CELL = 1024
local CACHE_TIME = 15

local cache = {}

local function CellKey(pos, radius)
	return math.floor(pos.x / CELL) .. ':' .. math.floor(pos.y / CELL) .. ':' .. math.floor(pos.z / CELL) .. ':' .. radius
end

local function GetPoints(pos, radius)
	local key = CellKey(pos, radius)
	local entry = cache[key]
	if entry and entry.time > CurTime() then return entry.points end

	-- The cell center, so every player of the cell gets the same points
	local center = Vector((math.floor(pos.x / CELL) + 0.5) * CELL, (math.floor(pos.y / CELL) + 0.5) * CELL, pos.z)
	local points = bgNPC.Nav.GetPointsInRadius(center, radius, 'walk', MAX_POINTS)

	while #points > MAX_POINTS do
		local i = math.random(#points)
		points[i] = points[#points]
		points[#points] = nil
	end

	cache[key] = { time = CurTime() + CACHE_TIME, points = points }
	return points
end

timer.Create('BGN_GhostCrowdCacheCleanup', CACHE_TIME, 0, function()
	local now = CurTime()
	for key, entry in pairs(cache) do
		if entry.time <= now then cache[key] = nil end
	end
end)

hook.Add('BGN_NavProviderChanged', 'BGN_GhostCrowdCache', function() cache = {} end)

bgNPC.Net.Receive('bgn_ghost_crowd_points', function(ply, radius)
	if not isnumber(radius) or (ply.bgn_ghost_points_next or 0) > CurTime() then return end
	ply.bgn_ghost_points_next = CurTime() + REQUEST_PERIOD

	-- Centered on the player's real position, the client only picks the radius (rounded: fewer cache keys)
	radius = math.Round(math.Clamp(radius, 0, MAX_RADIUS), -2)
	bgNPC.Net.Send('bgn_ghost_crowd_points', ply, GetPoints(ply:GetPos(), radius))
end)

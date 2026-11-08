--[[
	Ghost crowd, shared part: the rules both modes walk by.
	- Local mode (client only, "bgn_cl_ghost_crowd"): cl_ghost_crowd.lua invents ghosts for this player alone.
	- Server mode ("bgn_ghost_crowd"): sv_ghost_crowd.lua runs the ghosts, every client draws the same ones
	  (cl_ghost_crowd.lua), and a ghost a player walks up to turns into a real actor on its spot.
	A server ghost moves along segments { from, to, t0, speed }: the server sends a segment once, every client
	computes the position from CurTime() (SegmentPos), so all players see a ghost at the same place.
--]]

local GhostCrowd = {}
bgNPC.GhostCrowd = GhostCrowd

GhostCrowd.STEP_DIST = 700  -- farthest next point
GhostCrowd.MAX_STEP_Z = 72  -- the most height change between two points
GhostCrowd.HEAD = Vector(0, 0, 64)
GhostCrowd.VIEW_DOT = 0.4   -- a bit wider than a usual horizontal FOV
GhostCrowd.WALK_SPEED = 75  -- server mode: clients scale the animation to these speeds
GhostCrowd.RUN_SPEED = 190
GhostCrowd.FADE_TIME = 1.5

local CHEST = Vector(0, 0, 40)

function GhostCrowd.IsServerMode()
	return GetConVar('bgn_ghost_crowd'):GetBool()
end

-- Inner radius: ghosts leave inside it (real actors live there). Outer: they live up to it.
function GhostCrowd.Radii()
	local radius = GetConVar('bgn_spawn_radius'):GetFloat()
	return radius * 0.35, radius * 1.5
end

-- In front of the eyes and not behind a wall
function GhostCrowd.IsSeen(eye, eye_dir, pos)
	local dir = pos - eye
	dir:Normalize()
	if eye_dir:Dot(dir) < GhostCrowd.VIEW_DOT then return false end
	return not util.TraceLine({ start = eye, endpos = pos, mask = MASK_VISIBLE }).Hit
end

-- SetBodyGroups format: one char per group, 0-9 then a-z
function GhostCrowd.BodygroupsOf(ent)
	local chars = {}
	for i = 0, ent:GetNumBodyGroups() - 1 do
		local value = ent:GetBodygroup(i)
		chars[#chars + 1] = value < 10 and tostring(value) or string.char(87 + value)
	end
	return table.concat(chars)
end

-- @return Vector the position on the segment at the time now
function GhostCrowd.SegmentPos(seg, now)
	if seg.speed <= 0 then return seg.from end
	local len = seg.from:Distance(seg.to)
	if len < 1 then return seg.to end
	return LerpVector(math.Clamp((now - seg.t0) * seg.speed / len, 0, 1), seg.from, seg.to)
end

--[[
	Next point: within STEP_DIST, not back (prev), never towards away_from (sideways is fine when calm,
	only away when running), not blocked (inside a player's inner radius), no wall in the way.
	@param each function(callback) calls callback(pos) for every point near from
	@param blocked function(pos) true for points ghosts must not walk to
	@return Vector|nil
--]]
function GhostCrowd.NextPoint(from, prev, away_from, run_away, each, blocked)
	local away = from - away_from
	away.z = 0
	away:Normalize()
	local min_dot = run_away and 0.3 or -0.2
	local max_sqr = GhostCrowd.STEP_DIST * GhostCrowd.STEP_DIST
	local candidates = {}

	each(function(pos)
		local dist_sqr = pos:DistToSqr(from)
		if dist_sqr < 2500 or dist_sqr > max_sqr or math.abs(pos.z - from.z) > GhostCrowd.MAX_STEP_Z then return end
		if pos == prev or blocked(pos) then return end
		local dir = pos - from
		dir.z = 0
		dir:Normalize()
		local dot = dir:Dot(away)
		if dot >= min_dot then
			candidates[#candidates + 1] = { pos = pos, score = math.random() + (run_away and dot or 0) }
		end
	end)

	table.sort(candidates, function(a, b) return a.score > b.score end)

	for i = 1, math.min(#candidates, 3) do
		local pos = candidates[i].pos
		if not util.TraceLine({ start = from + CHEST, endpos = pos + CHEST, mask = MASK_SOLID_BRUSHONLY }).Hit then
			return pos
		end
	end
end

bgNPC.Test.Add('ghost_crowd_rules', function(check)
	local function List(points) return function(callback) for _, pos in ipairs(points) do callback(pos) end end end
	local function Never() return false end
	local from, ply_pos = Vector(0, 0, 0), Vector(-1000, 0, 0)

	check(GhostCrowd.NextPoint(from, nil, ply_pos, false, List({ Vector(-300, 0, 0), Vector(-300, 100, 0) }), Never) == nil,
		'never walks towards the player')
	check(GhostCrowd.NextPoint(from, nil, ply_pos, false, List({ Vector(300, 0, 500), Vector(2000, 0, 0) }), Never) == nil,
		'skips too high and too far points')
	check(GhostCrowd.NextPoint(from, nil, ply_pos, false, List({ Vector(300, 0, 0) }), function() return true end) == nil,
		'skips blocked points')
	local pos = GhostCrowd.NextPoint(from, nil, ply_pos, true, List({ Vector(300, 0, 0) }), Never)
	check(pos == nil or pos == Vector(300, 0, 0), 'runs away from the player') -- nil: a wall in the way on this map

	local seg = { from = Vector(0, 0, 0), to = Vector(100, 0, 0), t0 = 10, speed = 50 }
	check(GhostCrowd.SegmentPos(seg, 11) == Vector(50, 0, 0), 'segment: halfway after a second')
	check(GhostCrowd.SegmentPos(seg, 99) == seg.to, 'segment: stops at the end')
	check(GhostCrowd.SegmentPos(seg, 0) == seg.from, 'segment: not before the start')
	seg.speed = 0
	check(GhostCrowd.SegmentPos(seg, 11) == seg.from, 'segment: standing still')
end)

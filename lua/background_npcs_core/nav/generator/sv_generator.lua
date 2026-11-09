--[[
	Node generator for maps without NavMesh and nodegraph. Fills the custom graph by flood fill:
	from seed points it steps over the floor on a grid, checking every step with a human hull trace
	(walls, ledges, steep slopes and water stop it). Runs on the scheduler budget, never freezes the server.

	Commands (admin):
		bgn_nav_generate             whole map, seeds: player spawn points and players
		bgn_nav_generate around [r]  only around you (radius r, default bgn_dynamic_nodes_radius)
		bgn_nav_generate stop
	Runtime mode ("bgn_dynamic_nodes 1"): on maps that use an unsaved custom graph, the area around
	players is generated automatically. "bgn_dynamic_nodes_save_progress 1" saves the result.

	Hooks: BGN_NavGeneratorFinished(graph, added_count)
--]]

local Nav = bgNPC.Nav
local Generator = bgNPC.NavGenerator or {}
bgNPC.NavGenerator = Generator

local TASK = 'BGN_NavGenerator'
local HULL_MINS = Vector(-13, -13, 0)
local HULL_MAXS = Vector(13, 13, 64)
local STEP_UP = Vector(0, 0, 20)
local MAX_DROP = 60
local MIN_FLOOR_NORMAL_Z = 0.7
local DEFAULT_MAX_NODES = 15000
local NOTIFY_PERIOD = 1

local DIRECTIONS = {}
for i = 0, 7 do
	local a = math.rad(i * 45)
	DIRECTIONS[#DIRECTIONS + 1] = Vector(math.Round(math.cos(a), 3), math.Round(math.sin(a), 3), 0)
end

local cvar_step = GetConVar('bgn_runtime_generator_grid_offset')
local cvar_radius = GetConVar('bgn_dynamic_nodes_radius')
local cvar_dynamic = GetConVar('bgn_dynamic_nodes')
local cvar_save = GetConVar('bgn_dynamic_nodes_save_progress')
local cvar_max_nodes = CreateConVar('bgn_nav_generator_max_nodes', tostring(DEFAULT_MAX_NODES), { FCVAR_ARCHIVE },
	'Background NPCs: node limit of the generator', 100, 200000)

local hull_trace = { mins = HULL_MINS, maxs = HULL_MAXS, mask = MASK_NPCSOLID_BRUSHONLY }
local floor_trace = { mins = HULL_MINS, maxs = HULL_MAXS, mask = MASK_NPCSOLID_BRUSHONLY }

-- @return Vector|nil the floor under pos (within MAX_DROP below and STEP_UP above)
local function FindFloor(pos)
	floor_trace.start = pos + STEP_UP
	floor_trace.endpos = pos - Vector(0, 0, MAX_DROP)
	local tr = util.TraceHull(floor_trace)
	if not tr.Hit or tr.StartSolid or tr.HitNormal.z < MIN_FLOOR_NORMAL_Z then return nil end
	if bit.band(util.PointContents(tr.HitPos + STEP_UP), CONTENTS_WATER) ~= 0 then return nil end
	return tr.HitPos
end
Generator.FindFloor = FindFloor

-- Can a human walk straight from a to b (both on the floor)?
local function CanStep(a, b)
	hull_trace.start = a + STEP_UP
	hull_trace.endpos = b + STEP_UP
	local tr = util.TraceHull(hull_trace)
	return not tr.Hit and not tr.StartSolid
end
Generator.CanStep = CanStep

local function Notify(ply, text)
	if IsValid(ply) then
		bgNPC.Net.Send('bgn_nav_generator_progress', ply, text)
	end
	bgNPC.Util.Log(text, 'NavGenerator')
end

-- Removes nodes in the middle of straight two-way corridors (the neighbours see each other).
local function Simplify(graph, budget)
	local removed = 0
	for id in pairs(table.Copy(graph.pos)) do
		local neighbours = graph:GetNeighbours(id)
		if #neighbours == 2 then
			local a, b = graph:GetPos(neighbours[1]), graph:GetPos(neighbours[2])
			local pos = graph:GetPos(id)
			local dir_a, dir_b = (a - pos):GetNormalized(), (pos - b):GetNormalized()
			if dir_a:Dot(dir_b) > 0.98 and a:Distance(b) < 600 and CanStep(a, b) then
				graph:RemoveNode(id)
				graph:Link(neighbours[1], neighbours[2], 'walk')
				removed = removed + 1
			end
		end
		budget()
	end
	return removed
end

--[[
	Runs a generation task.
	@param options table { seeds = {Vector}, center = Vector|nil, radius = number|nil, ply = entity|nil, save = boolean }
--]]
function Generator.Start(options)
	local provider = Nav.GetProvider()
	if not provider.GetGraph or provider.name ~= 'custom' then
		Nav.Load('custom')
		provider = Nav.GetProvider()
	end

	local graph = provider:GetGraph()
	local step = math.max(64, cvar_step and cvar_step:GetFloat() or 200)
	local merge_radius = step * 0.6
	local max_nodes = cvar_max_nodes:GetInt()
	local center, radius = options.center, options.radius
	local radius_sqr = radius and radius * radius
	local ply = options.ply

	bgNPC.Tasks.Add(TASK, function(yield, wait, budget)
		local queue, head = {}, 1
		local added = 0
		local next_notify = 0

		local function AddPoint(pos)
			local existing = graph:FindNearest(pos, merge_radius)
			if existing then return existing, false end
			added = added + 1
			return graph:AddNode(pos), true
		end

		for _, seed in ipairs(options.seeds) do
			local floor = FindFloor(seed)
			if floor then
				local id, is_new = AddPoint(floor)
				if is_new or #graph:GetNeighbours(id) < 8 then queue[#queue + 1] = id end
			end
		end

		Notify(ply, 'Generating nodes...')

		while head <= #queue and graph:Count() < max_nodes do
			local id = queue[head]
			head = head + 1
			local pos = graph:GetPos(id)

			if pos then
				for i = 1, #DIRECTIONS do
					local target = pos + DIRECTIONS[i] * step
					if not radius_sqr or target:DistToSqr(center) <= radius_sqr then
						local floor = FindFloor(target)
						if floor and math.abs(floor.z - pos.z) <= STEP_UP.z + MAX_DROP and CanStep(pos, floor) then
							local next_id, is_new = AddPoint(floor)
							if next_id ~= id then
								graph:Link(id, next_id, 'walk')
								if is_new then queue[#queue + 1] = next_id end
							end
						end
					end
					budget()
				end
			end

			if CurTime() >= next_notify then
				next_notify = CurTime() + NOTIFY_PERIOD
				Notify(ply, 'Nodes: ' .. graph:Count())
			end
		end

		local removed = Simplify(graph, budget)
		Notify(ply, 'Done: ' .. graph:Count() .. ' nodes (' .. added .. ' new, ' .. removed .. ' merged)')

		if options.save then provider:Save() end
		hook.Run('BGN_NavGeneratorFinished', graph, added)
	end)
end

function Generator.Stop()
	bgNPC.Tasks.Remove(TASK)
end

function Generator.IsRunning()
	return bgNPC.Tasks.Exists(TASK)
end

-- Spawn points and players.
function Generator.MapSeeds()
	local seeds = {}
	for _, class in ipairs({ 'info_player_start', 'info_player_deathmatch', 'info_player_combine',
		'info_player_rebel', 'info_player_counterterrorist', 'info_player_terrorist', 'gmod_player_start' })
	do
		for _, ent in ipairs(ents.FindByClass(class)) do seeds[#seeds + 1] = ent:GetPos() end
	end
	for _, ply in ipairs(player.GetAll()) do
		if ply:Alive() then seeds[#seeds + 1] = ply:GetPos() end
	end
	return seeds
end

bgNPC.Commands.Register('bgn_nav_generate', {
	admin = true,
	help = 'Generates movement nodes: "bgn_nav_generate", "bgn_nav_generate around [radius]", "bgn_nav_generate stop".',
	server = function(ply, _, args)
		args = args or {}
		if args[1] == 'stop' or Generator.IsRunning() then
			Generator.Stop()
			Notify(ply, 'Generator stopped')
			return
		end

		if args[1] == 'around' then
			if not IsValid(ply) then return end
			Generator.Start({
				seeds = { ply:GetPos() },
				center = ply:GetPos(),
				radius = tonumber(args[2]) or cvar_radius:GetFloat(),
				ply = ply,
				save = true,
			})
			return
		end

		Generator.Start({ seeds = Generator.MapSeeds(), ply = ply, save = true })
	end,
})

-- OUTDATED name of the old navmesh-based generator
bgNPC.Commands.Register('bgn_generate_navmesh', {
	admin = true,
	server = function(ply) RunConsoleCommand('bgn_nav_generate') end,
})

-- Runtime mode: keep generating around players on maps that have no saved navigation data.
timer.Create('BGN_NavGenerator_Runtime', 10, 0, function()
	if not cvar_dynamic:GetBool() or Generator.IsRunning() then return end
	if not GetConVar('bgn_enable'):GetBool() then return end

	local provider = Nav.GetProvider()
	if provider.name ~= 'custom' or provider.source == 'file' or provider.source == 'legacy' or provider.source == 'dupe' then return end

	local seeds = {}
	for _, ply in ipairs(player.GetAll()) do
		if ply:Alive() and not provider:GetGraph():FindNearest(ply:GetPos(), 300) then
			seeds[#seeds + 1] = ply:GetPos()
		end
	end
	if #seeds == 0 then return end

	-- shortcut: the region is centred on the first uncovered player, others are covered on the next runs
	Generator.Start({
		seeds = seeds,
		center = seeds[1],
		radius = cvar_radius:GetFloat() * 2,
		save = cvar_save:GetBool(),
	})
end)

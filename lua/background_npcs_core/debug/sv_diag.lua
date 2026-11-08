--[[
	Testing mode, server side. One run at a time, driven by a coroutine that a 0.1 s timer resumes.

	Every test writes two things:
		Result(id, status, phrase, ...)  what the player sees: 'ok' | 'warn' | 'fail' and a phrase key from
		                                 resource/localization (arguments starting with '#' are phrases too)
		Log(...)                         the technical lines of the report that players copy to bug reports
	The report text is built here in English (the phrases are read from the English file), the client only
	shows the results list and the log (cl_diag.lua).

	Console: bgn_test (everything, admins), bgn_test_settings (rights and settings only), bgn_test_stop.
--]]

local Net = bgNPC.Net
local States = bgNPC.States

local FORCE_LIMIT = 10 -- actor types spawned on demand
local SETTLE_TIME = 12 -- seconds the spawned actors are watched
local NATURAL_WAIT = 15 -- seconds to wait for a regular spawn when the map is empty
local CAMERA_TIME = 3.5 -- seconds per group of actors
local CAMERA_GROUPS = 4
local ABORT = 'bgn_diag_abort'

local run
local last_fixes = {} -- result id -> console variables of the last run's "Fix" buttons

local function IsAdmin(ply)
	return IsValid(ply) and (ply:IsAdmin() or ply:IsSuperAdmin())
end

-- ---------------------------------------------------------------------------
-- English phrases for the report
-- ---------------------------------------------------------------------------

local english

local function English(key)
	if not english then
		english = {}
		for line in (file.Read('resource/localization/en/bgn_diag.properties', 'GAME') or ''):gmatch('[^\r\n]+') do
			local k, v = line:match('^([%w_%.]+)=(.*)$')
			if k then english[k] = v end
		end
	end
	return english[key] or key
end

local function Format(key, args)
	local list = {}
	for i = 1, #args do
		local v = args[i]
		list[i] = (isstring(v) and v:sub(1, 1) == '#') and English(v:sub(2)) or v
	end
	local ok, text = pcall(string.format, English(key), unpack(list))
	return ok and text or English(key)
end

-- ---------------------------------------------------------------------------
-- Results and log
-- ---------------------------------------------------------------------------

local function Section(id)
	run.cur = { id = id, title = English('bgn.diag.t.' .. id), lines = {} }
	run.sections[#run.sections + 1] = run.cur
end

local function Log(text, ...)
	if select('#', ...) > 0 then text = string.format(text, ...) end
	run.cur.lines[#run.cur.lines + 1] = text
end

-- @param status string 'ok' | 'warn' | 'fail'
-- @param key string phrase ("bgn.diag.<id>.<case>"), the rest are its format arguments
local function Result(status, key, ...)
	local args = { ... }
	run.cur.status = status
	run.cur.summary = Format(key, args)
	run.results[#run.results + 1] = { id = run.cur.id, status = status, key = key, args = args }
end

-- "3000.000000" -> "3000": console values are compared and printed as numbers when they are numbers
local function Norm(value)
	local n = tonumber(value)
	return n and string.format('%g', n) or tostring(value)
end

-- Offers the "Fix" button on the last result: console variables the server sets when an admin presses it.
-- Entries that already have the value are dropped; nothing is offered when nothing would change.
-- @param key string phrase "bgn.diag.fix.<case>" (the tooltip)
local function Fix(key, set)
	local changes = {}
	for name, value in pairs(set) do
		local cv = GetConVar(name)
		if cv and Norm(cv:GetString()) ~= Norm(value) then changes[name] = tostring(value) end
	end
	if not next(changes) then return end
	run.fixes[run.cur.id] = changes
	run.results[#run.results].fix = key
	local parts = {}
	for name, value in SortedPairs(changes) do parts[#parts + 1] = name .. ' = ' .. value end
	Log('fix offered: %s', table.concat(parts, ', '))
end

local function CheckAbort()
	if run.aborted or not IsValid(run.ply) then
		run.aborted = true
		error(ABORT, 0)
	end
end

local function Wait(seconds)
	local stop = CurTime() + seconds
	while CurTime() < stop do
		coroutine.yield()
		CheckAbort()
	end
end

local function WaitUntil(condition, timeout)
	local stop = CurTime() + timeout
	while CurTime() < stop do
		if condition() then return true end
		coroutine.yield()
		CheckAbort()
	end
	return condition()
end

local function Cvar(name)
	local cv = GetConVar(name)
	return cv and Norm(cv:GetString()) or '?'
end

-- ---------------------------------------------------------------------------
-- 1. Environment
-- ---------------------------------------------------------------------------

local function TestEnvironment()
	Section('env')
	local nav = bgNPC.Nav.GetInfo()
	local points = bgNPC.Points.Count()
	local enabled = GetConVar('bgn_enable'):GetBool()

	Log('addon enabled (bgn_enable): %s', tostring(enabled))
	Log('navigation provider: %s, points: %d', tostring(nav.provider), points)
	Log('brain: %s, body: %s', Cvar('bgn_brain'), Cvar('bgn_actor_body'))
	Log('limits: total %s, spawn radius %s, visibility %s, block radius %s, period %s',
		Cvar('bgn_max_npc'), Cvar('bgn_spawn_radius'), Cvar('bgn_spawn_radius_visibility'), Cvar('bgn_spawn_block_radius'), Cvar('bgn_spawn_period'))
	Log('actors now: %d, wanted mode: %s, DV support: %s', #bgNPC.Actors.GetAll(), Cvar('bgn_enable_wanted_mode'), Cvar('bgn_enable_dv_support'))

	local changed = {}
	for name, default in SortedPairs(bgNPC.cvar) do
		local cv = GetConVar(name)
		if cv and Norm(cv:GetString()) ~= Norm(default) then changed[#changed + 1] = string.format('%s = %s (default %s)', name, Norm(cv:GetString()), Norm(default)) end
	end
	Log('settings changed from the defaults: %d', #changed)
	for _, line in ipairs(changed) do Log('  %s', line) end

	if not enabled then
		Result('fail', 'bgn.diag.env.disabled')
		return Fix('bgn.diag.fix.enable', { bgn_enable = 1 })
	end
	if points == 0 then return Result('fail', 'bgn.diag.env.nonav', game.GetMap()) end
	Result('ok', 'bgn.diag.env.ok', tostring(nav.provider), points)
end

-- ---------------------------------------------------------------------------
-- 2. Rights and settings (server and client values)
-- ---------------------------------------------------------------------------

local function TestSettings()
	local ply = run.ply
	local cv = GetConVar('bgn_test_server_value')
	local original = cv:GetString()
	local token_s, token_c, token_back = tostring(math.random(1000, 4999)), tostring(math.random(5000, 9999)), tostring(math.random(10000, 14999))
	local server_admin = IsAdmin(ply)

	run.report, run.sync = nil, nil
	local started = SysTime()
	Net.Send('bgn.diag_cvar_begin', ply, token_s, token_c)

	local arrived = WaitUntil(function() return cv:GetString() == token_s end, 4)
	local delay = math.floor((SysTime() - started) * 1000)
	WaitUntil(function() return run.report end, 4)
	local report = run.report

	-- server -> clients: the server changes the value itself and the client has to see it
	local synced
	if report then
		RunConsoleCommand('bgn_test_server_value', token_back)
		Net.Send('bgn.diag_cvar_sync', ply, token_back)
		WaitUntil(function() return run.sync end, 4)
		synced = run.sync and run.sync.seen
	end
	RunConsoleCommand('bgn_test_server_value', original)

	Section('rights')
	Log('player: %s (%s)', ply:Nick(), ply:SteamID())
	Log('server: IsAdmin=%s IsSuperAdmin=%s group="%s" listen host=%s', tostring(ply:IsAdmin()), tostring(ply:IsSuperAdmin()), ply:GetUserGroup(), tostring(ply:IsListenServerHost()))
	if report then
		Log('client: IsAdmin=%s IsSuperAdmin=%s group="%s"', tostring(report.admin), tostring(report.super), tostring(report.group))
		Log('client: language %s, UI language %s, DX level %s, %d fps', tostring(report.lang), tostring(report.ui_lang), tostring(report.dx), report.fps or 0)
	else
		Log('client: no answer in 4 s (a Lua error on the client or a blocked network string "bgn_net")')
	end
	if not server_admin then
		Result('fail', 'bgn.diag.rights.server', ply:GetUserGroup())
	elseif report and not report.admin then
		Result('warn', 'bgn.diag.rights.client', ply:GetUserGroup())
	else
		Result('ok', 'bgn.diag.rights.ok', ply:GetUserGroup())
	end

	Section('cvar_server')
	Log('cvar bgn_test_server_value: set to %s from the client, server saw it: %s (%d ms)', token_s, tostring(arrived), delay)
	Log('server -> client: set to %s on the server, client saw it: %s', token_back, tostring(synced))
	Log('value restored to %s', original)
	-- one process: the server and the game share the console variables, so rights are not involved at all
	local shared = not game.IsDedicated()
	if shared then Log('single player / listen server: the client and the server share console variables, this check does not depend on admin rights') end
	if arrived and report and not server_admin and shared then
		Result('warn', 'bgn.diag.cvar_server.shared')
	elseif arrived and report and synced then
		Result('ok', 'bgn.diag.cvar_server.ok', delay)
	elseif arrived and report then
		Result('warn', 'bgn.diag.cvar_server.nosync')
	elseif not report then
		Result('fail', 'bgn.diag.cvar_server.noreport')
	elseif not server_admin then
		Result('fail', 'bgn.diag.cvar_server.server_denied', ply:GetUserGroup())
	elseif not report.admin then
		Result('fail', 'bgn.diag.cvar_server.client_denied')
	else
		Result('fail', 'bgn.diag.cvar_server.lost')
	end

	Section('cvar_client')
	if report then
		Log('cvar bgn_cl_test_value: set to %s, read back: %s', token_c, tostring(report.client_value))
		if report.client_value == token_c then
			Result('ok', 'bgn.diag.cvar_client.ok')
		else
			Result('fail', 'bgn.diag.cvar_client.fail')
		end
	else
		Log('no answer from the client')
		Result('fail', 'bgn.diag.cvar_server.noreport')
	end
end

-- ---------------------------------------------------------------------------
-- 3. Regular spawning
-- ---------------------------------------------------------------------------

-- @return string the most likely reason for the empty map (a phrase key without "#"), plus log lines
local function WhyNoSpawn(ply)
	if not GetConVar('bgn_enable'):GetBool() then return 'disabled' end
	if GetConVar('bgn_max_npc'):GetInt() == 0 then return 'max0' end

	local active = 0
	for actor_type, data in pairs(bgNPC.cfg.actors) do
		if not data.hidden and not data.wanted_level and bgNPC.Config.IsTypeActive(actor_type) and bgNPC.Config.GetTypeLimit(actor_type) > 0 then active = active + 1 end
	end
	Log('actor types that may spawn on their own: %d', active)
	if active == 0 then return 'types' end

	if bgNPC.Points.Count() == 0 then return 'nonav' end
	local radius = GetConVar('bgn_spawn_radius'):GetFloat()
	local points = bgNPC.Points.GetInRadius(ply:GetPos(), radius, 'walk')
	local hidden = 0
	for i = 1, math.min(#points, 80) do
		if bgNPC:IsHiddenSpawnPosition(points[i]:GetPos()) then hidden = hidden + 1 end
	end
	Log('navigation points within %d units of you: %d, of the first %d checked %d are hidden from you and far enough', radius, #points, math.min(#points, 80), hidden)
	if #points == 0 then return 'nopoints' end
	if hidden == 0 then return 'nohidden' end
	return 'unknown'
end

local function TestNaturalSpawn()
	Section('spawn_natural')
	local before = run.pre
	Log('actors when the test started: %d', before)

	if before == 0 and run.natural == 0 then
		WaitUntil(function() return run.natural > 0 end, NATURAL_WAIT)
	end

	local now = #bgNPC.Actors.GetAll()
	Log('actors now: %d, spawned by the regular spawner during the test: %d', now, run.natural)
	for actor_type, n in SortedPairs(run.natural_types) do Log('  spawned: %s x%d', actor_type, n) end

	if before > 0 then return Result('ok', 'bgn.diag.spawn_natural.exist', before) end
	if run.natural > 0 then return Result('ok', 'bgn.diag.spawn_natural.ok', run.natural, NATURAL_WAIT) end

	local reason = WhyNoSpawn(run.ply)
	Log('most likely reason: %s', reason)
	Result('fail', 'bgn.diag.spawn_natural.none', NATURAL_WAIT, '#bgn.diag.reason.' .. reason)

	local D = bgNPC.cvar
	if reason == 'disabled' then
		Fix('bgn.diag.fix.enable', { bgn_enable = 1 })
	elseif reason == 'max0' then
		Fix('bgn.diag.fix.limit', { bgn_max_npc = D.bgn_max_npc })
	elseif reason == 'types' then
		local set = {}
		for actor_type, data in pairs(bgNPC.cfg.actors) do
			if not data.hidden then
				set['bgn_npc_type_' .. actor_type] = data.enabled and 1 or 0
				set['bgn_npc_type_max_' .. actor_type] = bgNPC.Config.GetFullness(actor_type)
			end
		end
		Fix('bgn.diag.fix.types', set)
	elseif reason == 'nopoints' then
		Fix('bgn.diag.fix.radius', { bgn_spawn_radius = D.bgn_spawn_radius })
	elseif reason == 'nohidden' then
		Fix('bgn.diag.fix.hidden', { bgn_spawn_block_radius = D.bgn_spawn_block_radius, bgn_spawn_radius_visibility = D.bgn_spawn_radius_visibility })
	end
end

-- ---------------------------------------------------------------------------
-- 4. Spawning on demand
-- ---------------------------------------------------------------------------

local function SpawnPositions(ply)
	local origin = ply:GetPos()
	local list = {}

	for _, point in ipairs(bgNPC.Points.GetInRadius(origin, 1500, 'walk')) do
		local pos = point:GetPos()
		local dist = pos:DistToSqr(origin)
		if dist > 250 ^ 2 and util.IsInWorld(pos) and not bgNPC.Util.IsVectorInWater(pos) then list[#list + 1] = pos end
	end
	list = bgNPC.Table.Shuffle(list)

	if #list == 0 then
		Log('no navigation points around, using the floor around the player')
		for i = 0, 5 do
			local spot = origin + Angle(0, i * 60, 0):Forward() * 350
			local tr = util.TraceLine({ start = spot + Vector(0, 0, 60), endpos = spot - Vector(0, 0, 300), mask = MASK_SOLID_BRUSHONLY })
			if tr.Hit and not tr.StartSolid then list[#list + 1] = tr.HitPos + Vector(0, 0, 4) end
		end
	end
	return list
end

-- Spawns an actor the way the regular spawner does, but without its limits and visibility rules.
-- @return table|nil actor, string|nil error
local function ForceSpawn(actor_type, positions)
	local last_error
	for _ = 1, 4 do
		run.cursor = (run.cursor or 0) % #positions + 1
		run.forcing = true
		local ok, actor = pcall(bgNPC.SpawnActor, bgNPC, actor_type, positions[run.cursor])
		run.forcing = false
		if ok and actor and actor:IsAlive() then
			actor.diag_test = true
			-- over the limit: the regular remover takes such an actor away on purpose, that is not a bug
			actor.diag_over_limit = #bgNPC.Actors.GetNPCsByType(actor_type) > bgNPC.Config.GetTypeLimit(actor_type)
				or #bgNPC.Actors.GetAll() > GetConVar('bgn_max_npc'):GetInt()
			run.forced[#run.forced + 1] = actor
			return actor, nil, positions[run.cursor]
		elseif not ok then
			last_error = tostring(actor)
		end
	end
	return nil, last_error or 'no free spot (the actor was stuck in a wall or a prop)'
end

local function TestForcedSpawn()
	Section('spawn_forced')
	local ply = run.ply
	local positions = SpawnPositions(ply)
	Log('free spots found around the player: %d', #positions)
	if #positions == 0 then return Result('fail', 'bgn.diag.spawn_forced.nospot') end

	local tried, spawned = 0, 0
	for actor_type, data in SortedPairs(bgNPC.cfg.actors) do
		if tried >= FORCE_LIMIT then break end
		if data.hidden or data.wanted_level then
			Log('%-18s skipped (%s)', actor_type, data.hidden and 'hidden type' or 'appears only while wanted')
		elseif not bgNPC.Config.IsTypeActive(actor_type) then
			Log('%-18s skipped (type is switched off in the settings)', actor_type)
		else
			tried = tried + 1
			local actor, err = ForceSpawn(actor_type, positions)
			if actor then
				spawned = spawned + 1
				local npc = actor:GetNPC()
				Log('%-18s OK    class %s, model %s', actor_type, npc:GetClass(), npc:GetModel())
			else
				Log('%-18s FAIL  %s', actor_type, err)
			end
			Wait(0.15)
		end
	end

	run.spawn_time = CurTime()
	if tried == 0 then return Result('warn', 'bgn.diag.spawn_forced.notypes') end
	if spawned == tried then return Result('ok', 'bgn.diag.spawn_forced.ok', spawned) end
	if spawned == 0 then return Result('fail', 'bgn.diag.spawn_forced.none', tried) end
	Result('warn', 'bgn.diag.spawn_forced.some', spawned, tried)
end

-- ---------------------------------------------------------------------------
-- 5. Vehicles (Decent Vehicle)
-- ---------------------------------------------------------------------------

local function VehicleClassExists(class)
	return list.Get('Vehicles')[class] ~= nil or (simfphys ~= nil and list.Get('simfphys_vehicles')[class] ~= nil)
end

local function NearestWaypoint(pos)
	local best
	for _, point in ipairs(DecentVehicleDestination.Waypoints) do
		local dist = point.Target:DistToSqr(pos)
		if not best or dist < best then best = dist end
	end
	return best and math.sqrt(best)
end

local function TestVehicles()
	Section('vehicles')
	local dv = DecentVehicleDestination
	local waypoints = dv and dv.Waypoints and #dv.Waypoints or 0
	Log('Decent Vehicle loaded: %s, waypoints on this map: %d', tostring(dv ~= nil), waypoints)
	Log('Simfphys loaded: %s, bgn_enable_dv_support: %s, cars driven now: %d', tostring(simfphys ~= nil), Cvar('bgn_enable_dv_support'), #bgNPC.DVCars)

	local candidates, total_classes, found_classes = {}, 0, 0
	for actor_type, data in SortedPairs(bgNPC.cfg.actors) do
		if istable(data.vehicles) and #data.vehicles > 0 and not data.wanted_level then
			local valid = 0
			for _, class in ipairs(data.vehicles) do
				total_classes = total_classes + 1
				if VehicleClassExists(class) then valid = valid + 1 found_classes = found_classes + 1 end
			end
			Log('%-18s car classes in the config: %d, installed: %d', actor_type, #data.vehicles, valid)
			if valid > 0 and bgNPC.Config.IsTypeActive(actor_type) then candidates[#candidates + 1] = actor_type end
		end
	end

	if not dv then return Result('warn', 'bgn.diag.vehicles.nodv') end
	if not GetConVar('bgn_enable_dv_support'):GetBool() then
		Result('warn', 'bgn.diag.vehicles.off')
		return Fix('bgn.diag.fix.cars', { bgn_enable_dv_support = 1 })
	end
	if waypoints == 0 then return Result('warn', 'bgn.diag.vehicles.nowaypoints') end
	if #candidates == 0 then return Result('fail', 'bgn.diag.vehicles.noclasses', found_classes, total_classes) end

	local nearest = NearestWaypoint(run.ply:GetPos())
	Log('nearest road point to the player: %d units', nearest or -1)

	local positions = SpawnPositions(run.ply)
	if #positions == 0 then return Result('fail', 'bgn.diag.spawn_forced.nospot') end

	local actor_type = table.HasValue(candidates, 'taxi_driver') and 'taxi_driver' or candidates[1]
	local actor, err = ForceSpawn(actor_type, positions)
	if not actor then
		Log('driver "%s" was not spawned: %s', actor_type, err)
		return Result('fail', 'bgn.diag.vehicles.nodriver', actor_type)
	end

	local started = bgNPC:SpawnVehicleWithActor(actor, true)
	Log('SpawnVehicleWithActor("%s") returned %s', actor_type, tostring(started))
	if not started then
		actor:Remove()
		return Result('fail', 'bgn.diag.vehicles.nocar', actor_type)
	end

	WaitUntil(function() return actor:InVehicle() end, 3)
	if not actor:InVehicle() then
		Log('the driver did not get into the car in 3 s')
		return Result('fail', 'bgn.diag.vehicles.notseated', actor_type)
	end

	local car = actor:GetVehicle()
	run.cars[#run.cars + 1] = car
	Log('car: %s (%s) at %s, driver: %s', tostring(IsValid(car) and car:GetClass()), tostring(IsValid(car) and car:GetModel()), tostring(IsValid(car) and car:GetPos()), actor_type)
	Result('ok', 'bgn.diag.vehicles.ok', actor_type)
end

-- ---------------------------------------------------------------------------
-- 6. The spawned actors stay alive; actor states
-- ---------------------------------------------------------------------------

local function TestSettle()
	-- sample the walking actors, let them walk, compare
	local walkers = {}
	for _, actor in ipairs(bgNPC.Actors.GetAll()) do
		local npc = actor:GetNPC()
		if IsValid(npc) and actor:GetState() == 'walk' and not actor:InVehicle() then walkers[#walkers + 1] = { actor = actor, pos = npc:GetPos() } end
	end

	local remaining = (run.spawn_time or CurTime()) + SETTLE_TIME - CurTime()
	if remaining > 0 then Wait(remaining) end

	-- persistence
	Section('persist')
	local lost = 0
	for _, actor in ipairs(run.forced) do
		local alive = IsValid(actor:GetNPC()) and actor:IsAlive()
		if not alive and not actor.diag_over_limit then lost = lost + 1 end
		Log('%-18s %s', actor:GetType(), alive and ('still here after ' .. SETTLE_TIME .. ' s')
			or (actor.diag_over_limit and 'gone (was spawned over the actor limit: the remover takes such actors away, not a bug)' or 'GONE'))
	end
	local cars_lost = 0
	for _, car in ipairs(run.cars) do if not IsValid(car) then cars_lost = cars_lost + 1 end end
	if #run.cars > 0 then Log('cars: %d, gone: %d', #run.cars, cars_lost) end

	if #run.forced == 0 then
		Result('warn', 'bgn.diag.persist.none')
	elseif lost > 0 or cars_lost > 0 then
		Result('fail', 'bgn.diag.persist.lost', lost + cars_lost, #run.forced + #run.cars, SETTLE_TIME)
	else
		Result('ok', 'bgn.diag.persist.ok', #run.forced, SETTLE_TIME)
	end

	-- states
	Section('states')
	local by_state, by_type, by_body, by_brain, broken = {}, {}, {}, {}, {}
	local actors = bgNPC.Actors.GetAll()
	for _, actor in ipairs(actors) do
		local npc, state = actor:GetNPC(), actor:GetState()
		by_state[tostring(state)] = (by_state[tostring(state)] or 0) + 1
		by_type[actor:GetType()] = (by_type[actor:GetType()] or 0) + 1
		local body = actor.body and actor.body.ClassName or 'none'
		by_body[body] = (by_body[body] or 0) + 1
		local brain = actor.brain and actor.brain.ClassName or 'none'
		by_brain[brain] = (by_brain[brain] or 0) + 1

		local why
		if not IsValid(npc) then why = 'the entity is gone but the actor is still registered'
		elseif not state or not States.Exists(state) then why = 'unknown state "' .. tostring(state) .. '"'
		elseif npc:GetPos() == vector_origin then why = 'stands at the world origin'
		elseif not util.IsInWorld(npc:GetPos()) then why = 'is outside of the world'
		elseif not actor:IsAlive() then why = 'is dead but still registered' end
		if why then broken[#broken + 1] = actor:GetType() .. ' ' .. why end
	end
	Log('actors: %d', #actors)
	for name, n in SortedPairs(by_type) do Log('  type  %-18s %d', name, n) end
	for name, n in SortedPairs(by_state) do Log('  state %-18s %d', name, n) end
	for name, n in SortedPairs(by_body) do Log('  body  %-18s %d', name, n) end
	for name, n in SortedPairs(by_brain) do Log('  brain %-18s %d', name, n) end
	for _, line in ipairs(broken) do Log('  BROKEN: %s', line) end

	-- walking actors have to move
	local still = 0
	for _, w in ipairs(walkers) do
		local npc = w.actor:GetNPC()
		if IsValid(npc) and w.actor:GetState() == 'walk' and npc:GetPos():DistToSqr(w.pos) < 40 ^ 2 then still = still + 1 end
	end
	Log('actors in the "walk" state at the start: %d, of them stood still for the whole time: %d', #walkers, still)

	-- the state machine accepts a forced change
	local switch_failed
	local probe
	for _, actor in ipairs(run.forced) do if actor:IsAlive() and not actor:InVehicle() then probe = actor break end end
	if probe then
		for _, state in ipairs({ 'idle', 'walk' }) do
			if States.Exists(state) then
				probe:SetState(state, nil, true)
				Wait(0.3)
				local got = probe:GetState()
				Log('forced state "%s" on %s: actor reports "%s"', state, probe:GetType(), tostring(got))
				if got ~= state then switch_failed = state end
			end
		end
	else
		Log('no test actor for the forced state change')
	end

	if #actors == 0 then
		Result('warn', 'bgn.diag.states.none')
	elseif #broken > 0 then
		Result('fail', 'bgn.diag.states.broken', #broken, #actors)
	elseif switch_failed then
		Result('fail', 'bgn.diag.states.switch', switch_failed)
	elseif #walkers >= 3 and still / #walkers >= 0.6 then
		Result('warn', 'bgn.diag.states.still', still, #walkers)
	else
		Result('ok', 'bgn.diag.states.ok', #actors)
	end
end

-- ---------------------------------------------------------------------------
-- 7. Where the actors are: groups and the camera
-- ---------------------------------------------------------------------------

local function Groups()
	local groups = {}
	for _, actor in ipairs(bgNPC.Actors.GetAll()) do
		local npc = actor:GetNPC()
		if IsValid(npc) then
			local pos = npc:GetPos()
			local group
			for _, g in ipairs(groups) do
				if g.center:DistToSqr(pos) < 700 ^ 2 then group = g break end
			end
			if not group then
				group = { center = pos, sum = Vector(0, 0, 0), count = 0, types = {}, ents = {} }
				groups[#groups + 1] = group
			end
			group.sum = group.sum + pos
			group.count = group.count + 1
			group.center = group.sum / group.count
			group.types[actor:GetType()] = (group.types[actor:GetType()] or 0) + 1
			if #group.ents < 24 then group.ents[#group.ents + 1] = npc:EntIndex() end
		end
	end
	table.sort(groups, function(a, b) return a.count > b.count end)
	return groups
end

-- The camera spot: around the group, the direction with the most free room (not inside a wall)
local function CameraSpot(center)
	local target = center + Vector(0, 0, 50)
	local best_pos, best_fraction = target + Vector(0, 0, 250), -1
	for i = 0, 7 do
		local goal = target + Angle(0, i * 45, 0):Forward() * 380 + Vector(0, 0, 200)
		local tr = util.TraceLine({ start = target, endpos = goal, mask = MASK_SOLID_BRUSHONLY })
		if tr.Fraction > best_fraction then
			best_fraction = tr.Fraction
			best_pos = tr.Hit and (tr.HitPos - (goal - target):GetNormalized() * 16) or goal
		end
	end
	return best_pos, target
end

local function TestCrowd()
	Section('crowd')
	local groups = Groups()
	local ply = run.ply
	Log('groups of actors (actors closer than 700 units to each other): %d', #groups)
	for i, g in ipairs(groups) do
		local parts = {}
		for actor_type, n in SortedPairs(g.types) do parts[#parts + 1] = actor_type .. ' x' .. n end
		Log('  group %d: %d actors around %s, %d units from you (%s)', i, g.count, tostring(g.center), g.center:Distance(ply:GetPos()), table.concat(parts, ', '))
	end

	if #groups == 0 then return Result('warn', 'bgn.diag.crowd.none') end

	local shown = {}
	for i = 1, math.min(CAMERA_GROUPS, #groups) do
		local g = groups[i]
		local pos, target = CameraSpot(g.center)
		shown[i] = { pos = pos, target = target, count = g.count, types = g.types, ents = g.ents }
	end

	run.was_god, run.camera = ply:HasGodMode(), true
	ply:GodEnable()
	ply:Freeze(true)
	run.skip = false
	for i, g in ipairs(shown) do
		run.pvs = g.pos
		Net.Send('bgn.diag_cam', ply, g, i, #shown)
		WaitUntil(function() return run.skip end, CAMERA_TIME)
		if run.skip then break end
	end
	Net.Send('bgn.diag_cam', ply, nil)
	run.pvs = nil

	Result('ok', 'bgn.diag.crowd.ok', #shown, #groups)
end

-- ---------------------------------------------------------------------------
-- Run
-- ---------------------------------------------------------------------------

local STATUS = { ok = ' OK ', warn = 'WARN', fail = 'FAIL' }

local function BuildLog()
	local kind = game.SinglePlayer() and 'singleplayer' or (game.IsDedicated() and 'dedicated server' or 'listen server')
	local counts = { ok = 0, warn = 0, fail = 0 }
	for _, r in ipairs(run.results) do counts[r.status] = counts[r.status] + 1 end
	local bar = string.rep('=', 64)

	local out = {
		bar, ' Background NPCs - test report', bar,
		' Version  : ' .. bgNPC.VERSION,
		' Date     : ' .. os.date('%Y-%m-%d %H:%M:%S'),
		' Game     : ' .. tostring(VERSIONSTR) .. ' (' .. tostring(BRANCH) .. ')',
		' Map      : ' .. game.GetMap(),
		' Server   : ' .. kind .. ', ' .. player.GetCount() .. ' player(s)',
		' Gamemode : ' .. engine.ActiveGamemode(),
		' Run      : ' .. run.mode .. (run.aborted and ' (stopped before the end)' or ''),
		' Result   : ' .. counts.ok .. ' passed, ' .. counts.warn .. ' warnings, ' .. counts.fail .. ' failed',
		bar, '',
	}
	for _, section in ipairs(run.sections) do
		out[#out + 1] = string.format('[%s] %s', STATUS[section.status or 'warn'], section.title)
		if section.summary then out[#out + 1] = '       ' .. section.summary end
		for _, line in ipairs(section.lines) do out[#out + 1] = '       | ' .. line end
		out[#out + 1] = ''
	end
	return table.concat(out, '\n')
end

local function Cleanup()
	hook.Remove('SetupPlayerVisibility', 'BGN_Diag')
	timer.Remove('BGN_Diag')
	local ply = run.ply
	if IsValid(ply) and run.camera then
		ply:Freeze(false)
		if not run.was_god then ply:GodDisable() end
		Net.Send('bgn.diag_cam', ply, nil)
	end
	for _, actor in ipairs(run.forced) do
		if actor.Remove then actor:Remove() end
	end
	for _, car in ipairs(run.cars) do
		if IsValid(car) then car:Remove() end
	end
end

local function Main()
	for i, step in ipairs(run.steps) do
		CheckAbort()
		Net.Send('bgn.diag_progress', run.ply, i, #run.steps, step.id)
		local ok, err = pcall(step.func)
		if not ok then
			if run.aborted then return end
			ErrorNoHalt('[Background NPCs] test "' .. step.id .. '" failed: ' .. tostring(err) .. '\n')
			Section(step.id)
			Log('Lua error: %s', tostring(err))
			Result('fail', 'bgn.diag.lua_error', tostring(err))
		end
	end
end

local function Finish()
	local ply = run.ply
	last_fixes = run.fixes
	pcall(Cleanup)
	local log = BuildLog()
	if IsValid(ply) then Net.Send('bgn.diag_done', ply, run.results, log) end
	-- Msg cuts long strings: print line by line
	for _, line in ipairs(string.Explode('\n', log)) do Msg(line .. '\n') end
	run = nil
end

local function Tick()
	if not run then return timer.Remove('BGN_Diag') end
	if not IsValid(run.ply) then run.aborted = true end
	local ok, err = coroutine.resume(run.co)
	if not ok and err ~= ABORT then ErrorNoHalt('[Background NPCs] test runner: ' .. tostring(err) .. '\n') end
	if coroutine.status(run.co) == 'dead' then Finish() end
end

-- @param mode string 'full' | 'settings'
local function Start(ply, mode)
	local steps = { { id = 'rights', func = TestSettings } }
	if mode == 'full' then
		steps = {
			{ id = 'env', func = TestEnvironment }, { id = 'rights', func = TestSettings },
			{ id = 'spawn_natural', func = TestNaturalSpawn }, { id = 'spawn_forced', func = TestForcedSpawn },
			{ id = 'vehicles', func = TestVehicles }, { id = 'persist', func = TestSettle }, { id = 'crowd', func = TestCrowd },
		}
	end

	run = {
		ply = ply, mode = mode, steps = steps, results = {}, sections = {}, forced = {}, cars = {},
		fixes = {}, natural = 0, natural_types = {}, pre = #bgNPC.Actors.GetAll(),
	}
	run.co = coroutine.create(Main)
	run.cur = { id = 'none', lines = {} }

	hook.Add('SetupPlayerVisibility', 'BGN_Diag', function(viewer)
		if run and run.pvs and viewer == run.ply then AddOriginToPVS(run.pvs) end
	end)
	timer.Create('BGN_Diag', 0.1, 0, Tick)
end

hook.Add('BGN_InitActor', 'BGN_Diag', function(actor)
	if not run or run.forcing then return end
	run.natural = run.natural + 1
	local actor_type = actor:GetType()
	run.natural_types[actor_type] = (run.natural_types[actor_type] or 0) + 1
end)

Net.Receive('bgn.diag_start', function(ply, mode)
	if run then return Net.Send('bgn.diag_busy', ply) end
	-- the full test spawns and removes actors: admins only; everyone may check their rights
	if mode ~= 'full' or not IsAdmin(ply) then mode = 'settings' end
	Start(ply, mode)
end)

Net.Receive('bgn.diag_abort', function(ply)
	if run and (ply == run.ply or IsAdmin(ply)) then run.aborted = true end
end)

Net.Receive('bgn.diag_cam_skip', function(ply)
	if run and ply == run.ply then run.skip = true end
end)

Net.Receive('bgn.diag_cvar_report', function(ply, report)
	if run and ply == run.ply and istable(report) then run.report = report end
end)

Net.Receive('bgn.diag_cvar_sync_report', function(ply, seen)
	if run and ply == run.ply then run.sync = { seen = seen == true } end
end)

-- The "Fix" button: the client sends only the result id, the values come from the last run
Net.Receive('bgn.diag_fix', function(ply, id)
	local set = last_fixes[id]
	if not set then return end
	for name, value in pairs(set) do RunConsoleCommand(name, value) end
	last_fixes[id] = nil
	MsgN('[Background NPCs] test fix "' .. tostring(id) .. '" applied by ' .. ply:Nick())
end, { admin = true })

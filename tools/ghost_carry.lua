-- Opt-in isolated SP fixture. Run in both realms through a temporary bridge; private closures are inspected only here.
assert(game.SinglePlayer(), 'isolated single-player lab required')
local function Up(fn, wanted)
	for i = 1, 100 do
		local name, value = debug.getupvalue(fn, i)
		if not name then break end
		if name == wanted then return value end
	end
	error('missing fixture upvalue: ' .. wanted)
end
local report = { cases = {}, errors = {} }
local function Write()
	file.CreateDir('bgn_scenic_overhaul_lab')
	file.Write('bgn_scenic_overhaul_lab/ghost-' .. (SERVER and 'server' or 'client') .. '.json', util.TableToJSON(report, true))
end

if CLIENT then
	local task = assert(bgNPC.Tasks.list.bgn_ghost_crowd).func
	local CreateGhost = Up(Up(task, 'TrySpawn'), 'CreateGhost')
	local SetActivity = Up(CreateGhost, 'SetActivity')
	local RemoveGhost = Up(Up(task, 'RemoveAll'), 'RemoveGhost')
	local looks = Up(CreateGhost, 'looks')
	local old_looks = table.Copy(looks)
	local config = bgNPC.Config.GetActor('citizen')
	local old_carry = config.carry_items
	bgNPC.Tasks.Remove('bgn_ghost_crowd')
	local function Finish()
		for i = #bgNPC.ghost_crowd, 1, -1 do RemoveGhost(i) end
		table.Empty(looks) table.Add(looks, old_looks) config.carry_items = old_carry
		bgNPC.Tasks.Add('bgn_ghost_crowd', task)
		report.done, report.passed = true, #report.errors == 0 Write()
	end
	local function Run()
		table.Empty(looks)
		looks[1] = { type = 'citizen', model = 'models/humans/group01/male_07.mdl', skin = 0, bodygroups = '' }
		for _, kind in ipairs({ 'ration', 'suitcase', 'newspaper' }) do
			config.carry_items = { chance = 100, items = { kind } }
			local ghost = assert(CreateGhost(LocalPlayer():GetPos() + Vector(300, 0, 0)))
			assert(not ghost.carry and not IsValid(ghost.carry_prop), 'local ghosts ignore carry configuration')

			SetActivity(ghost, ACT_WALK)

			report.cases[#report.cases + 1] = { name = 'local_' .. kind, passed = true }
		end
		local receivers = Up(bgNPC.Net.Receive, 'receivers')
		local Apply = Up(receivers.bgn_ghost_crowd.func, 'ApplyServerOp')
		for i, kind in ipairs({ 'ration', 'suitcase', 'newspaper' }) do
			local pos = LocalPlayer():GetPos() + Vector(300, 100 * i, 0)
			Apply({ id = -i, from = pos, to = pos + Vector(100, 0, 0), t0 = CurTime(), speed = 75,
				carry = kind, look = looks[1] }, CurTime())
			local ghosts = Up(Apply, 'server_ghosts')
			local ghost = assert(ghosts[-i])
			assert(not ghost.carry and not IsValid(ghost.carry_prop), 'server ghosts ignore carried-item payloads')
			Apply({ id = -i, from = pos, to = pos, speed = 0, t0 = CurTime(), carry = false }, CurTime())
			assert(not ghost.carry and not IsValid(ghost.carry_prop), 'explicit false removes the synchronized item')
			report.cases[#report.cases + 1] = { name = 'server_visual_' .. kind, passed = true }
		end
	end
	local ok, err = xpcall(Run, debug.traceback)
	if not ok then report.errors[1] = err end
	Finish()
	return
end

local task = assert(bgNPC.Tasks.list.bgn_ghost_crowd_server).func
local Decide = Up(task, 'Decide')
local Handoff = Up(Decide, 'Handoff')
local SegmentOp = Up(Up(task, 'TrySpawn'), 'SegmentOp')
local old_body = GetConVar('bgn_actor_body'):GetString()
local base = assert(bgNPC.Scenic.Spots.Floor(Vector(-800, 1000, -11140)))
local actor
local jobs = { { 'npc', 'ration' }, { 'npc', 'suitcase' }, { 'npc', 'newspaper' }, { 'nextbot', 'ration' }, { 'nextbot', 'suitcase' }, { 'nextbot', 'newspaper' } }
local index = 0
local function Finish()
	if actor then actor:Remove() end
	GetConVar('bgn_actor_body'):SetString(old_body)
	report.done, report.passed = true, #report.errors == 0 Write()
end
local function Protect(fn)
	local ok, err = xpcall(fn, debug.traceback)
	if not ok then report.errors[#report.errors + 1] = err Finish() end
end
local Next
Next = function()
	if actor then actor:Remove() actor = nil end
	index = index + 1
	local job = jobs[index]
	if not job then Finish() return end
	local spawn_pos = base + Vector(-80 * math.floor((index - 1) / 3), 80 * ((index - 1) % 3 + 1), 0)
	GetConVar('bgn_actor_body'):SetString(job[1])
	local ghost = { id = -100 - index, look = { type = 'citizen', model = 'models/humans/group01/male_07.mdl', skin = 0, bodygroups = '' },
		carry = job[2], seg = { speed = 0 } }
	assert(SegmentOp(ghost, true).carry == nil, 'snapshots contain no carried item')
	local before = {}
	for _, a in ipairs(bgNPC.Actors.GetAll()) do before[a] = true end
	assert(Handoff(ghost, spawn_pos), 'seen ghost materializes')
	for _, a in ipairs(bgNPC.Actors.GetAll()) do if not before[a] and not a.is_removed then actor = a break end end
	-- Registration happens next tick; the entity still exposes its actor immediately.
	if not actor then
		for _, ent in ipairs(ents.FindInSphere(spawn_pos, 30)) do
			local a = ent.BGN_ACTOR_OBJECT
			if a and not before[a] and not a.is_removed then actor = a break end
		end
	end
	local expected = nil
	assert(actor and actor.carry_initialized and actor.carry_item == expected, 'handoff never equips a carried item')
	actor.eternal, actor.data.at_random = true, nil
	timer.Simple(0.4, function() Protect(function()
		assert(actor:IsAlive() and actor.carry_item == expected and (not expected or bgNPC.CarryItems.active[actor]), 'body eligibility survives initialization')
		report.cases[#report.cases + 1] = { name = job[1] .. '_handoff_' .. job[2], passed = true }
		Write() Next()
	end) end)
end
Protect(Next)
return { pending = true, report = 'bgn_scenic_overhaul_lab/ghost-server.json' }

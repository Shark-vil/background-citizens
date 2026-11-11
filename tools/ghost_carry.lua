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
		for _, kind in ipairs({ 'ration', 'suitcase' }) do
			config.carry_items = { chance = 100, items = { kind } }
			local ghost = assert(CreateGhost(LocalPlayer():GetPos() + Vector(300, 0, 0)))
			assert(ghost.carry == kind and IsValid(ghost.carry_prop), 'local ghost uses the actor carry config')
			assert(ghost.carry_prop:GetParent() == ghost.ent, 'client carried model follows its ghost')
			SetActivity(ghost, ACT_WALK)
			assert(ghost.ent:GetSequence() == bgNPC.CarryItems.Sequence(ghost.ent, kind, true), 'client walking animation carries the item')
			report.cases[#report.cases + 1] = { name = 'local_' .. kind, passed = true }
		end
		local receivers = Up(bgNPC.Net.Receive, 'receivers')
		local Apply = Up(receivers.bgn_ghost_crowd.func, 'ApplyServerOp')
		for i, kind in ipairs({ 'ration', 'suitcase' }) do
			local pos = LocalPlayer():GetPos() + Vector(300, 100 * i, 0)
			Apply({ id = -i, from = pos, to = pos + Vector(100, 0, 0), t0 = CurTime(), speed = 75,
				carry = kind, look = looks[1] }, CurTime())
			local ghosts = Up(Apply, 'server_ghosts')
			local ghost = assert(ghosts[-i])
			assert(ghost.carry == kind and IsValid(ghost.carry_prop), 'server-selected carried item reaches the client')
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
local Handoff, SetSegment = Up(Decide, 'Handoff'), Up(Decide, 'SetSegment')
local SegmentOp = Up(Up(task, 'TrySpawn'), 'SegmentOp')
local old_body = GetConVar('bgn_actor_body'):GetString()
local base = assert(bgNPC.Scenic.Spots.Floor(Vector(-800, 1000, -11140)))
local actor
local drops = {}
local jobs = { { 'npc', 'ration' }, { 'npc', 'suitcase' }, { 'nextbot', 'ration' }, { 'nextbot', 'suitcase' } }
local index = 0
local function Finish()
	if actor then actor:Remove() end
	for _, ent in ipairs(drops) do if IsValid(ent) then ent:Remove() end end
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
	local spawn_pos = base + Vector(0, index * 80, 0)
	GetConVar('bgn_actor_body'):SetString(job[1])
	local ghost = { id = -100 - index, look = { type = 'citizen', model = 'models/humans/group01/male_07.mdl', skin = 0, bodygroups = '' },
		carry = job[2], seg = { speed = 0 } }
	if index <= 2 then
		local panic = { id = -1000 - index, look = ghost.look, carry = job[2] }
		local old_props = {}
		for _, ent in ipairs(ents.FindByClass('prop_physics')) do old_props[ent] = true end
		local panic_pos = base + Vector(300, 0, 0)
		SetSegment(panic, panic_pos, panic_pos + Vector(100, 0, 0), true, CurTime())
		assert(not panic.carry and SegmentOp(panic, true).carry == false, 'panic explicitly synchronizes empty hands')
		if job[2] == 'ration' then
			assert(panic.stowed_carry == 'ration', 'ghost parcel is stowed')
			SetSegment(panic, panic_pos, nil, false, CurTime(), 2)
			assert(panic.carry == 'ration' and not panic.stowed_carry, 'ghost parcel returns after panic')
		else
			local found
			for _, ent in ipairs(ents.FindByClass('prop_physics')) do
				if not old_props[ent] then found = ent drops[#drops + 1] = ent end
			end
			assert(IsValid(found) and found:GetCollisionGroup() == COLLISION_GROUP_WORLD, 'ghost suitcase drops as a non-blocking prop')
			assert(not panic.stowed_carry, 'ghost suitcase is not pocketed')
		end
		report.cases[#report.cases + 1] = { name = 'panic_' .. job[2], passed = true }
	end
	assert(SegmentOp(ghost, true).carry == job[2], 'snapshot includes the server-selected item')
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
	assert(actor and actor.carry_initialized and actor.carry_item == job[2], 'handoff retains the chosen item without rerolling')
	actor.eternal, actor.data.at_random = true, nil
	timer.Simple(0.4, function() Protect(function()
		assert(actor:IsAlive() and actor.carry_item == job[2] and bgNPC.CarryItems.active[actor], 'carry survives actor initialization')
		report.cases[#report.cases + 1] = { name = job[1] .. '_handoff_' .. job[2], passed = true }
		Write() Next()
	end) end)
end
Protect(Next)
return { pending = true, report = 'bgn_scenic_overhaul_lab/ghost-server.json' }

-- Opt-in isolated SP gm_bigcity_improved fixture, sent through a temporary Lua bridge.
assert(game.SinglePlayer() and game.GetMap() == 'gm_bigcity_improved' and not BGNCarryLab, 'isolated idle SP lab required')
local ply = player.GetHumans()[1]
local old_body = GetConVar('bgn_actor_body'):GetString()
local old_pos, old_ang, old_move = ply:GetPos(), ply:EyeAngles(), ply:GetMoveType()
local base = bgNPC.Scenic.Spots.Floor(Vector(-800, 1000, -11140))
assert(base, 'lab floor')
local report = { cases = {}, errors = {} }
BGNCarryLab = report
local item, job, index
local jobs = { { 'npc', 'ration' }, { 'npc', 'suitcase' }, { 'nextbot', 'ration' }, { 'nextbot', 'suitcase' } }
for _, body in ipairs({ 'npc', 'nextbot' }) do
	for _, kind in ipairs({ 'ration', 'suitcase' }) do jobs[#jobs + 1] = { body, kind, automatic = true } end
end
hook.Add('BGN_OverrideSpawnData', 'BGN_CarryLab', function(kind, data)
	if kind ~= 'citizen' then return end
	data = table.Copy(data)
	data.models, data.random_model, data.default_models = { 'models/humans/group01/male_07.mdl' }, false, false
	data.weapons, data.getting_weapon_chance, data.start_random_state, data.at_random = {}, 0, false, nil
	return data
end)
local function Write()
	file.CreateDir('bgn_scenic_overhaul_lab')
	file.Write('bgn_scenic_overhaul_lab/carry.json', util.TableToJSON(report, true))
end
local function Clear()
	if item then bgNPC.Scenic.Debug.Remove(ply, item) item = nil end
	timer.Remove('BGN_CarryLab')
end
local function Finish()
	Clear()
	hook.Remove('BGN_OverrideSpawnData', 'BGN_CarryLab')
	GetConVar('bgn_actor_body'):SetString(old_body)
	ply:SetPos(old_pos) ply:SetEyeAngles(old_ang) ply:SetMoveType(old_move)
	report.done, report.passed = true, #report.errors == 0
	Write() BGNCarryLab = nil
end
local function Protect(fn)
	if not BGNCarryLab then return end
	local ok, err = xpcall(fn, debug.traceback)
	if not ok then report.errors[#report.errors + 1] = err Finish() end
end
local Next
local function Passed()
	report.cases[#report.cases + 1] = { name = job[1] .. '_' .. job[2] .. (job.automatic and '_auto' or '_tool'), passed = true }
	Write() Next()
end
index = 0
Next = function()
	Clear() index = index + 1 job = jobs[index]
	if not job then Finish() return end
	GetConVar('bgn_actor_body'):SetString(job[1])
	ply:SetMoveType(MOVETYPE_NOCLIP) ply:SetPos(base + Vector(100, 180, 10))
	if job.automatic then
		local spawned = assert(bgNPC:SpawnActor('citizen', base + Vector(0, 0, 4), false, false))
		item = { debug_owner = ply, actors = { spawned }, props = {}, started = true }
		spawned.scenic_debug_item = item
		spawned.data.start_random_state = false
		spawned.data.carry_items = { chance = 100, items = { job[2] }, drop_lifetime = 1 }
	else
		item = assert(bgNPC.Scenic.Debug.Spawn(ply, job[2] == 'ration' and 'ration' or 'luggage',
			{ Hit = true, HitPos = base, HitNormal = Vector(0, 0, 1) }))
	end
	local actor = item.actors[1]
	actor.weapon, actor.data.at_random = nil, nil
	actor.data.carry_items.drop_lifetime = 1
	local deadline, origin = CurTime() + 12, base
	timer.Simple(0.5, function() Protect(function()
		assert(actor:IsAlive() and actor.carry_item == job[2], 'manual carry preview starts on an ordinary actor')
		actor:WalkToPos(base + Vector(240, 0, 0))
		timer.Create('BGN_CarryLab', 0.1, 0, function() Protect(function()
			local npc = actor:GetNPC()
			assert(CurTime() < deadline, 'carrier must walk with its animation: ' .. npc:GetSequenceName(npc:GetSequence()))
			if npc:GetPos():DistToSqr(origin) < 40 ^ 2 then return end
			local carry = bgNPC.CarryItems.active[actor]
			assert(carry and IsValid(carry.prop) and carry.prop:GetParent() == npc, 'carried visual follows the moving body')
			assert(npc:GetSequence() == bgNPC.CarryItems.Sequence(npc, job[2], true), 'movement uses the carrying walk sequence')
			assert(not actor:HasActiveWeapon(), 'a carried prop must not count as a combat weapon')
			timer.Remove('BGN_CarryLab')
			actor:SetState('scenic_npc', { seq = 'idle_subtle' }, true)
			timer.Simple(0.3, function() Protect(function()
				if job[2] == 'ration' then
					assert(actor.carry_item == 'ration' and not IsValid(carry.prop), 'small parcels are stowed for incompatible actions')
					actor:SetState('idle', nil, true)
					timer.Simple(0.2, function() Protect(function()
						assert(IsValid(bgNPC.CarryItems.active[actor].prop), 'stowed parcel returns when compatible')
						Passed()
					end) end)
				else
					local dropped = item.props[1]
					assert(not actor.carry_item and IsValid(dropped), 'a suitcase is dropped instead of pocketed')
					assert(dropped:GetCollisionGroup() == COLLISION_GROUP_WORLD, 'dropped suitcase cannot collide with actors/props')
					timer.Simple(1.2, function() Protect(function()
						assert(not IsValid(dropped), 'dropped suitcase expires after its configured lifetime')
						Passed()
					end) end)
				end
			end) end)
		end) end)
	end) end)
end
Protect(Next)
return { pending = true, report = 'bgn_scenic_overhaul_lab/carry.json' }

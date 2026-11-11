-- Opt-in isolated single-player gm_bigcity_improved fixture, sent through a temporary Lua bridge.
assert(game.SinglePlayer() and game.GetMap() == 'gm_bigcity_improved', 'use an isolated gm_bigcity_improved session')
assert(not BGNDoorTest, 'a door fixture is already running')

local saved_tasks, entities, actors = {}, {}, {}
local player_entity = player.GetHumans()[1]
local player_pos, player_ang, player_move = player_entity:GetPos(), player_entity:EyeAngles(), player_entity:GetMoveType()
for _, id in ipairs({ 'bgn_actors_spawner_process', 'bgn_zone_actors_spawner_process', 'bgn_actors_remover_process', 'bgn_scenic' }) do
	local task = bgNPC.Tasks.list[id]
	if task then saved_tasks[id] = task.func bgNPC.Tasks.Remove(id) end
end
local report = { cases = {}, started = CurTime(), errors = {} }
BGNDoorTest = report
local current

local function Write()
	file.CreateDir('bgn_door_lab')
	file.Write('bgn_door_lab/doors.json', util.TableToJSON(report, true))
end

local function Clear()
	for _, actor in ipairs(actors) do actor:Remove() end
	for _, ent in ipairs(entities) do if IsValid(ent) then ent:Remove() end end
	actors, entities = {}, {}
end

local function Finish()
	Clear()
	hook.Remove('BGN_SetState', 'BGN_DoorTest')
	hook.Remove('CreateEntityRagdoll', 'BGN_DoorTest')
	timer.Remove('BGN_DoorTest')
	for id, func in pairs(saved_tasks) do bgNPC.Tasks.Add(id, func) end
	player_entity:SetMoveType(player_move)
	player_entity:SetPos(player_pos)
	player_entity:SetEyeAngles(player_ang)
	report.done, report.passed = true, #report.errors == 0
	Write()
	BGNDoorTest = nil
end

local function Check(value, message) assert(value, message) end
local function Protect(func)
	if not BGNDoorTest then return false end
	local ok, err = xpcall(func, debug.traceback)
	if not ok then report.errors[#report.errors + 1] = err Finish() end
	return ok
end

local base = Vector(-800, 1000, -11140)
local floor = util.TraceLine({ start = base + Vector(0, 0, 100), endpos = base - Vector(0, 0, 100), mask = MASK_SOLID_BRUSHONLY })
Check(floor.Hit, 'lab floor')
base = floor.HitPos

local function Spawn(body, police, pos, yaw)
	local class = police and 'npc_metropolice' or 'npc_citizen'
	local npc = ents.Create(body == 'nextbot' and 'bgn_nextbot' or class)
	entities[#entities + 1] = npc
	npc.bgn_npc_class = class
	npc.bgn_door_fixture = true
	npc:SetPos(pos)
	npc:SetAngles(Angle(0, yaw, 0))
	npc:Spawn()
	npc:Activate()
	local actor = bgNPC.Actor.Create(npc, police and 'police' or 'citizen')
	actors[#actors + 1] = actor
	actor.data.start_random_state, actor.data.start_state, actor.data.at_random = false, nil, nil
	actor.data.regeneration = false
	actor.mechanics.use_vehicle, actor.mechanics.call_for_help, actor.mechanics.targets_controller = false, false, false
	actor.eternal = true
	if not police then actor:SetTeam({ 'door_fixture' }) end
	return actor
end

local function Model(actor, police)
	local npc = actor:GetNPC()
	-- Fixture rigs only; production actions never change the actor's selected model.
	npc:SetModel(police and 'models/police.mdl' or 'models/humans/group01/male_07.mdl')
	if npc.IsBGNNextBot then npc:BGN_ResetHull() end
end

local cases = { { 'npc', 'npc', 0 }, { 'nextbot', 'nextbot', 90 }, { 'npc', 'nextbot', 180 }, { 'nextbot', 'npc', 270 },
	{ 'npc', 'npc', 0, 'cancel' }, { 'nextbot', 'npc', 90, 'cancel' } }
local index = 0
local Next, Guards

hook.Add('CreateEntityRagdoll', 'BGN_DoorTest', function(owner, rag)
	if owner.bgn_door_fixture then entities[#entities + 1] = rag end
end)

hook.Add('BGN_SetState', 'BGN_DoorTest', function(actor, state)
	if not current or actor ~= current.holder or state ~= 'knocked_down' then return end
	current.down_at, current.health = CurTime(), actor:Health()
	current.ragdoll = actor:GetStateData().ragdoll
	current.down_pos = actor:GetPos()
	timer.Simple(0, function()
		if not current or not current.officer:IsAlive() then return end
		local officer, npc = current.officer, current.officer:GetNPC()
		officer.brain = { Update = function() end, OnEvent = function() end, Stop = function() end }
		officer:SetState('scenic_npc', { seq = npc:GetSequenceName(npc:GetSequence()) }, true)
	end)
end)

Next = function()
	Clear()
	index = index + 1
	local spec = cases[index]
	if not spec then current = nil Guards('npc', function() Guards('nextbot', Finish) end) return end
	local ang = Angle(0, spec[3], 0)
	local normal, left = ang:Forward(), -ang:Right()
	local door = ents.Create('prop_door_rotating')
	entities[#entities + 1] = door
	door:SetModel('models/props_c17/door01_left.mdl')
	door:SetPos(base + Vector(0, 0, 54.25))
	door:SetAngles(ang)
	door:SetKeyValue('speed', '100')
	door:SetKeyValue('returndelay', '-1')
	door:Spawn()
	door:Activate()
	local center = base + left * 23
	local holder = Spawn(spec[1], false, center + normal * 100 + Vector(0, 0, 8), spec[3] + 180)
	local officer = Spawn(spec[2], true, center - normal * 140 + Vector(0, 0, 8), spec[3])
	current = { holder = holder, officer = officer, door = door, name = spec[1] .. '_vs_' .. spec[2] .. (spec[4] or ''),
		npc = holder:GetNPC(), uid = holder.uid, until_time = CurTime() + 22 }
	player_entity:SetMoveType(MOVETYPE_NOCLIP)
	player_entity:SetPos(center - normal * 160 + left * 180 + Vector(0, 0, 15))
	player_entity:SetEyeAngles((center + Vector(0, 0, 45) - player_entity:EyePos()):Angle())
	timer.Simple(0.5, function() Protect(function()
		Model(holder, false)
		Model(officer, true)
		holder.weapon = nil
		holder:GetNPC():SetHealth(math.floor(holder:GetMaxHealth() * 0.25))
		holder:AddEnemy(officer:GetNPC(), 'fear', true)
		holder.brain = bgNPC.GOAPBrain(holder)
		holder:SetState('fear', nil, true)
		local cop = officer:GetNPC()
		officer:SetState('scenic_npc', { seq = cop:GetSequenceName(cop:GetSequence()) }, true)
		door:Fire('Open')
	end) end)
	timer.Create('BGN_DoorTest', 0.1, 0, function() Protect(function()
		local c = current
		Check(holder:IsAlive() and officer:IsAlive(), c.name .. ': actors remain alive')
		Check(CurTime() < c.until_time, c.name .. ': interaction timeout (' .. holder:GetState() .. '/' .. officer:GetState() .. ')')
		local data = holder:GetStateData()
		if data.spot and data.spot.bracing and not c.braced then
			c.braced = true
			Check(bgNPC.Doors.IsClosed(door) and bgNPC.Util.IsDoorLocked(door), 'held door is closed and locked')
			Check(not bgNPC.Util.CanActorOpenDoor(door), 'ordinary NPC and NextBot opening respects the hold')
			door:Fire('Unlock')
			door:Fire('Open') -- AcceptInput must reject both while held.
			if spec[4] == 'cancel' then
				holder:Remove()
				timer.Remove('BGN_DoorTest')
				timer.Simple(0.4, function() Protect(function()
					Check(not bgNPC.Doors.held[door] and not bgNPC.Util.IsDoorLocked(door), 'removing a holder releases its door')
					report.cases[#report.cases + 1] = { name = c.name, passed = true }
					Write()
					Next()
				end) end)
				return
			end
			officer:AddEnemy(holder:GetNPC(), 'defense', true)
			officer.brain = bgNPC.GOAPBrain(officer)
			officer:SetState('defense', nil, true)
		end
		if c.down_at then
			if bgNPC.Util.IsDoorOpen(door) then c.opened = true end
			if IsValid(c.ragdoll) then c.travel = math.max(c.travel or 0, c.ragdoll:GetPos():Distance(c.down_pos)) end
			if CurTime() - c.down_at > 3.5 then
				Check(c.braced and c.opened and (c.travel or 0) > 30, 'breach opens the door and physically throws the holder')
				Check(not holder:HasState('knocked_down') and not IsValid(c.ragdoll), 'temporary ragdoll is removed after recovery')
				Check(holder:Health() == c.health and holder:GetNPC() == c.npc and holder.uid == c.uid, 'health, entity and UID survive')
				Check(not c.npc:GetNoDraw() and not c.npc:GetNW2Bool('bgn_knocked_down'), 'body is visible again')
				Check(bgNPC.Actors.Get(c.npc) == holder, 'actor registry survives the fall')
				Check(not bgNPC.Util.IsDoorLocked(door) and door:GetInternalVariable('m_flSpeed') == 100, 'door lock and speed are restored')
				report.cases[#report.cases + 1] = { name = c.name, yaw = spec[3], passed = true, health = c.health,
					travel = c.travel, holder_body = c.npc:GetClass(), police_body = officer:GetNPC():GetClass() }
				Write()
				timer.Remove('BGN_DoorTest')
				Next()
			end
		end
	end) end)
end

Guards = function(body, done)
	Clear()
	local actor = Spawn(body, false, base + Vector(180, 0, 8), 0)
	timer.Simple(0.5, function() Protect(function()
		Model(actor, false)
		local npc = actor:GetNPC()
		npc:SetHealth(50)
		actor:SetState('knocked_down', { velocity = vector_origin }, true)
		Check(actor:HasState('knocked_down'), body .. ': knockdown starts')
		local data = actor:GetStateData()
		actor:SetState('walk', nil, true)
		Check(actor:HasState('knocked_down') and npc:GetNoDraw(), 'forced reactions cannot uncover the frozen body')
		local trace = util.TraceHull
		util.TraceHull = function() return { Hit = true, StartSolid = true } end
		data.wake_at = 0
		local ok, err = pcall(function() actor:CallStateAction(nil, 'update', actor:GetState(), data) end)
		util.TraceHull = trace
		Check(ok, err)
		Check(actor:HasState('knocked_down') and IsValid(data.ragdoll), 'blocked standing hull retains the ragdoll')
		local damage = DamageInfo()
		damage:SetDamage(5)
		damage:SetDamageType(DMG_BULLET)
		damage:SetAttacker(game.GetWorld())
		damage:SetInflictor(game.GetWorld())
		data.ragdoll:TakeDamageInfo(damage)
		Check(actor:Health() == 45, 'shots at the temporary ragdoll damage the real actor once')
		timer.Simple(1, function() Protect(function()
			Check(actor:IsAlive() and not actor:HasState('knocked_down') and actor:Health() == 45, 'recovery keeps damage received while down')
			actor:SetState('knocked_down', { velocity = vector_origin }, true)
			local rag = actor:GetStateData().ragdoll
			damage:SetDamage(500)
			rag:TakeDamageInfo(damage)
			timer.Simple(0.2, function() Protect(function()
				Check(not actor:IsAlive() and not IsValid(rag), 'lethal damage ends temporary ragdoll ownership')
				local removed = Spawn(body, false, base + Vector(180, 0, 8), 0)
				timer.Simple(0.4, function() Protect(function()
					Model(removed, false)
					removed:SetState('knocked_down', { velocity = vector_origin }, true)
					local cleanup_rag = removed:GetStateData().ragdoll
					cleanup_rag:Remove()
					timer.Simple(0.2, function() Protect(function()
						Check(not removed:IsAlive() and not IsValid(cleanup_rag), 'removing a temporary ragdoll also removes the hidden actor')
						report.cases[#report.cases + 1] = { name = body .. '_recovery_damage_guards', passed = true }
						Write()
						done()
					end) end)
				end) end)
			end) end)
		end) end)
	end) end)
end

Protect(function()
	bgNPC.GOAP.ClearCache() -- planner self-tests construct fresh action instances
	for _, name in ipairs({ 'goap.planner', 'goap.sets' }) do bgNPC.Test.list[name](Check) end
	Next()
end)
return { pending = true, report = 'bgn_door_lab/doors.json' }

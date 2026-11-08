--[[
	Scenic NPCs: staged scenes that appear on the map and stay until nobody watches (data: config/states/sh_scenic.lua,
	places: sv_scenic_finders.lua, state: brain/fsm/states/sh_scenic_npc.lua).

	A scene is made of ordinary actors, so an NPC and a NextBot body both work and every reaction of the mod works:
	a shot, a hit or a nearby fight takes an actor out of the scene (it becomes a usual resident), the others stay.

	Console: bgn_scenic_spawn <scene id> puts a scene in front of the admin, bgn_scenic_clear removes all.
--]]

local Scenic = bgNPC.Scenic or {}
bgNPC.Scenic = Scenic
local Spots = Scenic.Spots
local Util = bgNPC.Util
local Budget = bgNPC.Tasks.Budget
--

local cvar_enable = GetConVar('bgn_scenic')
local cvar_max = GetConVar('bgn_scenic_max')
local cvar_period = GetConVar('bgn_scenic_period')
local cvar_radius = GetConVar('bgn_spawn_radius')
local cvar_block = GetConVar('bgn_spawn_block_radius')

local TRIES = 6 -- seeds checked in one pass
local MIN_DISTANCE_SQR = 400 * 400 -- between two scenes
local START_DELAY = 0.2 -- the actor finishes its own initialization first
local CHECK_PERIOD = 5
local DEFAULT_TTL = 600
local MAX_COOLDOWN = 600
local SPAWN_LIFT = Vector(0, 0, 4)

local active = Scenic.active or {}
Scenic.active = active

-- scene id -> { fails, until }: a scene that finds no place waits longer every time (no doors on the map, no walls...)
local cooldown = {}

-- ---------------------------------------------------------------------------
-- Planning
-- ---------------------------------------------------------------------------

local function ToWorld(spot, offset, yaw)
	local pos = spot.pos + spot.ang:Forward() * offset.x + spot.ang:Right() * offset.y
	pos.z = spot.pos.z + offset.z
	return pos, Angle(0, spot.ang.y + (yaw or 0), 0)
end

-- The members of a scene with the copies of the group: { def, offset, yaw }
local function Roster(scene)
	local roster = {}
	for i, def in ipairs(scene.members) do
		roster[i] = { def = def, offset = def.pos or vector_origin, yaw = def.yaw or 0 }
	end

	local group = scene.group
	if not group then return roster end

	local template = scene.members[1]
	local count = math.random(group.min, group.max)
	for i = 2, count do
		local offset, yaw = vector_origin, template.yaw or 0
		if group.step then
			offset = group.step * (i - 1) + Vector(0, math.random(-6, 6), 0)
		else
			-- a loose cluster: the first stands in the middle, the others around it
			local around = 360 / (count - 1) * (i - 2) + math.random(-20, 20)
			local dist = group.ring * math.Rand(0.7, 1)
			offset = Vector(math.cos(math.rad(around)) * dist, math.sin(math.rad(around)) * dist, 0)
			yaw = yaw + math.random(-70, 70)
		end
		roster[#roster + 1] = { def = template, offset = (template.pos or vector_origin) + offset, yaw = yaw }
	end

	return roster
end

-- @return table|nil plan { members = { { def, pos, ang } }, props = { { model, pos, ang, solid } } }
local function Plan(scene, spot)
	local members = {}
	for _, item in ipairs(Roster(scene)) do
		local def = item.def
		local pos, ang = ToWorld(spot, item.offset, item.yaw)

		if def.seat then
			pos, ang = spot.stage, spot.ang
		else
			local floor = Spots.Floor(pos)
			-- one level for the whole scene: no member on the floor below or on a ledge
			-- a body leaning on a wall (a gap under a body width) touches it by design, the finder checked the room
			local tight = (scene.gap or 22) < 18
			if not floor or math.abs(floor.z - spot.pos.z) > 20 or Util.IsVectorInWater(floor)
				or not (tight or Spots.HasRoom(floor))
			then
				return
			end
			pos = floor
		end

		if not bgNPC:IsValidSpawnArea(def.type, pos) then return end
		members[#members + 1] = { def = def, pos = pos, ang = ang }
	end

	local props = {}
	for _, prop in ipairs(scene.props or {}) do
		local pos, ang = ToWorld(spot, prop.pos, prop.yaw)
		local model = istable(prop.model) and table.Random(prop.model) or prop.model
		props[#props + 1] = { model = model, pos = pos, ang = ang, solid = prop.solid ~= false }
	end

	return { members = members, props = props }
end

Scenic.Plan = Plan

-- ---------------------------------------------------------------------------
-- Poses
-- ---------------------------------------------------------------------------

local function PickSequence(actor, list)
	if isstring(list) then list = { list } end
	for _, name in ipairs(bgNPC.Table.Shuffle(list)) do
		if actor:IsValidSequence(name) then return name end
	end
end

-- Sits the NPC on the chair or the custom seat of the spot, the way the sit_to_chair states do.
-- @return table|nil what the state has to give back when the actor leaves the scene
local function Sit(actor, spot)
	local npc = actor:GetNPC()
	local back = { old_collision = npc:GetCollisionGroup() }

	if spot.seat then
		spot.seat:SetSitting(npc)
		npc:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
		npc:SetPos(spot.seat:GetPos())
		npc:SetAngles(spot.seat:GetAngles())
		npc:SetCollisionGroup(back.old_collision)
		back.seat = spot.seat
		return back
	end

	local chair, data = spot.chair, spot.chair_data
	if not IsValid(chair) then return end

	local pos = chair:GetPos() + chair:GetForward() * 35
	local ang = chair:GetAngles()
	if data.offsetPosition then pos = data.offsetPosition(npc, chair, pos) end
	if data.offsetAngle then ang = data.offsetAngle(npc, chair, ang) end

	chair.occupied = true
	npc:SetCollisionGroup(COLLISION_GROUP_WORLD)
	npc:SetPos(pos)
	npc:SetAngles(ang)
	npc:SetParent(chair)
	local phys = chair:GetPhysicsObject()
	if IsValid(phys) then phys:EnableMotion(false) end
	back.chair = chair
	return back
end

local function CreateProp(info)
	local prop = ents.Create('prop_dynamic')
	if not IsValid(prop) then return end
	prop:SetModel(info.model)
	prop:SetPos(info.pos)
	prop:SetAngles(info.ang)
	prop:Spawn()
	if info.solid then
		prop:SetSolid(SOLID_VPHYSICS)
	else
		prop:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	end
	return prop
end

-- ---------------------------------------------------------------------------
-- Scene
-- ---------------------------------------------------------------------------

function Scenic.Remove(item)
	for _, actor in ipairs(item.actors) do
		-- only those still on the stage: the ones that left are usual residents now and the remover's business
		if actor:HasState('scenic_npc') or not item.started then actor:Remove() end
	end
	for _, prop in ipairs(item.props) do
		if IsValid(prop) then prop:Remove() end
	end
	table.RemoveByValue(active, item)
end

local function Start(item, plan, spot)
	item.started = true
	if not item.actors[1] then return end

	local playing = 0
	for i, actor in ipairs(item.actors) do
		local npc = actor:GetNPC()
		local member = plan.members[i]
		if actor:IsAlive() and IsValid(npc) then
			local seq = PickSequence(actor, member.def.seq)
			local back
			if member.def.seat then
				back = Sit(actor, spot)
			else
				npc:SetPos(member.pos)
				npc:SetAngles(member.ang)
			end

			if seq and (back or not member.def.seat) then
				if member.def.weapon then actor:PrepareWeapon(member.def.weapon, true) end
				actor:SetState('scenic_npc', { seq = seq, scene = item, back = back }, true)
				playing = playing + 1
			else
				actor:Remove() -- no sequence for this model, or the chair is gone
			end
		end
	end

	if playing == 0 then Scenic.Remove(item) end
end

-- Spawns the scene at the spot.
-- @return table|nil the scene
function Scenic.Create(id, scene, spot, plan)
	plan = plan or Plan(scene, spot)
	if not plan then return end

	local item = { id = id, scene = scene, pos = spot.pos, actors = {}, props = {}, born = CurTime() }

	for _, member in ipairs(plan.members) do
		-- a hull exactly on the floor counts as stuck: the spawner gets a little height; a member that stands closer
		-- than a body to an earlier one is spawned higher (the spawner refuses overlapping bodies), Start puts all in place
		local lift = SPAWN_LIFT
		for _, other in ipairs(item.actors) do
			if other:GetNPC():GetPos():Distance(member.pos) < 40 then lift = lift + Vector(0, 0, 90) end
		end
		local actor = bgNPC:SpawnActor(member.def.type, member.pos + lift)
		if not actor then
			for _, spawned in ipairs(item.actors) do spawned:Remove() end
			return
		end

		local npc = actor:GetNPC()
		npc:SetAngles(member.ang)
		if member.def.models then
			local model = table.Random(member.def.models)
			if util.IsValidModel(model) then npc:SetModel(model) end
		end

		actor.mechanics.ignore_limit = true
		actor.data.start_random_state, actor.data.start_state = false, nil
		item.actors[#item.actors + 1] = actor
	end

	for _, info in ipairs(plan.props) do
		item.props[#item.props + 1] = CreateProp(info)
	end

	active[#active + 1] = item
	timer.Simple(START_DELAY, function() Start(item, plan, spot) end)

	bgNPC.Util.Log('Scene ' .. id .. ' (' .. #item.actors .. ' actors)', 'Scenic')
	return item
end

-- ---------------------------------------------------------------------------
-- Finding a place
-- ---------------------------------------------------------------------------

local function PickScene()
	local total, list = 0, {}
	local now = CurTime()
	for id, scene in pairs(bgNPC.cfg.scenic) do
		local wait = cooldown[id]
		if not (wait and wait.till > now) then
			local weight = scene.weight or 10
			list[#list + 1] = { id = id, weight = weight }
			total = total + weight
		end
	end

	local roll = math.random() * total
	for _, entry in ipairs(list) do
		roll = roll - entry.weight
		if roll <= 0 then return entry.id end
	end
end

local function IsFarFromScenes(pos)
	for _, item in ipairs(active) do
		if item.pos:DistToSqr(pos) < MIN_DISTANCE_SQR then return false end
	end
	return true
end

local function Backoff(id, found)
	if found then
		cooldown[id] = nil
		return
	end
	local fails = (cooldown[id] and cooldown[id].fails or 0) + 1
	cooldown[id] = { fails = fails, till = CurTime() + math.min(MAX_COOLDOWN, 20 * 2 ^ fails) }
end

-- One pass: the scene id (or a random one) at the first seed that fits.
-- @return table|nil the scene
function Scenic.TrySpawn(id)
	local players = player.GetHumans()
	if #players == 0 then return end

	id = id or PickScene()
	local scene = id and bgNPC.cfg.scenic[id]
	if not scene then return end

	local seeds = Spots.Seeds(scene.place, players)
	for i = 1, math.min(TRIES, #seeds) do
		Budget()
		local spot = Spots.Find(scene.place, seeds[i], scene)
		if spot and IsFarFromScenes(spot.pos) then
			local plan = Plan(scene, spot)
			if plan and bgNPC:IsHiddenSpawnPosition(spot.pos) then
				local item = Scenic.Create(id, scene, spot, plan)
				if item then
					Backoff(id, true)
					return item
				end
			end
		end
	end

	Backoff(id, false)
end

-- ---------------------------------------------------------------------------
-- Life cycle
-- ---------------------------------------------------------------------------

-- Nobody sees the place and nobody is close.
local function IsUnwatched(pos)
	local block_sqr = cvar_block:GetFloat() ^ 2
	for _, ply in ipairs(player.GetHumans()) do
		if pos:DistToSqr(ply:GetPos()) <= block_sqr or bgNPC.Vision.PlayerCanSeePos(ply, pos) then return false end
	end
	return true
end

local function IsFarFromPlayers(pos)
	local far_sqr = (cvar_radius:GetFloat() * 1.1) ^ 2
	for _, ply in ipairs(player.GetHumans()) do
		if pos:DistToSqr(ply:GetPos()) <= far_sqr then return false end
	end
	return true
end

local function Check(item)
	local staying = 0
	for i = #item.actors, 1, -1 do
		local actor = item.actors[i]
		if not actor:IsAlive() then
			table.remove(item.actors, i)
		elseif actor:HasState('scenic_npc') then
			staying = staying + 1
		end
	end

	local far = IsFarFromPlayers(item.pos)
	local done = staying == 0 or CurTime() - item.born > (item.scene.ttl or DEFAULT_TTL)
	if far or (done and IsUnwatched(item.pos)) then Scenic.Remove(item) end
end

bgNPC.Tasks.Add('bgn_scenic', function(yield, wait)
	local next_spawn = 0
	while true do
		wait(CHECK_PERIOD)

		for i = #active, 1, -1 do
			if active[i] then Check(active[i]) end
			yield()
		end

		if cvar_enable:GetBool() and CurTime() >= next_spawn and #active < cvar_max:GetInt()
			and GetConVar('bgn_enable'):GetBool()
		then
			next_spawn = CurTime() + cvar_period:GetFloat()
			Scenic.TrySpawn()
		end
	end
end)

-- ---------------------------------------------------------------------------
-- Console
-- ---------------------------------------------------------------------------

function Scenic.Clear()
	for i = #active, 1, -1 do Scenic.Remove(active[i]) end
end

bgNPC.Commands.Register('bgn_scenic_clear', { admin = true, server = Scenic.Clear, help = 'Removes every scenic scene' })

bgNPC.Commands.Register('bgn_scenic_spawn', {
	admin = true,
	help = 'bgn_scenic_spawn <scene id>: a scene where you look (the finder place rules do not apply)',
	autocomplete = function(_, args)
		local list = {}
		for id in pairs(bgNPC.cfg.scenic) do list[#list + 1] = 'bgn_scenic_spawn ' .. id end
		return list
	end,
	server = function(ply, _, args)
		local id = args[1]
		local scene = id and bgNPC.cfg.scenic[id]
		if not IsValid(ply) or not scene then return MsgN('[Background NPCs] Unknown scene: ' .. tostring(id)) end

		local tr = ply:GetEyeTrace()
		local pos = Spots.Floor(tr.HitPos + tr.HitNormal * 4) or tr.HitPos
		local spot = { pos = pos, ang = Angle(0, ply:EyeAngles().y + 180, 0) }
		if scene.place == 'wall' or scene.place == 'door' then spot.ang = tr.HitNormal:Angle() end
		if not Scenic.Create(id, scene, spot) then MsgN('[Background NPCs] The scene does not fit here: ' .. id) end
	end,
})

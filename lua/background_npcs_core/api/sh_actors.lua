local Assert = bgNPC.Assert
local Actors = bgNPC.Actors
local table_HasValueBySeq = bgNPC.Table.HasValue
--

--[[
	Storage (kept on bgNPC for backward compatibility):
		bgNPC.actors        - list of all actors
		bgNPC.npcs          - list of their entities
		bgNPC.factors       - actor type -> list of actors
		bgNPC.fnpcs         - actor type -> list of entities
		bgNPC.actors_by_uid - uid -> actor
--]]

function Actors.ResetStorage()
	bgNPC.actors = {}
	bgNPC.npcs = {}
	bgNPC.factors = {}
	bgNPC.fnpcs = {}
	bgNPC.actors_by_uid = {}
end

if not bgNPC.actors_by_uid then Actors.ResetStorage() end

-- ---------------------------------------------------------------------------
-- Registry
-- ---------------------------------------------------------------------------

local function RemoveFirst(list, value)
	for i = #list, 1, -1 do
		if list[i] == value then
			table.remove(list, i)
			return true
		end
	end
	return false
end

-- Registers an actor in all lookup lists. Called automatically by BGN_ACTOR:Instance.
function Actors.Register(actor)
	Assert.Arg(1, actor, 'actor', 'bgNPC.Actors.Register')

	if bgNPC.actors_by_uid[actor.uid] == actor then return end

	local npc = actor:GetNPC()
	if table_HasValueBySeq(bgNPC.npcs, npc) then return end

	local actor_type = actor:GetType()

	table.insert(bgNPC.actors, actor)
	table.insert(bgNPC.npcs, npc)

	bgNPC.factors[actor_type] = bgNPC.factors[actor_type] or {}
	table.insert(bgNPC.factors[actor_type], actor)

	bgNPC.fnpcs[actor_type] = bgNPC.fnpcs[actor_type] or {}
	table.insert(bgNPC.fnpcs[actor_type], npc)

	bgNPC.actors_by_uid[actor.uid] = actor
end

-- Unregisters the actor bound to the entity. The entity itself is not removed.
function Actors.UnregisterActor(actor)
	local npc = actor:GetNPC()
	if IsValid(npc) then npc.isBgnActor = false end
	RemoveFirst(bgNPC.actors, actor)

	local actor_type = actor:GetType()

	bgNPC.actors_by_uid[actor.uid] = nil
	RemoveFirst(bgNPC.npcs, npc)
	if bgNPC.factors[actor_type] then RemoveFirst(bgNPC.factors[actor_type], actor) end
	if bgNPC.fnpcs[actor_type] then RemoveFirst(bgNPC.fnpcs[actor_type], npc) end

	if SERVER then
		bgNPC.Net.Send('bgm_update_death_actors_on_client', nil, npc, actor.uid)
	end
end

function Actors.Unregister(npc)
	for _, actor in ipairs(bgNPC.actors) do
		if actor:GetNPC() == npc then Actors.UnregisterActor(actor) return end
	end
end

-- The character survives boarding; only its engine entity changes.
function Actors.Rebind(actor, npc)
	local old = actor:GetNPC()
	if old == npc then return end
	if IsValid(old) then
		old.isBgnActor, old.BGN_ACTOR_OBJECT, old.GetActor = false, nil, nil
		if SERVER then old:SetNW2Bool('bgn_actor', false) end
	end
	actor.npc, actor.npc_index = npc, npc:EntIndex()
	if IsValid(old) then
		npc.bgn_has_killed, npc.bgn_last_attack = old.bgn_has_killed, old.bgn_last_attack
	end
	npc.isBgnActor, npc.BGN_ACTOR_OBJECT = true, actor
	function npc:GetActor() return actor end
	if SERVER then
		npc:SetNW2Bool('bgn_actor', true)
		npc.inpcIgnore = actor.mechanics.inpc_ignore
		actor.body = bgNPC.Body.For(actor, npc)
		actor.entity_generation = (actor.entity_generation or 0) + 1
		actor.sync_players_hash = setmetatable({}, { __mode = 'k' })
	end
	for _, list in ipairs({ bgNPC.npcs, bgNPC.fnpcs[actor:GetType()] or {} }) do
		local replaced = false
		for i, ent in ipairs(list) do if ent == old then list[i], replaced = npc, true end end
		if not replaced and bgNPC.actors_by_uid[actor.uid] == actor then list[#list + 1] = npc end
	end
	for _, other in ipairs(bgNPC.actors) do
		for _, list in ipairs({ other.enemies, other.targets, other.enemies_always_visible }) do
			for i, ent in ipairs(list) do if ent == old then list[i] = npc end end
		end
		if other.walkTarget == old then other.walkTarget = npc end
		for _, state in ipairs({ other.state_data or {}, other.old_state or {} }) do
			for key, value in pairs(state.data or {}) do if value == old then state.data[key] = npc end end
		end
		if other.enemy_last_seen and other.enemy_last_seen[old] then
			other.enemy_last_seen[npc], other.enemy_last_seen[old] = other.enemy_last_seen[old], nil
		end
		if other.body and other.body:GetEnemy() == old then other.body:SetEnemy(npc) end
	end
	hook.Run('BGN_ActorEntityChanged', actor, old, npc)
	if SERVER then
		bgNPC.Net.Send('bgn_add_actor_from_client', nil, npc, actor.type, actor.uid, actor.info,
			actor.entity_generation, actor.class, actor.model)
	end
end

-- Removes every actor whose entity no longer exists.
function Actors.ClearRemoved()
	-- Client entities may disappear before the replacement arrives; only the server retires a UID.
	if CLIENT then return end
	local actors = bgNPC.actors
	for i = #actors, 1, -1 do
		local actor = actors[i]
		if not IsValid(actor:GetNPC()) and not (SERVER and actor.vehicle_body and actor:InVehicle()) then
			actor:RemoveActor()
		end
	end

	local npcs = bgNPC.npcs
	for i = #npcs, 1, -1 do
		if not IsValid(npcs[i]) then table.remove(npcs, i) end
	end

	for _, list in pairs(bgNPC.fnpcs) do
		for i = #list, 1, -1 do
			if not IsValid(list[i]) then table.remove(list, i) end
		end
	end
end

if CLIENT then
	local generations = {}
	bgNPC.Net.Receive('bgm_update_death_actors_on_client', function(ply, npc, uid)
		if uid then
			generations[uid] = math.huge
			local actor = Actors.GetByUid(uid)
			if actor then Actors.UnregisterActor(actor) end
		elseif npc then Actors.Unregister(npc) end
		Actors.ClearRemoved()
	end)

	function Actors.ReceiveBinding(npc, npc_type, uid, info, generation, class, model)
		generation = generation or 0
		if generation < (generations[uid] or 0) or not IsValid(npc) then return end
		generations[uid] = generation
		local actor = Actors.GetByUid(uid)
		if actor and (actor.entity_generation or 0) > (generation or 0) then return end
		if not actor then
			actor = bgNPC.Actor.Create(npc, npc_type, uid)
			if actor then Actors.Register(actor) end
		elseif actor:GetNPC() ~= npc then
			Actors.Rebind(actor, npc)
		end
		if not actor then return end
		actor.entity_generation = generation or 0
		if info then actor.info = info end
		actor.class, actor.model = class or actor.class, model or actor.model
		return actor
	end
	bgNPC.Net.Receive('bgn_add_actor_from_client', function(ply, ...)
		Actors.ReceiveBinding(...)
	end, { wait_entities = true })
end

-- ---------------------------------------------------------------------------
-- Lookups
-- ---------------------------------------------------------------------------

-- Returns the actor bound to an entity.
-- @param npc entity|nil
-- @return table|nil actor
function Actors.Get(npc)
	if not IsValid(npc) or not npc.isBgnActor then return nil end
	if npc.GetActor then return npc:GetActor() end
	return npc.BGN_ACTOR_OBJECT
end

function Actors.IsActor(npc)
	return Actors.Get(npc) ~= nil
end

function Actors.GetByUid(uid)
	if uid == nil then return nil end
	return bgNPC.actors_by_uid[uid]
end

function Actors.GetFirst()
	return bgNPC.actors[1]
end

-- ! Returns the internal list, do not modify it.
function Actors.GetAll()
	return bgNPC.actors
end

-- @param actor_type string|nil nil - all actors
function Actors.Count(actor_type)
	if not actor_type then return #bgNPC.actors end
	local list = bgNPC.factors[actor_type]
	return list and #list or 0
end

function Actors.GetByType(actor_type)
	return bgNPC.factors[actor_type] or {}
end

function Actors.GetAllNPCs()
	return bgNPC.npcs
end

function Actors.GetNPCsByType(actor_type)
	return bgNPC.fnpcs[actor_type] or {}
end

function Actors.HasNPC(npc)
	return table_HasValueBySeq(bgNPC.npcs, npc)
end

-- Returns actors for which predicate(actor) is true.
function Actors.Filter(predicate)
	Assert.Arg(1, predicate, 'function', 'bgNPC.Actors.Filter')

	local actors = bgNPC.actors
	local result = {}

	for i = 1, #actors do
		local actor = actors[i]
		if predicate(actor) then result[#result + 1] = actor end
	end

	return result
end

-- @param team string|table|entity|actor anything ACTOR:HasTeam accepts
function Actors.GetByTeam(team)
	return Actors.Filter(function(actor) return actor:HasTeam(team) end)
end

-- @param state string|table state name or list of names
function Actors.GetByState(state)
	return Actors.Filter(function(actor) return actor:HasState(state) end)
end

function Actors.GetInRadius(center, radius)
	Assert.Arg(1, center, 'vector', 'bgNPC.Actors.GetInRadius')
	Assert.Arg(2, radius, 'number', 'bgNPC.Actors.GetInRadius')

	local radius_sqr = radius * radius
	return Actors.Filter(function(actor)
		local npc = actor:GetNPC()
		return IsValid(npc) and npc:GetPos():DistToSqr(center) <= radius_sqr
	end)
end

local function FindNearest(actors, center)
	local nearest, nearest_dist

	for i = 1, #actors do
		local actor = actors[i]
		local npc = actor:GetNPC()
		if IsValid(npc) then
			local dist = npc:GetPos():DistToSqr(center)
			if not nearest_dist or dist < nearest_dist then
				nearest = actor
				nearest_dist = dist
			end
		end
	end

	return nearest
end

function Actors.GetNearest(center)
	Assert.Arg(1, center, 'vector', 'bgNPC.Actors.GetNearest')
	return FindNearest(bgNPC.actors, center)
end

function Actors.GetNearestByType(center, actor_type)
	Assert.Arg(1, center, 'vector', 'bgNPC.Actors.GetNearestByType')
	Assert.Arg(2, actor_type, 'string', 'bgNPC.Actors.GetNearestByType')
	return FindNearest(Actors.GetByType(actor_type), center)
end

-- Do two actor entities share at least one team.
function Actors.ShareTeam(npc1, npc2)
	local actor1 = Actors.Get(npc1)
	local actor2 = Actors.Get(npc2)
	if not actor1 or not actor2 then return false end

	local team1 = actor1:GetData().team
	local team2 = actor2:GetData().team
	if not istable(team1) or not istable(team2) then return false end

	for i = 1, #team1 do
		if table_HasValueBySeq(team2, team1[i]) then return true end
	end

	return false
end

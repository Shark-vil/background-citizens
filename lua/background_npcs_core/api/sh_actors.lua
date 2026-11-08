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
function Actors.Unregister(npc)
	if IsValid(npc) then npc.isBgnActor = false end

	local list = bgNPC.actors
	local actor

	for i = #list, 1, -1 do
		if list[i]:GetNPC() == npc then
			actor = list[i]
			table.remove(list, i)
			break
		end
	end

	if not actor then return end

	local actor_type = actor:GetType()

	bgNPC.actors_by_uid[actor.uid] = nil
	RemoveFirst(bgNPC.npcs, npc)
	if bgNPC.factors[actor_type] then RemoveFirst(bgNPC.factors[actor_type], actor) end
	if bgNPC.fnpcs[actor_type] then RemoveFirst(bgNPC.fnpcs[actor_type], npc) end

	if SERVER then
		bgNPC.Net.Send('bgm_update_death_actors_on_client', nil, npc)
	end
end

-- Removes every actor whose entity no longer exists.
function Actors.ClearRemoved()
	local actors = bgNPC.actors
	for i = #actors, 1, -1 do
		local actor = actors[i]
		if not IsValid(actor:GetNPC()) then
			bgNPC.actors_by_uid[actor.uid] = nil
			table.remove(actors, i)
		end
	end

	local npcs = bgNPC.npcs
	for i = #npcs, 1, -1 do
		if not IsValid(npcs[i]) then table.remove(npcs, i) end
	end

	for _, list in pairs(bgNPC.factors) do
		for i = #list, 1, -1 do
			if not IsValid(list[i]:GetNPC()) then table.remove(list, i) end
		end
	end

	for _, list in pairs(bgNPC.fnpcs) do
		for i = #list, 1, -1 do
			if not IsValid(list[i]) then table.remove(list, i) end
		end
	end
end

if CLIENT then
	bgNPC.Net.Receive('bgm_update_death_actors_on_client', function(ply, npc)
		if npc then Actors.Unregister(npc) end
		Actors.ClearRemoved()
	end)

	bgNPC.Net.Receive('bgn_add_actor_from_client', function(ply, npc, npc_type, uid, info)
		if Actors.Get(npc) ~= nil then return end
		local actor = bgNPC.Actor.Create(npc, npc_type, uid)
		if actor and info then actor.info = info end
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

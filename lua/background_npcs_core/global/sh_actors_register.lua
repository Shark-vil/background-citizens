local bgNPC = bgNPC
local Assert = bgNPC.Assert
local CLIENT = CLIENT
local SERVER = SERVER
local pairs = pairs
local IsValid = IsValid
local table_insert = table.insert
local table_remove = table.remove
--

-- uid -> actor, keeps GetActorByUid O(1)
bgNPC.actors_by_uid = bgNPC.actors_by_uid or {}

if CLIENT then
	snet.Callback('bgm_update_death_actors_on_client', function(ply, npc)
		if npc then bgNPC:RemoveNPC(npc) end
		bgNPC:ClearRemovedNPCs()
	end).Register()

	snet.Callback('bgn_add_actor_from_client', function(ply, npc, npc_type, uid, info)
		if bgNPC:GetActor(npc) ~= nil then return end
		local actor = BGN_ACTOR:Instance(npc, npc_type, uid)
		if actor and info then actor.info = info end
	end).Validator(SNET_ENTITY_VALIDATOR).Register()
end

local function RemoveFirst(list, predicate)
	for i = #list, 1, -1 do
		if predicate(list[i]) then
			table_remove(list, i)
			return true
		end
	end
	return false
end

local function RemoveAll(list, predicate)
	for i = #list, 1, -1 do
		if predicate(list[i]) then table_remove(list, i) end
	end
end

-- Registers an actor in all lookup lists.
function bgNPC:AddNPC(actor)
	Assert.Arg(1, actor, 'actor', 'bgNPC:AddNPC')

	local npc = actor:GetNPC()
	if self.actors_by_uid[actor.uid] == actor then return end
	if table.HasValueBySeq(self.npcs, npc) then return end

	local npc_type = actor:GetType()

	table_insert(self.actors, actor)
	table_insert(self.npcs, npc)

	self.factors[npc_type] = self.factors[npc_type] or {}
	table_insert(self.factors[npc_type], actor)

	self.fnpcs[npc_type] = self.fnpcs[npc_type] or {}
	table_insert(self.fnpcs[npc_type], npc)

	self.actors_by_uid[actor.uid] = actor
end

-- Unregisters the actor bound to the entity.
function bgNPC:RemoveNPC(npc)
	if IsValid(npc) then npc.isBgnActor = false end

	local removed_actor
	RemoveFirst(self.actors, function(actor)
		if actor:GetNPC() == npc then
			removed_actor = actor
			return true
		end
	end)

	if not removed_actor then return end

	self.actors_by_uid[removed_actor.uid] = nil

	local is_npc = function(value) return value == npc end
	RemoveFirst(self.npcs, is_npc)

	local npc_type = removed_actor:GetType()
	if self.factors[npc_type] then RemoveFirst(self.factors[npc_type], function(a) return a == removed_actor end) end
	if self.fnpcs[npc_type] then RemoveFirst(self.fnpcs[npc_type], is_npc) end

	if SERVER then
		snet.Request('bgm_update_death_actors_on_client', npc).InvokeAll()
	end
end

-- Removes every actor whose entity no longer exists.
function bgNPC:ClearRemovedNPCs()
	local is_removed_actor = function(actor) return not IsValid(actor:GetNPC()) end
	local is_removed_npc = function(npc) return not IsValid(npc) end

	for i = #self.actors, 1, -1 do
		local actor = self.actors[i]
		if is_removed_actor(actor) then
			self.actors_by_uid[actor.uid] = nil
			table_remove(self.actors, i)
		end
	end

	RemoveAll(self.npcs, is_removed_npc)

	for _, list in pairs(self.factors) do RemoveAll(list, is_removed_actor) end
	for _, list in pairs(self.fnpcs) do RemoveAll(list, is_removed_npc) end
end

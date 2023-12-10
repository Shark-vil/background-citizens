local bgNPC = bgNPC
local CLIENT = CLIENT
local table = table
local pairs = pairs
local IsValid = IsValid
-- local ents_GetAll = ents.GetAll
--

if CLIENT then
	snet.Callback('bgm_update_death_actors_on_client', function(ply, npc)
		if npc then bgNPC:RemoveNPC(npc) end
		bgNPC:ClearRemovedNPCs()
	end).Register()

	-- timer.Create('bgn_client_async_actors', 1, 9, function()
	-- 	local entities = ents_GetAll()

	-- 	for i = 1, #entities do
	-- 		local ent = entities[i]
	-- 		if IsValid(ent) and ent:GetNWBool('IS_BGN_ACTOR', false) and not bgNPC:IsActor(ent) then
	-- 			local npc_type = ent:GetNWString('BGB_ACTOR_TYPE', nil)
	-- 			local uid = ent:GetNWString('BGB_ACTOR_UID', nil)
	-- 			local info = ent:GetNWString('BGN_ACTOR_INFO', nil)
	-- 			if not npc_type or not uid or not info then continue end
	-- 			local actor = BGN_ACTOR:Instance(ent, npc_type, uid)
	-- 			if info then
	-- 				actor.info = snet.Deserialize(util.Decompress(info))
	-- 			end
	-- 		end
	-- 	end
	-- end)

	snet.Callback('bgn_add_actor_from_client', function(ply, npc, npc_type, uid, info)
		if bgNPC:GetActor(npc) ~= nil then return end
		local actor = BGN_ACTOR:Instance(npc, npc_type, uid)
		actor.info = info
	end).Validator(SNET_ENTITY_VALIDATOR).Register()
end

function bgNPC:AddNPC(actor)
	local npc = actor:GetNPC()
	if table.HasValueBySeq(self.npcs, npc) then return end

	table.insert(self.actors, actor)
	table.insert(self.npcs, npc)

	local npc_type = actor:GetType()
	self.factors[npc_type] = self.factors[npc_type] or {}
	table.insert(self.factors[npc_type], actor)

	self.fnpcs[npc_type] = self.fnpcs[npc_type] or {}
	table.insert(self.fnpcs[npc_type], npc)
end

function bgNPC:RemoveNPC(npc)
	if SERVER then
		snet.Request('bgm_update_death_actors_on_client', npc).InvokeAll()
	end

	if IsValid(npc) then
		npc.isBgnActor = false
	end

	for i = #self.actors, 1, -1 do
		if self.actors[i]:GetNPC() == npc then
			table.remove(self.actors, i)
			break
		end
	end

	for i = #self.npcs, 1, -1 do
		if self.npcs[i] == npc then
			table.remove(self.npcs, i)
			break
		end
	end

	for key, data in pairs(self.factors) do
		for i = #data, 1, -1 do
			if data[i]:GetNPC() == npc then
				table.remove(self.factors[key], i)
				break
			end
		end
	end

	for key, data in pairs(self.fnpcs) do
		for i = #data, 1, -1 do
			if data[i] == npc then
				table.remove(self.fnpcs[key], i)
				break
			end
		end
	end
end

function bgNPC:ClearRemovedNPCs()
	for i = #self.actors, 1, -1 do
		local npc = self.actors[i]:GetNPC()
		if not IsValid(npc) then table.remove(self.actors, i) end
	end

	for i = #self.npcs, 1, -1 do
		local npc = self.npcs[i]
		if not IsValid(npc) then table.remove(self.npcs, i) end
	end

	for key, data in pairs(self.factors) do
		for i = #data, 1, -1 do
			local npc = data[i]:GetNPC()
			if not IsValid(npc) then table.remove(self.factors[key], i) end
		end
	end

	for key, data in pairs(self.fnpcs) do
		for i = #data, 1, -1 do
			local npc = data[i]
			if not IsValid(npc) then table.remove(self.fnpcs[key], i) end
		end
	end
end
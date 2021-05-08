if CLIENT then
	snet.Callback('bgm_update_death_actors_on_client', function(ply, npc)
		if npc then bgNPC:RemoveNPC(npc) end
		bgNPC:ClearRemovedNPCs()
	end).Register()

	snet.Callback('bgn_add_actor_from_client', function(ply, npc, npc_type, uid)
		if bgNPC:GetActor(npc) ~= nil then return end
		BGN_ACTOR:Instance(npc, npc_type, uid)
	end).Validator(SNET_ENTITY_VALIDATOR).Register()
end

function bgNPC:AddNPC(actor)
	local npc = actor:GetNPC()
	if array.HasValue(self.npcs, npc) then return end

	table.insert(self.actors, actor)
	table.insert(self.npcs, npc)

	local type = actor:GetType()
	self.factors[type] = self.factors[type] or {}
	table.insert(self.factors[type], actor)

	self.fnpcs[type] = self.fnpcs[type] or {}
	table.insert(self.fnpcs[type], npc)
end

function bgNPC:RemoveNPC(npc)
	snet.Create('bgm_update_death_actors_on_client', npc).InvokeAll()

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
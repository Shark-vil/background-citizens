if CLIENT then
	snet.Callback('bgn_remove_actor_from_client', function(ply, npc)
		if not npc then return end
		bgNPC:RemoveNPC(npc)
	end).Register()

	snet.Callback('bgn_add_actor_from_client', function(ply, npc, npcType, uid)
		if bgNPC:GetActor(npc) ~= nil then return end

		local actor = BGN_ACTOR:Instance(npc, npcType, bgNPC.cfg.npcs_template[npcType], uid)
		bgNPC:AddNPC(actor)
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
	snet.Create('bgn_remove_actor_from_client', npc).InvokeAll()

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

local function NpcIsValid(npc)
	if not IsValid(npc) or npc:Health() <= 0 or (npc:IsNPC() and npc:IsCurrentSchedule(SCHED_DIE)) then
		return false
	end
	return true
end

function bgNPC:ClearRemovedNPCs()
	for i = #self.actors, 1, -1 do
		local npc = self.actors[i]:GetNPC()
		if not NpcIsValid(npc) then table.remove(self.actors, i) end
	end

	for i = #self.npcs, 1, -1 do
		local npc = self.npcs[i]
		if not NpcIsValid(npc) then table.remove(self.npcs, i) end
	end

	for key, data in pairs(self.factors) do
		for i = #data, 1, -1 do
			local npc = data[i]:GetNPC()
			if not NpcIsValid(npc) then table.remove(self.factors[key], i) end
		end
	end

	for key, data in pairs(self.fnpcs) do
		for i = #data, 1, -1 do
			local npc = data[i]
			if not NpcIsValid(npc) then table.remove(self.fnpcs[key], i) end
		end
	end
end
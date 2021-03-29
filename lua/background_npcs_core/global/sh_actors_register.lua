if CLIENT then
	snet.RegisterCallback('bgn_add_actor_from_client', function(ply, npc, npcType, uid)
		if bgNPC:GetActor(npc) ~= nil then return end

		local actor = BGN_ACTOR:Instance(npc, npcType, bgNPC.cfg.npcs_template[npcType], uid)
		bgNPC:AddNPC(actor)
	end)
end

if SERVER then
	local hooks_active = {}
	function bgNPC:FindSpawnLocation(spawner_id, desiredPosition, limit_pass, action)
		if not action and not isfunction(action) then return end

		local hook_name = 'BGN_SpawnerThread_' .. spawner_id
		if hooks_active[hook_name] then return end
		hooks_active[hook_name] = true

		if not desiredPosition then
			local ply = table.Random(player.GetAll())
			desiredPosition = ply:GetPos()
		end

		if not desiredPosition then return end
		
		local bgn_spawn_radius 
			= GetConVar('bgn_spawn_radius'):GetFloat()

		local bgn_spawn_radius_visibility 
			= GetConVar('bgn_spawn_radius_visibility'):GetFloat() ^ 2

		local bgn_spawn_radius_raytracing 
			= GetConVar('bgn_spawn_radius_raytracing'):GetFloat() ^ 2

		local bgn_spawn_block_radius
			= GetConVar('bgn_spawn_block_radius'):GetFloat() ^ 2

		local spawn_radius = bgn_spawn_radius
		local limit_pass = limit_pass or 10
		local current_pass = 0
		
		local thread = coroutine.create(function()
			local radius_positions = {}
		
			for _, node in ipairs(bgNPC:GetAllPointsInRadius(desiredPosition, spawn_radius)) do
				local walkNodes = node:GetLinks('walk')

				for _, walkNode in ipairs(walkNodes) do
					local nodePosition = walkNode:GetPos()

					if table.IHasValue(radius_positions, nodePosition) then
						goto skip_walk_nodes
					end

					for _, ply in ipairs(player.GetAll()) do
						local distance = nodePosition:DistToSqr(ply:GetPos())
						
						if distance <= bgn_spawn_block_radius then
							goto skip_walk_nodes
						end

						if distance < bgn_spawn_radius_visibility and bgNPC:PlayerIsViewVector(ply, nodePosition) then							
							if bgn_spawn_radius_raytracing == 0 then
								goto skip_walk_nodes
							end

							local tr = util.TraceLine({
								start = ply:EyePos(),
								endpos = nodePosition,
								filter = function(ent)
									if IsValid(ent) and ent ~= ply 
										and not ent:IsVehicle() and ent:IsWorld() 
										and not string.StartWith(ent:GetClass(), 'prop_')
									then
										return true
									end
								end
							})
		
							if not tr.Hit then
								goto skip_walk_nodes
							end
						end
					end

					table.insert(radius_positions, nodePosition)
					current_pass = current_pass + 1
					if current_pass == limit_pass then
						coroutine.yield()
						current_pass = 0
					end
					
					::skip_walk_nodes::
				end
			end

			if not GetConVar('bgn_enable'):GetBool() then
				return coroutine.yield()
			end

			if #radius_positions == 0 then
				return coroutine.yield()
			end
		
			return coroutine.yield(table.Random(radius_positions))
		end)

		hook.Add("Think", hook_name, function()
			if coroutine.status(thread) == 'dead' then
				hook.Remove("Think", hook_name)
				hooks_active[hook_name] = false
				return
			end

			local worked, nodePosition = coroutine.resume(thread)
			if nodePosition then
				action(nodePosition)
			end
		end)
	end

	function bgNPC:SpawnActor(npcType, desiredPosition)
		if player.GetCount() == 0 then return end

		local npcData = bgNPC.cfg.npcs_template[npcType]

		bgNPC:FindSpawnLocation(npcType, desiredPosition, nil, function(nodePosition)
			local is_many_classes = false
			local npc_class
			
			if istable(npcData.class) then
				npc_class = table.Random(npcData.class)
				is_many_classes = true
			else
				npc_class = npcData.class
			end
			
			if hook.Run('BGN_OnValidSpawnActor', npcData, npc_class, nodePosition) then
				return
			end

			local newNpcData, newNpcClass = hook.Run('BGN_OverrideSpawnData', 
				npcType, npcData, npc_class)

			if newNpcData then npcData = newNpcData end
			if newNpcClass then npc_class = newNpcClass end

			local npc = ents.Create(npc_class)
			npc:SetPos(nodePosition)
			
			--[[
				ATTENTION! Be careful, this hook is called before the NPC spawns. 
				If you give out a weapon or something similar, it will crash the game!
			--]]
			if hook.Run('BGN_PreSpawnActor', npc, npcType, npcData) then
				if IsValid(npc) then npc:Remove() end
				return
			end

			npc:Spawn()
			npc:Activate()
			npc:PhysWake()

			hook.Run('BGN_PostSpawnActor', npc, npcType, npcData)

			if npcData.models then
				local model

				if is_many_classes then
					if npcData.models[npc_class] then
						model = table.Random(npcData.models[npc_class])
					end
				else
					model = table.Random(npcData.models)
				end

				if model ~= nil and util.IsValidModel(model) then
					-- Backward compatibility with the old version of the config
					npcData.default_models = npcData.default_models or npcData.defaultModels

					if not npcData.default_models or (npcData.default_models and math.random(0, 10) <= 5) then
						if not hook.Run('BGN_PreSetActorModel', model, npc, npcType, npcData) then
							npc:SetModel(model)
						end
					end
				end
			end

			-- Backward compatibility with the old version of the config
			npcData.random_skin = npcData.random_skin or npcData.randomSkin

			if npcData.random_skin then
				local skin = math.random(0, npc:SkinCount())
				
				if not hook.Run('BGN_PreSetActorSkin', skin, npc, npcType, npcData) then
					npc:SetSkin(math.random(0, npc:SkinCount()))
				end
			end

			-- Backward compatibility with the old version of the config
			npcData.random_bodygroups = npcData.random_bodygroups or npcData.randomBodygroups

			if npcData.random_bodygroups then
				for _, bodygroup in ipairs(npc:GetBodyGroups()) do
					local id = bodygroup.id
					local value = math.random(0, npc:GetBodygroupCount(id))

					if not hook.Run('BGN_PreSetActorBodygroup', id, value, npc, npcType, npcData) then
						npc:SetBodygroup(id, value)
					end
				end
			end

			local actor = BGN_ACTOR:Instance(npc, npcType, npcData)
			bgNPC:AddNPC(actor)
			actor:RandomState()
			
			hook.Run('BGN_InitActor', actor)

			snet.EntityInvokeAll('bgn_add_actor_from_client', npc, npcType, actor.uid)
		end)
	end
end

function bgNPC:AddNPC(actor)
	local npc = actor:GetNPC()
	if table.IHasValue(self.npcs, npc) then return end

	table.insert(self.actors, actor)
	table.insert(self.npcs, npc)

	local type = actor:GetType()
	self.factors[type] = self.factors[type] or {}
	table.insert(self.factors[type], actor)

	self.fnpcs[type] = self.fnpcs[type] or {}
	table.insert(self.fnpcs[type], npc)
end

function bgNPC:RemoveNPC(npc)
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
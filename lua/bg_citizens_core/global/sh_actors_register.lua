if CLIENT then
	snet.RegisterCallback('bgn_add_actor_from_client', function(ply, npc, npcType, uid)
		if bgNPC:GetActor(npc) ~= nil then return end

		local actor = BGN_ACTOR:Instance(npc, npcType, bgNPC.cfg.npcs_template[npcType], uid)
		bgNPC:AddNPC(actor)
	end)
else
	local hooks_active = {}
	function bgNPC:SpawnActor(type, desiredPosition)
		if player.GetCount() == 0 then return end

		local hook_name = 'BGN_SpawnerThread_' .. type
		if hooks_active[hook_name] then return end

		local bgn_spawn_radius 
			= GetConVar('bgn_spawn_radius'):GetFloat()
	
		local bgn_spawn_radius_visibility 
			= GetConVar('bgn_spawn_radius_visibility'):GetFloat() ^ 2
	
		local bgn_spawn_radius_raytracing 
			= GetConVar('bgn_spawn_radius_raytracing'):GetFloat() ^ 2
	
		local bgn_spawn_block_radius
			= GetConVar('bgn_spawn_block_radius'):GetFloat() ^ 2

		local data = bgNPC.cfg.npcs_template[type]
		if data.validator ~= nil then
			local result = data.validator(data, type)
			if result ~= nil and not result then
				return
			end
		end

		local spawn_delayer = bgNPC.respawn_actors_delay[type]
		if data.respawn_delay ~= nil and spawn_delayer ~= nil and spawn_delayer.count ~= 0 then
			if spawn_delayer.time < CurTime() then
				bgNPC.respawn_actors_delay[type].time = CurTime() + data.respawn_delay
				bgNPC.respawn_actors_delay[type].count = spawn_delayer.count - 1
			else
				return
			end
		end

		local ply = table.Random(player.GetAll())
		
		if IsValid(ply) then
			local hook_name = 'BGN_SpawnerThread_' .. type
			hooks_active[hook_name] = true

			local _center = desiredPosition or ply:GetPos()
			local _radius = bgn_spawn_radius ^ 2
			local _max_pass = 3
			local _pass = 0
			local function CoroutineGetAllPointsInRadius()
				local radius_positions = {}
			
				for _, v in ipairs(bgNPC.points) do
					if v.pos:DistToSqr(_center) <= _radius then
						table.insert(radius_positions, v)
						_pass = _pass + 1
						if _pass == _max_pass then
							coroutine.yield()
							_pass = 0
						end
					end
				end

				if not GetConVar('bgn_enable'):GetBool() then
					return coroutine.yield()
				end

				if #radius_positions == 0 then
					return coroutine.yield()
				end
			
				local point = table.Random(radius_positions)
				return coroutine.yield(point.pos)
			end
			
			local thread = coroutine.create(CoroutineGetAllPointsInRadius)
			hook.Add("Think", hook_name, function()
				if coroutine.status(thread) == 'dead' then
					hook.Remove("Think", hook_name)
					hooks_active[hook_name] = false
					return
				end

				local worked, result = coroutine.resume(thread)
				if result ~= nil and isvector(result) then                   
					local pos = result
				
					for _, ent in ipairs(ents.FindInSphere(pos, 100)) do
						if IsValid(ent) and (ent:IsNPC() or ent:IsPlayer()) then
							return
						end
					end
			
					for _, ply in ipairs(player.GetAll()) do
						local distance = pos:DistToSqr(ply:GetPos())
						if distance < bgn_spawn_radius_visibility 
							and bgNPC:PlayerIsViewVector(ply, pos)
						then
							if distance <= bgn_spawn_block_radius then
								return
							end
							
							if bgn_spawn_radius_raytracing ~= 0 then
								local tr = util.TraceLine({
									start = ply:EyePos(),
									endpos = pos,
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
									return
								end
							else
								return
							end
						end
					end
			
					local is_many_classes = false
					local npc_class
					
					if istable(data.class) then
						npc_class = table.Random(data.class)
						is_many_classes = true
					else
						npc_class = data.class
					end
					
					if hook.Run('BGN_OnValidSpawnActor', data, npc_class, pos) then
						return
					end

					local npc = ents.Create(npc_class)
					npc:SetPos(pos)
					-- npc:SetSpawnEffect(true)
					
					--[[
						ATTENTION! Be careful, this hook is called before the NPC spawns. 
						If you give out a weapon or something similar, it will crash the game!
					--]]
					if hook.Run('BGN_PreSpawnActor', npc, type, data) then
						if IsValid(npc) then npc:Remove() end
						return
					end
			
					npc:Spawn()
					npc:Activate()
					npc:PhysWake()

					hook.Run('BGN_PostSpawnActor', npc, type, data)
			
					if data.models then
						local model

						if is_many_classes then
							if data.models[npc_class] then
								model = table.Random(data.models[npc_class])
							end
						else
							model = table.Random(data.models)
						end

						if model ~= nil and util.IsValidModel(model) then							
							if not data.defaultModels or (data.defaultModels and math.random(0, 10) <= 5) then
								if not hook.Run('BGN_PreSetActorModel', model, npc, type, data) then
									npc:SetModel(model)
								end
							end
						end
					end

					if data.randomSkin then
						local skin = math.random(0, npc:SkinCount())
						
						if not hook.Run('BGN_PreSetActorSkin', skin, npc, type, data) then
							npc:SetSkin(math.random(0, npc:SkinCount()))
						end
					end

					if data.randomBodygroups then
						for _, bodygroup in ipairs(npc:GetBodyGroups()) do
							local id = bodygroup.id
							local value = math.random(0, npc:GetBodygroupCount(id))

							if not hook.Run('BGN_PreSetActorBodygroup', id, value, npc, type, data) then
								npc:SetBodygroup(id, value)
							end
						end
					end
			
					local actor = BGN_ACTOR:Instance(npc, type, data)
					bgNPC:AddNPC(actor)
					actor:RandomState()
					
					hook.Run('BGN_InitActor', actor)

					snet.EntityInvokeAll('bgn_add_actor_from_client', npc, type, actor.uid)
				end
			end)
		end
	end
end

function bgNPC:AddNPC(actor)
	local npc = actor:GetNPC()
	if table.HasValue(self.npcs, npc) then return end

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

function bgNPC:ClearRemovedNPCs()
	for i = #self.actors, 1, -1 do
		local npc = self.actors[i]:GetNPC()
		if not IsValid(npc) or npc:Health() <= 0 then
			table.remove(self.actors, i)
		end
	end

	for i = #self.npcs, 1, -1 do
		local npc = self.npcs[i]
		if not IsValid(npc) or npc:Health() <= 0 then
			table.remove(self.npcs, i)
		end
	end

	for key, data in pairs(self.factors) do
		for i = #data, 1, -1 do
			local npc = data[i]:GetNPC()
			if not IsValid(npc) or npc:Health() <= 0 then
				table.remove(self.factors[key], i)
			end
		end
	end

	for key, data in pairs(self.fnpcs) do
		for i = #data, 1, -1 do
			local npc = data[i]
			if not IsValid(npc) or npc:Health() <= 0 then
				table.remove(self.fnpcs[key], i)
			end
		end
	end
end
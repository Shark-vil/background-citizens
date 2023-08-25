local bgNPC = bgNPC
local util_IsInWorld = util.IsInWorld
local string_StartWith = string.StartWith
-- local coroutine_yield = coroutine.yield
local ents_FindInSphere = ents.FindInSphere
local ents_FindInBox = ents.FindInBox
local IsValid = IsValid
local util_TraceLine = util.TraceLine
local table_shuffle = table.shuffle
local GetConVar = GetConVar
local Vector = Vector
local table_RandomBySeq = table.RandomBySeq
local player_GetHumans = player.GetHumans
local math_random = math.random
local math_Clamp = math.Clamp
local hook_Run = hook.Run
local istable = istable
local isstring = isstring
local pairs = pairs
local ipairs = ipairs
local slib_chance = slib.chance
-- local assert = assert
-- local FrameTime = FrameTime
local coroutine_yield = coroutine.yield
--

local function IsNotBlockSpawnPosition(node_position, all_players, spawn_radius, block_radius, target_entity)
	local entities = ents_FindInSphere(node_position, 150)
	for e = 1, #entities do
		local ent = entities[e]
		if IsValid(ent) and (ent:IsNPC() or ent:IsNextBot() or string_StartWith(ent:GetClass(), 'prop_')) then
			return false
		end
	end

	for p = 1, #all_players do
		local ply = all_players[p]
		local distance = node_position:DistToSqr(ply:GetPos())

		if distance <= block_radius then
			return false
		end

		if IsValid(target_entity) and ply:slibIsTraceEntity(target_entity, spawn_radius, true) then
			return false
		end

		if bgNPC:PlayerIsViewVector(ply, node_position) then
			local tr = util_TraceLine({
				start = ply:EyePos(),
				endpos = node_position,
				filter = function(ent)
					if IsValid(ent)
						and ent ~= ply
						and not ent:IsVehicle()
						and ent:IsWorld()
						and not string_StartWith(ent:GetClass(), 'prop_')
					then
						return true
					end
				end
			})

			if not tr.Hit or not util_IsInWorld(node_position) then
				return false
			end
		end
	end

	return true
end

local function FindSpawnLocationProcess(all_players, settings, is_async)
	local spawn_radius = GetConVar('bgn_spawn_radius'):GetFloat()
	local radius_visibility = GetConVar('bgn_spawn_radius_visibility'):GetFloat()
	local block_radius = GetConVar('bgn_spawn_block_radius'):GetFloat() ^ 2
	local desired_position = settings.position
	local teleport_radius = settings.radius or spawn_radius
	local target_entity = settings.target
	local pass_current = 0
	local AsyncYield = function()
		pass_current = pass_current + 1
		if pass_current >= 1 / slib.deltaTime then
			pass_current = 0
			coroutine_yield()
		end
	end

	if teleport_radius and teleport_radius <= block_radius then
		teleport_radius = radius_visibility
	end

	local points = bgNPC:GetAllPointsInRadius(desired_position, teleport_radius, 'walk')
	local points_count = #points
	local nodePosition

	if points_count ~= 0 then
		if is_async then AsyncYield() end
		points = table_shuffle(points)
		if is_async then AsyncYield() end
	else
		spawn_radius = math_Clamp(spawn_radius, 0, 1000)
		block_radius = math_Clamp(block_radius, 0, spawn_radius)
		local dist_x = math_random(block_radius, spawn_radius)
		local dist_y = math_random(block_radius, spawn_radius)
		if slib_chance(50) then dist_x = -dist_x end
		if slib_chance(50) then dist_y = -dist_y end
		local new_pos = Vector(desired_position.x + dist_x, desired_position.y + dist_y, desired_position.z)
		if not util_IsInWorld(new_pos) then return end
		if bgNPC:VectorInWater(new_pos) then return end
		if not IsNotBlockSpawnPosition(new_pos, all_players, spawn_radius, block_radius, target_entity) then return end
		return new_pos
	end

	for i = 1, points_count do
		local walkNode = points[i]
		nodePosition = walkNode:GetPos()

		if bgNPC:VectorInWater(nodePosition) then
			nodePosition = nil
			continue
		end

		if is_async then AsyncYield() end

		if not IsNotBlockSpawnPosition(nodePosition, all_players, spawn_radius, block_radius, target_entity) then
			nodePosition = nil
			continue
		end

		if nodePosition then
			return nodePosition
		end
	end
end

function bgNPC:ActorIsStuck(actor)
	if not actor or not actor:IsAlive() or actor:InVehicle() then return false end
	local npc = actor:GetNPC()
	local min_vector = npc:LocalToWorld(npc:OBBMins())
	local max_vector = npc:LocalToWorld(npc:OBBMaxs())
	local entities = ents_FindInBox(min_vector, max_vector)
	for i = 1, #entities do
		local ent = entities[i]
		if IsValid(ent) and ent ~= npc then
			return true
		end
	end
	return false
end

function bgNPC:FindSpawnPosition(settings, is_async)
	settings = settings or {}

	local all_players = player_GetHumans()
	local desired_position = settings.position

	if not desired_position then
		local ply = table_RandomBySeq(all_players)
		desired_position = ply:GetPos()

		for _, area in pairs(bgNPC.SpawnArea) do
			local center = (area.startPoint + area.endPoint) / 2
			local radius = center:DistToSqr(area.startPoint) + 1000000
			if desired_position:DistToSqr(center) <= radius and slib_chance(80) then
				desired_position = center
				break
			end
		end
	end

	settings.position = desired_position
	if not settings.position then return end

	local isvector = isvector
	local nodePosition = FindSpawnLocationProcess(all_players, settings, is_async)
	if nodePosition and isvector(nodePosition) then
		return nodePosition
	-- elseif desired_position then
	-- 	local spawn_radius = GetConVar('bgn_spawn_radius'):GetFloat()
	-- 	spawn_radius = math.Clamp(spawn_radius, 0, 1000)

	-- 	local spawn_block_radius = GetConVar('bgn_spawn_block_radius'):GetFloat()
	-- 	spawn_block_radius = math.Clamp(spawn_block_radius, 0, spawn_radius)

	-- 	local dist_x = math.random(spawn_block_radius, spawn_radius)
	-- 	local dist_y = math.random(spawn_block_radius, spawn_radius)
	-- 	if slib.chance(50) then dist_x = -dist_x end
	-- 	if slib.chance(50) then dist_y = -dist_y end
	-- 	local new_pos = Vector(desired_position.x + dist_x, desired_position.y + dist_y, desired_position.z)
	-- 	if util.IsInWorld(new_pos) then
	-- 		local entities = ents.FindInSphere(new_pos, 250)
	-- 		local bad_spawn = false
	-- 		local valid_class = {
	-- 			'func_*',
	-- 			'env_*',
	-- 			'keyframe_*',
	-- 			'move_rope',
	-- 			'trigger_*',
	-- 		}
	-- 		for _, ent in ipairs(entities) do
	-- 			if not ent:IsWorld() then
	-- 				local ent_class = ent:GetClass()
	-- 				local has_skip = false
	-- 				for _, class in ipairs(valid_class) do
	-- 					if string.find(ent_class, class) then
	-- 						has_skip = true
	-- 						break
	-- 					end
	-- 				end
	-- 				if not has_skip then
	-- 					print(ent)
	-- 					bad_spawn = true
	-- 					break
	-- 				end
	-- 			end
	-- 		end
	-- 		if not bad_spawn then
	-- 			return new_pos
	-- 		end
	-- 	end
	end
end

function bgNPC:FindSpawnPositionAsync(settings)
	return self:FindSpawnPosition(settings, true)
end

do
	local random_models_storage = {}
	local player_GetCount = player.GetCount
	local table_HasValueBySeq = table.HasValueBySeq
	local list_Get = list.Get
	local table_insert = table.insert
	local util_IsValidModel = util.IsValidModel
	-- local math_random = math.random

	function bgNPC:SpawnActor(npc_type, desiredPosition, enableSpawnEffect)
		if player_GetCount() == 0 then return end
		if bgNPC:VectorInWater(desiredPosition) then return end

		local npc_data = bgNPC:GetActorConfig(npc_type)
		local is_many_classes = false
		local npc_class

		if istable(npc_data.class) then
			npc_class = table_RandomBySeq(npc_data.class)
			is_many_classes = true
		else
			npc_class = npc_data.class
		end

		if hook_Run('BGN_OnValidSpawnActor', npc_type, npc_data, npc_class, desiredPosition) then return end

		local new_npc_data, new_npc_class = hook_Run('BGN_OverrideSpawnData', npc_type, npc_data, npc_class)

		if new_npc_data then
			npc_data = new_npc_data
		end

		if new_npc_class then
			npc_class = new_npc_class
		end

		local npc = ents.Create(npc_class)
		if not IsValid(npc) then
			MsgN('[Background NPCs] ERROR: Actor with class - ' .. npc_class .. ' cannot be created!')
			return
		end
		npc:SetPos(desiredPosition)

		--[[
			ATTENTION! Be careful, this hook is called before the NPC spawns. 
			If you give out a weapon or something similar, it will crash the game!
		--]]
		if hook_Run('BGN_PreSpawnActor', npc, npc_type, npc_data, npc_class, desiredPosition) then
			if IsValid(npc) then npc:Remove() end
			npc = nil
			return
		end

		npc:SetSpawnEffect(enableSpawnEffect or false)
		-- -- ------------------------------------------------------------------
		-- -- Unsopported iNPC - Artifical Intelligence Module (Improved NPC AI)
		-- -- https://steamcommunity.com/sharedfiles/filedetails/?id=632126111
		-- npc.inpcIgnore = true
		-- -- ------------------------------------------------------------------
		npc:Spawn()
		npc:SetOwner(game.GetWorld())
		npc:Activate()
		npc:PhysWake()

		-- if npc.DropToFloor then npc:DropToFloor() end

		hook_Run('BGN_PostSpawnActor', npc, npc_type, npc_data)

		local skip_set_model = false
		local npcs_list = nil

		do
			local actorData = bgNPC.cfg.actors[npc_type]
			npcs_list = list_Get('NPC')

			for npcClass, actorTypesList in pairs(bgNPC.SpawnMenu.Creator['NPC']) do
				for _, actorType in ipairs(actorTypesList) do
					if actorType == npc_type and table_HasValueBySeq(actorData.class, npcClass) then
						local listData = npcs_list[npcClass]
						if not listData or not listData.Model then
							skip_set_model = true
							break
						end
					end
				end
			end
		end

		if npcs_list and (npc_data.random_model or GetConVar('bgn_all_models_random'):GetBool()) then
			if not random_models_storage[npc_class] then
				random_models_storage[npc_class] = {}

				for k, v in pairs(npcs_list) do
					if v.Model and isstring(v.Model) and v.Class == npc_class then
						table_insert(random_models_storage[npc_class], v)
					end
				end
			end

			local models = random_models_storage[npc_class]
			if models and #models ~= 0 then
				local model_info = table_RandomBySeq(models)
				if util_IsValidModel(model_info.Model) then
					npc:SetModel(model_info.Model)

					if model_info.KeyValues and istable(model_info.KeyValues) then
						for key, value in pairs(model_info.KeyValues) do
							npc:SetKeyValue(key, value)
						end
					end
				end
			end
		elseif not skip_set_model and npc_data.models and istable(npc_data.models) then
			local model

			if is_many_classes and npc_data.models[npc_class] then
				model = table_RandomBySeq(npc_data.models[npc_class])
			elseif #npc_data.models ~= 0 then
				model = table_RandomBySeq(npc_data.models)
			end

			if model and util_IsValidModel(model) then
				-- Backward compatibility with the old version of the config
				local default_models = npc_data.default_models or npc_data.defaultModels

				if (not default_models or slib_chance(80)) and not hook_Run('BGN_PreSetActorModel', model, npc, npc_type, npc_data) then
					npc:SetModel(model)
				end
			end
		end

		do
			-- Backward compatibility with the old version of the config
			local random_skin = npc_data.random_skin or npc_data.randomSkin

			if random_skin then
				local skinNumber = math_random(0, npc:SkinCount())

				if not hook_Run('BGN_PreSetActorSkin', skinNumber, npc, npc_type, npc_data) then
					npc:SetSkin(math_random(0, npc:SkinCount()))
				end
			end
		end

		do
			-- Backward compatibility with the old version of the config
			local random_bodygroups = npc_data.random_bodygroups or npc_data.randomBodygroups

			if random_bodygroups then
				for _, bodygroup in ipairs(npc:GetBodyGroups()) do
					local id = bodygroup.id
					local value = math_random(0, npc:GetBodygroupCount(id))

					if not hook_Run('BGN_PreSetActorBodygroup', id, value, npc, npc_type, npc_data) then
						npc:SetBodygroup(id, value)
					end
				end
			end
		end

		return BGN_ACTOR:Instance(npc, npc_type)
	end
end
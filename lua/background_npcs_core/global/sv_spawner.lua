local util_IsInWorld = util.IsInWorld
local string_StartWith = string.StartWith
-- local coroutine_yield = coroutine.yield
local ents_FindInSphere = ents.FindInSphere
local ents_FindInBox = ents.FindInBox
local IsValid = IsValid
local util_TraceLine = util.TraceLine
local table_shuffle = table.shuffle
local GetConVar = GetConVar
local table_RandomBySeq = table.RandomBySeq
local player_GetHumans = player.GetHumans
local hook_Run = hook.Run
local istable = istable
local isstring = isstring
local pairs = pairs
local ipairs = ipairs
local slib_chance = slib.chance
local CONTENTS_WATER = CONTENTS_WATER
local bit_band = bit.band
local util_PointContents = util.PointContents
local assert = assert
-- local FrameTime = FrameTime
-- local type = type
--

local function HasBlockFoundSpawnPosition(node_position, all_players, spawn_radius, block_radius, target_entity)
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

local function FindSpawnLocationProcess(all_players, settings, yield)
	local is_async = yield ~= nil
	local spawn_radius = GetConVar('bgn_spawn_radius'):GetFloat()
	local radius_visibility = GetConVar('bgn_spawn_radius_visibility'):GetFloat()
	local block_radius = GetConVar('bgn_spawn_block_radius'):GetFloat() ^ 2
	local desired_position = settings.position
	local teleport_radius = settings.radius or spawn_radius
	local target_entity = settings.target
	local pass_current = 0
	local AsyncYield = function()
		pass_current = pass_current + 1
		-- if pass_current >= 1 / FrameTime() then
		if pass_current >= 1 / slib.deltaTime then
			pass_current = 0
			yield()
		end
	end

	if teleport_radius and teleport_radius <= block_radius then
		teleport_radius = radius_visibility
	end

	local points = bgNPC:GetAllPointsInRadius(desired_position, teleport_radius, 'walk')
	local nodePosition

	if is_async then AsyncYield() end

	points = table_shuffle(points)

	if is_async then AsyncYield() end

	for i = 1, #points do
		local walkNode = points[i]
		nodePosition = walkNode:GetPos()

		if bit_band(util_PointContents(nodePosition), CONTENTS_WATER) == CONTENTS_WATER then
			nodePosition = nil
			continue
		end

		if is_async then AsyncYield() end

		if not HasBlockFoundSpawnPosition(nodePosition, all_players, spawn_radius, block_radius, target_entity, yield) then
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

function bgNPC:FindSpawnPosition(settings)
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
	local nodePosition = FindSpawnLocationProcess(all_players, settings, nil)
	if nodePosition and isvector(nodePosition) then
		return nodePosition
	end
end

function bgNPC:FindSpawnPositionAsync(process_name, settings, action)
	assert(isfunction(action), 'The variable type is not a function')

	local async_spawner_name = 'bgn_async_spawner_' .. process_name
	if async.Exists(async_spawner_name) then return end

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

	async.Add(async_spawner_name, function(yield, wait)
		slib.def({
			try = function()
				local nodePosition = FindSpawnLocationProcess(all_players, settings, yield)
				if nodePosition and isvector(nodePosition) then
					action(nodePosition)
				end
			end
		})
		return 'stop'
	end)
end

do
	local random_models_storage = {}
	local player_GetCount = player.GetCount
	local table_HasValueBySeq = table.HasValueBySeq
	local list_Get = list.Get
	local isbool = isbool
	local table_insert = table.insert
	local util_IsValidModel = util.IsValidModel
	local math_random = math.random

	function bgNPC:SpawnActor(npcType, desiredPosition, enableSpawnEffect)
		if player_GetCount() == 0 then return end
		if bgNPC:VectorInWater(desiredPosition) then return end

		local npcData = bgNPC:GetActorConfig(npcType)
		local is_many_classes = false
		local npc_class

		if istable(npcData.class) then
			npc_class = table_RandomBySeq(npcData.class)
			is_many_classes = true
		else
			npc_class = npcData.class
		end

		if hook_Run('BGN_OnValidSpawnActor', npcType, npcData, npc_class, desiredPosition) then return end

		local newNpcData, newNpcClass = hook_Run('BGN_OverrideSpawnData', npcType, npcData, npc_class)

		if newNpcData then
			npcData = newNpcData
		end

		if newNpcClass then
			npc_class = newNpcClass
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
		if hook_Run('BGN_PreSpawnActor', npc, npcType, npcData) then
			if IsValid(npc) then npc:Remove() end
			return
		end

		npc:SetSpawnEffect(enableSpawnEffect or false)
		npc:Spawn()
		npc:SetOwner(game.GetWorld())
		npc:Activate()
		npc:PhysWake()

		-- if npc.DropToFloor then npc:DropToFloor() end

		hook_Run('BGN_PostSpawnActor', npc, npcType, npcData)

		local skipSetModel = false
		local npcs_list = nil

		do
			local actorData = bgNPC.cfg.actors[npcType]
			npcs_list = list_Get('NPC')

			for npcClass, actorTypesList in pairs(bgNPC.SpawnMenu.Creator['NPC']) do
				for _, actorType in ipairs(actorTypesList) do
					if actorType == npcType and table_HasValueBySeq(actorData.class, npcClass) then
						local listData = npcs_list[npcClass]
						if not listData or not listData.Model then
							skipSetModel = true
							break
						end
					end
				end
			end
		end

		if npcs_list and npcData.random_model or GetConVar('bgn_all_models_random'):GetBool() then
			if not random_models_storage[npc_class] then
				random_models_storage[npc_class] = {}

				for k, v in pairs(npcs_list) do
					if v.Model and isstring(v.Model) and v.Class == npc_class then
						table_insert(random_models_storage[npc_class], v.Model)
					end
				end
			end

			local models = random_models_storage[npc_class]
			if models and #models ~= 0 then
				npc:SetModel(table_RandomBySeq(models))
			end
		elseif not skipSetModel and npcData.models and istable(npcData.models) then
			local model

			if is_many_classes and npcData.models[npc_class] then
				model = table_RandomBySeq(npcData.models[npc_class])
			elseif #npcData.models ~= 0 then
				model = table_RandomBySeq(npcData.models)
			end

			if model and util_IsValidModel(model) then
				-- Backward compatibility with the old version of the config
				npcData.default_models = npcData.default_models or npcData.defaultModels

				if (not npcData.default_models or (npcData.default_models and slib_chance(80)))
					and not hook_Run('BGN_PreSetActorModel', model, npc, npcType, npcData)
				then
					npc:SetModel(model)
				end
			end
		end

		-- Backward compatibility with the old version of the config
		npcData.random_skin = npcData.random_skin or npcData.randomSkin

		if npcData.random_skin and isbool(npcData.random_skin) then
			local skinNumber = math_random(0, npc:SkinCount())

			if not hook_Run('BGN_PreSetActorSkin', skinNumber, npc, npcType, npcData) then
				npc:SetSkin(math_random(0, npc:SkinCount()))
			end
		end

		-- Backward compatibility with the old version of the config
		npcData.random_bodygroups = npcData.random_bodygroups or npcData.randomBodygroups

		if npcData.random_bodygroups and isbool(npcData.random_bodygroups) then
			for _, bodygroup in ipairs(npc:GetBodyGroups()) do
				local id = bodygroup.id
				local value = math_random(0, npc:GetBodygroupCount(id))

				if not hook_Run('BGN_PreSetActorBodygroup', id, value, npc, npcType, npcData) then
					npc:SetBodygroup(id, value)
				end
			end
		end

		local actor = BGN_ACTOR:Instance(npc, npcType)
		actor:RandomState()
		-- hook_Run('BGN_InitActor', actor)
		-- actor:RemoveAllEnemies()
		-- actor:RemoveAllTargets()
		-- hook_Run('BGN_PostInitActor', actor)

		return actor
	end
end
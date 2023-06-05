local cvar_bgn_generator_restict = GetConVar('bgn_enable_dynamic_nodes_only_when_mesh_not_exists')
local cvar_bgn_dynamic_nodes = GetConVar('bgn_dynamic_nodes')
local cvar_bgn_dynamic_nodes_type = GetConVar('bgn_dynamic_nodes_type')
local cvar_bgn_spawn_radius = GetConVar('bgn_spawn_radius')
local cvar_bgn_runtime_generator_grid_offset = GetConVar('bgn_runtime_generator_grid_offset')
local table_Combine = table.Combine
-- local table_shuffle = table.shuffle
local player_GetAll = player.GetAll
local table_remove = table.remove
local map_name = game.GetMap()
local math_random = math.random
local util_IsInWorld = util.IsInWorld
local util_TraceLine = util.TraceLine
local math_Clamp = math.Clamp
local file_Exists = file.Exists
local Vector = Vector
local bit_band = bit.band
local util_PointContents = util.PointContents
local CONTENTS_WATER = CONTENTS_WATER
-- local math_floor = math.floor
-- local math_modf = math.modf
-- local FrameTime = FrameTime
local add_z_axis = Vector(0, 0, 20)
local cell_size = 200
local add_endpos_trace_vector = Vector(0, 0, 1000)
local chunks = {}
local map_points = {}
local points_count = 0
local current_pass = 0
local coroutine_yield = coroutine.yield
-- local MAP_CHUNKS = slib.Instance('Chunks', { chunk_size = 1000 })
-- MAP_CHUNKS:SetConditionChunkTouchesTheWorld()

local MAP_CHUNKS = BGN_NODE:GetChunkController()
print(MAP_CHUNKS:ChunksCount())

local trace_filter = function(ent)
	if ent:IsWorld() or ent:GetClass() == 'infmap_terrain_collider' then
		return true
	end
end

local function PassYield()
	current_pass = current_pass + 1
	if current_pass >= 1 / slib.deltaTime then
		current_pass = 0
		coroutine_yield()
	end
end

local function GetChunkId(pos)
	local chunk = MAP_CHUNKS:GetChunkByVectorAsync(pos, true)
	-- local chunk = MAP_CHUNKS:GetChunkByVectorAsync(pos)
	if not chunk then return end
	return chunk.index
end

local function MovementMeshExists()
	if file_Exists('background_npcs/nodes/' .. map_name .. '.dat', 'DATA') then
		return true
	elseif file_Exists('background_npcs/nodes/' .. map_name .. '.json', 'DATA') then
		return true
	end
	return false
end

local function ChunkHasFull(point_position)
	-- local max_points = 40
	local min_distance_between_points = 150 ^ 2
	local nodes_in_chunk = BGN_NODE:GetChunkNodes(point_position)
	if nodes_in_chunk then
		for i = 1, #nodes_in_chunk do
			local node = nodes_in_chunk[i]
			if node and node:GetPos():DistToSqr(point_position) <= min_distance_between_points then
				return true
			end
		end
	end

	-- if BGN_NODE:GetChunkNodesCount(point_position) + 1 >= max_points then return end

	-- local point_chunk_id = GetChunkId(point_position)
	-- if not point_chunk_id then return true end

	-- local max_points = 18

	-- if cvar_bgn_dynamic_nodes_type:GetString() ~= 'grid' then
	-- 	max_points = 16
	-- end

	-- if chunks[point_chunk_id] and chunks[point_chunk_id] >= max_points then
	-- 	return true
	-- end

	-- chunks[point_chunk_id] = chunks[point_chunk_id] or 0
	-- chunks[point_chunk_id] = chunks[point_chunk_id] + 1

	return false
end

-- local function UpdateChunkPointsCount(point_position)
-- 	local point_chunk_id = GetChunkId(point_position)
-- 	if not point_chunk_id then return end

-- 	chunks[point_chunk_id] = chunks[point_chunk_id] or 0
-- 	chunks[point_chunk_id] = chunks[point_chunk_id] + 1
-- end

timer.Create('bgn_chunk_checker', .25, 0, function()
	for _, ply in ipairs(player.GetAll()) do
		local chunk = MAP_CHUNKS:GetChunkByEntity(ply)
		if chunk then
			MAP_CHUNKS:ChunkDebugOverlay(chunk, nil, .25)
		end
	end
end)

async.AddDedic('bgNPC_MovementMapDynamicGenerator', function(yield, wait)
	while true do
		wait(1)

		local restict = cvar_bgn_generator_restict:GetBool()
		local enabled = cvar_bgn_dynamic_nodes:GetBool()

		if not enabled or (restict and MovementMeshExists()) then
			if map_points and #map_points ~= 0 then
				map_points = nil
			end
			if chunks and #chunks ~= 0 then
				chunks = nil
			end
			if points_count ~= 0 then
				points_count = 0
			end
		else
			if MAP_CHUNKS:ChunksCount() == 0 then
				MAP_CHUNKS:MakeChunksAsync()
				print('Chunks count:', MAP_CHUNKS:ChunksCount())
			end
			map_points = {}
			-- if not map_points then map_points = {} end
			if not chunks then chunks = {} end

			print('Start generate nodes...')

			local expensive_generator = cvar_bgn_dynamic_nodes_type:GetString() == 'grid'
			-- local radius = cvar_bgn_spawn_radius:GetFloat()
			local radius = 1000 ^ 2
			-- local players = table_shuffle(player_GetAll())
			local players = player_GetAll()

			current_pass = 0
			cell_size = cvar_bgn_runtime_generator_grid_offset:GetInt()

			for i = #players, 1, -1 do
				local ply = players[i]
				if not ply or not ply:Alive() then
					table_remove(players, i)
				end
				PassYield()
			end

			yield()

			if not expensive_generator then
				-- for player_index = 1, math_Clamp(#players, 0, 4) do
				for player_index = 1, #players do
					local ply = players[player_index]
					if not ply then continue end

					local center = ply:LocalToWorld(ply:OBBCenter())
					local current_radius_randomize = cell_size
					local z = center.z + 50

					for i = 1, radius do
						current_radius_randomize = math_Clamp(current_radius_randomize, 0, radius)

						local x = center.x + math_random(-radius, radius)
						local y = center.y + math_random(-radius, radius)
						local start_point_vector = Vector(x, y, z)
						local tr = util_TraceLine({
							start = start_point_vector,
							endpos = start_point_vector - add_endpos_trace_vector,
							filter = trace_filter
						})

						if not tr.Hit then
							PassYield()
							continue
						end

						local new_point_position = tr.HitPos + add_z_axis
						if bit_band(util_PointContents(new_point_position), CONTENTS_WATER) == CONTENTS_WATER then
							continue
						end

						if not util_IsInWorld(new_point_position) or ChunkHasFull(new_point_position) then
							-- PassYield()
							continue
						end

						points_count = points_count + 1
						map_points[points_count] = BGN_NODE:Instance(new_point_position)

						-- UpdateChunkPointsCount(new_point_position)
						PassYield()

						current_radius_randomize = current_radius_randomize + cell_size
					end

					PassYield()
				end
			else
				local generator_iterations = 0
				local calc_iterations = true
				local sqr_radius = radius ^ 2
				local new_map_points_x = {}
				local new_points_count_x = 0
				local new_map_points_y = {}
				local new_points_count_y = 0

				for player_index = 1, #players do
					local ply = players[player_index]
					if not ply then continue end

					local center = ply:LocalToWorld(ply:OBBCenter())
					local x_offset = 0
					local y = center.y
					local z = center.z + 50
					local start_point_vector = Vector(center.x, y, z)

					while start_point_vector:DistToSqr(center) <= sqr_radius do
						if calc_iterations then
							generator_iterations = generator_iterations + 1
						end

						for k = 1, 2 do
							local x = k == 1 and center.x + x_offset or center.x - x_offset
							start_point_vector.x = x

							local different_start_point = start_point_vector + Vector(0, 0, math_random(0, 100))
							if not util_IsInWorld(different_start_point) then
								different_start_point = start_point_vector
							end

							if not util_IsInWorld(different_start_point) then
								-- PassYield()
								continue
							end

							local tr = util_TraceLine({
								start = different_start_point,
								endpos = different_start_point - add_endpos_trace_vector,
								filter = trace_filter
							})

							if not tr.Hit then
								PassYield()
								continue
							end

							local new_point_position = tr.HitPos + add_z_axis
							if bit_band(util_PointContents(new_point_position), CONTENTS_WATER) == CONTENTS_WATER then
								continue
							end

							if ChunkHasFull(new_point_position) then
								-- PassYield()
								continue
							end

							new_points_count_x = new_points_count_x + 1
							new_map_points_x[new_points_count_x] = BGN_NODE:Instance(new_point_position)

							-- UpdateChunkPointsCount(new_point_position)
							PassYield()
						end

						x_offset = x_offset + cell_size
					end

					calc_iterations = false
					PassYield()
				end

				-- local y_axis_points = {}
				-- local y_points_count = 0

				for node_index = 1, new_points_count_x do
					local center = new_map_points_x[node_index]:GetPos()
					local y_offset = 0
					local x = center.x
					local z = center.z + 50
					local start_point_vector = Vector(x, 0, z)

					for i = 1, generator_iterations do
						for k = 1, 2 do
							local y = k == 1 and center.y + y_offset or center.y - y_offset
							start_point_vector.y = y

							local different_start_point = start_point_vector + Vector(0, 0, math_random(0, 100))
							if not util_IsInWorld(different_start_point) then
								different_start_point = start_point_vector
							end

							if not util_IsInWorld(different_start_point) then
								-- PassYield()
								continue
							end

							local tr = util_TraceLine({
								start = different_start_point,
								endpos = different_start_point - add_endpos_trace_vector,
								filter = trace_filter
							})

							if not tr.Hit then
								PassYield()
								continue
							end

							local new_point_position = tr.HitPos + add_z_axis
							if bit_band(util_PointContents(new_point_position), CONTENTS_WATER) == CONTENTS_WATER then
								continue
							end

							if ChunkHasFull(new_point_position) then
								-- PassYield()
								continue
							end

							-- y_points_count = y_points_count + 1
							-- y_axis_points[y_points_count] = BGN_NODE:Instance(new_point_position)

							new_points_count_y = new_points_count_y + 1
							new_map_points_y[new_points_count_y] = BGN_NODE:Instance(new_point_position)

							-- UpdateChunkPointsCount(new_point_position)
							PassYield()
						end

						y_offset = y_offset + cell_size
					end
				end

				-- local new_map_points = table_Combine(new_map_points_x, new_map_points_y)
				-- map_points = table_Combine(map_points, new_map_points)

				map_points = table_Combine(map_points, new_map_points_x, new_map_points_y)
				points_count = points_count + new_points_count_x + new_points_count_y

				-- map_points = table_Combine(map_points, new_map_points)
				-- points_count = points_count + new_points_count
			end

			local custom_current_pass = 0
			local main_map_nodes = BGN_NODE:GetMap()

			print('Nodes generate links')

			for point_index = 1, points_count do
				local node = map_points[point_index]
				if not node then continue end

				-- Setting up links between generation nodes
				for another_point_index = 1, points_count do
					local anotherNode = map_points[another_point_index]
					if not anotherNode or anotherNode == node then continue end

					local pos = anotherNode:GetPos()
					if node:CheckDistanceLimitToNode(pos)
						and not anotherNode:HasParent(node)
						and node:CheckHeightLimitToNode(pos)
						and node:CheckTraceSuccessToNode(pos)
					then
						anotherNode:AddParentNode(node)
						anotherNode:AddLink(node, 'walk')
						PassYield()
					end

					custom_current_pass = custom_current_pass + 1
					-- if custom_current_pass >= 2500 then
					-- 	custom_current_pass = 0
					-- 	yield()
					-- end

					if custom_current_pass >= 1 / slib.deltaTime then
						custom_current_pass = 0
						yield()
					end
				end

				-- Setting up links between existing map nodes
				for another_point_index = 1, #main_map_nodes do
					local anotherNode = main_map_nodes[another_point_index]
					if not anotherNode then continue end

					local pos = anotherNode:GetPos()
					if node:CheckDistanceLimitToNode(pos)
						and not anotherNode:HasParent(node)
						and node:CheckHeightLimitToNode(pos)
						and node:CheckTraceSuccessToNode(pos)
					then
						anotherNode:AddParentNode(node)
						anotherNode:AddLink(node, 'walk')
						PassYield()
					end

					custom_current_pass = custom_current_pass + 1
					-- if custom_current_pass >= 2500 then
					-- 	custom_current_pass = 0
					-- 	yield()
					-- end

					if custom_current_pass >= 1 / slib.deltaTime then
						custom_current_pass = 0
						yield()
					end
				end

				-- print(point_index, ' / ', points_count)

				-- PassYield()
			end

			-- player.GetAll()[1]:ChatPrint('New mesh generated' .. ' ' .. tostring(CurTime()))

			print('Nodes map expand')

			BGN_NODE:ExpandMap(map_points)

			print('Nodes map generate complete')
		end
	end
end)
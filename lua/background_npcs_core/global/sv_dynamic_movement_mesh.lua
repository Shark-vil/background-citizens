async.AddDedic('bgNPC_MovementMapDynamicGenerator', function(yield, wait)
	local cvar_bgn_generator_restict = GetConVar('bgn_enable_dynamic_nodes_only_when_mesh_not_exists')
	local cvar_bgn_dynamic_nodes = GetConVar('bgn_dynamic_nodes')
	local cvar_bgn_dynamic_nodes_type = GetConVar('bgn_dynamic_nodes_type')
	local cvar_bgn_spawn_radius = GetConVar('bgn_spawn_radius')
	local cvar_bgn_runtime_generator_grid_offset = GetConVar('bgn_runtime_generator_grid_offset')
	local cvar_bgn_dynamic_nodes_save_progress = GetConVar('bgn_dynamic_nodes_save_progress')
	local table_Combine = table.Combine
	local bit_band = bit.band
	local util_PointContents = util.PointContents
	local CONTENTS_WATER = CONTENTS_WATER
	local IsValid = IsValid
	local player_GetAll = player.GetAll
	local table_remove = table.remove
	local map_name = game.GetMap()
	local math_random = math.random
	local util_IsInWorld = util.IsInWorld
	local util_TraceLine = util.TraceLine
	local math_Clamp = math.Clamp
	local file_Exists = file.Exists
	local Vector = Vector
	local add_z_axis = Vector(0, 0, 20)
	local cell_size = 200
	local sqrt_cell_size = cell_size ^ 2
	local add_endpos_trace_vector = Vector(0, 0, 1000)
	local map_points = {}
	local points_count = 0
	local current_pass = 0
	local is_infmap = slib.IsInfinityMap()
	if is_infmap then
		util_IsInWorld = function(...) return util.IsInWorld(...) end
		util_TraceLine = function(...) return util.TraceLine(...) end
		util_PointContents = function(...) return util.PointContents(...) end
	end
	local trace_filter = function(ent)
		if IsValid(ent) and (ent:IsWorld() or (is_infmap and select(1, ent:GetClass():find('collider')) ~= nil)) then
			return true
		end
	end

	local function PassYield()
		current_pass = current_pass + 1
		if current_pass >= 1 / slib.deltaTime then
			current_pass = 0
			yield()
		end
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
		if BGN_NODE:GetChunkNodesCountInRadius(point_position, cell_size) >= 1 then
			return true
		end

		PassYield()

		local point_chunk_id = BGN_NODE:GetChunkID(point_position)
		if point_chunk_id == -1 then
			return true
		end

		PassYield()

		for i = 1, points_count do
			local node = map_points[i]
			if node and node.chunk and node.chunk.index == point_chunk_id and node:GetPos():DistToSqr(point_position) <= sqrt_cell_size then
				return true
			end
			PassYield()
		end

		return false
	end

	while true do
		local restict = cvar_bgn_generator_restict:GetBool()
		local enabled = cvar_bgn_dynamic_nodes:GetBool()

		if not enabled or (restict and MovementMeshExists()) or not IsValid(BGN_NODE:GetChunkManager()) then
			wait(1)
		else
			map_points = {}
			points_count = 0
			local is_dynamic_nodes_save = cvar_bgn_dynamic_nodes_save_progress:GetBool()
			local expensive_generator = cvar_bgn_dynamic_nodes_type:GetString() == 'grid'
			local radius = cvar_bgn_spawn_radius:GetFloat()
			local players = player_GetAll()
			current_pass = 0
			cell_size = cvar_bgn_runtime_generator_grid_offset:GetInt()
			sqrt_cell_size = cell_size ^ 2

			for i = #players, 1, -1 do
				local ply = players[i]
				if not ply or not ply:Alive() then
					table_remove(players, i)
				end
				PassYield()
			end

			yield()

			-- print('Start generate new nodes...')

			if not expensive_generator then
				for player_index = 1, #players do
					local ply = players[player_index]
					if not ply then continue end

					local center = ply:LocalToWorld(ply:OBBCenter())
					local current_radius_randomize = cell_size
					local z = center.z + 100

					for i = 1, 1000 do
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
							PassYield()
							continue
						end

						if not util_IsInWorld(new_point_position) or ChunkHasFull(new_point_position) then
							PassYield()
							continue
						end

						local node = BGN_NODE:Instance(new_point_position)
						if is_dynamic_nodes_save then
							node.single_check = true
						end

						points_count = points_count + 1
						map_points[points_count] = node

						PassYield()

						current_radius_randomize = current_radius_randomize + cell_size
					end

					PassYield()
				end
			else
				local generator_iterations = 0
				local calc_iterations = true
				local sqr_radius = radius ^ 2

				for player_index = 1, #players do
					local ply = players[player_index]
					if not ply then continue end

					local center = ply:LocalToWorld(ply:OBBCenter())
					local x_offset = 0
					local start_point_vector = center + Vector(0, 0, 100)

					while start_point_vector:DistToSqr(center) <= sqr_radius do
						if calc_iterations then
							generator_iterations = generator_iterations + 1
						end

						for k = 1, 2 do
							local x = k == 1 and center.x + x_offset or center.x - x_offset
							start_point_vector.x = x

							local different_start_point = start_point_vector
							if not util_IsInWorld(different_start_point) then
								PassYield()
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
								PassYield()
								continue
							end

							if ChunkHasFull(new_point_position) then
								PassYield()
								continue
							end

							points_count = points_count + 1

							local new_node = BGN_NODE:Instance(new_point_position)
							map_points[points_count] = new_node

							PassYield()
						end

						x_offset = x_offset + cell_size
					end

					calc_iterations = false
					PassYield()
				end

				local y_axis_points = {}
				local y_points_count = 0

				for node_index = 1, points_count do
					local node = map_points[node_index]
					if is_dynamic_nodes_save and node_index < points_count - 1 then
						node.single_check = true
					end

					local center = node:GetPos()
					local y_offset = 0
					local start_point_vector = Vector(center.x, 0, center.z) + Vector(0, 0, 100)

					for i = 1, generator_iterations do
						for k = 1, 2 do
							local y = k == 1 and center.y + y_offset or center.y - y_offset
							start_point_vector.y = y

							local different_start_point = start_point_vector
							if not util_IsInWorld(different_start_point) then
								PassYield()
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
								PassYield()
								continue
							end

							if ChunkHasFull(new_point_position) then
								PassYield()
								continue
							end

							local new_node = BGN_NODE:Instance(new_point_position)
							if is_dynamic_nodes_save and i < generator_iterations - 1 then
								new_node.single_check = true
							end

							y_points_count = y_points_count + 1
							y_axis_points[y_points_count] = new_node

							PassYield()
						end

						y_offset = y_offset + cell_size
					end
				end

				map_points = table_Combine(map_points, y_axis_points)
				points_count = #map_points
			end

			if cvar_bgn_dynamic_nodes_save_progress:GetBool() then
				BGN_NODE:ExpandMap(map_points)
			else
				BGN_NODE:SetMap(map_points)
			end

			yield()

			if cvar_bgn_dynamic_nodes_save_progress:GetBool() then
				BGN_NODE:AutoLinkAsync()
				wait(1)
			else
				BGN_NODE:AutoLink()
				wait(5)
			end
		end
	end
end)
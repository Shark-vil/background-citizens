async.Add('bgNPC_MovementMapDynamicGenerator', function(yield, wait)
	local table_Combine = table.Combine
	local GetConVar = GetConVar
	local map_name = game.GetMap()
	local math_random = math.random
	local util_IsInWorld = util.IsInWorld
	local util_TraceLine = util.TraceLine
	-- local math_Clamp = math.Clamp
	local file_Exists = file.Exists
	local Vector = Vector
	local math_floor = math.floor
	local math_modf = math.modf
	-- local FrameTime = FrameTime
	local add_z_axis = Vector(0, 0, 20)
	local cell_size = 250
	local add_endpos_trace_vector = Vector(0, 0, 1000)
	local chunks = {}
	local chunk_size = 500
	local current_pass = 0
	local trace_filter = function(ent)
		if ent:IsWorld() then
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

	local function GetChunkId(pos)
		local x = pos.x
		local y = pos.y
		local xid = math_modf(x / chunk_size)
		local yid = math_modf(y / chunk_size)
		return xid .. yid
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
		local point_chunk_id = GetChunkId(point_position)
		if chunks[point_chunk_id] and chunks[point_chunk_id] >= 10 then
			return true
		end
		return false
	end

	local function UpdateChunkPointsCount(point_position)
		local point_chunk_id = GetChunkId(point_position)
		chunks[point_chunk_id] = chunks[point_chunk_id] or 0
		chunks[point_chunk_id] = chunks[point_chunk_id] + 1
	end

	while true do
		local restict = GetConVar('bgn_enable_dynamic_nodes_only_when_mesh_not_exists'):GetBool()
		local enabled = GetConVar('bgn_dynamic_nodes'):GetBool()

		if not enabled or (restict and MovementMeshExists()) then
			wait(1)
		else
			local map_points = {}
			local points_count = 0
			local expensive_generator = GetConVar('bgn_dynamic_nodes_type'):GetString() == 'grid'
			local radius = GetConVar('bgn_spawn_radius'):GetFloat()
			local players = table.shuffle(player.GetAll())
			local table_remove = table.remove
			chunks = {}
			current_pass = 0

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
					local z = center.z + 50

					for i = 1, 500 do
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

						if not util_IsInWorld(new_point_position) or ChunkHasFull(new_point_position) then
							PassYield()
							continue
						end

						points_count = points_count + 1
						map_points[points_count] = BGN_NODE:Instance(new_point_position)

						UpdateChunkPointsCount(new_point_position)
						PassYield()
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

							points_count = points_count + 1

							local new_point_position = tr.HitPos + add_z_axis
							if ChunkHasFull(new_point_position) then
								PassYield()
								continue
							end

							map_points[points_count] = BGN_NODE:Instance(new_point_position)

							UpdateChunkPointsCount(new_point_position)

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
					local center = map_points[node_index]:GetPos()
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

							y_points_count = y_points_count + 1

							local new_point_position = tr.HitPos + add_z_axis
							if ChunkHasFull(new_point_position) then
								PassYield()
								continue
							end

							y_axis_points[y_points_count] = BGN_NODE:Instance(new_point_position)

							UpdateChunkPointsCount(new_point_position)

							PassYield()
						end

						y_offset = y_offset + cell_size
					end
				end

				map_points = table_Combine(map_points, y_axis_points)
				points_count = #map_points
			end

			for point_index = 1, points_count do
				local node = map_points[point_index]
				if not node then continue end

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
				end

				-- print(point_index, ' / ', points_count)

				PassYield()
			end

			-- MsgN('New mesh generated')

			BGN_NODE:SetMap(map_points)

			wait(5)
		end
	end
end)
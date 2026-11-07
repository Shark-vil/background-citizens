local cvar_bgn_generator_restict = GetConVar('bgn_enable_dynamic_nodes_only_when_mesh_not_exists')
local cvar_bgn_dynamic_nodes = GetConVar('bgn_dynamic_nodes')
local cvar_bgn_enable = GetConVar('bgn_enable')

local function IsEnableGenerator()
	local restict = cvar_bgn_generator_restict:GetBool()
	local enabled = cvar_bgn_enable:GetBool() and cvar_bgn_dynamic_nodes:GetBool()
	return enabled and (not BGN_NODE:IsOnChunkSystem() or IsValid(BGN_NODE:GetChunkManager())) and (not restict or not BGN_NODE:RouteFileExists())
end

do
	local IsInWorld = bgNPC.Util.IsInWorld
	local trace_data = {}
	local vec_0_0_20 = Vector(0, 0, 20)
	local vec_0_0_50 = Vector(0, 0, 50)
	local vec_0_0_1000 = Vector(0, 0, 1000)

	local function TracePositionFixed(position)
		trace_data.start = position + vec_0_0_50
		trace_data.endpos = position - vec_0_0_1000
		trace_data.filter = nil
		return util.TraceLine(trace_data).HitPos + vec_0_0_20
	end

	local function TraceIsWorld(startPos, endPos)
		trace_data.start = startPos
		trace_data.endpos = endPos
		trace_data.filter = function(ent)
			if ent:IsWorld() and not bgNPC.Util.IsDoorLocked(ent) then
				return true
			end
		end
		local pos = util.TraceLine(trace_data).HitPos
		return pos
	end

	cvars.AddChangeCallback('bgn_dynamic_nodes', function(_, _, new_value)
		if new_value == '1' and IsEnableGenerator() and not BGN_NODE:RouteFileExists() then
			BGN_NODE:ClearNodeMap()
		end
	end, 'on_change_bgn_dynamic_nodes_and_off_altgen')

	bgNPC.Tasks.Add('bgNPC_MovementMapDynamicGeneratorAlternative', function(yield, wait)
		local current_pass = 0
		local function PassYield()
			if current_pass >= 1 / FrameTime() then
				current_pass = 0
				yield()
			end
			current_pass = current_pass + 1
		end
		wait(5)
		while true do
			if not cvar_bgn_enable:GetBool() or IsEnableGenerator() and BGN_NODE:RouteFileExists() then
				wait(1)
				continue
			end
			local new_nodes = {}
			for _, ply in ipairs(player.GetAll()) do
				if IsValid(ply) and ply:Alive() then
					local ply_pos = ply:GetPos()
					for i = 1, 50 do
						local x = ply_pos.x + math.random(-1000, 1000)
						local y = ply_pos.y + math.random(-1000, 1000)
						local new_point = TracePositionFixed(Vector(x, y, ply_pos.z))
						if new_point and not bgNPC.Util.IsVectorInWater(new_point) and IsInWorld(new_point) then
							local skip_point = false
							for _, node in ipairs(new_nodes) do
								if node:GetPos():DistToSqr(new_point) <= 202500 then
									skip_point = true
									break
								end
							end
							if not skip_point then
								local node = BGN_NODE:Instance(new_point)
								table.insert(new_nodes, node)
							end
						end
						PassYield()
					end
				end
			end
			for i = #new_nodes, 1, -1 do
				local node = new_nodes[i]
				for _, another_node in ipairs(BGN_NODE:GetMap()) do
					local node_pos = node:GetPos()
					local another_node_pos = another_node:GetPos()
					if node_pos:DistToSqr(another_node_pos) <= 22500
					or (
						node_pos:DistToSqr(another_node_pos) <= 202500
						and not TraceIsWorld(node_pos, another_node_pos)
					)
					then
						table.remove(new_nodes, i)
					end
					PassYield()
				end
			end
			for i = 1, #new_nodes do
				BGN_NODE:AddNodeToMap(new_nodes[i])
				PassYield()
			end
			BGN_NODE:AutoLinkAsync()
			wait(5)
		end
	end)
end

hook.Add('BGN_PlayerReady', 'BGN_MovementMeshGeneratorNotify', function(ply)
	if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end
	if not IsEnableGenerator() then return end
	bgNPC.Util.EntityTimer(ply, 'bgn_dynamic_mevement_mesh_alert_message', 2, 1, function()
		if not IsEnableGenerator() then return end
		bgNPC.Net.Send('bgn_dynamic_mevement_mesh_alert_message', ply)
	end)
end)

bgNPC.Tasks.Add('bgNPC_MovementMapDynamicGenerator', function(yield, wait)
	local cvar_bgn_dynamic_nodes_type = GetConVar('bgn_dynamic_nodes_type')
	local cvar_bgn_spawn_radius = GetConVar('bgn_dynamic_nodes_radius')
	local cvar_bgn_runtime_generator_grid_offset = GetConVar('bgn_runtime_generator_grid_offset')
	local cvar_bgn_dynamic_nodes_save_progress = GetConVar('bgn_dynamic_nodes_save_progress')
	local table_Combine = bgNPC.Table.Append
	local add_z_axis = Vector(0, 0, 20)
	local cell_size = 200
	-- local sqrt_cell_size = cell_size ^ 2
	-- local add_endpos_trace_vector = Vector(0, 0, 1000)
	local add_endpos_trace_vector = Vector(0, 0, 400)
	local map_points = {}
	local points_count = 0
	local current_pass = 0
	local is_dynamic_nodes_save
	local expensive_generator
	local radius
	local is_infmap = bgNPC.Util.IsInfinityMap()
	local info_message_for_admins_has_send = true
	local trace_filter = function(ent)
		if IsValid(ent) and (ent:IsWorld() or (is_infmap and select(1, ent:GetClass():find('collider')) ~= nil)) then
			return true
		end
	end

	local function PassYield()
		current_pass = current_pass + 1
		if current_pass >= 1 / FrameTime() then
			current_pass = 0
			yield()
		end
	end

	local function ChunkHasFull(point_position)
		local cell_size_limit = cell_size - 5
		if not expensive_generator then
			local cell_size_limit_sqrt = cell_size_limit ^ 2
			for i = 1, points_count do
				local node = map_points[i]
				if node:GetPos():DistToSqr(point_position) <= cell_size_limit_sqrt then
					return true
				end
			end
		end
		if BGN_NODE:IsOnChunkSystem() then
			if BGN_NODE:GetChunkNodesCountInRadiusAsync(point_position, cell_size_limit) >= 1 then
				return true
			end
			PassYield()
			return BGN_NODE:GetChunkID(point_position) == -1
		end
		return BGN_NODE:GetNodesCountInRadiusAsync(point_position, cell_size_limit) >= 1
	end

	-- local function HasTraceToPlayers(point_position)
	-- 	local players = player.GetAll()
	-- 	for i = #players, 1, -1 do
	-- 		local ply = players[i]
	-- 		if IsValid(ply) and ply:Alive() then
	-- 			local tr = util.TraceLine({
	-- 				start = point_position,
	-- 				endpos = ply:LocalToWorld(ply:OBBCenter()),
	-- 				filter = function(ent)
	-- 					if IsValid(ent) and not ent:IsNPC() and not ent:IsNextBot() and not ent:IsVehicle() then
	-- 						return true
	-- 					end
	-- 				end
	-- 			})
	-- 			if tr.Hit and IsValid(tr.Entity) and tr.Entity:IsPlayer() then return true end
	-- 		end
	-- 		PassYield()
	-- 	end
	-- end

	while true do
		if not IsEnableGenerator() then
			if info_message_for_admins_has_send then info_message_for_admins_has_send = false end
			wait(1)
		else
			if not info_message_for_admins_has_send then
				info_message_for_admins_has_send = true
				local admins = {}
				for _, v in ipairs(player.GetAll()) do
					if IsValid(v) and (v:IsAdmin() or v:IsSuperAdmin()) then
						table.insert(admins, v)
					end
				end
				if #admins ~= 0 then
					bgNPC.Net.Send('bgn_dynamic_mevement_mesh_alert_message', admins)
				end
			end

			map_points = {}
			points_count = 0
			is_dynamic_nodes_save = cvar_bgn_dynamic_nodes_save_progress:GetBool()
			expensive_generator = cvar_bgn_dynamic_nodes_type:GetString() == 'grid'
			radius = cvar_bgn_spawn_radius:GetFloat()
			current_pass = 0
			cell_size = cvar_bgn_runtime_generator_grid_offset:GetInt()
			sqrt_cell_size = cell_size ^ 2

			-- if not is_dynamic_nodes_save then
			-- 	radius = math.Clamp(radius, 0, 1500)
			-- end

			local players = player.GetAll()
			for i = #players, 1, -1 do
				local ply = players[i]
				if not ply or not ply:Alive() then
					table.remove(players, i)
				end
				PassYield()
			end

			yield()

			bgNPC.Util.Log('[Dynamic Nodes] Start generate new nodes...')

			if not expensive_generator then
				bgNPC.Util.Log('[Dynamic Nodes] Generator type - Random')

				for player_index = 1, #players do
					local ply = players[player_index]
					if not ply then continue end

					local center = ply:LocalToWorld(ply:OBBCenter())
					local current_radius_randomize = cell_size
					local z = center.z + 100

					for i = 1, 1000 do
						current_radius_randomize = math.Clamp(current_radius_randomize, 0, radius)

						local x = center.x + math.random(-current_radius_randomize, current_radius_randomize)
						local y = center.y + math.random(-current_radius_randomize, current_radius_randomize)
						-- local z = center.z
						local start_point_vector = Vector(x, y, z)
						local tr = util.TraceLine({
							start = start_point_vector,
							endpos = start_point_vector - add_endpos_trace_vector,
							filter = trace_filter
						})

						PassYield()

						if not tr.Hit then
							PassYield()
							continue
						end

						PassYield()

						local new_point_position = tr.HitPos + add_z_axis
						-- if not HasTraceToPlayers(new_point_position) then
						-- 	PassYield()
						-- 	continue
						-- end

						if bgNPC.Util.IsVectorInWater(new_point_position) then
							PassYield()
							continue
						end

						PassYield()

						if not util.IsInWorld(new_point_position) or ChunkHasFull(new_point_position) then
							PassYield()
							continue
						end

						local node = BGN_NODE:Instance(new_point_position)
						if is_dynamic_nodes_save then
							node.single_check = true
						end

						points_count = points_count + 1
						map_points[points_count] = node
						current_radius_randomize = current_radius_randomize + cell_size

						PassYield()
					end
				end
			else
				bgNPC.Util.Log('[Dynamic Nodes] Generator type - Grid')

				local generator_iterations = 0
				local calc_iterations = true
				local sqr_radius = radius ^ 2

				bgNPC.Util.Log('[Dynamic Nodes] Grid generator - make X axis nodes')

				for player_index = 1, #players do
					local ply = players[player_index]
					if not ply then continue end

					local center = ply:LocalToWorld(ply:OBBCenter())
					local x_offset = 0
					-- local start_point_vector = Vector(center.x, center.y, center.z)
					local start_point_vector = center + Vector(0, 0, 100)

					while start_point_vector:DistToSqr(center) <= sqr_radius do
						if calc_iterations then
							generator_iterations = generator_iterations + 1
						end

						for k = 1, 2 do
							local x = k == 1 and center.x + x_offset or center.x - x_offset
							start_point_vector.x = x

							local different_start_point = start_point_vector
							if not util.IsInWorld(different_start_point) then
								PassYield()
								continue
							end

							local tr = util.TraceLine({
								start = different_start_point,
								endpos = different_start_point - add_endpos_trace_vector,
								filter = trace_filter
							})

							if not tr.Hit then
								PassYield()
								continue
							end

							PassYield()

							local new_point_position = tr.HitPos + add_z_axis
							-- if not HasTraceToPlayers(new_point_position) then
							-- 	PassYield()
							-- 	continue
							-- end

							if bgNPC.Util.IsVectorInWater(new_point_position) then
								PassYield()
								continue
							end

							PassYield()

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

				bgNPC.Util.Log('[Dynamic Nodes] Grid generator - make Y axis nodes')

				local y_axis_points = {}
				local y_points_count = 0

				for node_index = 1, points_count do
					local node = map_points[node_index]
					if is_dynamic_nodes_save and node_index < points_count - 1 then
						node.single_check = true
					end

					local center = node:GetPos()
					local y_offset = 0
					-- local start_point_vector = Vector(center.x, 0, center.z)
					local start_point_vector = Vector(center.x, 0, center.z) + Vector(0, 0, 100)

					for i = 1, generator_iterations do
						for k = 1, 2 do
							local y = k == 1 and center.y + y_offset or center.y - y_offset
							start_point_vector.y = y

							local different_start_point = start_point_vector
							if not util.IsInWorld(different_start_point) then
								PassYield()
								continue
							end

							local tr = util.TraceLine({
								start = different_start_point,
								endpos = different_start_point - add_endpos_trace_vector,
								filter = trace_filter
							})

							if not tr.Hit then
								PassYield()
								continue
							end

							PassYield()

							local new_point_position = tr.HitPos + add_z_axis
							-- if not HasTraceToPlayers(new_point_position) then
							-- 	PassYield()
							-- 	continue
							-- end

							if bgNPC.Util.IsVectorInWater(new_point_position) then
								PassYield()
								continue
							end

							PassYield()

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

					PassYield()
				end

				bgNPC.Util.Log('[Dynamic Nodes] Grid generator - combine X and Y nodes')

				map_points = table_Combine(map_points, y_axis_points)
				points_count = #map_points
			end

			if cvar_bgn_dynamic_nodes_save_progress:GetBool() then
				bgNPC.Util.Log('[Dynamic Nodes] Expandable generator - start expand map')
				BGN_NODE:ExpandMapAsync(map_points, false)
				yield()
				bgNPC.Util.Log('[Dynamic Nodes] Expandable generator - start link nodes')
				BGN_NODE:AutoLinkAsync()
				yield()
			else
				bgNPC.Util.Log('[Dynamic Nodes] Static generator - start set map')
				BGN_NODE:SetMap(map_points)
				yield()
				bgNPC.Util.Log('[Dynamic Nodes] Static generator - start link nodes')
				BGN_NODE:AutoLink()
				yield()
			end

			bgNPC.Util.Log('[Dynamic Nodes] Complete generation')

			wait(1)
		end
	end
end)
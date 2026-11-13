local debug_draw_chunk_color = Color(250, 45, 240, 10)
local zero_angle = Angle()
local debugoverlay_Box = debugoverlay.Box
local math_Round = math.Round
local LerpVector = LerpVector
local Vector = Vector
local util_IsInWorld = util.IsInWorld
local WorldToLocal = WorldToLocal
local IsValid = IsValid
local coroutine_yield = coroutine.yield
-- local ents_FindInBox = ents.FindInBox
local util_TraceHull = util.TraceHull
-- local MASK_SHOT_HULL = MASK_SHOT_HULL
local COLLISION_GROUP_WORLD = COLLISION_GROUP_WORLD
local MASK_SOLID_BRUSHONLY = MASK_SOLID_BRUSHONLY
-- local FrameTime = FrameTime
local is_infmap = slib.IsInfinityMap()
if is_infmap then
	util_IsInWorld = function(...) return util.IsInWorld(...) end
	util_TraceHull = function(...) return util.TraceHull(...) end
end

local CLASS = {}

function CLASS:Instance(settings)
	settings = settings or {}

	local private = {}
	private.chunk_size_x = settings.chunk_size or settings.chunk_size_x or self:GetDefaultChunkSize()
	private.chunk_size_y = settings.chunk_size or settings.chunk_size_y or self:GetDefaultChunkSize()
	private.chunk_size_z = settings.chunk_size or settings.chunk_size_z or self:GetDefaultChunkSize()

	private.chunk_center_index = 0
	private.chunks_count = 0

	private.gmod_map_size_max_x = settings.map_size or settings.map_size_x or self:GetMaxMapSize()
	private.gmod_map_size_max_y = settings.map_size or settings.map_size_y or self:GetMaxMapSize()
	private.gmod_map_size_max_z = settings.map_size or settings.map_size_z or self:GetMaxMapSize()

	private.gmod_map_size_axis_x = private.gmod_map_size_max_x / 2
	private.gmod_map_size_axis_y = private.gmod_map_size_max_y / 2
	private.gmod_map_size_axis_z = private.gmod_map_size_max_z / 2

	private.gmod_map_chunks_count_x = math_Round(private.gmod_map_size_max_x / private.chunk_size_x)
	private.gmod_map_chunks_count_y = math_Round(private.gmod_map_size_max_y / private.chunk_size_y)
	private.gmod_map_chunks_count_z = math_Round(private.gmod_map_size_max_z / private.chunk_size_z)

	private.gmod_map_chunks = {}
	private.condition_chunk_touches_the_World = false
	private.make_chunks_async = false

	function private:GetYieldPassController(condition)
		local yield_pass = 0
		local function action()
			if condition and not condition() then return end
			yield_pass = yield_pass + 1
			if yield_pass >= 1 / slib.deltaTime then
				yield_pass = 0
				coroutine_yield()
			end
		end
		return action
	end

	local public = {}

	function private:MakeChunks()
		local yield_pass = private:GetYieldPassController(function() return private.make_chunks_async end)
		local gmod_map_chunks = {}
		local chunks_count = 0

		local y_start = -private.gmod_map_size_axis_y
		for y = 1, private.gmod_map_chunks_count_y do
			local x_start = -private.gmod_map_size_axis_x
			for x = 1, private.gmod_map_chunks_count_x do
				local z_start = -private.gmod_map_size_axis_z
				for z = 1, private.gmod_map_chunks_count_z do
					local start_pos = Vector(x_start, y_start, z_start)
					local end_pos = start_pos + Vector(private.chunk_size_x, private.chunk_size_y, private.chunk_size_z)
					local center_pos = LerpVector(.5, start_pos, end_pos)
					local is_valid_chunk = true

					if private.condition_chunk_touches_the_World then
						if not util_IsInWorld(center_pos) then
							is_valid_chunk = false
						else
							yield_pass()
						end

						if not is_valid_chunk then
							local tr = util_TraceHull({
								start = center_pos,
								endpos = center_pos,
								maxs = end_pos,
								mins = start_pos,
								mask = MASK_SOLID_BRUSHONLY,
								collisiongroup = COLLISION_GROUP_WORLD,
							})

							if tr and tr.Hit then
								is_valid_chunk = true
								yield_pass()
							end
						end

						if not is_valid_chunk and public:CheckChunkIsInWorld({ start_pos = start_pos }) then
							is_valid_chunk = true
							yield_pass()
						end

						-- if not public:CheckChunkIsInWorld({ start_pos = start_pos }) then
						-- 	is_valid_chunk = false
						-- else
						-- 	yield_pass()
						-- end
					end

					if is_valid_chunk then
						chunks_count = chunks_count + 1
						local data_index = chunks_count
						local data = { index = data_index, center_pos = center_pos, start_pos = start_pos, end_pos = end_pos }
						gmod_map_chunks[data_index] = data
						-- yield_pass()
					end

					z_start = z_start + private.chunk_size_z
					-- yield_pass()
				end
				x_start = x_start + private.chunk_size_x
				-- yield_pass()
			end
			y_start = y_start + private.chunk_size_y
			-- yield_pass()
		end

		public:SetChunks(gmod_map_chunks, chunks_count)

		return private.gmod_map_chunks
	end

	function public:CheckChunkIsInWorld(chunk)
		local slib_IsInWorld = slib.IsInWorld
		local size_check = 200
		local half_size = size_check / 2
		local x_parse = private.chunk_size_x / size_check
		local y_parse = private.chunk_size_y / size_check
		local z_parse = private.chunk_size_z / size_check
		local start_pos = Vector(chunk.start_pos.x, chunk.start_pos.y, chunk.start_pos.z)
		local check_pos = Vector(start_pos.x + half_size, start_pos.y + half_size, start_pos.z + half_size)
		-- local clr = Color(255, 68, 68, 190)
		-- local render_DrawSphere = render.DrawSphere

		for y = 1, y_parse do
			for x = 1, x_parse do
				for z = 1, z_parse do
					-- render.DrawSphere(check_pos, 25, 5, 5, clr)

					if slib_IsInWorld(check_pos) then
						-- render_DrawSphere(check_pos, 25, 5, 5, clr)
						return true
					end

					check_pos.z = check_pos.z + size_check
				end
				check_pos.x = check_pos.x + size_check
				check_pos.z = start_pos.z + half_size
			end
			check_pos.y = check_pos.y + size_check
			check_pos.x = start_pos.x + half_size
			-- check_pos.z = start_pos.z + half_size
		end

		return false
	end

	function public:MakeChunks()
		private.make_chunks_async = false
		return private:MakeChunks()
	end

	function public:MakeChunksAsync()
		private.make_chunks_async = true
		return private:MakeChunks()
	end

	function public:SetChunks(gmod_map_chunks, chunks_count)
		private.gmod_map_chunks = istable(gmod_map_chunks) and gmod_map_chunks or {}
		private.chunks_count = isnumber(chunks_count) and chunks_count or #private.gmod_map_chunks

		if private.chunks_count ~= 0 then
			local center_index = 0
			if private.chunks_count % 2 == 0 then
				center_index = private.chunks_count / 2
			else
				center_index = (private.chunks_count - 1) / 2
			end
			private.chunk_center_index = center_index
		end
	end

	function public:SetConditionChunkTouchesTheWorld()
		private.condition_chunk_touches_the_World = true
	end

	function public:GetChunks()
		return private.gmod_map_chunks
	end

	function public:GetSettings()
		return {
			chunk_size_x = private.chunk_size_x,
			chunk_size_y = private.chunk_size_y,
			chunk_size_z = private.chunk_size_z,

			chunk_center_index = private.chunk_center_index,
			chunks_count = private.chunks_count,

			gmod_map_size_max_x = private.gmod_map_size_max_x,
			gmod_map_size_max_y = private.gmod_map_size_max_y,
			gmod_map_size_max_z = private.gmod_map_size_max_z,

			gmod_map_size_axis_x = private.gmod_map_size_axis_x,
			gmod_map_size_axis_y = private.gmod_map_size_axis_y,
			gmod_map_size_axis_z = private.gmod_map_size_axis_z,

			gmod_map_chunks_count_x = private.gmod_map_chunks_count_x,
			gmod_map_chunks_count_y = private.gmod_map_chunks_count_y,
			gmod_map_chunks_count_z = private.gmod_map_chunks_count_z,
		}
	end

	function public:SetPrivateVariables(key_values)
		if SERVER then return end
		for key, value in pairs(key_values) do
			private[key] = value
		end
	end

	function public:ChunksCount()
		return private.chunks_count
	end

	function public:IsValid()
		return private.chunks_count ~= 0
	end

	function public:InChunkPosition(chunk, position)
		if position:WithinAABox(chunk.start_pos, chunk.end_pos) then
			return true
		end
		return false
	end

	function public:InChunkEntity(chunk, ent)
		if IsValid(ent) then
			return self:InChunkPosition(chunk, ent:GetPos())
		end
		return false
	end

	function public:GetChunkByVector(position, two_way_searching, is_async)
		if is_infmap then
			local cs = InfMap.chunk_size
			local cs_double = cs * 2
			local floor = math.floor
			local cox = floor((position[1] + cs) / cs_double)
			local coy = floor((position[2] + cs) / cs_double)
			local coz = floor((position[3] + cs) / cs_double)
			local chunk_offset = Vector(cox, coy, coz)
			local chunk_size_vector = Vector(private.chunk_size_x, private.chunk_size_y, private.chunk_size_z)
			return {
				index = math.abs(chunk_offset.x) + math.abs(chunk_offset.y) + math.abs(chunk_offset.z),
				center_pos = position,
				start_pos = position - chunk_size_vector,
				end_pos = position + chunk_size_vector
			}
		end

		local yield_pass

		if is_async then
			yield_pass = private:GetYieldPassController()
		end

		if not two_way_searching then
			for i = 1, private.chunks_count do
				local chunk = private.gmod_map_chunks[i]
				if position:WithinAABox(chunk.start_pos, chunk.end_pos) then
					-- if is_infmap and chunk.index <= CLASS:GetMaxMapSize() then
					-- 	chunk.index = chunk.index + CLASS:GetMaxMapSize() + 1
					-- end
					return chunk
				end

				if is_async then
					yield_pass()
				end
			end
		else
			local chunks_count = private.chunks_count
			if chunks_count == 0 then return end

			local while_index, while_start_index, while_end_index, is_beginning = 0, 1, chunks_count, false

			while while_index ~= private.chunk_center_index do
				is_beginning = not is_beginning
				while_index = is_beginning and while_start_index or while_end_index

				local chunk = private.gmod_map_chunks[while_index]
				if position:WithinAABox(chunk.start_pos, chunk.end_pos) then
					-- if is_infmap and chunk.index <= self:GetMaxMapSize() then
					-- 	chunk.index = chunk.index + self:GetMaxMapSize() + 1
					-- end
					return chunk
				end

				if is_async then
					yield_pass()
				end

				if is_beginning then
					while_start_index = while_start_index + 1
				else
					while_end_index = while_end_index - 1
				end
			end
		end
	end

	function public:GetChunkByEntity(ent, two_way_searching)
		if IsValid(ent) then
			return self:GetChunkByVector(ent:GetPos(), two_way_searching)
		end
	end

	function public:VectorInChunkByIndex(position, two_way_searching)
		local chunk = self:GetChunkByVector(position, two_way_searching)
		return index == chunk.index
	end

	function public:EntityInChunkByIndex(ent, two_way_searching)
		local chunk = self:GetChunkByEntity(ent, two_way_searching)
		return index == chunk.index
	end

	function public:GetChunkByVectorAsync(position, two_way_searching)
		return self:GetChunkByVector(position, two_way_searching, true)
	end

	function public:GetChunkByEntityAsync(ent, two_way_searching)
		if IsValid(ent) then
			return self:GetChunkByVectorAsync(ent:GetPos(), two_way_searching)
		end
	end

	function public:VectorInChunkByIndexAsync(position, two_way_searching)
		local chunk = self:GetChunkByVectorAsync(position, two_way_searching)
		return index == chunk.index
	end

	function public:EntityInChunkByIndexAsync(ent, two_way_searching)
		local chunk = self:GetChunkByEntityAsync(ent, two_way_searching)
		return index == chunk.index
	end

	function public:ChunkDebugOverlay(chunk, color, lifetime)
		if not chunk or not chunk.index then return end
		local box_min = WorldToLocal(chunk.center_pos, zero_angle, chunk.start_pos, zero_angle)
		local box_max = WorldToLocal(chunk.center_pos, zero_angle, chunk.end_pos, zero_angle)
		debugoverlay_Box(chunk.center_pos, box_min, box_max, lifetime or .1, color or debug_draw_chunk_color)
	end

	return public
end

function CLASS:GetMaxMapSize()
	return 32768
end

function CLASS:GetDefaultChunkSize()
	return is_infmap and 10000 or 1000
end

slib.SetComponent('Chunks', CLASS)
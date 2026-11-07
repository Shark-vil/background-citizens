--[[
	Generic A* with a binary heap. Used by the node graph and the navmesh provider.

		local path = bgNPC.AStar.Search({
			start = start_id,
			is_goal = function(id) return id == goal_id end,
			neighbours = function(id, push) push(next_id, step_cost) ... end,
			heuristic = function(id) return estimate end,
			max_iterations = 2000,
		})
		-- path: list of ids from start to goal, or nil

	Ids can be any table keys (numbers, nav areas, ...).
--]]

local AStar = bgNPC.AStar or {}
bgNPC.AStar = AStar

-- ---------------------------------------------------------------------------
-- Binary min-heap of (key, priority)
-- ---------------------------------------------------------------------------

local Heap = bgNPC.Class('BGN_Heap')
AStar.Heap = Heap

function Heap:Init()
	self.keys = {}
	self.prio = {}
	self.size = 0
end

function Heap:Push(key, priority)
	local keys, prio = self.keys, self.prio
	local i = self.size + 1
	self.size = i

	while i > 1 do
		local parent = math.floor(i / 2)
		if prio[parent] <= priority then break end
		keys[i], prio[i] = keys[parent], prio[parent]
		i = parent
	end

	keys[i], prio[i] = key, priority
end

-- @return key, priority (nil when empty)
function Heap:Pop()
	local size = self.size
	if size == 0 then return nil end

	local keys, prio = self.keys, self.prio
	local top_key, top_prio = keys[1], prio[1]
	local last_key, last_prio = keys[size], prio[size]
	keys[size], prio[size] = nil, nil
	size = size - 1
	self.size = size

	if size > 0 then
		local i = 1
		while true do
			local child = i * 2
			if child > size then break end
			if child < size and prio[child + 1] < prio[child] then child = child + 1 end
			if prio[child] >= last_prio then break end
			keys[i], prio[i] = keys[child], prio[child]
			i = child
		end
		keys[i], prio[i] = last_key, last_prio
	end

	return top_key, top_prio
end

function Heap:IsEmpty()
	return self.size == 0
end

-- ---------------------------------------------------------------------------
-- Search
-- ---------------------------------------------------------------------------

local DEFAULT_MAX_ITERATIONS = 3000

-- @return table|nil path of ids, number iterations used
function AStar.Search(params)
	local start = params.start
	local is_goal = params.is_goal
	local neighbours = params.neighbours
	local heuristic = params.heuristic
	local max_iterations = params.max_iterations or DEFAULT_MAX_ITERATIONS

	local open = Heap()
	local cost = { [start] = 0 }
	local came_from = {}
	local closed = {}

	open:Push(start, heuristic(start))

	local current, current_cost
	local function push(next_id, step_cost)
		if closed[next_id] then return end
		local new_cost = current_cost + step_cost
		local old_cost = cost[next_id]
		if old_cost and old_cost <= new_cost then return end
		cost[next_id] = new_cost
		came_from[next_id] = current
		open:Push(next_id, new_cost + heuristic(next_id))
	end

	local iterations = 0
	while iterations < max_iterations do
		current = open:Pop()
		if current == nil then return nil, iterations end

		if not closed[current] then
			iterations = iterations + 1

			if is_goal(current) then
				local path, n = {}, 0
				local node = current
				while node ~= nil do
					n = n + 1
					path[n] = node
					node = came_from[node]
				end
				-- reverse in place
				for i = 1, math.floor(n / 2) do
					path[i], path[n - i + 1] = path[n - i + 1], path[i]
				end
				return path, iterations
			end

			closed[current] = true
			current_cost = cost[current]
			neighbours(current, push)
		end
	end

	return nil, iterations
end

-- ---------------------------------------------------------------------------
-- Tests
-- ---------------------------------------------------------------------------

bgNPC.Test.Add('nav.heap', function(check)
	local heap = Heap()
	for _, v in ipairs({ 5, 1, 9, 3, 7, 2, 8 }) do heap:Push('k' .. v, v) end
	local out = {}
	while not heap:IsEmpty() do
		local _, p = heap:Pop()
		out[#out + 1] = p
	end
	check(table.concat(out, ',') == '1,2,3,5,7,8,9', 'heap pops in order: ' .. table.concat(out, ','))
end)

bgNPC.Test.Add('nav.astar.grid', function(check)
	-- 10x10 grid with a wall at x = 5 (gap at y = 9)
	local function id(x, y) return y * 10 + x end
	local function xy(i) return i % 10, math.floor(i / 10) end
	local function blocked(x, y) return x == 5 and y ~= 9 end

	local path = AStar.Search({
		start = id(0, 0),
		is_goal = function(i) return i == id(9, 0) end,
		heuristic = function(i) local x, y = xy(i) return math.abs(9 - x) + math.abs(y) end,
		neighbours = function(i, push)
			local x, y = xy(i)
			for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
				local nx, ny = x + d[1], y + d[2]
				if nx >= 0 and nx < 10 and ny >= 0 and ny < 10 and not blocked(nx, ny) then push(id(nx, ny), 1) end
			end
		end,
	})

	check(path ~= nil, 'path found')
	check(path and #path == 28, 'shortest path length 28, got ' .. tostring(path and #path))

	local none = AStar.Search({
		start = 1, is_goal = function(i) return i == 99 end, heuristic = function() return 0 end,
		neighbours = function() end,
	})
	check(none == nil, 'no path returns nil')
end)

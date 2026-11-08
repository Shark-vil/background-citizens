--[[
	GOAP planner (goal oriented action planning).

	World state is a bit mask of named facts. Actions have preconditions and effects (fact -> boolean),
	goals list the facts they want. The planner runs A* (bgNPC.AStar) over world states and returns
	the cheapest action chain that makes the goal true.

		local GOAP = bgNPC.GOAP
		local attack = GOAP.Action('attack', {
			pre = { has_enemy = true, armed = true },
			effects = { threat_handled = true },
			state = 'defense',                         -- the FSM state that performs the action
			cost = function(ws) return 2 end,          -- number or function(world_state)
		})
		local goal = GOAP.Goal('eliminate', { want = { threat_handled = true } })
		local plan = GOAP.Plan(ws, goal, { attack, ... })  -- list of actions, {} if already true, nil if impossible

	Costs depend only on the world state, so plans are cached by (state, goal, action set).
--]]

local GOAP = bgNPC.GOAP or {}
bgNPC.GOAP = GOAP

-- hot path: the planner calls these in its inner loop
local band, bor, bxor, bnot = bit.band, bit.bor, bit.bxor, bit.bnot

local MAX_FACTS = 31
local MAX_ITERATIONS = 200
local CACHE_LIMIT = 1024

GOAP.facts = GOAP.facts or {}
GOAP.fact_names = GOAP.fact_names or {}

-- @return number the bit of a fact, registered on first use
function GOAP.Fact(name)
	local fact = GOAP.facts[name]
	if fact then return fact end

	local index = table.Count(GOAP.facts)
	assert(index < MAX_FACTS, 'bgNPC.GOAP: too many facts')
	fact = bit.lshift(1, index)
	GOAP.facts[name] = fact
	GOAP.fact_names[fact] = name
	return fact
end

-- { fact = boolean } -> mask, value
function GOAP.Condition(conditions)
	local mask, value = 0, 0
	for name, wanted in pairs(conditions or {}) do
		local fact = GOAP.Fact(name)
		mask = bor(mask, fact)
		if wanted then value = bor(value, fact) end
	end
	return mask, value
end

function GOAP.Matches(state, mask, value)
	return band(state, mask) == value
end

function GOAP.Apply(state, mask, value)
	return bor(band(state, bnot(mask)), value)
end

-- @return string "fact1 !fact2" for debug output
function GOAP.Describe(state, mask)
	local parts = {}
	for name, fact in SortedPairs(GOAP.facts) do
		if (not mask or band(mask, fact) ~= 0) and not string.StartWith(name, 'test_') then
			parts[#parts + 1] = (band(state, fact) ~= 0 and '' or '!') .. name
		end
	end
	return table.concat(parts, ' ')
end

local function CountBits(n)
	local count = 0
	while n ~= 0 do
		n = band(n, n - 1)
		count = count + 1
	end
	return count
end

-- ---------------------------------------------------------------------------
-- Action / Goal
-- ---------------------------------------------------------------------------

local Action = bgNPC.Class('BGN_GOAPAction')
GOAP.Action = Action

function Action:Init(name, def)
	self.name = name
	self.state = def.state
	-- states the FSM state may move on to while still doing the action (fear -> run_from_danger, ...)
	self.states = def.state and { [def.state] = true } or {}
	for _, state in ipairs(def.also or {}) do self.states[state] = true end
	self.trait = def.trait
	self.always = def.always -- allowed without a config weight
	self.chance = def.chance -- share of actors that get a trait action without a config weight
	self.prepare = def.prepare -- function(actor) -> boolean, sets up the state before it starts
	self.pre_mask, self.pre_value = GOAP.Condition(def.pre)
	self.effect_mask, self.effect_value = GOAP.Condition(def.effects)
	self.cost = def.cost or 1
end

function Action:Runs(state)
	return self.states[state] == true
end

function Action:CanRun(ws)
	return band(ws, self.pre_mask) == self.pre_value
end

function Action:IsDone(ws)
	return band(ws, self.effect_mask) == self.effect_value
end

-- Costs below 1 would break the A* heuristic (one unsatisfied fact = at least cost 1).
function Action:GetCost(ws)
	local cost = isfunction(self.cost) and self.cost(ws) or self.cost
	return math.max(1, cost)
end

local Goal = bgNPC.Class('BGN_GOAPGoal')
GOAP.Goal = Goal

function Goal:Init(name, def)
	self.name = name
	self.mask, self.value = GOAP.Condition(def.want)
end

function Goal:IsSatisfied(ws)
	return band(ws, self.mask) == self.value
end

-- ---------------------------------------------------------------------------
-- Planner
-- ---------------------------------------------------------------------------

local cache, cache_size = {}, 0

local function ActionsKey(actions)
	local names = {}
	for i = 1, #actions do names[i] = actions[i].name end
	return table.concat(names, ',')
end

-- @return table|nil list of actions
function GOAP.Plan(ws, goal, actions, actions_key)
	if goal:IsSatisfied(ws) then return {} end

	actions_key = actions_key or ActionsKey(actions)
	local key = ws .. ':' .. goal.name .. ':' .. actions_key
	local cached = cache[key]
	if cached ~= nil then return cached or nil end

	local via = {}
	local path = bgNPC.AStar.Search({
		start = ws,
		max_iterations = MAX_ITERATIONS,
		is_goal = function(state) return band(state, goal.mask) == goal.value end,
		heuristic = function(state) return CountBits(band(bxor(state, goal.value), goal.mask)) end,
		neighbours = function(state, push)
			for i = 1, #actions do
				local action = actions[i]
				if band(state, action.pre_mask) == action.pre_value then
					local next_state = bor(band(state, bnot(action.effect_mask)), action.effect_value)
					if next_state ~= state and push(next_state, action:GetCost(state)) then
						via[next_state] = action
					end
				end
			end
		end,
	})

	local plan
	if path then
		plan = {}
		for i = 2, #path do plan[#plan + 1] = via[path[i]] end
	end

	if cache_size >= CACHE_LIMIT then cache, cache_size = {}, 0 end
	cache[key] = plan or false
	cache_size = cache_size + 1

	return plan
end

function GOAP.ClearCache()
	cache, cache_size = {}, 0
end

-- ---------------------------------------------------------------------------
-- Tests
-- ---------------------------------------------------------------------------

bgNPC.Test.Add('goap.planner', function(check)
	local F = GOAP.Fact
	local get_weapon = Action('test_get_weapon', { effects = { test_armed = true }, cost = 2 })
	local attack = Action('test_attack', { pre = { test_armed = true }, effects = { test_win = true }, cost = 1 })
	local punch = Action('test_punch', { effects = { test_win = true }, cost = 5 })
	local win = Goal('test_win', { want = { test_win = true } })

	local plan = GOAP.Plan(0, win, { get_weapon, attack, punch })
	check(plan and #plan == 2 and plan[1] == get_weapon and plan[2] == attack, 'cheapest chain: get weapon, attack')

	plan = GOAP.Plan(F('test_armed'), win, { get_weapon, attack, punch })
	check(plan and #plan == 1 and plan[1] == attack, 'armed: attack right away')

	check(#GOAP.Plan(F('test_win'), win, { attack }) == 0, 'satisfied goal: empty plan')
	check(GOAP.Plan(0, win, { attack }) == nil, 'impossible goal: nil')
	check(GOAP.Plan(0, win, { attack }) == nil, 'impossible goal is cached')
end)

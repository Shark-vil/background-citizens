--[[
	Scheduler: long-running background tasks on coroutines with a shared per-tick time budget.

		bgNPC.Tasks.Add('my_task', function(yield, wait, budget)
			while true do
				for i = 1, #list do
					work(list[i])
					budget()  -- yields only when this tick's time budget is spent
				end
				wait(1)       -- sleep for one second (the task is not resumed meanwhile)
			end
		end)

	yield()   always gives the tick away.
	budget()  gives the tick away only when the budget ("bgn_tasks_budget_ms") is spent.
	wait(s)   sleeps, the scheduler does not resume the task until the time passes.

	Tasks are resumed round-robin, so one heavy task can't starve the others.
	A task that errors is removed and reported. Returning from the function finishes the task.
--]]

local Tasks = bgNPC.Tasks or {}
bgNPC.Tasks = Tasks

local DEFAULT_BUDGET_MS = SERVER and 3 or 1.5

local list = Tasks.list or {}
Tasks.list = list

local order = Tasks.order or {}
Tasks.order = order

local budget_cvar = CreateConVar('bgn_tasks_budget_ms', tostring(DEFAULT_BUDGET_MS),
	{ FCVAR_ARCHIVE }, 'Background NPCs: time per tick (ms) for background tasks', 0.1, 50)

local tick_deadline = 0
local current

local function yield()
	coroutine.yield()
end

local function wait(seconds)
	current.wake = CurTime() + (seconds or 0)
	coroutine.yield()
end

local function budget()
	if SysTime() >= tick_deadline then coroutine.yield() end
end

local function RemoveFromOrder(id)
	for i = #order, 1, -1 do
		if order[i] == id then table.remove(order, i) end
	end
end

-- Replaces a task with the same id.
function Tasks.Add(id, func)
	assert(isfunction(func), 'bgNPC.Tasks.Add: function expected')
	if not list[id] then order[#order + 1] = id end
	list[id] = { func = func, wake = 0 }
end

function Tasks.Remove(id)
	if not list[id] then return end
	list[id] = nil
	RemoveFromOrder(id)
end

function Tasks.Exists(id)
	return list[id] ~= nil
end

-- Spent time of the last tick, for debugging.
Tasks.last_tick_ms = 0

local cursor = 1

hook.Add('Think', 'BGN_Tasks', function()
	local count = #order
	if count == 0 then return end

	local start = SysTime()
	tick_deadline = start + budget_cvar:GetFloat() / 1000

	local now = CurTime()
	if cursor > count then cursor = 1 end

	for _ = 1, count do
		local id = order[cursor]
		cursor = cursor % count + 1

		local task = list[id]
		if task and task.wake <= now then
			local co = task.co
			if not co then
				co = coroutine.create(task.func)
				task.co = co
			end

			current = task
			local ok, err = coroutine.resume(co, yield, wait, budget)
			current = nil

			if not ok then
				ErrorNoHalt('[Background NPCs] Task "' .. tostring(id) .. '" error: ' .. tostring(err) .. '\n')
				if list[id] == task then Tasks.Remove(id) end
				count = #order
			elseif coroutine.status(co) == 'dead' and list[id] == task then
				Tasks.Remove(id)
				count = #order
			end

			if SysTime() >= tick_deadline or count == 0 then break end
		end
	end

	Tasks.last_tick_ms = (SysTime() - start) * 1000
end)

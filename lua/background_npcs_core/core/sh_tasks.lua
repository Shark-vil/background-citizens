--[[
	Long-running background tasks on coroutines. Replaces slib "async".

		bgNPC.Tasks.Add('my_task', function(yield, wait)
			while true do
				-- work
				yield()   -- continue on the next tick
				wait(1)   -- sleep for one second
			end
		end)

	All tasks run from one Think hook. A task that errors is removed and reported.
	Returning from the function finishes the task.
--]]

local Tasks = bgNPC.Tasks or {}
bgNPC.Tasks = Tasks

--

local list = Tasks.list or {}
Tasks.list = list

local function yield() coroutine.yield() end
local function wait(seconds) coroutine.wait(seconds) end

function Tasks.Add(id, func)
	list[id] = { func = func }
end

function Tasks.Remove(id)
	list[id] = nil
end

function Tasks.Exists(id)
	return list[id] ~= nil
end

local ids = {}

hook.Add('Think', 'BGN_Tasks', function()
	-- Snapshot the ids: tasks may add or remove tasks while running.
	local count = 0
	for id in pairs(list) do
		count = count + 1
		ids[count] = id
	end

	for i = 1, count do
		local id = ids[i]
		ids[i] = nil
		local task = list[id]
		if not task then continue end

		local co = task.co
		if not co then
			co = coroutine.create(task.func)
			task.co = co
		end

		local ok, err = coroutine.resume(co, yield, wait)

		if not ok then
			list[id] = nil
			ErrorNoHalt('[Background NPCs] Task "' .. tostring(id) .. '" error: ' .. tostring(err) .. '\n')
		elseif coroutine.status(co) == 'dead' and list[id] == task then
			list[id] = nil
		end
	end
end)

local coroutine_yield = coroutine.yield
local coroutine_wait = coroutine.wait
local coroutine_create = coroutine.create
local coroutine_resume = coroutine.resume
local table_remove = table.remove
local table_insert = table.insert
local isfunction = isfunction
local registred_async_process = {}
local registred_async_process_count = 0
--
async = async or {}

local function async_execute(obj)
	local id = obj.id
	local func = obj.func
	local co = obj.co
	local worked = obj.worked
	local value = obj.value
	local dispatcher_invoke = obj.dispatcher_invoke

	if dispatcher_invoke then
		slib.def({try = dispatcher_invoke})
		obj.dispatcher_invoke = nil
	end

	if not co or not worked then
		co = coroutine_create(func)
	end

	worked, value = coroutine_resume(co, coroutine_yield, coroutine_wait, dispatcher)

	obj.value = value
	obj.worked = worked
	obj.co = co

	local is_dead = value and (value == 'stop' or value == 'cannot resume dead coroutine' )
	local is_stop = not worked or is_dead

	if is_stop then
		async.Remove(id)
		if value then
			if is_dead then
				slib.DebugLog('Async process "' .. id .. '" is stopped')
			else
				slib.Error('Async process "' .. id .. '" error:\n' .. value)
			end
		end
	end
end

function async.Add(id, func)
	async.Remove(id)

	local value
	value = {
		id = id,
		uuid = slib.UUID(),
		func = func,
		co = nil,
		worked = false,
		value = nil,
		dispatcher_invoke = nil,
		dispatcher = function(invoke)
			if not invoke or not isfunction(invoke) then return end
			value.dispatcher_invoke = invoke
			coroutine_yield()
		end
	}

	local index = table_insert(registred_async_process, value)
	local obj = registred_async_process[index]

	hook.Add('Think', 'slib.system.async_process_handler.' .. value.uuid, function()
		async_execute(obj)
	end)

	slib.DebugLog('Added independent asynchronous process - ', value.id, ' [', value.uuid, ']')
	registred_async_process_count = #registred_async_process
end

-- Obsolete
function async.AddDedic(id, func)
	async.Add(id, func)
end

function async.Exists(id)
	for i = registred_async_process_count, 1, -1 do
		if registred_async_process[i].id == id then return true end
	end

	return false
end

function async.Remove(id)
	for i = registred_async_process_count, 1, -1 do
		local obj = registred_async_process[i]
		if obj.id ~= id then continue end
		hook.Remove('Think', 'slib.system.async_process_handler.' .. obj.uuid)
		table_remove(registred_async_process, i)

		slib.DebugLog('Remove independent asynchronous process - ', obj.id, ' [', obj.uuid, ']')
		break
	end

	registred_async_process_count = #registred_async_process
end
local snet = slib.Components.Network
local SERVER = SERVER
local table = table
local hook = hook
local IsValid = IsValid
local ipairs = ipairs
local AddOriginToPVS = AddOriginToPVS
local RealTime = RealTime
local IsEntity = IsEntity
local istable = istable
local unpack = unpack
local table_insert = table.insert
local table_remove = table.remove
local hook_Run = hook.Run
--

if SERVER then
	local entities_queue = {}

	local function EntitiesPack(tbl, data, is_deep_search)
		if not is_deep_search then
			for i = 1, #data do
				local value = data[i]
				if IsEntity(value) and IsValid(value) then
					table_insert(tbl, value)
				elseif istable(value) then
					EntitiesPack(tbl, value, is_deep_search)
				end
			end
		else
			for _, value in pairs(data) do
				if IsEntity(value) and IsValid(value) then
					table_insert(tbl, value)
				elseif istable(value) then
					EntitiesPack(tbl, value, is_deep_search)
				end
			end
		end
	end

	snet.Callback('snet_sv_entity_network_start', function(ply, id, backward, is_deep_search)
		local request = snet.FindRequestById(id, true)
		if not request then return end

		local entities = {}
		EntitiesPack(entities, request.data, is_deep_search)

		if #entities == 0 then return end

		table_insert(entities_queue, {
			id = id,
			backward = backward or false,
			request_data = {
				id = request.id,
				name = request.name,
				vars = request.data,
				unreliable = request.unreliable,
				func_success = request.func_success
			},
			ply = ply,
			entities = entities,
			equalDelay = 0,
			timeout = RealTime() + 5,
			isSuccess = false,
		})
	end)

	snet.Callback('snet_sv_entity_network_success', function(ply, id)
		for _, data in ipairs(entities_queue) do
			if not data.isSuccess and data.id == id then
				data.isSuccess = true
				return
			end
		end
	end)

	hook.Add('SetupPlayerVisibility', 'Slib_TemporaryEntityNetworkVisibility', function(ply)
		for _, data in ipairs(entities_queue) do
			for i = 1, #data.entities do
				local ent = data.entities[i]
				if IsValid(ent) and data.ply == ply then
					AddOriginToPVS(ent:GetPos())
				end
			end
		end
	end)

	hook.Add('Think', 'Slib_TemporaryEntityNetworkVisibilityChecker', function()
		local delay_infelicity = 0

		for i = #entities_queue, 1, -1 do
			local data = entities_queue[i]
			local request_data = data.request_data
			local ply = data.ply
			local backward = data.backward
			local entities = {}
			local entities_index = 0
			local real_time = RealTime()

			for k = 1, #data.entities do
				local ent = data.entities[k]
				if IsValid(ent) then
					entities_index = entities_index + 1
					entities[entities_index] = ent
				end
			end

			if data.timeout < real_time or entities_index == 0 or not IsValid(ply) then
				hook_Run('SNetEntitySuccessInvoked', false, request_data.name, ply, entities)
				table_remove(entities_queue, i)
			elseif data.isSuccess then
				hook_Run('SNetEntitySuccessInvoked', true, request_data.name, ply, entities)
				table_remove(entities_queue, i)
			elseif data.equalDelay < real_time then
				snet.Request('snet_cl_entity_network_callback',
					request_data.id, request_data.name, request_data.vars, backward)
					.Success(request_data.func_success)
					.Error(request_data.func_error)
					.Invoke(ply)

				data.equalDelay = real_time + 0.5 + delay_infelicity
				delay_infelicity = delay_infelicity + 0.1
			end
		end
	end)
else
	snet.Callback('snet_cl_entity_network_callback', function(ply, id, name, vars, backward)
		for i = 1, #vars do
			local ent = vars[i]
			if IsEntity(ent) and not IsValid(ent) then
				--ErrorNoHalt('Erroneous entity validation')
				return
			end
		end

		if snet.execute(backward, id, name, ply, unpack(vars)) then
			snet.Request('snet_sv_entity_network_success', id).InvokeServer()
		end
	end)

	SNET_ENTITY_VALIDATOR = function(backward, id, name, ply, ...)
		local args = { ... }
		if #args == 0 then return end

		for i = 1, #args do
			local ent = args[i]
			if IsEntity(ent) and not IsValid(ent) then
				snet.Request('snet_sv_entity_network_start', id, backward).InvokeServer()
				return false
			end
		end

		return true
	end

	local function DeepValidator(args)
		for _, value in pairs(args) do
			if (IsEntity(value) and not IsValid(value)) or (istable(value) and not DeepValidator(value)) then
				return false
			end
		end

		return true
	end

	SNET_DEEP_ENTITY_VALIDATOR = function(backward, id, name, ply, ...)
		local args = { ... }

		if not DeepValidator(args) then
			snet.Request('snet_sv_entity_network_start', id, backward, true).InvokeServer()
			return false
		end

		return true
	end
end
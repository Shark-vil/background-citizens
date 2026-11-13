local slib = slib
local snet = slib.Components.Network
local CLIENT = CLIENT
local SERVER = SERVER
local istable = istable
local isfunction = isfunction
local RealTime = RealTime
local string_len = string.len
local table_insert = table.insert
local table_HasValueBySeq = table.HasValueBySeq
local table_remove = table.remove
local xpcall = xpcall
local snet_Serialize = slib.Serialize
local util_Compress = util.Compress
local player_GetHumans = player.GetHumans
local net_Start = net.Start
local net_WriteString = net.WriteString
local net_WriteUInt = net.WriteUInt
local net_WriteData = net.WriteData
local net_WriteBool = net.WriteBool
local net_Send = net.Send
local net_SendToServer = net.SendToServer
local Error = slib.Error
local DebugError = slib.DebugError
local garbage_collection_timer_name = 'snet.TimerForDeletingObsoleteRequests'
--
local REQUEST_LIFE_TIME = snet.REQUEST_LIFE_TIME
local REQUEST_STORAGE = {}

local function SplitIntoPackages(text_data, max_size)
	local network_packages = {}
	local network_packages_index = 0

	for i = 1, #text_data, max_size do
		local single_package = util_Compress(text_data:sub(i, i + max_size - 1))
		network_packages_index = network_packages_index + 1
		network_packages[network_packages_index] = {
			data = single_package,
			length = string_len(single_package)
		}
	end

	return network_packages
end

function snet.Request(name, ...)
	local obj = {}
	obj.id = slib.UUID()
	obj.name = name
	obj.data = { ... }
	do
		local serialize_data = snet_Serialize(obj.data, true)
		if not serialize_data then
			serialize_data = snet_Serialize()
			DebugError('An error occurred while compressing data - ' .. name)
		end
		obj.packages = SplitIntoPackages(serialize_data, 4096)
	end
	obj.unreliable = nil
	obj.package_count = #obj.packages
	obj.package_index = 1
	obj.backward = false
	obj.func_success = nil
	obj.func_error = nil
	obj.func_complete = nil
	obj.lifetime = REQUEST_LIFE_TIME
	obj.receiver = {}
	obj.receiver_count = 1
	obj.receiver_complete_count = 0
	obj.progress_text = ''

	function obj.ProgressText(text)
		obj.progress_text = text
		return obj
	end

	function obj.SetLifeTime(time)
		obj.lifetime = time
		return obj
	end

	function obj.Success(func)
		if func and isfunction(func) then
			obj.func_success = func
			obj.backward = true
		end
		return obj
	end

	function obj.Error(func)
		if func and isfunction(func) then
			obj.func_error = func
			obj.backward = true
		end
		return obj
	end

	function obj.Complete(func)
		if func and isfunction(func) then
			obj.func_complete = func
			obj.backward = true
		end
		return obj
	end

	function obj.Eternal()
		obj.eternal = true
	end

	function obj.Invoke(receiver, unreliable)
		if CLIENT then return end

		if not istable(receiver) then
			receiver = { receiver }
		end

		local receivers = slib.ListFastPlayerParse(receiver)
		if #receivers == 0 then return obj end

		obj.receiver_count = #receivers
		obj.receiver = receivers

		snet.PushRequest(obj)
		obj.unreliable = unreliable or false

		local single_package = obj.packages[obj.package_index]
		local compressed_data = single_package.data
		local compressed_length = single_package.length

		net_Start('cl_network_rpc_callback', obj.unreliable)
		net_WriteString(obj.id)
		net_WriteUInt(compressed_length, 32)
		net_WriteData(compressed_data, compressed_length)
		net_WriteUInt(obj.package_index, 12)
		net_WriteUInt(obj.package_count, 12)
		net_WriteString(obj.name)
		net_WriteBool(obj.backward)
		net_WriteString(obj.progress_text)
		net_Send(receivers)
		return obj
	end

	function obj.InvokeAll(unreliable)
		if CLIENT then return end
		obj.Invoke(player_GetHumans(), unreliable)
		return obj
	end

	function obj.InvokeIgnore(receiver, unreliable)
		if CLIENT then return end
		local receivers = {}

		if isentity(receiver) then
			table_insert(receivers, receiver)
		end

		if #receivers == 0 then
			obj.Invoke(player_GetHumans(), unreliable)
		else
			local players = player_GetHumans()
			local player_list = {}
			for i = 1, #players do
				local ply = players[i]
				if not table_HasValueBySeq(receivers, ply) then
					table_insert(player_list, ply)
				end
			end
			obj.Invoke(player_list, unreliable)
		end

		return obj
	end

	function obj.InvokeServer(unreliable)
		if SERVER then return end

		snet.PushRequest(obj)
		obj.unreliable = unreliable or false

		local single_package = obj.packages[obj.package_index]
		local compressed_data = single_package.data
		local compressed_length = single_package.length

		net_Start('sv_network_rpc_callback', obj.unreliable)
		net_WriteString(obj.id)
		net_WriteUInt(compressed_length, 32)
		net_WriteData(compressed_data, compressed_length)
		net_WriteUInt(obj.package_index, 12)
		net_WriteUInt(obj.package_count, 12)
		net_WriteString(obj.name)
		net_WriteBool(obj.backward)
		net_WriteString(obj.progress_text)
		net_SendToServer()
		return obj
	end

	function obj:Clone()
		local clone = snet.Request(obj.name)
		clone.data = obj.data
		clone.packages = obj.packages
		clone.package_count = obj.package_count
		clone.package_index = obj.package_index
		clone.progress_text = obj.progress_text
		clone.backward = obj.backward
		clone.func_success = obj.func_success
		clone.func_error = obj.func_error
		clone.lifetime = obj.lifetime
		return clone
	end

	return obj
end

function snet.PushRequest(request)
	table_insert(REQUEST_STORAGE, {
		request = request,
		timeout = RealTime() + (request.lifetime or REQUEST_LIFE_TIME)
	})
end

function snet.PopRequest(id)
	local request
	local count = #REQUEST_STORAGE
	if count ~= 0 then
		if id then
			for i = 1, count do
				local data = REQUEST_STORAGE[i]
				if data and data.request and data.request.id == id then
					request = data
					table_remove(REQUEST_STORAGE, i)
					break
				end
			end
		else
			request = REQUEST_STORAGE[1]
			table_remove(REQUEST_STORAGE, 1)
		end
	end
	return request
end

function snet.PeekRequest()
	if #REQUEST_STORAGE ~= 0 then
		return REQUEST_STORAGE[1]
	end
end

function snet.GetRequestList()
	return REQUEST_STORAGE
end

function snet.Clear()
	REQUEST_STORAGE = {}
end

function snet.FindRequestById(id, to_extend)
	to_extend = to_extend or false

	for i = #REQUEST_STORAGE, 1, -1 do
		local data = REQUEST_STORAGE[i]
		if data and data.request and data.request.id == id then
			if to_extend then data.timeout = RealTime() + data.request.lifetime end
			return data.request
		end
	end
	return nil
end

function snet.RemoveRequestById(id)
	for i = #REQUEST_STORAGE, 1, -1 do
		local data = REQUEST_STORAGE[i]
		if data and data.request and data.request.id == id then
			table_remove(REQUEST_STORAGE, i)
			return true
		end
	end
	return false
end

if not timer.Exists(garbage_collection_timer_name) then
	local RunGarbageCollection = snet.RunGarbageCollection
	timer.Create(garbage_collection_timer_name, 1, 0, function()
		xpcall(function()
			RunGarbageCollection(REQUEST_STORAGE)
		end, function(error_message)
			Error('Attention! Something is creating errors in the request queue! Contact the developer to identify issues.')
			Error('NETWORK ERROR: ' .. error_message)
		end)
	end)
end
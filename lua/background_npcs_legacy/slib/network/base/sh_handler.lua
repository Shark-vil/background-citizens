local snet = slib.Components.Network
local CLIENT = CLIENT
local SERVER = SERVER
local table = table
local net = net
local hook = hook
local util = util
local isbool = isbool
local RealTime = RealTime
local table_remove = table.remove
local snet_Deserialize = slib.Deserialize
local util_Decompress = util.Decompress
--
local REQUEST_LIMITS_LIST = snet.REQUEST_LIMITS_LIST
local REQUEST_LIFE_TIME = snet.REQUEST_LIFE_TIME
local REQUEST_STORAGE = {}

local function RequestHandler(backward, id, name, ply, ...)
	if CLIENT then ply = LocalPlayer() end

	local data = snet.GetCallback(name)
	if not data then return false end

	if data.isAdmin and (not ply:IsAdmin() and not ply:IsSuperAdmin()) then
		return false
	end

	if data.limits then
		local is_exists = false

		for i = #REQUEST_LIMITS_LIST, 1, -1 do
			local value = REQUEST_LIMITS_LIST[i]
			if value and value.ply == ply and value.name == name then
				is_exists = true

				if value.nextTime <= RealTime() then
					table_remove(REQUEST_LIMITS_LIST, i)
					break
				end

				if value.current == value.limit then
					value.warning(ply, name)
				else
					value.current = value.current + 1
				end

				value.nextTime = RealTime() + data.limits.delay
				return false
			end
		end

		if not is_exists then
			REQUEST_LIMITS_LIST[#REQUEST_LIMITS_LIST + 1] = {
				ply = ply,
				name = name,
				nextTime = RealTime() + data.limits.delay,
				limit = data.limits.limit,
				current = 0,
				warning = data.limits.warning or function(warning_player, network_hook_name)
					MsgN('Attention! An attempt to hack or disable '
					.. 'the server is possible! Player - "' .. tostring(warning_player)
					.. '" is sending too many validation checks on the hook "' .. network_hook_name .. '"!')
				end
			}
		end
	end

	if data.validator then
		local validator_result = data.validator(backward, id, name, ply, ...)
		if isbool(validator_result) and not validator_result then return false end
	end

	data.execute(ply, ...)

	if data.auto_destroy then snet.RemoveCallback(name) end

	return true
end

function snet.execute(backward, id, name, ply, ...)
	local success = RequestHandler(backward, id, name, ply, ...)

	if backward then
		if CLIENT then
			if success then
				net.Start('sv_network_rpc_success')
			else
				net.Start('sv_network_rpc_error')
			end
			net.WriteString(id)
			net.SendToServer()
		else
			if success then
				net.Start('cl_network_rpc_success')
			else
				net.Start('cl_network_rpc_error')
			end
			net.WriteString(id)
			net.Send(ply)
		end
	end

	hook.Run('SNetRequestResult', id, name, reuslt, ...)

	return success
end

function snet.UploadProgressUpdate(id, progress_text, load_index, load_count, target_player)
	if SERVER then
		if target_player and isentity(target_player) and target_player:IsPlayer() then
			net.Start('cl_network_upload_progress_update')
			net.WriteString(id)
			net.WriteString(progress_text)
			net.WriteUInt(load_index, 12)
			net.WriteUInt(load_count, 12)
			net.Send(target_player)
		end
	else
		if not progress_text or string.len(progress_text) == 0 then return end
		progress_text = progress_text
		notification.AddProgress(id, progress_text, (1 / load_count) * load_index)
		if load_index >= load_count then
			notification.AddProgress(id, '✓ ' .. progress_text, 1)
			timer.Simple(3, function()
				notification.Kill(id)
			end)
		end
	end
end

local function NetReceiveHandler(len, ply)
	local id = net.ReadString()
	local compressed_length = net.ReadUInt(32)
	local compressed_data = net.ReadData(compressed_length)
	local package_index = net.ReadUInt(12)
	local package_count = net.ReadUInt(12)
	local name = net.ReadString()
	local backward = net.ReadBool()
	local progress_text = net.ReadString()

	if package_count == 1 then
		snet.UploadProgressUpdate(
			id,
			progress_text,
			package_index,
			package_count,
			ply
		)

		local vars = snet_Deserialize(util_Decompress(compressed_data))
		snet.execute(backward, id, name, ply, unpack(vars))
		return
	end

	local index, request = table.WhereFindBySeq(REQUEST_STORAGE, function(_, v) return v.id == id end)
	if request then
		request.package_index = package_index
		request.data = request.data .. util_Decompress(compressed_data)

		snet.UploadProgressUpdate(
			id,
			request.progress_text,
			request.package_index,
			request.package_count,
			ply
		)

		if request.package_index == request.package_count then
			local vars = snet_Deserialize(request.data)
			snet.execute(request.backward, request.id, request.name, ply, unpack(vars))
			table_remove(REQUEST_STORAGE, index)
			return
		else
			request.hold_time = RealTime() + REQUEST_LIFE_TIME
		end
	else
		snet.UploadProgressUpdate(
			id,
			progress_text,
			package_index,
			package_count,
			ply
		)

		REQUEST_STORAGE[#REQUEST_STORAGE + 1] = {
			id = id,
			name = name,
			hold_time = RealTime() + REQUEST_LIFE_TIME,
			backward = backward,
			package_index = package_index,
			package_count = package_count,
			progress_text = progress_text,
			data = util_Decompress(compressed_data)
		}
	end

	net.Start(SERVER and 'cl_network_get_next_package' or 'sv_network_get_next_package')
	net.WriteString(id)
	if SERVER then net.Send(ply) else net.SendToServer() end
end

if SERVER then
	net.Receive('sv_network_rpc_callback', NetReceiveHandler)
else
	net.Receive('cl_network_rpc_callback', NetReceiveHandler)
	net.Receive('cl_network_upload_progress_update', function()
		local id = net.ReadString()
		local progress_text = net.ReadString()
		local package_index = net.ReadUInt(12)
		local package_count = net.ReadUInt(12)

		snet.UploadProgressUpdate(
			id,
			progress_text,
			package_index,
			package_count
		)
	end)
end

timer.Create('SlibNetworkHandlerClientStorageAutoCleanRequestStorage', 1, 0, function()
	for i = #REQUEST_STORAGE, 1, -1 do
		local request = REQUEST_STORAGE[i]
		if not request or request.hold_time < RealTime() then
			if request then notification.Kill(request.id) end
			table_remove(REQUEST_STORAGE, i)
		end
	end

	-- print('Handler request storage count - ', #REQUEST_STORAGE)
end)
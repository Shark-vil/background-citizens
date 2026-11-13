local SERVER = SERVER
local net_Start = net.Start
local net_WriteString = net.WriteString
local net_WriteUInt = net.WriteUInt
local net_WriteData = net.WriteData
local net_Send = net.Send
local net_SendToServer = net.SendToServer
local net_ReadString = net.ReadString
local string_len = string.len
local timer_Simple = timer.Simple

local function ProgressTextUpdate(id, progress_text, load_index, load_count)
	if not progress_text or string_len(progress_text) == 0 then return end
	progress_text = progress_text
	notification.AddProgress(id, progress_text, (1 / load_count) * load_index)
	if load_index >= load_count then
		notification.AddProgress(id, '✓ ' .. progress_text, 1)
		timer_Simple(3, function()
			notification.Kill(id)
		end)
	end
end

local function NetworkNextPackage(_, ply)
	local id = net_ReadString()
	local request = snet.FindRequestById(id, true)
	if not request then return end

	request.package_index = request.package_index + 1
	if request.package_index > request.package_count then
		snet.RemoveRequestById(id)
		return
	end

	local single_package = request.packages[request.package_index]
	local compressed_data = single_package.data
	local compressed_length = single_package.length

	if SERVER then
		net_Start('cl_network_rpc_callback', request.unreliable)
		net_WriteString(request.id)
		net_WriteUInt(compressed_length, 32)
		net_WriteData(compressed_data, compressed_length)
		net_WriteUInt(request.package_index, 12)
		net_Send(ply)
	else
		net_Start('sv_network_rpc_callback', request.unreliable)
		net_WriteString(request.id)
		net_WriteUInt(compressed_length, 32)
		net_WriteData(compressed_data, compressed_length)
		net_WriteUInt(request.package_index, 12)
		net_SendToServer()
		ProgressTextUpdate(request.id, request.progress_text, request.package_index, request.package_count)
	end
end

if SERVER then
	net.Receive('sv_network_get_next_package', NetworkNextPackage)
else
	net.Receive('cl_network_get_next_package', NetworkNextPackage)
end
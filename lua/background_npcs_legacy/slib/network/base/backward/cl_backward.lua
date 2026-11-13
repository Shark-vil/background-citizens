local net = net
local snet = slib.Components.Network
local LocalPlayer = LocalPlayer
--

net.Receive('cl_network_rpc_success', function(len, ply)
	local id = net.ReadString()
	local request = snet.FindRequestById(id)
	if not request then return end
	request.receiver_complete_count = request.receiver_complete_count + 1

	if request.func_success then
		request.func_success(LocalPlayer(), request)
	end

	if request.receiver_complete_count >= request.receiver_count then
		if request.func_complete then
			request.func_complete()
		end
		snet.RemoveRequestById(id)
	end
end)

net.Receive('cl_network_rpc_error', function(len, ply)
	local id = net.ReadString()
	local request = snet.FindRequestById(id)
	if not request then return end

	if request.func_error then
		request.func_error(LocalPlayer(), request)
	end
end)
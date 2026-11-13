local net = net
local snet = slib.Components.Network
--

net.Receive('sv_network_rpc_success', function(len, ply)
	local id = net.ReadString()
	local request = snet.FindRequestById(id)
	if not request then return end
	request.receiver_complete_count = request.receiver_complete_count + 1

	if request.func_success then
		request.func_success(ply, request)
	end

	if request.receiver_complete_count >= request.receiver_count then
		if request.func_complete then
			request.func_complete(request.receiver, request)
		end
		snet.RemoveRequestById(id)
	end
end)

net.Receive('sv_network_rpc_error', function(len, ply)
	local id = net.ReadString()
	local request = snet.FindRequestById(id)
	if not request then return end

	if request.func_error then
		request.func_error(ply, request)
	end

	if not request.backward then
		request.receiver_count = request.receiver_count - 1
		if request.receiver_complete_count >= request.receiver_count then
			if request.func_complete then
				request.func_complete(request.receiver, request)
			end
			snet.RemoveRequestById(id)
		end
	end
end)

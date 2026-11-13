local snet = slib.Components.Network
local CLIENT = CLIENT
local snet_Request = snet.Request
--

function snet.Invoke(name, receiver, ...)
	if CLIENT then
		return snet_Request(name, ...).InvokeServer()
	end
	return snet_Request(name, ...).Invoke(receiver)
end

function snet.InvokeAll(name, ...)
	return snet_Request(name, ...).InvokeAll()
end

function snet.InvokeIgnore(name, receiver, ...)
	return snet_Request(name, ...).InvokeIgnore(receiver)
end

function snet.InvokeServer(name, ...)
	return snet_Request(name, ...).InvokeServer()
end
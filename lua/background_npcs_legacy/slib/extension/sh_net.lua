local originalNetReceive = net.Receive
local isstring = isstring
local isfunction = isfunction
--

local function GetCallbackFunction(messageName, func)
	return function(...)
		if hook.Run('slib.OnCallNetMessage', messageName, ...) == false then return end
		return func(...)
	end
end

function net.Receive(messageName, func, ...)
	if not isstring(messageName) or not isfunction(func) then return end
	return originalNetReceive(messageName, GetCallbackFunction(messageName, func), ...)
end
local originalConcommandAdd = concommand.Add
local isstring = isstring
local isfunction = isfunction
--

local function GetCallbackFunction(commandName, func)
	return function(...)
		if hook.Run('slib.OnCallCommand', commandName, ...) == false then return end
		return func(...)
	end
end

function concommand.Add(commandName, func, ...)
	if not isstring(commandName) or not isfunction(func) then return end
	return originalConcommandAdd(commandName, GetCallbackFunction(commandName, func), ...)
end
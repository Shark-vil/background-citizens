local dupeHandlers = {}

function slib.RegisterDupeHandler(handlerName, dupeIdentifier, func)
	if not isstring(dupeIdentifier) then return end
	if not isstring(handlerName) then return end
	if not isfunction(func) then return end

	dupeHandlers[handlerName] = {
		id = dupeIdentifier,
		func = func
	}
end

hook.Add('OnLoadDuplicator', 'Slib.CustomDuplicator.Handler', function(ply, id, data)
	for _, v in pairs(dupeHandlers) do
		if v.id == id then
			v.func(ply, data)
			return false
		end
	end
end)
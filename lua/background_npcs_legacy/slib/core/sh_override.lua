local FindMetaTable = FindMetaTable
local isentity = isentity
local istable = istable
--
local base_empty = function() end
local override_cache = {}

timer.Create('Slib.System.Override.GarbageCollector', 1, 0, function()
	local new_override_cache = {}

	for k, v in pairs(override_cache) do
		if istable(k) or (isentity(k) and IsValid(k)) then
			new_override_cache[k] = v
		end
	end

	override_cache = new_override_cache
end)

function slib.Override(data, function_name, func, not_use_original_base)
	if not istable(data) and not isentity(data) then return end

	override_cache[data] = override_cache[data] or {}

	local cache = override_cache[data]
	cache[function_name] = cache[function_name] or data[function_name]

	local base

	if not_use_original_base then
		base = data[function_name]
	else
		base = cache[function_name]
	end

	if not base then base = base_empty end

	data[function_name] = function(...)
		return func(base, ...)
	end
end

function slib.OverrideMetaTable(metatable_name, function_name, func, not_use_original_base)
	local data = FindMetaTable(metatable_name)
	if not data then return end
	slib.Override(data, function_name, func, not_use_original_base)
end
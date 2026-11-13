local GetConVar = GetConVar
local tostring = tostring

function slib.CvarCheckValue(cvar_name, check_value)
	local convar_object = GetConVar(cvar_name)
	if not convar_object then return false end
	local value = convar_object:GetString()
	local convert_value = tostring(check_value)
	return convert_value == value
end
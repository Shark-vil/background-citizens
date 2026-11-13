local snet = slib.Components.Network
local IsValid = IsValid
--
local validators = {}

function snet.RegisterValidator(validator_name, callback)
	validators[validator_name] = callback
end

function snet.GetValidator(validator_name)
	return validators[validator_name]
end

snet.RegisterValidator('entity', function(ply, uid, ent) return IsValid(ent) end)
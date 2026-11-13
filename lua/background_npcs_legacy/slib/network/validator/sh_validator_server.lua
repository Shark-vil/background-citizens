local slib = slib
local snet = slib.Components.Network
local timer = timer
local isfunction = isfunction
local SERVER = SERVER
--
local netowrk_name_to_client = slib.GetNetworkString('SNet', 'CL_ValidatorForServer')
local netowrk_name_to_server = slib.GetNetworkString('SNet', 'SV_ValidatorForServer')

if SERVER then
	snet.Callback(netowrk_name_to_server, function(ply, uid, validator_name, ...)
		local success = false
		local validator_method = snet.GetValidator(validator_name)
		if validator_method == nil then return end
		success = validator_method(ply, uid, ...)
		snet.Request(netowrk_name_to_client, uid, success).Invoke(ply)
	end).Period(0.1, 5)
else
	local callback_data = {}

	function snet.IsValidForServer(func_callback, validator_name, ...)
		validator_name = validator_name or 'entity'
		local uid = slib.GetChecksumUID(validator_name)
		local func = func_callback

		callback_data[uid] = function(ply, result)
			timer.Remove('SNetServerValidatorTimeout_' .. uid)

			if func and isfunction(func) then
				func(ply, result)
			end

			callback_data[uid] = nil
		end

		timer.Create('SNetServerValidatorTimeout_' .. uid, 1.5, 1, function()
			local data_callback = callback_data[uid]

			if data_callback then
				data_callback(LocalPlayer(), false)
			end
		end)

		snet.Request(netowrk_name_to_server, uid, validator_name, ...).InvokeServer()
	end

	snet.Callback(netowrk_name_to_client, function(ply, uid, success)
		local data_callback = callback_data[uid]

		if data_callback then
			data_callback(ply, success)
		end
	end)
end
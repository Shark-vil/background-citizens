local slib = slib
local string = string
local util = util
local SERVER = SERVER
--

local function ValidateNetworkName(str_name)
	return string.Replace(string.lower(str_name), ' ', '_')
end

local function NormalizeNetworkName(category_name, network_string_name)
	category_name = ValidateNetworkName(category_name)
	network_string_name = ValidateNetworkName(network_string_name)

	return category_name .. '_' .. network_string_name
end

function slib.AddNetworkString(category_name, network_string_name)
	local normalize_name = NormalizeNetworkName(category_name, network_string_name)

	if SERVER then
		util.AddNetworkString(normalize_name)
	end

	return normalize_name
end

function slib.GetNetworkString(category_name, network_string_name)
	return NormalizeNetworkName(category_name, network_string_name)
end
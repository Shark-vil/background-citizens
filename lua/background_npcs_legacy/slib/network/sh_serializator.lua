local snet = slib.Components.Network
local TYPE_TABLE = TYPE_TABLE
local TYPE_NUMBER = TYPE_NUMBER
local TYPE_STRING = TYPE_STRING
local TYPE_BOOL = TYPE_BOOL
local TYPE_ENTITY = TYPE_ENTITY
local TYPE_VECTOR = TYPE_VECTOR
local TYPE_ANGLE = TYPE_ANGLE
local TYPE_MATRIX = TYPE_MATRIX
local TYPE_COLOR = TYPE_COLOR
local IsValid = IsValid
local IsColor = IsColor
local type = type
local istable = istable
local isfunction = isfunction
local pairs = pairs
local Entity = Entity
local Matrix = Matrix
local Color = Color
local Vector = Vector
local Angle = Angle
local tonumber = tonumber
local table_insert = table.insert
local util_TableToJSON = util.TableToJSON
local util_JSONToTable = util.JSONToTable
local string_Split = string.Split
--
local ValueSerialize = {
	[TYPE_TABLE] = function(t, v)
		local getdatatable = slib.Serialize(v, false)
		if getdatatable then return t, getdatatable end
	end,
	[TYPE_NUMBER] = function(t, v) return t, v end,
	[TYPE_STRING] = function(t, v) return t, v end,
	[TYPE_BOOL] = function(t, v) return t, v == true and 1 or 0 end,
	[TYPE_ENTITY] = function(t, v)
		if not v or not IsValid(v) then return end
		local index = v:EntIndex()
		if index == -1 then return end
		return t, index
	end,
	[TYPE_VECTOR] = function(t, v) return t, v.x .. ':' .. v.y .. ':' .. v.z end,
	[TYPE_ANGLE] = function(t, v) return t, v.x .. ':' .. v.y .. ':' .. v.z end,
	[TYPE_MATRIX] = function(t, v)
		local value = ''
		for row = 1, 4 do
			for col = 1, 4 do
				value = value .. v:GetField(row, col)
				if col ~= 4 then value = value .. ':' end
			end
			if row ~= 4 then value = value .. ';' end
		end
		return t, value
	end,
	[TYPE_COLOR] = function(t, v) return t, v.r .. ':' .. v.g .. ':' .. v.b .. ':' .. v.a end,
}

local function GetValueType(value)
	local typeid

	if IsColor(value) then
		typeid = TYPE_COLOR
	else
		typeid = TypeID(value)
	end

	return typeid
end

local function GetValueToCompress(k, v)
	local key_type, key_data, val_type, val_data, typeid, converter
	typeid = GetValueType(k)
	converter = ValueSerialize[typeid]

	if converter then
		key_type, key_data = converter(typeid, k)
		typeid = GetValueType(v)
		converter = ValueSerialize[typeid]

		if converter then
			val_type, val_data = converter(typeid, v)

			return {key_type, key_data, val_type, val_data,}
		end
	end

	return nil
end

function slib.Serialize(data, numbered_parsing, return_table)
	local datatable = {}

	if type(data) == 'table' and not data._snet_disable then
		if data._snet_getdata and isfunction(data._snet_getdata) then
			local getdata = data._snet_getdata()

			if istable(getdata) then
				datatable = getdata
			end
		else
			if numbered_parsing then
				for k = 1, #data do
					local result = GetValueToCompress(k, data[k])

					if result then
						table_insert(datatable, result)
					end
				end
			else
				for k, v in pairs(data) do
					local result = GetValueToCompress(k, v)

					if result then
						table_insert(datatable, result)
					end
				end
			end
		end
	end

	if not return_table then
		return util_TableToJSON(datatable)
	else
		return datatable
	end
end
-- Compatibility with older versions
snet.Serialize = slib.Serialize

local ValueDeserialize = {
	[TYPE_TABLE] = function(v)
		local getdatatable = slib.Deserialize(v)
		if getdatatable then return getdatatable end
	end,
	[TYPE_NUMBER] = function(v) return v end,
	[TYPE_STRING] = function(v) return v end,
	[TYPE_BOOL] = function(v) return v == 1 and true or false end,
	[TYPE_ENTITY] = function(v) return Entity(v) end,
	[TYPE_VECTOR] = function(v)
		local value = string_Split(v, ':')
		return Vector(tonumber(value[1]), tonumber(value[2]), tonumber(value[3]))
	end,
	[TYPE_ANGLE] = function(v)
		local value = string_Split(v, ':')
		return Angle(tonumber(value[1]), tonumber(value[2]), tonumber(value[3]))
	end,
	[TYPE_MATRIX] = function(v)
		local rows = string_Split(v, ';')
		local tbl = {}
		for i = 1, 4 do
			local col = string_Split(rows[i], ':')
			tbl[i] = { tonumber(col[1]), tonumber(col[2]), tonumber(col[3]), tonumber(col[4]) }
		end
		return Matrix(tbl)
	end,
	[TYPE_COLOR] = function(v)
		local value = string_Split(v, ':')
		return Color(tonumber(value[1]), tonumber(value[2]), tonumber(value[3]), tonumber(value[4]))
	end,
}

function slib.Deserialize(json_datatable)
	local datatable = {}
	local t_type = type(json_datatable)
	local getdatatable

	if t_type == 'string' then
		getdatatable = util_JSONToTable(json_datatable)
	elseif t_type == 'table' then
		getdatatable = json_datatable
	end

	if not getdatatable then
		return datatable
	end

	for i = 1, #getdatatable do
		local key, value
		local data = getdatatable[i]

		do
			local deconverter = ValueDeserialize[data[1]]

			if deconverter then
				key = deconverter(data[2])
			end
		end

		if key ~= nil then
			local deconverter = ValueDeserialize[data[3]]

			if deconverter then
				value = deconverter(data[4])
				datatable[key] = value
			end
		end
	end

	return datatable
end
-- Compatibility with older versions
snet.Deserialize = slib.Deserialize

function snet.ValueIsValid(value)
	local typeid = TypeID(value)
	return typeid ~= nil and ValueSerialize[typeid] ~= nil
end

function snet.GetNormalizeDataTable(data)
	local new_data = {}
	if not istable(data) then return new_data end
	if data._snet_disable then return new_data end

	if data._snet_getdata and isfunction(data._snet_getdata) then
		local getdata = data._snet_getdata()
		if istable(getdata) then return getdata end

		return new_data
	end

	for k, v in pairs(data) do
		if not snet.ValueIsValid(k) or not snet.ValueIsValid(v) then
			continue
		end

		if istable(v) then
			new_data[k] = snet.GetNormalizeDataTable(v)
		else
			new_data[k] = v
		end
	end

	return new_data
end
slib.GetNormalizeDataTable = snet.GetNormalizeDataTable
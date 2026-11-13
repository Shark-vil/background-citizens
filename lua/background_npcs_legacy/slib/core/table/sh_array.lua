local type = type
local next = next
local math_random = math.random
local table_remove = table.remove
local table_Random = table.Random
local table_insert = table.insert
local type = type
--

function table.isArray(t)
	return #t > 0 and next(t, #t) == nil
end

function table.HasValueBySeq(t, val)
	for i = 1, #t do
		if t[i] == val then return true end
	end

	return false
end

function table.WhereHasValueBySeq(t, condition)
	for i = 1, #t do
		if condition(i, t[i]) then return true end
	end

	return false
end

function table.FindBySeq(t, find_value)
	for i = 1, #t do
		local value = t[i]
		if find_value == value then return i, value end
	end

	return -1, nil
end

function table.WhereFindBySeq(t, condition)
	for i = 1, #t do
		local value = t[i]
		if condition(i, value) then return i, value end
	end

	return -1, nil
end

function table.shuffle(t)
	local tbl = {}

	for i = 1, #t do
		tbl[i] = t[i]
	end

	for i = #tbl, 2, -1 do
		local j = math_random(i)
		tbl[i], tbl[j] = tbl[j], tbl[i]
	end

	return tbl
end

function table.RandomBySeq(t)
	local count = #t
	if count == 0 then return nil end
	if count == 1 then return t[1] end

	local index = math_random(count)
	return t[index], index
end

function table.RandomOmitBySeq(t, v)
	if v == nil then return table_Random(t) end
	local count = #t
	if count == 0 then return nil end

	if count == 1 then
		local first_value = t[1]
		if first_value == v then return nil end

		return first_value
	end

	local random_value = v
	repeat
		random_value = table_Random(t)
	until random_value ~= v

	return random_value
end

function table.pop(t)
	local index = #t
	local v = t[index]
	t[index] = nil
	return v
end

function table.push(t, v)
	local index = #t + 1
	t[index] = v
	return index, v
end

function table.GetFirstValueBySeq(t)
	return t[1]
end

function table.GetFirstKeyBySeq(t)
	if t[1] ~= nil then return 1 end

	return nil
end

function table.RemoveValueBySeq(t, v)
	for i = #t, 1, -1 do
		if t[i] == v then
			return table_remove(t, i)
		end
	end
end

function table.RemoveAllValueBySeq(t, v)
	for i = #t, 1, -1 do
		if t[i] == v then
			table_remove(t, i)
		end
	end

	return t
end

function table.EqualsBySeq(t1, t2)
	if type(t1) ~= 'table' or type(t2) ~= 'table' then return false end

	for i = 1, #t1 do
		local v = t1[i]

		if type(v) == 'table' then
			if not table.EqualsBySeq(v, t2[i]) then return false end
		elseif v ~= t2[i] then
			return false
		end
	end

	return true
end

function table.ValuesToArray(t)
	if table.isArray(t) then return t end

	local new_table = {}
	local index = 1

	for _, value in pairs(t) do
		new_table[index] = value
		index = index + 1
	end

	return  new_table
end

function table.KeysToArray(t)
	if table.isArray(t) then return t end

	local new_table = {}
	local index = 1

	for key, _ in pairs(t) do
		new_table[index] = key
		index = index + 1
	end

	return  new_table
end

-- function table.Combine(dest, source)
-- 	local new_index = #dest + 1

-- 	for i = 1, #source do
-- 		dest[new_index] = source[i]
-- 		new_index = new_index + 1
-- 	end

-- 	return dest
-- end

function table.Combine(dest, ...)
	local new_index = #dest + 1
	local tables = { ... }

	for table_index = 1, #tables do
		local table_value = tables[table_index]
		for index = 1, #table_value do
			dest[new_index] = table_value[index]
			new_index = new_index + 1
		end
	end

	return dest
end

function table.InsertNoValue(t, v, condition)
	local index

	if condition then
		index = table.WhereFindBySeq(t, condition)
	else
		index = table.FindBySeq(t, v)
	end

	if index ~= -1 then
		return index, false
	end

	return table_insert(t, v), true
end

function table.InsertOrReplace(t, v, condition)
	local index, exists = table.InsertNoValue(t, v, condition)

	if exists then
		t[index] = v
	end

	return index
end
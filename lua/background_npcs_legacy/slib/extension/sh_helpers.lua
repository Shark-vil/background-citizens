local engine_TickInterval = engine.TickInterval
local math_sqrt = math.sqrt
local string_Trim = string.Trim
local tostring = tostring
local math_random = math.random
local table_Copy = table.Copy
local istable = istable
local engine_GetAddons = engine.GetAddons
local ipairs = ipairs
local isfunction = isfunction
local IsValid = IsValid
local IsEntity = IsEntity
local isnumber = isnumber
local Entity = Entity
--
local call_markers = {}
local language_codes = {
	['bg'] = 'bulgarian',
	['cs'] = 'czech',
	['da'] = 'danish',
	['de'] = 'german',
	['el'] = 'greek',
	['en'] = 'english',
	['en-pt'] = 'pirate english',
	['es-es'] = 'spanish',
	['et'] = 'estonian',
	['fi'] = 'finnish',
	['fr'] = 'french',
	['he'] = 'hebrew',
	['hr'] = 'croatian',
	['hu'] = 'hungarian',
	['it'] = 'italian',
	['ja'] = 'japanese',
	['ko'] = 'korean',
	['lt'] = 'lithuanian',
	['nl'] = 'dutch',
	['no'] = 'norwegian',
	['pl'] = 'polish',
	['pt-br'] = 'portuguese (brazil)',
	['pt-pt'] = 'portuguese (portugal)',
	['ru'] = 'russian',
	['sk'] = 'slovak',
	['sv-se'] = 'swedish',
	['th'] = 'thai',
	['tr'] = 'turkish',
	['uk'] = 'ukrainian',
	['vi'] = 'vietnamese',
	['zh-cn'] = 'chinese simplified',
	['zh-tw'] = 'chinese traditional',
}

function slib.GetLanguageCode(select_language)
	local _select_language = tostring(select_language):lower()
	for code, value in pairs(language_codes) do
		if value == _select_language or code == _select_language then return code, value end
	end
	return 'en', 'english'
end

function slib.language(data, select_language)
	if not istable(data) then return '' end

	if select_language and isstring(select_language) then
		if select_language and data[select_language] then return data[select_language] end

		local code, lang = slib.GetLanguageCode(select_language)
		if code and data[code] then return data[code] end
		if lang and data[lang] then return data[lang] end
	end

	if CLIENT then
		local current_language = GetConVar('cl_language'):GetString()
		if data[current_language] then return data[current_language] end

		local code, lang = slib.GetLanguageCode(current_language)
		if code and data[code] then return data[code] end
		if lang and data[lang] then return data[lang] end
	end

	if data['default'] then return data['default'] end

	return ''
end

function slib.chance(percent)
	if percent < 0 then percent = 0 end
	if percent > 100  then percent = 100 end
	if percent == 0 then return false end
	if percent == 100 then return true end
	return percent >= math_random(1, 100)
end

function slib.GetServerTickrate()
	return 1 / engine_TickInterval()
end

do
	local CLIENT = CLIENT
	local tr, util_TraceLine, util_IsInWorld
	tr = {
		mask = MASK_SOLID_BRUSHONLY,
		collisiongroup = COLLISION_GROUP_WORLD,
		output = {}
	}
	if CLIENT then
		util_TraceLine = util.TraceLine
	else
		util_IsInWorld = util.IsInWorld
	end
	function slib.IsInWorld(pos)
		if CLIENT then
			tr.start = pos
			tr.endpos = pos
			return not util_TraceLine(tr).HitWorld
		else
			return util_IsInWorld(pos)
		end
	end
end

function slib.magnitude(vec)
	local magnitude = vec
	magnitude = magnitude.x ^ 2 + magnitude.y ^ 2 + magnitude.z ^ 2
	magnitude = math_sqrt(magnitude)
	return magnitude
end

function slib.StringLinePairs(text, start_index)
	if not text or not isstring(text) then
		text = tostring(text)
	end

	if start_index and isnumber(start_index) then
		start_index = start_index
	end

	local line_index = 1
	local text_lines = {}
	local temp_data = text .. '\n'

	for text_line in temp_data:gmatch('(.-)\n') do
		if not text_line then continue end

		text_line = string_Trim(text_line)
		if #text_line == 0 then continue end

		text_lines[line_index] = text_line
		line_index = line_index + 1
	end

	local parse_index = 0

	if start_index then
		parse_index = start_index - 1
		if parse_index < 0 then
			parse_index = 0
		end
	end

	return function()
		parse_index = parse_index + 1
		if parse_index <= line_index and text_lines[parse_index] ~= nil then
			return parse_index, text_lines[parse_index]
		end
	end
end

function math.sign(x)
	return x > 0 and 1 or x < 0 and -1 or 0
end

function slib.TryGetEntity(obj)
	local ent
	if IsEntity(obj) then
		ent = obj
	elseif isnumber(obj) then
		ent = Entity(obj)
	end
	if IsValid(ent) then return ent end
end

function slib.MoveTowardsVector(current_vector, target_vector, delta_time)
	local direction_vector = target_vector - current_vector
	local magnitude = slib.magnitude(direction_vector)
	if magnitude <= delta_time or magnitude == 0 then
		return target_vector
	end
	return current_vector + direction_vector / magnitude * delta_time
end

function slib.MoveTowardsNumber(current_number, target_number, delta_time)
	if math.abs(target_number - current_number) <= delta_time then
		return target_number
	end
	return current_number + math.sign(target_number - current_number) * delta_time
end

function slib.MarkCall(name, nesting)
	local debug_info = debug.getinfo(nesting or 3, 'S')
	call_markers[name] = debug_info
end

function slib.GetCallMarker(name, destroy_after_getting)
	destroy_after_getting = destroy_after_getting or false

	if call_markers[name] then
		local response = table_Copy(call_markers[name])

		if destroy_after_getting then
			call_markers[name] = nil
		end

		return response
	end
end

function slib.GetAddon(wsid)
	wsid = isstring(wsid) and wsid or tostring(wsid)

	for _, addon in ipairs(engine_GetAddons()) do
		if tostring(addon.wsid)	== wsid and addon.mounted then
			return addon
		end
	end
end

function slib.ClientAction(func)
	if SERVER or not isfunction(func) then return end
	func()
end

function slib.ServerAction(func)
	if CLIENT or not isfunction(func) then return end
	func()
end
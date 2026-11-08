--[[
	Small shared helpers. Replace the slib helpers and table extensions.
		bgNPC.Util   - random, ids, language, world checks, doors, view checks, entity timers
		bgNPC.Table  - array helpers
--]]

local Util = bgNPC.Util or {}
bgNPC.Util = Util
local Table = bgNPC.Table or {}
bgNPC.Table = Table

--

-- ---------------------------------------------------------------------------
-- Random and ids
-- ---------------------------------------------------------------------------

-- @param percent number 0..100
function Util.Chance(percent)
	if percent <= 0 then return false end
	if percent >= 100 then return true end
	return percent >= math.random(1, 100)
end

local last_uid = 0
-- Unique number within the current session.
function Util.NextId()
	last_uid = last_uid + 1
	return last_uid
end

function Util.UUID()
	return (string.gsub('xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx', '[xy]', function(c)
		return string.format('%x', c == 'x' and math.random(0, 0xf) or math.random(8, 0xb))
	end))
end

-- ---------------------------------------------------------------------------
-- Language
-- ---------------------------------------------------------------------------

local LANGUAGE_CODES = {
	['bg'] = 'bulgarian', ['cs'] = 'czech', ['da'] = 'danish', ['de'] = 'german',
	['el'] = 'greek', ['en'] = 'english', ['en-pt'] = 'pirate english', ['es-es'] = 'spanish',
	['et'] = 'estonian', ['fi'] = 'finnish', ['fr'] = 'french', ['he'] = 'hebrew',
	['hr'] = 'croatian', ['hu'] = 'hungarian', ['it'] = 'italian', ['ja'] = 'japanese',
	['ko'] = 'korean', ['lt'] = 'lithuanian', ['nl'] = 'dutch', ['no'] = 'norwegian',
	['pl'] = 'polish', ['pt-br'] = 'portuguese (brazil)', ['pt-pt'] = 'portuguese (portugal)',
	['ru'] = 'russian', ['sk'] = 'slovak', ['sv-se'] = 'swedish', ['th'] = 'thai',
	['tr'] = 'turkish', ['uk'] = 'ukrainian', ['vi'] = 'vietnamese',
	['zh-cn'] = 'chinese simplified', ['zh-tw'] = 'chinese traditional',
}

-- @return string code ('en'), string name ('english')
function Util.LanguageCode(language)
	language = tostring(language or ''):lower()
	for code, name in pairs(LANGUAGE_CODES) do
		if code == language or name == language then return code, name end
	end
	return 'en', 'english'
end

-- Language of the local player (client) or of the given player (server).
function Util.GetLanguage(ply)
	local language
	if CLIENT then
		language = GetConVar('bgn_cl_ui_language'):GetString()
		if language == 'auto' then language = GetConVar('gmod_language'):GetString() end
	elseif IsValid(ply) then
		language = ply:GetInfo('bgn_cl_language')
	end
	return Util.LanguageCode(language)
end

--[[
	Picks a translation from a table:
		Util.Lang({ default = 'Hello', russian = 'Привет' })
	Keys can be language names or codes. Falls back to "default".
--]]
function Util.Lang(data, ply_or_language)
	if not istable(data) then return '' end

	local code, name
	if isstring(ply_or_language) then
		code, name = Util.LanguageCode(ply_or_language)
	else
		code, name = Util.GetLanguage(ply_or_language)
	end

	return data[name] or data[code] or data['default'] or ''
end

if CLIENT then
	CreateClientConVar('bgn_cl_ui_language', 'auto', true, false, 'Language of the mod: auto (the game language), english, russian.')
	CreateClientConVar('bgn_cl_language', 'en', false, true, 'Synchronized with gmod_language, do not change.')
	local function SyncLanguage()
		RunConsoleCommand('bgn_cl_language', (Util.GetLanguage()))
	end
	cvars.AddChangeCallback('gmod_language', SyncLanguage, 'bgn_cl_language')
	cvars.AddChangeCallback('bgn_cl_ui_language', SyncLanguage, 'bgn_cl_language')
	hook.Add('InitPostEntity', 'BGN_SyncLanguage', SyncLanguage)
end

-- ---------------------------------------------------------------------------
-- World
-- ---------------------------------------------------------------------------

do
	local trace = { mask = MASK_SOLID_BRUSHONLY, collisiongroup = COLLISION_GROUP_WORLD, output = {} }

	function Util.IsInWorld(pos)
		if SERVER then return util.IsInWorld(pos) end
		trace.start = pos
		trace.endpos = pos
		return not util.TraceLine(trace).HitWorld
	end
end

-- "Infinite map" addon support.
function Util.IsInfinityMap()
	return file.Exists('infmap/' .. game.GetMap(), 'LUA')
end

local DOOR_CLASSES = {
	['func_door'] = true,
	['func_door_rotating'] = true,
	['prop_door_rotating'] = true,
}

function Util.IsDoor(ent)
	return IsValid(ent) and DOOR_CLASSES[ent:GetClass()] == true
end

-- Not a door or no data: treated as locked.
function Util.IsDoorLocked(ent)
	if not Util.IsDoor(ent) then return true end
	local locked = ent:GetInternalVariable('m_bLocked')
	if isbool(locked) then return locked end
	return true
end

-- ---------------------------------------------------------------------------
-- View
-- ---------------------------------------------------------------------------

-- Is the position in front of the entity's eyes. radius: 90 by default (slib compatible formula).
function Util.IsInView(ent, pos, radius)
	local viewer = ent.GetViewEntity and ent:GetViewEntity() or ent
	if not IsValid(viewer) or not viewer.EyePos or not viewer.GetAimVector then return true end

	local diff = pos - viewer:EyePos()
	local len = diff:Length()
	if len == 0 then return true end

	return viewer:GetAimVector():Dot(diff) / len > math.pi / (radius or 90)
end

-- Is the target directly visible from the entity's eyes.
function Util.CanSeeEntity(ent, target, check_view)
	if not IsValid(ent) or not IsValid(target) then return false end

	local target_pos = target:LocalToWorld(target:OBBCenter())
	if check_view and not Util.IsInView(ent, target_pos) then return false end

	local eye_pos
	if ent.EyePos then
		eye_pos = ent:EyePos()
	else
		local center = ent:OBBCenter()
		center.z = ent:OBBMaxs().z
		eye_pos = ent:LocalToWorld(center)
	end

	local tr = util.TraceLine({ start = eye_pos, endpos = target_pos, filter = ent })
	if not tr.Hit then return false end

	local hit = tr.Entity
	return hit == target or (IsValid(hit) and hit:IsVehicle() and hit:GetDriver() == target)
end

function Util.IsAnyPlayerLooking(pos)
	local players = player.GetAll()
	for i = 1, #players do
		if Util.IsInView(players[i], pos) then return true end
	end
	return false
end

-- ---------------------------------------------------------------------------
-- Entity timers
-- ---------------------------------------------------------------------------

local function EntityTimerName(ent, name)
	return 'BGN_ENT_TIMER_' .. util.CRC(ent:EntIndex() .. name)
end

-- Timer bound to an entity: stops by itself when the entity is removed.
function Util.EntityTimer(ent, name, delay, repetitions, func)
	local timer_name = EntityTimerName(ent, name)
	timer.Create(timer_name, delay, repetitions, function()
		if not IsValid(ent) then
			timer.Remove(timer_name)
			return
		end
		func(ent)
	end)
end

function Util.RemoveEntityTimer(ent, name)
	timer.Remove(EntityTimerName(ent, name))
end

function Util.EntityTimerExists(ent, name)
	return timer.Exists(EntityTimerName(ent, name))
end

if SERVER then
	-- Smoothly fades the entity (and its weapon) out, then removes it.
	function Util.FadeRemove(ent, step)
		if not IsValid(ent) or ent.bgn_fade_remove then return end
		ent.bgn_fade_remove = true
		step = step or 1

		ent:SetRenderMode(RENDERMODE_TRANSCOLOR)
		Util.EntityTimer(ent, 'fade_remove', .01, 0, function()
			local alpha = ent:GetColor().a - step
			if alpha <= 0 then
				ent:Remove()
				return
			end

			local color = ColorAlpha(ent:GetColor(), alpha)
			ent:SetColor(color)

			local weapon = ent.GetActiveWeapon and ent:GetActiveWeapon()
			if IsValid(weapon) then
				weapon:SetRenderMode(RENDERMODE_TRANSCOLOR)
				weapon:SetColor(color)
			end
		end)
	end
end

-- ---------------------------------------------------------------------------
-- Notifications
-- ---------------------------------------------------------------------------

local NOTIFY_TYPES = { generic = 0, error = 1, undo = 2, hint = 3, cleanup = 4 }

-- Shows notification.AddLegacy on the player's screen. type: 'generic'|'error'|'undo'|'hint'|'cleanup'
function Util.Notify(ply, text, notify_type, length, sound)
	notify_type = NOTIFY_TYPES[notify_type] or notify_type or 0

	if SERVER then
		bgNPC.Net.Send('bgn.notify', ply, text, notify_type, length, sound)
		return
	end

	notification.AddLegacy(text or '', notify_type, length or 3)
	if sound then surface.PlaySound(sound) end
end

if CLIENT then
	bgNPC.Net.Receive('bgn.notify', function(_, text, notify_type, length, sound)
		Util.Notify(nil, text, notify_type, length, sound)
	end)
end

-- Returns a hook function registered by another addon (or nil).
function Util.GetHook(event_name, hook_name)
	local list = hook.GetTable()[event_name]
	return list and list[hook_name]
end

-- ---------------------------------------------------------------------------
-- Table (arrays)
-- ---------------------------------------------------------------------------

-- @return value, index
function Table.Random(t)
	local count = #t
	if count == 0 then return nil end
	local index = math.random(count)
	return t[index], index
end

function Table.HasValue(t, value)
	for i = 1, #t do
		if t[i] == value then return true end
	end
	return false
end

-- @return number index or -1, value
function Table.FindWhere(t, condition)
	for i = 1, #t do
		local value = t[i]
		if condition(i, value) then return i, value end
	end
	return -1, nil
end

function Table.HasWhere(t, condition)
	return Table.FindWhere(t, condition) ~= -1
end

-- Removes the first occurrence. @return boolean removed
function Table.RemoveValue(t, value)
	for i = 1, #t do
		if t[i] == value then
			table.remove(t, i)
			return true
		end
	end
	return false
end

-- Inserts the value if it is not in the array yet. @return boolean inserted
function Table.InsertUnique(t, value)
	if Table.HasValue(t, value) then return false end
	t[#t + 1] = value
	return true
end

-- Appends all values of the given arrays to dest. @return dest
function Table.Append(dest, ...)
	for k = 1, select('#', ...) do
		local source = select(k, ...)
		if istable(source) then
			for i = 1, #source do dest[#dest + 1] = source[i] end
		end
	end
	return dest
end

-- @return a shuffled copy, the source array is not changed
function Table.Shuffle(t)
	local copy = {}
	for i = 1, #t do copy[i] = t[i] end
	for i = #copy, 2, -1 do
		local j = math.random(i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

-- Non-empty sequence without extra keys.
function Table.IsArray(t)
	return istable(t) and #t > 0 and next(t, #t) == nil
end

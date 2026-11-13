-- local math_pi = math.pi
-- local util_TraceLine = util.TraceLine
--
local meta = FindMetaTable('Player')

function meta:slibNotify(text, notify_type, length, sound_name)
	text = text or ''

	if isstring(notify_type) then
		if notify_type == 'generic' then
			notify_type = 0
		elseif notify_type == 'error' then
			notify_type = 1
		elseif notify_type == 'undo' then
			notify_type = 2
		elseif notify_type == 'hint' then
			notify_type = 3
		elseif notify_type == 'cleanup' then
			notify_type = 4
		else
			notify_type = 0
		end
	end

	notify_type = notify_type or 0
	length = length or 3

	if SERVER then
		snet.Invoke('slib_player_notify', self, text, notify_type, length, sound_name)
		return
	end

	notification.AddLegacy(text, notify_type, length)

	if sound_name then
		surface.PlaySound(sound_name)
	end
end

function meta:snetIsReady()
	return self.snet_ready or false
end

function meta:slibGetActiveTool(tool_name, ignore_gmod_tool_active)
	ignore_gmod_tool_active = ignore_gmod_tool_active or false

	if not ignore_gmod_tool_active then
		local wep = self:GetActiveWeapon()
		if not IsValid(wep) or wep:GetClass() ~= 'gmod_tool' then return nil end
	end

	local tool = self:GetTool()
	if not tool or not tool.GetMode or tool:GetMode() ~= tool_name then return nil end

	return tool
end

-- function meta:slibIsViewVector(pos, radius)
-- 	radius = radius or 90

-- 	local DirectionAngle = math_pi / radius
-- 	local EntityDifference = pos - self:EyePos()
-- 	local EntityDifferenceDot = self:GetAimVector():Dot(EntityDifference) / EntityDifference:Length()

-- 	return EntityDifferenceDot > DirectionAngle
-- end

-- function meta:slibIsTranceEntity(target, distance, check_view_vector)
-- 	distance = distance or 1000

-- 	local target_pos = target:LocalToWorld(target:OBBCenter())
-- 	local player_eye_pos = self:EyePos()

-- 	if check_view_vector and not self:slibIsViewVector(target_pos) then return false end

-- 	local tr = util_TraceLine({
-- 		start = player_eye_pos,
-- 		endpos = target_pos,
-- 		filter = function(ent)
-- 			if ent ~= self and ent == target then return true end
-- 		end
-- 	})

-- 	return tr.Hit
-- end

function meta:slibLanguage(data)
	return slib.language(data, self:slibGetLanguage())
end

function meta:slibGetLanguage()
	local lang, code

	if CLIENT then
		lang = GetConVar('cl_language'):GetString()
		code, lang = slib.GetLanguageCode(lang)
	else
		lang = self:slibGetVar('slib_client_language', 'english')
		code = self:slibGetVar('slib_client_language_code', 'en')
	end

	return lang, code
end
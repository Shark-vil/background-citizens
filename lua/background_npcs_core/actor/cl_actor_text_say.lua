--[[
	Lines over the actors' heads: a dark plate with the speaker's name in the team color, an accent bar
	and the line wrapped by words. Rises and fades in, fades out at the end and with the distance.
--]]

local FONT, FONT_NAME = 'BGN_SpeakingFont', 'BGN_SpeakingName'
local SCALE = 0.09
local MAX_WIDTH = 480 -- text width on the plate, px
local PAD_X, PAD_Y, BAR, GAP, ARROW = 14, 9, 4, 3, 8
local FADE_IN, FADE_OUT, RISE = 0.2, 0.5, 4
local DIST, DIST_FADE = 800, 200
local HEAD_BONE = 'ValveBiped.Bip01_Head1'
local HEAD_OFFSET = Vector(0, 0, 14)

local PLATE = Color(14, 16, 20, 205)
local TEXT = Color(236, 238, 242)
local ACCENT_DEFAULT = Color(196, 200, 210)
local ACCENTS = {
	police = Color(92, 156, 255),
	medics = Color(80, 214, 150),
	bandits = Color(236, 112, 72),
	zombies = Color(150, 200, 60),
}

local speaking_actors = {}

local function RemoveSpeakByUid(uid)
	for i = #speaking_actors, 1, -1 do
		if speaking_actors[i].uid == uid then table.remove(speaking_actors, i) end
	end
end

local function Accent(actor)
	for team, color in pairs(ACCENTS) do
		if actor:HasTeam(team) then return color end
	end
	return ACCENT_DEFAULT
end

local function Wrap(text)
	surface.SetFont(FONT)
	local lines, line = {}, ''
	for word in text:gmatch('%S+') do
		local try = line == '' and word or line .. ' ' .. word
		if line ~= '' and surface.GetTextSize(try) > MAX_WIDTH then
			lines[#lines + 1] = line
			line = word
		else
			line = try
		end
	end
	lines[#lines + 1] = line
	return lines
end

local function DrawActorText(actor_uid, say_text, say_time)
	RemoveSpeakByUid(actor_uid)

	local actor = bgNPC.Actors.GetByUid(actor_uid)
	if not actor then return end

	local lines = Wrap(utf8.force(say_text))
	surface.SetFont(FONT)
	local width, line_h = 0, select(2, surface.GetTextSize('Ay'))
	for _, line in ipairs(lines) do width = math.max(width, (surface.GetTextSize(line))) end

	local name = actor:GetName()
	if not isstring(name) then name = '' end
	surface.SetFont(FONT_NAME)
	local name_w, name_h = surface.GetTextSize(name)
	if name == '' then name_h = -GAP end

	local now = CurTime()
	speaking_actors[#speaking_actors + 1] = {
		uid = actor_uid,
		actor = actor,
		lines = lines,
		name = name,
		accent = Accent(actor),
		line_h = line_h,
		name_h = name_h,
		w = math.max(width, name_w) + PAD_X * 2 + BAR,
		h = PAD_Y * 2 + name_h + GAP + line_h * #lines,
		start = now,
		finish = now + say_time,
	}
end

bgNPC.Net.Receive('bgn_actor_text_say', function(_, actor_uid, say_text, say_time)
	DrawActorText(actor_uid, say_text, say_time)
end)

bgNPC.Net.Receive('bgn_actor_text_say_replic', function(_, actor_uid, replic_id, replic_index, say_time)
	if not bgNPC.cfg.replics[replic_id] or not bgNPC.cfg.replics[replic_id][replic_index] then return end
	DrawActorText(actor_uid, bgNPC.cfg.replics[replic_id][replic_index], say_time)
	local actor = bgNPC.Actors.GetByUid(actor_uid)
	if actor then bgNPC.VoicePlay(actor, replic_id, replic_index) end
end)

local arrow = { {}, {}, {} }

local function DrawPlate(item, alpha)
	local w, h, accent = item.w, item.h, item.accent
	local x, y = -w * 0.5, -h - ARROW

	surface.SetDrawColor(PLATE.r, PLATE.g, PLATE.b, PLATE.a * alpha)
	surface.DrawRect(x, y, w, h)
	draw.NoTexture()
	arrow[1].x, arrow[1].y = -ARROW, -ARROW
	arrow[2].x, arrow[2].y = ARROW, -ARROW
	arrow[3].x, arrow[3].y = 0, 0
	surface.DrawPoly(arrow)

	surface.SetDrawColor(accent.r, accent.g, accent.b, 255 * alpha)
	surface.DrawRect(x, y, BAR, h)
	surface.SetDrawColor(accent.r, accent.g, accent.b, 90 * alpha)
	surface.DrawRect(x + BAR, y + h - 1, w - BAR, 1)

	local text_x, text_y = x + BAR + PAD_X, y + PAD_Y
	if item.name ~= '' then
		surface.SetFont(FONT_NAME)
		surface.SetTextColor(accent.r, accent.g, accent.b, 255 * alpha)
		surface.SetTextPos(text_x, text_y)
		surface.DrawText(item.name)
	end
	text_y = text_y + item.name_h + GAP

	surface.SetFont(FONT)
	surface.SetTextColor(TEXT.r, TEXT.g, TEXT.b, 255 * alpha)
	for _, line in ipairs(item.lines) do
		surface.SetTextPos(text_x, text_y)
		surface.DrawText(line)
		text_y = text_y + item.line_h
	end
end

hook.Add('PostDrawTranslucentRenderables', 'BGN_Actor_SayText_Drawing', function(_, skybox)
	if skybox or #speaking_actors == 0 then return end

	local eye = EyePos()
	local angle = Angle(0, EyeAngles().y - 90, 90)
	local now = CurTime()

	for i = #speaking_actors, 1, -1 do
		local item = speaking_actors[i]
		if item.finish <= now then
			table.remove(speaking_actors, i)
			continue
		end

		local actor = item.actor
		local npc = actor:GetNPC()
		if not IsValid(npc) or npc:GetNoDraw() or not actor:IsAlive() then continue end

		local dist = npc:GetPos():Distance(eye)
		local shown = math.min((now - item.start) / FADE_IN, 1)
		local alpha = math.min(shown, (item.finish - now) / FADE_OUT, (DIST - dist) / DIST_FADE)
		if alpha <= 0 then continue end

		local bone = npc:LookupBone(HEAD_BONE)
		local pos = bone and npc:GetBonePosition(bone) or npc:GetPos() + Vector(0, 0, npc:OBBMaxs().z)
		pos = pos + HEAD_OFFSET
		pos.z = pos.z - (1 - shown) * RISE

		cam.Start3D2D(pos, angle, SCALE)
			DrawPlate(item, math.min(alpha, 1))
		cam.End3D2D()
	end
end)

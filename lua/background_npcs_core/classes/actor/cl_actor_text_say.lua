surface.CreateFont('BGN_SpeakingFont', {
	font = 'background_npcs_speaking_font',
	extended = false,
	size = 14,
	weight = 100,
	blursize = 0,
	scanlines = 0,
	antialias = true,
	underline = false,
	italic = false,
	strikeout = false,
	symbol = false,
	rotary = false,
	shadow = true,
	additive = false,
	outline = false,
})
--
local TEXT_ALIGN_CENTER = TEXT_ALIGN_CENTER
local LocalPlayer = LocalPlayer
local cam_Start3D2D = cam.Start3D2D
local cam_End3D2D = cam.End3D2D
local draw_SimpleTextOutlined = draw.SimpleTextOutlined
--
local speaking_actors = {}
local font_name = 'BGN_SpeakingFont'
local clr_1 = Color(255, 255, 255)
local clr_2 = Color(0, 0, 0)

local function RemoveSpeakByUid(uid)
	for i = #speaking_actors, 1, -1 do
		local item = speaking_actors[i]
		if item and item.uid == uid then
			table.remove(speaking_actors, i)
			break
		end
	end
end

local function DrawActorText(actor_uid, say_text, say_time)
	local actor = bgNPC:GetActorByUid(actor_uid)
	if not actor then return end

	RemoveSpeakByUid(actor_uid)

	local text_lines = {}
	local text = utf8.force(say_text)
	local maxLineSize = 50
	local startPos = 1
	local endPos = maxLineSize
	local str_len = utf8.len(text)

	if str_len >= maxLineSize then
		for k = 1, str_len do
			if endPos == k then
				local line = utf8.sub(text, startPos, endPos)
				table.insert(text_lines, string.Trim(line))

				startPos = k
				endPos = endPos + maxLineSize
				if endPos > str_len then
					endPos = str_len
				end
			end
		end
	end

	if #text_lines == 0 then
		table.insert(text_lines, text)
	end

	table.insert(speaking_actors, {
		uid = actor_uid,
		actor = actor,
		text_lines = text_lines,
		time = say_time,
	})

	local timer_name = 'bgn_actor_' .. tostring(actor_uid) .. '_say_text_timer'

	timer.Create(timer_name, say_time, 1, function()
		RemoveSpeakByUid(actor_uid)
	end)
end

snet.Callback('bgn_actor_text_say', function(_, actor_uid, say_text, say_time)
	DrawActorText(actor_uid, say_text, say_time)
end)

snet.Callback('bgn_actor_text_say_replic', function(_, actor_uid, replic_id, replic_index, say_time)
	if not bgNPC.cfg.replics[replic_id] or not bgNPC.cfg.replics[replic_id][replic_index] then return end
	DrawActorText(actor_uid, bgNPC.cfg.replics[replic_id][replic_index], say_time)
end)

hook.Add('PostDrawOpaqueRenderables', 'BGN_Actor_SayText_Drawing', function()
	local localPos = LocalPlayer():GetPos()
	local eyeAngles = LocalPlayer():EyeAngles()
	eyeAngles:RotateAroundAxis(eyeAngles:Forward(), 90)
	eyeAngles:RotateAroundAxis(eyeAngles:Right(), 90)

	for i = #speaking_actors, 1, -1 do
		local item = speaking_actors[i]
		local actor = item.actor

		if not actor or not actor:IsAlive() then continue end

		local npc = actor:GetNPC()
		if not IsValid(npc) or npc:GetPos():Distance(localPos) > 800 then continue end

		local text_lines = item.text_lines
		local upperVectorPos = Vector(0, 0, 5)
		local startPos = npc:LookupBone('ValveBiped.Bip01_Head')
		if startPos then
			startPos = startPos + npc:GetForward() + npc:GetUp() * upperVectorPos.z
		else
			startPos = npc:GetPos() + npc:GetForward() + npc:GetUp() * (npc:OBBMaxs().z + upperVectorPos.z)
		end

		cam_Start3D2D(startPos, eyeAngles, 0.25)
			local ypos = -15
			for k = 1, #text_lines do
				local draw_text = text_lines[k]
				draw_SimpleTextOutlined(draw_text, font_name, 0, ypos, clr_1,
					TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, clr_2)
				ypos = ypos + 15
			end
		cam_End3D2D()
	end
end)
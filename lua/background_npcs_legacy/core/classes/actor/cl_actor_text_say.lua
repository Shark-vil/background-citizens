local TEXT_ALIGN_CENTER = TEXT_ALIGN_CENTER
local LocalPlayer = LocalPlayer
local IsValid = IsValid
local cam_Start3D2D = cam.Start3D2D
local cam_End3D2D = cam.End3D2D
local draw_SimpleTextOutlined = draw.SimpleTextOutlined
--
local speaking_actors = {}
local font_name = 'BGN_SpeakingFont'
local head_bone_name = 'ValveBiped.Bip01_Head'
local clr_1 = Color(255, 255, 255)
local clr_2 = Color(0, 0, 0)
local vector_0_0_5 = Vector(0, 0, 5)

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
	RemoveSpeakByUid(actor_uid)

	local actor = bgNPC:GetActorByUid(actor_uid)
	if not actor then return end

	local text_lines = {}
	local text = utf8.force(say_text)
	local max_line_size = 50
	local start_pos = 1
	local end_pos = max_line_size
	local str_len = utf8.len(text)
	local utf8_sub = utf8.sub
	local string_Trim = string.Trim
	local table_insert = table.insert

	if str_len >= max_line_size then
		for k = 1, str_len do
			if end_pos == k then
				local line = utf8_sub(text, start_pos, end_pos)
				table_insert(text_lines, string_Trim(line))

				start_pos = k
				end_pos = end_pos + max_line_size

				if end_pos > str_len then
					end_pos = str_len
				end
			end
		end
	end

	if #text_lines == 0 then
		table_insert(text_lines, text)
	end

	table_insert(speaking_actors, {
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
	local local_player = LocalPlayer()
	local local_player_pos = local_player:GetPos()
	local local_player_eye_angles = local_player:EyeAngles()
	local_player_eye_angles:RotateAroundAxis(local_player_eye_angles:Forward(), 90)
	local_player_eye_angles:RotateAroundAxis(local_player_eye_angles:Right(), 90)

	for i = #speaking_actors, 1, -1 do
		local item = speaking_actors[i]
		local actor = item.actor

		if not actor or not actor:IsAlive() then continue end

		local npc = actor:GetNPC()
		if not IsValid(npc) then continue end

		local npc_pos = npc:GetPos()
		if npc_pos:Distance(local_player_pos) > 800 then continue end

		local text_lines = item.text_lines
		local upper_vector_pos = vector_0_0_5
		local start_pos = npc:LookupBone(head_bone_name)
		if start_pos then
			start_pos = start_pos + npc:GetForward() + npc:GetUp() * upper_vector_pos.z
		else
			start_pos = npc_pos + npc:GetForward() + npc:GetUp() * (npc:OBBMaxs().z + upper_vector_pos.z)
		end

		local text3d_y_axis = -15

		cam_Start3D2D(start_pos, local_player_eye_angles, 0.25)
			for k = 1, #text_lines do
				local draw_text = text_lines[k]
				draw_SimpleTextOutlined(draw_text, font_name, 0, text3d_y_axis, clr_1, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, clr_2)
				text3d_y_axis = text3d_y_axis + 15
			end
		cam_End3D2D()
	end
end)
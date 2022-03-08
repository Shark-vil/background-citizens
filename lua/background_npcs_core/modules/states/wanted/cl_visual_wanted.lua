local bgNPC = bgNPC
local TEXT_ALIGN_CENTER = TEXT_ALIGN_CENTER
local IsValid = IsValid
local GetConVar = GetConVar
local LocalPlayer = LocalPlayer
local cam_Start3D2D = cam.Start3D2D
local cam_End3D2D = cam.End3D2D
local draw_SimpleTextOutlined = draw.SimpleTextOutlined
local halo_Add = halo.Add
local surface_SetFont = surface.SetFont
local surface_SetTextColor = surface.SetTextColor
local surface_SetTextPos = surface.SetTextPos
local surface_SetDrawColor = surface.SetDrawColor
local surface_SetMaterial = surface.SetMaterial
local surface_DrawText = surface.DrawText
local surface_DrawTexturedRect = surface.DrawTexturedRect
local math_Round = math.Round
local string_Replace = string.Replace
--
local asset = bgNPC:GetModule('wanted')
local text_wanted_font_name = 'Trebuchet24'
local text_calling_police_font_name = 'DermaLarge'
local wanted_config = bgNPC.cfg.wanted

hook.Add('PreDrawHalos', 'BGN_RenderOutlineOnPlayerWanted', function()
	if GetConVar('bgn_disable_halo'):GetBool() then return end

	local wanted_list = asset:GetAllWanted()
	local wanted_count = #wanted_list
	if wanted_count == 0 then return end

	local targets = {}
	local targets_count = 0

	for i = 1, wanted_count do
		local WantedClass = wanted_list[i]
		local ent = WantedClass.target

		if not IsValid(ent) then continue end

		targets_count = targets_count + 1
		targets[targets_count] = ent
	end

	if targets_count == 0 then return end

	halo_Add(targets, wanted_config.color['wanted_halo'], 3, 3, 2)
end)

hook.Add('HUDPaint', 'BGN_DrawWantedText', function()
	local is_draw_text = GetConVar('bgn_wanted_hud_text'):GetBool()
	local is_draw_stars = GetConVar('bgn_wanted_hud_stars'):GetBool()

	if not is_draw_text and not is_draw_stars then return end
	if not GetConVar('bgn_wanted_level'):GetBool() then
		is_draw_stars = false
	end

	local WantedClass = asset:GetWanted(LocalPlayer())
	if not WantedClass then return end

	if is_draw_text then
		surface_SetFont(text_wanted_font_name)
		surface_SetTextColor(255, 0, 0)
		surface_SetTextPos(30, 30)

		local wanted_text
		local time = WantedClass.wait_time
		if time > 60 then
			time = math_Round(time / 60)
			wanted_text = string_Replace(wanted_config.language['wanted_text_m'], '%time%', time)
		else
			wanted_text = string_Replace(wanted_config.language['wanted_text_s'], '%time%', time)
		end

		surface_DrawText(wanted_text)
	end

	if is_draw_stars then
		local x = 35
		local x_update = x

		for i = 1, WantedClass.level do
			surface_SetDrawColor(255, 255, 255, 255)
			surface_SetMaterial(wanted_config.texture['wanted_star'])
			surface_DrawTexturedRect(x_update, 60, 30, 30)
			x_update = x_update + 40
		end
	end
end)

hook.Add('PreDrawHalos', 'BGN_RenderOutlineOnNPCCallingPolice', function()
	if GetConVar('bgn_disable_halo'):GetBool() then return end

	local localPlayer = LocalPlayer()
	if not IsValid(localPlayer) then return end

	local playerPos = localPlayer:GetPos()
	local npcs = {}
	local npcs_count = 0
	local actors = bgNPC:GetAll()

	for i = 1, #actors do
		local actor = actors[i]
		if not actor then continue end

		local npc = actor:GetNPC()
		if not IsValid(npc) or actor:GetState() ~= 'calling_police' then continue end
		if npc:GetPos():DistToSqr(playerPos) >= 6250000 then continue end -- 2500 ^ 2

		npcs_count = npcs_count + 1
		npcs[npcs_count] = npc
	end

	if npcs_count == 0 then return end

	halo_Add(npcs, wanted_config.color['calling_police_halo'], 3, 3, 2)
end)

hook.Add('PostDrawOpaqueRenderables', 'BGN_RenderTextAboveNPCCallingPolice', function()
	local localPlayer = LocalPlayer()
	if not IsValid(localPlayer) then return end

	local playerPos = localPlayer:GetPos()
	local playerEyeAngles = localPlayer:EyeAngles()
	local color_text = wanted_config.color['calling_police_text']
	local color_text_outline = wanted_config.color['calling_police_text_outline']
	local text = wanted_config.language['calling_police']
	local actors = bgNPC:GetAll()

	for i = 1, #actors do
		local actor = actors[i]
		if not actor or actor:GetState() ~= 'calling_police' then continue end

		local npc = actor:GetNPC()
		if not IsValid(npc) then continue end
		if npc:GetPos():DistToSqr(playerPos) >= 6250000 then continue end -- 2500 ^ 2

		local angle = playerEyeAngles
		angle:RotateAroundAxis(angle:Forward(), 90)
		angle:RotateAroundAxis(angle:Right(), 90)

		cam_Start3D2D(npc:GetPos() + npc:GetForward() + npc:GetUp() * 78, angle, 0.25)
			draw_SimpleTextOutlined(text, text_calling_police_font_name, 0, -15, color_text,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_text_outline)
		cam_End3D2D()
	end
end)
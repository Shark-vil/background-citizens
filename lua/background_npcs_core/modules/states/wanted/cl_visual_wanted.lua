local bgNPC = bgNPC
local TEXT_ALIGN_CENTER = TEXT_ALIGN_CENTER
local pairs = pairs
local ipairs = ipairs
local IsValid = IsValid
local GetConVar = GetConVar
local LocalPlayer = LocalPlayer
local cam_Start3D2D = cam.Start3D2D
local cam_End3D2D = cam.End3D2D
local draw_SimpleTextOutlined = draw.SimpleTextOutlined
local halo_Add = halo.Add
local table_insert = table.insert
local table_Count = table.Count
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

hook.Add('PreDrawHalos', 'BGN_RenderOutlineOnPlayerWanted', function()
	if not LocalPlayer().snet_ready then return end
	if GetConVar('bgn_disable_halo'):GetBool() then return end

	local wanted_list = asset:GetAllWanted()

	if table_Count(wanted_list) == 0 then return end

	local targets = {}
	for ent, _ in pairs(wanted_list) do
		if IsValid(ent) then
			table_insert(targets, ent)
		end
	end

	if #targets ~= 0 then
		halo_Add(targets, bgNPC.cfg.wanted.color['wanted_halo'], 3, 3, 2)
	end
end)

hook.Add('HUDPaint', 'BGN_DrawWantedText', function()
	local localPlayer = LocalPlayer()

	if not localPlayer.snet_ready then return end

	local is_draw_text = GetConVar('bgn_wanted_hud_text'):GetBool()
	local is_draw_stars = GetConVar('bgn_wanted_hud_stars'):GetBool()

	if not is_draw_text and not is_draw_stars then return end
	if not GetConVar('bgn_wanted_level'):GetBool() then
		is_draw_stars = false
	end

	local wanted_list = asset:GetAllWanted()

	if table_Count(wanted_list) == 0 then return end

	if not IsValid(localPlayer) then return end
	if not asset:HasWanted(localPlayer) then return end

	local c_Wanted = asset:GetWanted(localPlayer)

	if is_draw_text then
		surface_SetFont(text_wanted_font_name)
		surface_SetTextColor(255, 0, 0)
		surface_SetTextPos(30, 30)

		local wanted_text
		local time = c_Wanted.wait_time
		if time > 60 then
			time = math_Round(time / 60)
			wanted_text = string_Replace(bgNPC.cfg.wanted.language['wanted_text_m'], '%time%', time)
		else
			wanted_text = string_Replace(bgNPC.cfg.wanted.language['wanted_text_s'], '%time%', time)
		end

		surface_DrawText(wanted_text)
	end

	if is_draw_stars then
		local x = 35
		local x_update = x

		for i = 1, c_Wanted.level do
			surface_SetDrawColor(255, 255, 255, 255)
			surface_SetMaterial(bgNPC.cfg.wanted.texture['wanted_star'])
			surface_DrawTexturedRect(x_update, 60, 30, 30)
			x_update = x_update + 40
		end
	end
end)

hook.Add('PreDrawHalos', 'BGN_RenderOutlineOnNPCCallingPolice', function()
	local localPlayer = LocalPlayer()

	if not localPlayer.snet_ready then return end
	if GetConVar('bgn_disable_halo'):GetBool() then return end

	local npcs = {}

	for _, actor in ipairs(bgNPC:GetAll()) do
		local npc = actor:GetNPC()
		if IsValid(npc) and actor:GetState() == 'calling_police'
			and npc:GetPos():DistToSqr(localPlayer:GetPos()) < 6250000 -- 2500 ^ 2
		then
			table_insert(npcs, npc)
		end
	end

	if #npcs ~= 0 then
		halo_Add(npcs, bgNPC.cfg.wanted.color['calling_police_halo'], 3, 3, 2)
	end
end)

hook.Add('PostDrawOpaqueRenderables', 'BGN_RenderTextAboveNPCCallingPolice', function()
	local localPlayer = LocalPlayer()
	local color_text = bgNPC.cfg.wanted.color['calling_police_text']
	local color_text_outline = bgNPC.cfg.wanted.color['calling_police_text_outline']
	local text = bgNPC.cfg.wanted.language['calling_police']

	for _, actor in ipairs(bgNPC:GetAll()) do
		local npc = actor:GetNPC()
		if IsValid(npc) and actor:GetState() == 'calling_police'
			and npc:GetPos():DistToSqr(localPlayer:GetPos()) < 6250000 -- 2500 ^ 2
		then
			local angle = localPlayer:EyeAngles()
			angle:RotateAroundAxis(angle:Forward(), 90)
			angle:RotateAroundAxis(angle:Right(), 90)

			cam_Start3D2D(npc:GetPos() + npc:GetForward() + npc:GetUp() * 78, angle, 0.25)
				draw_SimpleTextOutlined(text, text_calling_police_font_name, 0, -15, color_text,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_text_outline)
			cam_End3D2D()
		end
	end
end)
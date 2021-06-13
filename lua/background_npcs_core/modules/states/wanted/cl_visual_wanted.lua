local asset = bgNPC:GetModule('wanted')

hook.Add("PreDrawHalos", "BGN_RenderOutlineOnPlayerWanted", function()
	if not LocalPlayer().snet_ready then return end
	if GetConVar('bgn_disable_halo'):GetBool() then return end

	local wanted_list = asset:GetAllWanted()

	if table.Count(wanted_list) == 0 then return end
	
	local targets = {}
	for ent, _ in pairs(wanted_list) do
		if IsValid(ent) then
			table.insert(targets, ent)
		end
	end

	if #targets ~= 0 then
		halo.Add(targets, bgNPC.cfg.wanted.color['wanted_halo'], 3, 3, 2)
	end
end)

hook.Add('HUDPaint', 'BGN_DrawWantedText', function()
	if not LocalPlayer().snet_ready then return end
	
	local is_draw_text = GetConVar('bgn_wanted_hud_text'):GetBool()
	local is_draw_stars = GetConVar('bgn_wanted_hud_stars'):GetBool()

	if not is_draw_text and not is_draw_stars then return end
	if not GetConVar('bgn_wanted_level'):GetBool() then
		is_draw_stars = false
	end

	local wanted_list = asset:GetAllWanted()

	if table.Count(wanted_list) == 0 then return end

	if not IsValid(LocalPlayer()) then return end
	if not asset:HasWanted(LocalPlayer()) then return end

	local c_Wanted = asset:GetWanted(LocalPlayer())
	
	if is_draw_text then
		surface.SetFont("Trebuchet24")
		surface.SetTextColor(255, 0, 0)
		surface.SetTextPos(30, 30)

		local wanted_text
		local time = c_Wanted.wait_time
		if time > 60 then
			time = math.Round(time / 60)
			wanted_text = string.Replace(bgNPC.cfg.wanted.language['wanted_text_m'], '%time%', time)
		else
			wanted_text = string.Replace(bgNPC.cfg.wanted.language['wanted_text_s'], '%time%', time)
		end

		surface.DrawText(wanted_text)
	end

	if is_draw_stars then
		local x = 35
		local x_update = x

		for i = 1, c_Wanted.level do
			surface.SetDrawColor(255, 255, 255, 255)
			surface.SetMaterial(bgNPC.cfg.wanted.texture['wanted_star'])
			surface.DrawTexturedRect(x_update, 60, 30, 30)
			x_update = x_update + 40
		end
	end
end)

hook.Add("PreDrawHalos", "BGN_RenderOutlineOnNPCCallingPolice", function()
	if not LocalPlayer().snet_ready then return end
	if GetConVar('bgn_disable_halo'):GetBool() then return end
	
	local npcs = {}

	for _, actor in ipairs(bgNPC:GetAll()) do
		local npc = actor:GetNPC()
		if IsValid(npc) then
			if actor:GetState() == 'calling_police' then
				if npc:GetPos():DistToSqr(LocalPlayer():GetPos()) < 6250000 then -- 2500 ^ 2
					table.insert(npcs, npc)
				end
			end
		end
	end

	if #npcs ~= 0 then
		halo.Add(npcs, bgNPC.cfg.wanted.color['calling_police_halo'], 3, 3, 2)
	end
end)

hook.Add('PostDrawOpaqueRenderables', 'BGN_RenderTextAboveNPCCallingPolice', function()
	local color_text = bgNPC.cfg.wanted.color['calling_police_text']
	local color_text_outline = bgNPC.cfg.wanted.color['calling_police_text_outline']
	local text = bgNPC.cfg.wanted.language['calling_police']

	for _, actor in ipairs(bgNPC:GetAll()) do
		local npc = actor:GetNPC()
		if IsValid(npc) then
			if actor:GetState() == 'calling_police' then
				if npc:GetPos():DistToSqr(LocalPlayer():GetPos()) < 6250000 then -- 2500 ^ 2
					local angle = LocalPlayer():EyeAngles()
					angle:RotateAroundAxis(angle:Forward(), 90)
					angle:RotateAroundAxis(angle:Right(), 90)
			
					cam.Start3D2D(npc:GetPos() + npc:GetForward() + npc:GetUp() * 78, angle, 0.25)
						draw.SimpleTextOutlined(text, "DermaLarge", 0, -15, color_text, 
							TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_text_outline)
					cam.End3D2D()
				end
			end
		end
	end
end)
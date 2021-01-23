local asset = bgNPC:GetModule('wanted')

local wanted_halo_color = Color(240, 34, 34)
hook.Add("PreDrawHalos", "BGN_RenderOutlineOnPlayerWanted", function()
    local wanted_list = asset:GetAllWanted()

    if table.Count(wanted_list) == 0 then return end
    
    for ent, _ in ipairs(wanted_list) do
        if IsValid(ent) then
            halo.Add(ent, wanted_halo_color, 3, 3, 2)
        end
    end
end)

local color_text = Color(82, 223, 255)
local color_black = Color(0, 0, 0)

local m_wanted_star = Material('background_npcs/vgui/wanted_star.png')
hook.Add('HUDPaint', 'BGN_DrawWantedText', function()
    local wanted_list = asset:GetAllWanted()

    if table.Count(wanted_list) == 0 then return end

    if not IsValid(LocalPlayer()) then return end
    if not asset:HasWanted(LocalPlayer()) then return end

    local c_Wanted = asset:GetWanted(LocalPlayer())
    
    surface.SetFont("Trebuchet24")
    surface.SetTextColor(255, 0, 0)
    surface.SetTextPos(30, 30) 
    surface.DrawText('YOU ARE WANTED! The search will end in ' .. c_Wanted.wait_time .. ' seconds...')

    local x = 35

    surface.SetDrawColor(255, 255, 255, 10)
    surface.DrawRect(x - 15, 55, 250, 55)
    
    local x_update = x

    for i = 1, c_Wanted.level do
        -- surface.DrawCircle(x, 80, 10, Color(255, 120, 0))
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(m_wanted_star)
        surface.DrawTexturedRect(x_update, 60, 40, 40)
        x_update = x_update + 45
    end
end)

local halo_color = Color(0, 60, 255)
hook.Add("PreDrawHalos", "BGN_RenderOutlineOnNPCCallingPolice", function()
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
        halo.Add(npcs, halo_color, 3, 3, 2)
    end
end)

hook.Add('PostDrawOpaqueRenderables', 'BGN_RenderTextAboveNPCCallingPolice', function()	
    for _, actor in ipairs(bgNPC:GetAll()) do
        local npc = actor:GetNPC()
        if IsValid(npc) then
            if actor:GetState() == 'calling_police' then
                if npc:GetPos():DistToSqr(LocalPlayer():GetPos()) < 6250000 then -- 2500 ^ 2
                    local angle = LocalPlayer():EyeAngles()
                    angle:RotateAroundAxis(angle:Forward(), 90)
                    angle:RotateAroundAxis(angle:Right(), 90)
            
                    cam.Start3D2D(npc:GetPos() + npc:GetForward() + npc:GetUp() * 78, angle, 0.25)
                        draw.SimpleTextOutlined('Calling police...', 
                            "DermaLarge", 0, -15, color_text, 
                            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
                    cam.End3D2D()
                end
            end
        end
    end
end)
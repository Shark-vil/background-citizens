--[[
	The police break into the player's car (sv_car_breakin.lua): a bar that shrinks from both sides to the
	middle; empty means arrested. Drive away to stop it.
--]]

local start, duration = 0, 0

bgNPC.Net.Receive('bgn_car_breakin', function(_, new_start, new_duration)
	start, duration = new_start or 0, new_duration or 0
end)

surface.CreateFont('BGN.CarBreakin', { font = 'Roboto', size = 22, weight = 700, extended = true, antialias = true })

local BAR_BG = Color(0, 0, 0, 170)
local BAR_FILL = Color(220, 60, 50)
local BAR_URGENT = Color(255, 220, 80)
local TEXT = Color(255, 255, 255)

hook.Add('HUDPaint', 'BGN_CarBreakin', function()
	if start <= 0 or duration <= 0 then return end
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:InVehicle() then return end

	local left = 1 - math.Clamp((CurTime() - start) / duration, 0, 1)
	local w, h = math.min(ScrW() * 0.4, 520), 10
	local x, y = (ScrW() - w) / 2, ScrH() * 0.78

	draw.RoundedBox(4, x - 2, y - 2, w + 4, h + 4, BAR_BG)
	local fill = math.Round(w * left)
	-- the last quarter blinks
	local color = (left < 0.25 and CurTime() % 0.5 < 0.25) and BAR_URGENT or BAR_FILL
	draw.RoundedBox(4, x + (w - fill) / 2, y, fill, h, color)

	local text = bgNPC.Menu and bgNPC.Menu.Text('#bgn.hud.car_breakin') or language.GetPhrase('bgn.hud.car_breakin')
	draw.SimpleTextOutlined(text, 'BGN.CarBreakin', ScrW() / 2, y - 8, TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, BAR_BG)
end)

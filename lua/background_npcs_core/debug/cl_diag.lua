--[[
	Testing mode, client side (the runner is sv_diag.lua):
	  - answers the settings test (changes a server and a client value the way the settings window does)
	  - a progress bar while the test runs and the camera that shows where the actors gather
	  - the results window (the settings window style, with the theme switch) and the copyable log
--]]

local Net = bgNPC.Net
local Menu = bgNPC.Menu
local C = Menu.colors
local Diag = bgNPC.Diag
local ICONS = 'background_npcs/vgui/menu/'
local REPORT_FILE = 'background_npcs/test_report.txt'

local cvar_client = CreateClientConVar('bgn_cl_test_value', '0', true, false, 'Testing mode: a client value used to check that settings can be changed.')

local beam = Material('effects/laser1')

-- ---------------------------------------------------------------------------
-- Settings test: the server asks, this client changes the values and reports what it sees
-- ---------------------------------------------------------------------------

Net.Receive('bgn.diag_cvar_begin', function(_, token_server, token_client)
	local ply = LocalPlayer()
	local previous = cvar_client:GetString()

	-- exactly what a settings row does: the client copy changes, the change goes to the server for admins
	RunConsoleCommand('bgn_test_server_value', token_server)
	RunConsoleCommand('bgn_cl_test_value', token_client)

	timer.Simple(0.7, function()
		local report = {
			admin = ply:IsAdmin(), super = ply:IsSuperAdmin(), group = ply:GetUserGroup(),
			client_value = cvar_client:GetString(),
			lang = GetConVar('gmod_language'):GetString(), ui_lang = GetConVar('bgn_cl_ui_language'):GetString(),
			dx = render.GetDXLevel(), fps = math.floor(1 / math.max(RealFrameTime(), 0.001)),
		}
		RunConsoleCommand('bgn_cl_test_value', previous)
		Net.SendToServer('bgn.diag_cvar_report', report)
	end)
end)

-- the server changed its value itself: this client has to see it
Net.Receive('bgn.diag_cvar_sync', function(_, token)
	local cv = GetConVar('bgn_test_server_value')
	local stop = RealTime() + 3
	timer.Create('BGN_Diag_Sync', 0.1, 0, function()
		local seen = cv:GetString() == token
		if not seen and RealTime() < stop then return end
		timer.Remove('BGN_Diag_Sync')
		Net.SendToServer('bgn.diag_cvar_sync_report', seen)
	end)
end)

-- ---------------------------------------------------------------------------
-- Run control, progress, camera
-- ---------------------------------------------------------------------------

local function Message(result)
	local args = {}
	for i, v in ipairs(result.args or {}) do
		args[i] = (isstring(v) and v:sub(1, 1) == '#') and Menu.Text(v) or v
	end
	local phrase = Menu.Text('#' .. result.key)
	local ok, text = pcall(string.format, phrase, unpack(args))
	return ok and text or phrase
end

local function Start(mode)
	if Diag.running then return end
	if Menu.IsOpen() then Menu.Close() end
	if IsValid(Diag.window) then Diag.window:Remove() end
	Menu.CreateFonts()
	Menu.ApplyTheme(true)
	Diag.running, Diag.progress, Diag.cam, Diag.started = true, { step = 0, count = 1, id = 'env' }, nil, RealTime()
	Net.SendToServer('bgn.diag_start', mode)
	-- no answer from the server: do not hang in the "running" state
	timer.Create('BGN_Diag_Wait', 8, 1, function()
		if Diag.running and Diag.progress.step == 0 then
			Diag.running = false
			notification.AddLegacy(Menu.Text('#bgn.diag.no_answer'), NOTIFY_ERROR, 6)
		end
	end)
end

concommand.Add('bgn_test', function() Start('full') end, nil, 'Testing mode: spawns and checks actors, cars and settings, then shows the results')
concommand.Add('bgn_test_settings', function() Start('settings') end, nil, 'Testing mode: checks only the rights and the settings changes')
concommand.Add('bgn_test_stop', function() Net.SendToServer('bgn.diag_abort') end, nil, 'Stops a running test')

Net.Receive('bgn.diag_progress', function(_, step, count, id)
	Diag.progress = { step = step, count = count, id = id }
end)

Net.Receive('bgn.diag_busy', function()
	Diag.running = false
	notification.AddLegacy(Menu.Text('#bgn.diag.busy'), NOTIFY_ERROR, 5)
end)

Net.Receive('bgn.diag_cam', function(_, group, index, count)
	if not group then Diag.cam = nil return end
	local previous = Diag.cam
	Diag.cam = {
		pos = group.pos, target = group.target, group = group, index = index, count = count, start = RealTime(),
		from_pos = previous and previous.pos or EyePos(), from_ang = previous and (previous.target - previous.pos):Angle() or EyeAngles(),
	}
end)

hook.Add('CalcView', 'BGN_Diag', function(ply, origin, angles, fov)
	local cam = Diag.cam
	if not cam then return end
	local f = math.Clamp((RealTime() - cam.start) / 1.4, 0, 1)
	f = f * f * (3 - 2 * f)
	local ang = LerpAngle(f, cam.from_ang, (cam.target - cam.pos):Angle())
	ang.y = ang.y + math.sin(RealTime() * 0.6) * 4
	return { origin = LerpVector(f, cam.from_pos, cam.pos), angles = ang, fov = 70, drawviewer = true }
end)

hook.Add('ShouldDrawLocalPlayer', 'BGN_Diag', function()
	if Diag.cam then return true end
end)

hook.Add('PostDrawTranslucentRenderables', 'BGN_Diag', function(depth, skybox)
	local cam = Diag.cam
	if not cam or skybox then return end
	local ground = cam.target - Vector(0, 0, 50)
	local pulse = 0.6 + math.sin(RealTime() * 4) * 0.4
	local color = Color(255, 190, 40, 255 * pulse)
	render.SetMaterial(beam)
	render.DrawBeam(ground, ground + Vector(0, 0, 700), 40, 0, 1, color)
	render.SetColorMaterial()
	render.DrawWireframeSphere(ground, 350, 18, 12, color, true)
end)

hook.Add('PreDrawHalos', 'BGN_Diag', function()
	local cam = Diag.cam
	if not cam then return end
	local ents = {}
	for _, index in ipairs(cam.group.ents) do
		local ent = Entity(index)
		if IsValid(ent) then ents[#ents + 1] = ent end
	end
	if #ents > 0 then halo.Add(ents, Color(255, 190, 40), 3, 3, 2, true, true) end
end)

local skip_down

hook.Add('HUDPaint', 'BGN_Diag', function()
	if not Diag.running then return end
	local s = Menu.Scale()
	local R = math.Round
	local cam = Diag.cam
	local progress = Diag.progress
	local w, h = R(460 * s), R(76 * s)
	local x, y = (ScrW() - w) / 2, R(24 * s)

	draw.RoundedBox(R(10 * s), x, y, w, h, C.border)
	draw.RoundedBox(R(10 * s), x + 1, y + 1, w - 2, h - 2, C.surface)
	local title = progress.step == 0 and Menu.Text('#bgn.diag.starting')
		or string.format(Menu.Text('#bgn.diag.progress'), progress.step, progress.count, Menu.Text('#bgn.diag.t.' .. progress.id))
	draw.SimpleText(title, 'BGN.Menu.Body', x + R(16 * s), y + R(12 * s), C.text)
	draw.SimpleText(Menu.Text(cam and '#bgn.diag.skip_camera' or '#bgn.diag.stop_hint'), 'BGN.Menu.Small', x + R(16 * s), y + R(36 * s), C.muted)
	local bar_w = w - R(32 * s)
	draw.RoundedBox(3, x + R(16 * s), y + h - R(16 * s), bar_w, 6, C.track)
	draw.RoundedBox(3, x + R(16 * s), y + h - R(16 * s), bar_w * math.Clamp(progress.step / math.max(progress.count, 1), 0, 1), 6, C.accent)

	if not cam then return end

	local spot = (cam.target + Vector(0, 0, 130)):ToScreen()
	if spot.visible then
		local parts = {}
		for actor_type, n in SortedPairs(cam.group.types) do parts[#parts + 1] = actor_type .. ' x' .. n end
		draw.SimpleTextOutlined(string.format(Menu.Text('#bgn.diag.cam.group'), cam.index, cam.count, cam.group.count),
			'BGN.Menu.PageTitle', spot.x, spot.y, Color(255, 190, 40), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 2, Color(0, 0, 0, 220))
		draw.SimpleTextOutlined(table.concat(parts, ', '), 'BGN.Menu.Body', spot.x, spot.y, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, Color(0, 0, 0, 220))
	end

	local down = input.IsKeyDown(KEY_SPACE)
	if down and not skip_down then Net.SendToServer('bgn.diag_cam_skip') end
	skip_down = down
end)

-- ---------------------------------------------------------------------------
-- Results window
-- ---------------------------------------------------------------------------

local function StatusColor(status)
	if status == 'fail' then return C.danger end
	if status == 'warn' then return C.warn end
	return GetConVar('bgn_menu_dark'):GetBool() and Color(74, 200, 120) or Color(22, 163, 74)
end

local function StyleScroll(scroll, s)
	local bar = scroll:GetVBar()
	bar:SetWide(math.Round(10 * s))
	bar:SetHideButtons(true)
	bar.Paint = nil
	bar.btnGrip.Paint = function(self, w, h)
		local inset = math.Round(3 * s)
		draw.RoundedBox((w - inset * 2) / 2, inset, 0, w - inset * 2, h, (self:IsHovered() or self.Depressed) and C.muted or C.border)
	end
end

function Diag.OpenReport()
	local last = Diag.last
	if not last then
		notification.AddLegacy(Menu.Text('#bgn.diag.no_report'), NOTIFY_HINT, 4)
		return
	end
	if Menu.IsOpen() then Menu.Close() end
	if IsValid(Diag.window) then Diag.window:Remove() end
	Menu.CreateFonts()
	Menu.ApplyTheme(true)

	local s = Menu.Scale()
	local R = math.Round
	local W, H = math.min(R(780 * s), ScrW() - 32), math.min(R(700 * s), ScrH() - 48)
	local pad, gap = R(28 * s), R(8 * s)
	local counts = { ok = 0, warn = 0, fail = 0 }
	for _, r in ipairs(last.results) do counts[r.status] = (counts[r.status] or 0) + 1 end
	local title_h = Menu.FontHeight('BGN.Menu.PageTitle')
	local head_h = pad + title_h + R(30 * s)
	local foot_h = R(32 * s) + pad * 2

	local frame = vgui.Create('EditablePanel')
	Diag.window = frame
	frame:SetSize(W, H)
	frame:Center()
	frame:MakePopup()
	frame:SetAlpha(0)
	frame:AlphaTo(255, 0.15)
	Menu.Sound('open')
	frame.Think = Menu.UpdateTheme
	frame.OnRemove = function() if Diag.window == frame then Diag.window = nil end end

	local radius = R(10 * s)
	frame.Paint = function(_, w, h)
		DisableClipping(true)
		for i = 1, 4 do
			draw.RoundedBox(radius + i * 2, -i * 2, -i * 2 + 4, w + i * 4, h + i * 4, Menu.Fade(C.shadow, 0.35 / i))
		end
		DisableClipping(false)
		draw.RoundedBox(radius, 0, 0, w, h, C.bg)
		draw.SimpleText(Menu.Text('#bgn.diag.results'), 'BGN.Menu.PageTitle', pad, pad, C.text)

		-- "5 passed  1 warning  2 failed" in the colors of the icons
		local x, y = pad, pad + title_h + R(6 * s)
		for _, item in ipairs({ { 'ok', '#bgn.diag.count.ok' }, { 'warn', '#bgn.diag.count.warn' }, { 'fail', '#bgn.diag.count.fail' } }) do
			local text = string.format(Menu.Text(item[2]), counts[item[1]] or 0)
			draw.SimpleText(text, 'BGN.Menu.Body', x, y, (counts[item[1]] or 0) > 0 and StatusColor(item[1]) or C.muted)
			surface.SetFont('BGN.Menu.Body')
			x = x + surface.GetTextSize(text) + R(20 * s)
		end
		draw.SimpleText(game.GetMap() .. '  ·  v' .. bgNPC.VERSION, 'BGN.Menu.Small', x, y + 2, C.muted)
	end

	local size = R(36 * s)
	local close = Menu.IconButton(frame, size, function() return ICONS .. 'close.png' end, Menu.Text('#bgn.menu.close'), function() frame:Remove() end)
	close:SetPos(W - pad + R(4 * s) - size, R(18 * s))
	local theme = Menu.IconButton(frame, size,
		function() return GetConVar('bgn_menu_dark'):GetBool() and ICONS .. 'sun.png' or ICONS .. 'moon.png' end,
		Menu.Text('#bgn.menu.theme'),
		function()
			Menu.Sound('click')
			RunConsoleCommand('bgn_menu_dark', GetConVar('bgn_menu_dark'):GetBool() and '0' or '1')
		end)
	theme:SetPos(close.x - gap - size, R(18 * s))

	local list = frame:Add('DScrollPanel')
	list:SetPos(pad, head_h)
	list:SetSize(W - pad * 2, H - head_h - foot_h)
	StyleScroll(list, s)

	local ip, icon = R(16 * s), R(26 * s)
	for _, result in ipairs(last.results) do
		local row = list:Add('DPanel')
		row:Dock(TOP)
		row:DockMargin(0, 0, R(14 * s), gap)
		local title, text = Menu.Text('#bgn.diag.t.' .. result.id), Message(result)
		local text_x = ip * 2 + icon
		row.PerformLayout = function(self, w)
			local lines = Menu.Wrap(text, 'BGN.Menu.Small', w - text_x - ip)
			local h = ip * 2 + Menu.FontHeight('BGN.Menu.Body') + R(3 * s) + #lines * Menu.FontHeight('BGN.Menu.Small')
			if self:GetTall() ~= h then self:SetTall(h) end
		end
		row.Paint = function(self, w, h)
			local color = StatusColor(result.status)
			local r = R(8 * s)
			draw.RoundedBox(r, 0, 0, w, h, result.status == 'fail' and C.danger or C.border)
			draw.RoundedBox(r, 1, 1, w - 2, h - 2, C.surface)
			draw.RoundedBox(icon / 2, ip, ip, icon, icon, color)
			if result.status == 'ok' then
				Menu.Icon(ICONS .. 'check.png', ip + icon * 0.15, ip + icon * 0.15, icon * 0.7, color_white)
			elseif result.status == 'fail' then
				Menu.Icon(ICONS .. 'close.png', ip + icon * 0.2, ip + icon * 0.2, icon * 0.6, color_white)
			else
				draw.SimpleText('!', 'BGN.Menu.Body', ip + icon / 2, ip + icon / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
			draw.SimpleText(title, 'BGN.Menu.Body', text_x, ip, C.text)
			local y = ip + Menu.FontHeight('BGN.Menu.Body') + R(3 * s)
			for _, line in ipairs(Menu.Wrap(text, 'BGN.Menu.Small', w - text_x - ip)) do
				draw.SimpleText(line, 'BGN.Menu.Small', text_x, y, C.muted)
				y = y + Menu.FontHeight('BGN.Menu.Small')
			end
		end
	end

	-- footer
	local copy = Menu.Button(frame, Menu.Text('#bgn.diag.copy'), 'primary', function()
		SetClipboardText(last.log)
		notification.AddLegacy(Menu.Text('#bgn.diag.copied'), NOTIFY_GENERIC, 4)
	end)
	local again = Menu.Button(frame, Menu.Text('#bgn.diag.again'), 'secondary', function()
		frame:Remove()
		RunConsoleCommand(last.mode == 'full' and 'bgn_test' or 'bgn_test_settings')
	end)
	local done = Menu.Button(frame, Menu.Text('#bgn.menu.close'), 'secondary', function() frame:Remove() end)
	local by = H - pad - copy:GetTall()
	done:SetPos(W - pad - done:GetWide(), by)
	again:SetPos(done.x - gap - again:GetWide(), by)
	copy:SetPos(again.x - gap - copy:GetWide(), by)

	local hint_lines = Menu.Wrap(Menu.Text('#bgn.diag.log_hint'), 'BGN.Menu.Small', copy.x - pad - R(16 * s))
	local base_paint = frame.Paint
	frame.Paint = function(self, w, h)
		base_paint(self, w, h)
		for i, line in ipairs(hint_lines) do
			draw.SimpleText(line, 'BGN.Menu.Small', pad, by + (i - 1) * Menu.FontHeight('BGN.Menu.Small'), C.muted)
		end
	end
end

concommand.Add('bgn_test_report', Diag.OpenReport, nil, 'Opens the results of the last test')

Net.Receive('bgn.diag_done', function(_, results, log)
	Diag.running, Diag.cam = false, nil
	timer.Remove('BGN_Diag_Wait')
	Diag.last = { results = results, log = log, mode = Diag.progress and Diag.progress.count > 1 and 'full' or 'settings' }
	file.Write(REPORT_FILE, log)
	Diag.OpenReport()
end)

hook.Add('OnPauseMenuShow', 'BGN_Diag', function()
	if not IsValid(Diag.window) then return end
	Diag.window:Remove()
	return false
end)

cvars.AddChangeCallback('gmod_language', function() timer.Simple(0.2, function() if IsValid(Diag.window) then Diag.OpenReport() end end) end, 'BGN_Diag')

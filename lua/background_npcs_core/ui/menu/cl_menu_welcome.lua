--[[
	First-start window: "Classic" or "New" mode.
	Console "bgn_mode_welcome" (or Settings -> Client) opens it again.

	A mode is only a preset of settings that already exist: client ones always apply to this player,
	server ones only when the player is an admin (the server checks the rights again).
--]]

local Menu = bgNPC.Menu
local C = Menu.colors
local ICONS = 'background_npcs/vgui/menu/'

CreateClientConVar('bgn_mode', 'classic', true, false, 'Background NPCs: chosen mode (classic | new)')
local cvar_chosen = CreateClientConVar('bgn_mode_chosen', '0', true, false, 'Background NPCs: the mode window was answered (1) or not (0)')

local MODES = {
	{
		key = 'classic', icon = 'classic.png',
		features = {
			{ true, '#bgn.mode.classic.f1' }, { true, '#bgn.mode.classic.f2' }, { true, '#bgn.mode.classic.f3' },
			{ true, '#bgn.mode.classic.f4' }, { false, '#bgn.mode.classic.f5' },
		},
		server = { bgn_actor_body = 'npc', bgn_brain = 'fsm', bgn_ghost_crowd = '0', bgn_scenic = '0', bgn_settings_rev = '1' },
		client = { bgn_cl_ghost_crowd = '0', bgn_cl_voices = '2', bgn_cl_settings_rev = '1' },
	},
	{
		key = 'new', icon = 'modern.png',
		features = {
			{ true, '#bgn.mode.new.f1' }, { true, '#bgn.mode.new.f2' }, { true, '#bgn.mode.new.f3' },
			{ true, '#bgn.mode.new.f4' }, { false, '#bgn.mode.new.f5' },
		},
		server = { bgn_actor_body = 'nextbot', bgn_brain = 'auto', bgn_ghost_crowd = '1', bgn_scenic = '1', bgn_settings_rev = '1' },
		client = { bgn_cl_ghost_crowd = '1', bgn_cl_voices = '1', bgn_cl_settings_rev = '1' },
	},
}

local function Apply(mode)
	RunConsoleCommand('bgn_mode', mode.key == 'classic' and 'classic' or 'new')
	for name, value in pairs(mode.client) do RunConsoleCommand(name, value) end
	if Menu.IsAdmin() then
		for name, value in pairs(mode.server) do RunConsoleCommand(name, value) end
	end
	notification.AddLegacy(Menu.Text('#bgn.mode.applied.' .. mode.key), NOTIFY_GENERIC, 6)
end

function Menu.CloseWelcome()
	local frame = Menu.welcome
	if not IsValid(frame) or frame.closing then return end
	frame.closing = true
	RunConsoleCommand('bgn_mode_chosen', '1')
	-- first start: the mode is step one, the short setup of the details follows whatever the player chose
	if Menu.welcome_first then
		Menu.welcome_first = nil
		timer.Simple(0.25, function() if Menu.OpenWizard then Menu.OpenWizard() end end)
	end
	frame:AlphaTo(0, 0.1, 0, function() if IsValid(frame) then frame:Remove() end end)
end

function Menu.OpenWelcome()
	if IsValid(Menu.welcome) then Menu.welcome:Remove() end
	Menu.CreateFonts()
	Menu.ApplyTheme(true)

	local s = Menu.Scale()
	local R = math.Round
	local W = math.min(R(900 * s), ScrW() - 32)
	local pad, gap, ip = R(28 * s), R(16 * s), R(20 * s)
	local card_w = math.floor((W - pad * 2 - gap) / 2)
	local text_w = card_w - ip * 2
	local lh_body, lh_small = Menu.FontHeight('BGN.Menu.Body'), Menu.FontHeight('BGN.Menu.Small')
	local mark, tile, btn_h = R(18 * s), R(48 * s), R(38 * s)
	local is_admin = Menu.IsAdmin()
	local function Lines(key, font, width) return Menu.Wrap(Menu.Text(key), font, width) end

	-- Draws a card (or only measures it) and returns its height; the button sits below the returned y
	local function Card(mode, paint)
		local base = '#bgn.mode.' .. mode.key
		local y = ip
		if paint then
			draw.RoundedBox(R(12 * s), ip, y, tile, tile, mode.neutral and C.text or C.accent)
			Menu.Icon(ICONS .. mode.icon, ip + tile * 0.17, y + tile * 0.17, tile * 0.66, mode.neutral and C.surface or C.on_accent)
			local x = ip + tile + R(14 * s)
			draw.SimpleText(Menu.Text(base), 'BGN.Menu.PageTitle', x, y + tile * 0.3, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(Menu.Text(base .. '.tag'), 'BGN.Menu.Small', x, y + tile * 0.78, mode.recommended and C.accent or C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		y = y + tile + R(16 * s)

		for _, line in ipairs(Lines(base .. '.desc', 'BGN.Menu.Body', text_w)) do
			if paint then draw.SimpleText(line, 'BGN.Menu.Body', ip, y, C.text) end
			y = y + lh_body
		end
		y = y + R(16 * s)

		for _, f in ipairs(mode.features) do
			local lines = Lines(f[2], 'BGN.Menu.Body', text_w - mark - R(10 * s))
			local color = f[1] and C.text or C.muted
			if paint then
				local mx, my = ip, y + (lh_body - mark) / 2
				if f[1] then
					Menu.Icon(ICONS .. 'check.png', mx, my, mark, C.accent)
				else
					Menu.Icon(ICONS .. 'close.png', mx, my, mark, C.muted)
				end
				for i, line in ipairs(lines) do
					draw.SimpleText(line, 'BGN.Menu.Body', ip + mark + R(10 * s), y + (i - 1) * lh_body, color)
				end
			end
			y = y + math.max(#lines * lh_body, mark) + R(6 * s)
		end
		y = y + R(10 * s)

		for _, line in ipairs(Lines(base .. '.best', 'BGN.Menu.Small', text_w)) do
			if paint then draw.SimpleText(line, 'BGN.Menu.Small', ip, y, C.muted) end
			y = y + lh_small
		end
		return y + R(16 * s) + btn_h + ip
	end

	local card_h = math.max(Card(MODES[1]), Card(MODES[2]))
	local title_h = Menu.FontHeight('BGN.Menu.PageTitle')
	local sub_lines = Lines('#bgn.mode.subtitle', 'BGN.Menu.Body', W - pad * 2 - R(60 * s))
	local note_lines = Lines(is_admin and '#bgn.mode.note.admin' or '#bgn.mode.note.player', 'BGN.Menu.Small', W - pad * 2)
	local head_h = pad + title_h + R(6 * s) + #sub_lines * lh_body + R(20 * s)
	local H = head_h + card_h + R(16 * s) + #note_lines * lh_small + R(14 * s) + R(32 * s) + pad

	local frame = vgui.Create('EditablePanel')
	Menu.welcome = frame
	frame:SetSize(W, H)
	frame:Center()
	frame:MakePopup()
	frame:SetAlpha(0)
	frame:AlphaTo(255, 0.15)
	Menu.Sound('open')
	frame.Think = Menu.UpdateTheme
	frame.OnRemove = function() if Menu.welcome == frame then Menu.welcome = nil end end

	local radius = R(10 * s)
	frame.Paint = function(self, w, h)
		DisableClipping(true)
		for i = 1, 4 do
			draw.RoundedBox(radius + i * 2, -i * 2, -i * 2 + 4, w + i * 4, h + i * 4, Menu.Fade(C.shadow, 0.35 / i))
		end
		DisableClipping(false)
		draw.RoundedBox(radius, 0, 0, w, h, C.bg)
		draw.SimpleText(Menu.Text('#bgn.mode.title'), 'BGN.Menu.PageTitle', pad, pad, C.text)
		for i, line in ipairs(sub_lines) do
			draw.SimpleText(line, 'BGN.Menu.Body', pad, pad + title_h + R(6 * s) + (i - 1) * lh_body, C.muted)
		end
		local y = head_h + card_h + R(16 * s)
		for i, line in ipairs(note_lines) do
			draw.SimpleText(line, 'BGN.Menu.Small', pad, y + (i - 1) * lh_small, C.muted)
		end
	end

	local size = R(36 * s)
	local theme = Menu.IconButton(frame, size,
		function() return GetConVar('bgn_menu_dark'):GetBool() and ICONS .. 'sun.png' or ICONS .. 'moon.png' end,
		Menu.Text('#bgn.menu.theme'),
		function()
			Menu.Sound('click')
			RunConsoleCommand('bgn_menu_dark', GetConVar('bgn_menu_dark'):GetBool() and '0' or '1')
		end)
	theme:SetPos(W - pad + R(4 * s) - size, R(18 * s))

	for i, mode in ipairs(MODES) do
		local card = frame:Add('DPanel')
		card:SetPos(pad + (i - 1) * (card_w + gap), head_h)
		card:SetSize(card_w, card_h)
		card.Paint = function(self, w, h)
			local r = R(10 * s)
			draw.RoundedBox(r, 0, 0, w, h, mode.recommended and C.accent or C.border)
			draw.RoundedBox(r, 1, 1, w - 2, h - 2, C.surface)
			if mode.recommended then
				local text = Menu.Text('#bgn.mode.recommended')
				surface.SetFont('BGN.Menu.Small')
				local tw = surface.GetTextSize(text)
				local bw, bh = tw + R(18 * s), lh_small + R(6 * s)
				draw.RoundedBox(bh / 2, w - ip - bw, ip + R(4 * s), bw, bh, C.accent)
				draw.SimpleText(text, 'BGN.Menu.Small', w - ip - bw / 2, ip + R(4 * s) + bh / 2, C.on_accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
			Card(mode, true)
		end
		local button = Menu.Button(card, Menu.Text('#bgn.mode.choose'), mode.recommended and 'primary' or 'secondary', function()
			Apply(mode)
			Menu.CloseWelcome()
		end)
		button:SetSize(text_w, btn_h)
		button:SetPos(ip, card_h - ip - btn_h)
	end

	local skip = Menu.Button(frame, Menu.Text('#bgn.mode.skip'), 'secondary', Menu.CloseWelcome)
	skip:SetPos(W - pad - skip:GetWide(), H - pad - skip:GetTall())
end

concommand.Add('bgn_mode_welcome', Menu.OpenWelcome, nil, 'Opens the Classic / New mode choice window')

-- First start: a few seconds after the player has loaded in. Only for the owner of the game (singleplayer or the
-- listen server host): a player who joins somebody's server is never greeted, the window stays in the menu and the console.
hook.Add('InitPostEntity', 'BGN_ModeWelcome', function()
	timer.Simple(5, function()
		if (game.SinglePlayer() or LocalPlayer():IsListenServerHost()) and not cvar_chosen:GetBool() and not Menu.IsOpen() and not IsValid(Menu.welcome) then
			Menu.welcome_first = true
			Menu.OpenWelcome()
		end
	end)
end)

hook.Add('OnPauseMenuShow', 'BGN_ModeWelcome', function()
	if not IsValid(Menu.welcome) then return end
	Menu.CloseWelcome()
	return false
end)

cvars.AddChangeCallback('gmod_language', function() timer.Simple(0.2, function() if IsValid(Menu.welcome) then Menu.OpenWelcome() end end) end, 'BGN_ModeWelcome')

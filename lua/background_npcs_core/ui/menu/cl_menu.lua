--[[
	bgNPC.Menu: the settings window.
	Open: console "bgn_menu [page]", the context menu (C) icon, Spawn menu -> Options -> Background NPCs.

	Add a page (the built-in ones: cl_menu_pages.lua, controls: cl_menu_controls.lua):

		bgNPC.Menu.AddPage('my_addon', {
			title = '#my.phrase',                              -- '#phrase', plain text or { en = '', ru = '' }
			icon = 'background_npcs/vgui/menu/general.png',    -- optional white glyph
			order = 500,                                       -- sidebar position, built-in pages use 100..1100
			build = function(page)
				page:Section('#my.section')
				page:Toggle('my_cvar', '#my.phrase')           -- help text: '#my.phrase.help' when it exists
				page:Slider('my_number', 'Distance', 0, 5000)
				page:Button('Clear', 'my_command', { confirm = true })
			end,
			group = '#bgn.menu.group.server',                -- optional sidebar heading over pages of one group
		})

	Settings registered with bgNPC.CVars are server settings: only admins see them. A page whose rows are all
	hidden is not listed. "bgn_menu_as_player" shows the window as a non-admin sees it (debug).
	Texts follow the game language (gmod_language).
--]]

local Menu = bgNPC.Menu or {}
bgNPC.Menu = Menu
Menu.pages = Menu.pages or {}

local cvar_dark = CreateClientConVar('bgn_menu_dark', '1', true, false, 'Background NPCs menu: dark theme')
local cvar_sounds = CreateClientConVar('bgn_menu_sounds', '1', true, false, 'Background NPCs menu: interface sounds')

local ICONS = 'background_npcs/vgui/menu/'

-- ---------------------------------------------------------------------------
-- Pages
-- ---------------------------------------------------------------------------

-- @param id string unique page id (also "bgn_menu <id>")
-- @param def table { title, icon, order, build = function(page) }
function Menu.AddPage(id, def)
	assert(isstring(id) and istable(def) and isfunction(def.build), 'bgNPC.Menu.AddPage(id, { title, build })')
	def.id = id
	def.order = def.order or 1000
	Menu.pages[id] = def
	if Menu.IsOpen() then Menu.Open(Menu.page_id) end
end

function Menu.RemovePage(id)
	Menu.pages[id] = nil
end

local function SortedPages()
	local list = {}
	for _, def in pairs(Menu.pages) do list[#list + 1] = def end
	table.sort(list, function(a, b)
		if a.order ~= b.order then return a.order < b.order end
		return a.id < b.id
	end)
	return list
end

-- ---------------------------------------------------------------------------
-- Text
-- ---------------------------------------------------------------------------

-- @param value string|table '#phrase', plain text or { en = '', ru = '' }
function Menu.Text(value)
	if istable(value) then
		return value[(bgNPC.Util.GetLanguage())] or value.en or ''
	end
	value = tostring(value or '')
	if value:sub(1, 1) == '#' then
		local key = value:sub(2)
		return bgNPC.Phrases[key] or language.GetPhrase(key)
	end
	return value
end

-- @return string|nil the phrase, nil when the language files don't have it
function Menu.Phrase(key)
	if key:sub(1, 1) == '#' then key = key:sub(2) end
	local text = bgNPC.Phrases[key] or language.GetPhrase(key)
	if text ~= key then return text end
end

local wrap_cache = {}

-- @return table lines of the text that fit into width (explicit line breaks are kept)
function Menu.Wrap(text, font, width)
	width = math.floor(width)
	local key = font .. '\0' .. width .. '\0' .. text
	if wrap_cache[key] then return wrap_cache[key] end

	surface.SetFont(font)
	local lines = {}
	for paragraph in (text .. '\n'):gmatch('(.-)\n') do
		local line = ''
		for word in paragraph:gmatch('%S+') do
			local try = line == '' and word or line .. ' ' .. word
			if line ~= '' and surface.GetTextSize(try) > width then
				lines[#lines + 1] = line
				line = word
			else
				line = try
			end
		end
		lines[#lines + 1] = line
	end

	wrap_cache[key] = lines
	return lines
end

function Menu.FontHeight(font)
	surface.SetFont(font)
	local _, h = surface.GetTextSize('Ag')
	return h
end

-- ---------------------------------------------------------------------------
-- Theme: one accent, neutral surfaces
-- ---------------------------------------------------------------------------

local LIGHT = {
	bg = Color(244, 245, 247), sidebar = Color(236, 238, 242), surface = Color(255, 255, 255),
	hover = Color(243, 244, 247), border = Color(222, 225, 230), text = Color(31, 35, 41),
	muted = Color(107, 114, 128), accent = Color(37, 99, 235), accent_hover = Color(29, 78, 216),
	on_accent = Color(255, 255, 255), track = Color(209, 213, 219), knob = Color(255, 255, 255),
	danger = Color(220, 38, 38), nav_active = Color(255, 255, 255), overlay = Color(15, 17, 21, 110),
	shadow = Color(0, 0, 0, 40),
}

local DARK = {
	bg = Color(22, 24, 29), sidebar = Color(17, 19, 23), surface = Color(30, 33, 40),
	hover = Color(37, 41, 50), border = Color(46, 51, 61), text = Color(230, 232, 235),
	muted = Color(154, 161, 172), accent = Color(76, 141, 255), accent_hover = Color(108, 162, 255),
	on_accent = Color(255, 255, 255), track = Color(58, 64, 75), knob = Color(245, 246, 248),
	danger = Color(240, 82, 82), nav_active = Color(30, 33, 40), overlay = Color(0, 0, 0, 150),
	shadow = Color(0, 0, 0, 90),
}

local C = Menu.colors or {}
Menu.colors = C
local theme_from, theme_to, theme_start

-- @param instant boolean skip the cross-fade
function Menu.ApplyTheme(instant)
	local to = cvar_dark:GetBool() and DARK or LIGHT
	if instant or next(C) == nil then
		for k, v in pairs(to) do C[k] = v end
		theme_to = nil
		return
	end
	theme_from, theme_to, theme_start = table.Copy(C), to, RealTime()
end

local function UpdateTheme()
	if not theme_to then return end
	local f = math.Clamp((RealTime() - theme_start) / 0.2, 0, 1)
	for k, to in pairs(theme_to) do
		local from = theme_from[k] or to
		C[k] = Color(Lerp(f, from.r, to.r), Lerp(f, from.g, to.g), Lerp(f, from.b, to.b), Lerp(f, from.a, to.a))
	end
	if f >= 1 then theme_to = nil end
end

Menu.ApplyTheme(true)
cvars.AddChangeCallback('bgn_menu_dark', function() Menu.ApplyTheme() end, 'BGN_Menu')

-- Color with the alpha multiplied (locked controls are drawn at half strength)
function Menu.Fade(color, alpha)
	return Color(color.r, color.g, color.b, color.a * alpha)
end

function Menu.LerpColor(f, a, b)
	return Color(Lerp(f, a.r, b.r), Lerp(f, a.g, b.g), Lerp(f, a.b, b.b), Lerp(f, a.a, b.a))
end

-- ---------------------------------------------------------------------------
-- Scale and fonts: the layout is designed at 1080p and scaled with the screen height
-- ---------------------------------------------------------------------------

function Menu.Scale()
	return math.Clamp(ScrH() / 1080, 0.75, 2)
end

local font_scale

local function CreateFonts()
	local s = Menu.Scale()
	if font_scale == s then return end
	font_scale = s
	wrap_cache = {}

	local function Font(name, size, weight)
		surface.CreateFont(name, { font = 'Roboto', size = math.Round(size * s), weight = weight, extended = true, antialias = true })
	end
	Font('BGN.Menu.Brand', 19, 700)
	Font('BGN.Menu.PageTitle', 24, 700)
	Font('BGN.Menu.Section', 15, 700)
	Font('BGN.Menu.Nav', 15, 500)
	Font('BGN.Menu.Body', 16, 500)
	Font('BGN.Menu.Small', 14, 400)
	Font('BGN.Menu.Value', 15, 500)
end

local materials = {}

function Menu.Material(path)
	materials[path] = materials[path] or Material(path, 'smooth mips')
	return materials[path]
end

-- Draws a white glyph tinted with the color
function Menu.Icon(path, x, y, size, color)
	surface.SetMaterial(Menu.Material(path))
	surface.SetDrawColor(color)
	surface.DrawTexturedRect(x, y, size, size)
end

-- ---------------------------------------------------------------------------
-- Sounds (sound/background_npcs/ui, generated soft sine tones)
-- ---------------------------------------------------------------------------

local last_hover = 0

-- @param name string hover | click | toggle_on | toggle_off | open | close | tick | denied
function Menu.Sound(name)
	if not cvar_sounds:GetBool() then return end
	if name == 'hover' then
		if RealTime() - last_hover < 0.06 then return end
		last_hover = RealTime()
	end
	surface.PlaySound('background_npcs/ui/' .. name .. '.wav')
end

function Menu.IsAdmin()
	if Menu.as_player then return false end
	local ply = LocalPlayer()
	return IsValid(ply) and ply:IsAdmin()
end

-- ---------------------------------------------------------------------------
-- Small shared widgets
-- ---------------------------------------------------------------------------

-- Round icon button for the header (close, theme)
local function IconButton(parent, size, icon_fn, tooltip, on_click)
	local button = parent:Add('DButton')
	button:SetText('')
	button:SetSize(size, size)
	button:SetTooltip(tooltip)
	button.hover = 0
	button.Paint = function(self, w, h)
		self.hover = Lerp(FrameTime() * 16, self.hover, self:IsHovered() and 1 or 0)
		draw.RoundedBox(h / 2, 0, 0, w, h, Menu.Fade(C.hover, self.hover))
		local icon = math.Round(h * 0.5)
		Menu.Icon(icon_fn(), (w - icon) / 2, (h - icon) / 2, icon, Menu.LerpColor(self.hover, C.muted, C.text))
	end
	button.OnCursorEntered = function() Menu.Sound('hover') end
	button.DoClick = on_click
	return button
end

-- Styled push button. @param style 'primary' | 'secondary' | 'danger'
function Menu.Button(parent, text, style, on_click)
	local s = Menu.Scale()
	local button = parent:Add('DButton')
	button:SetText('')
	button.text = text
	button.style = style or 'secondary'
	surface.SetFont('BGN.Menu.Value')
	button:SetSize(math.max(surface.GetTextSize(text) + 32 * s, 88 * s), math.Round(32 * s))
	button.hover = 0
	button.Paint = function(self, w, h)
		self.hover = Lerp(FrameTime() * 16, self.hover, (self:IsHovered() and self:IsEnabled()) and 1 or 0)
		local r = math.Round(6 * s)
		local alpha = self:IsEnabled() and 1 or 0.45
		local fg
		if self.style == 'primary' then
			draw.RoundedBox(r, 0, 0, w, h, Menu.Fade(Menu.LerpColor(self.hover, C.accent, C.accent_hover), alpha))
			fg = C.on_accent
		else
			local edge = self.style == 'danger' and C.danger or C.border
			draw.RoundedBox(r, 0, 0, w, h, Menu.Fade(edge, alpha))
			draw.RoundedBox(r, 1, 1, w - 2, h - 2, Menu.LerpColor(self.hover, C.surface, C.hover))
			fg = self.style == 'danger' and C.danger or C.text
		end
		draw.SimpleText(self.text, 'BGN.Menu.Value', w / 2, h / 2, Menu.Fade(fg, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	button.OnCursorEntered = function(self) if self:IsEnabled() then Menu.Sound('hover') end end
	button.DoClick = function()
		Menu.Sound('click')
		on_click()
	end
	return button
end

-- Modal card over the window. build(card) fills it; returns the card. Esc / a click outside closes it.
function Menu.Dialog(width, build)
	local frame = Menu.frame
	if not IsValid(frame) then return end
	local s = Menu.Scale()

	local overlay = frame:Add('DPanel')
	overlay:SetSize(frame:GetSize())
	overlay:SetAlpha(0)
	overlay:AlphaTo(255, 0.12)
	overlay.Paint = function(self, w, h)
		draw.RoundedBox(math.Round(10 * s), 0, 0, w, h, C.overlay)
	end
	overlay.OnMousePressed = function(self) self:Remove() end
	frame.dialog = overlay

	local pad = math.Round(24 * s)
	local card = overlay:Add('DPanel')
	card:SetWide(math.Round(width * s))
	card:DockPadding(pad, pad, pad, pad)
	card.Paint = function(self, w, h)
		draw.RoundedBox(math.Round(10 * s), 0, 0, w, h, C.border)
		draw.RoundedBox(math.Round(10 * s), 1, 1, w - 2, h - 2, C.surface)
	end
	card.OnMousePressed = function() end -- clicks inside don't close
	card.Close = function() if IsValid(overlay) then overlay:Remove() end end

	build(card)

	-- children that wrap text get their height from their width: lay out twice, then sum
	card:InvalidateLayout(true)
	for _, child in ipairs(card:GetChildren()) do child:InvalidateLayout(true) end
	card:InvalidateLayout(true)
	local height = pad * 2
	for _, child in ipairs(card:GetChildren()) do
		local _, top, _, bottom = child:GetDockMargin()
		height = height + child:GetTall() + top + bottom
	end
	card:SetTall(height)
	card:Center()
	return card
end

-- Adds the dialog's button row (right-aligned). buttons: { { text, style, on_click }, ... }
function Menu.DialogButtons(card, buttons)
	local s = Menu.Scale()
	local row = card:Add('DPanel')
	row:Dock(TOP)
	row:DockMargin(0, math.Round(20 * s), 0, 0)
	row:SetTall(math.Round(32 * s))
	row.Paint = nil
	for i = #buttons, 1, -1 do
		local def = buttons[i]
		local button = Menu.Button(row, def[1], def[2], function()
			card.Close()
			if def[3] then def[3]() end
		end)
		button:Dock(RIGHT)
		button:DockMargin(math.Round(8 * s), 0, 0, 0)
	end
	return row
end

-- Text block for dialogs and notes
function Menu.Paragraph(parent, text, font, color)
	local label = parent:Add('DPanel')
	label:Dock(TOP)
	label.Paint = function(self, w)
		local lh = Menu.FontHeight(font)
		for i, line in ipairs(Menu.Wrap(text, font, w)) do
			draw.SimpleText(line, font, 0, (i - 1) * lh, color or C.text)
		end
	end
	label.PerformLayout = function(self, w)
		local h = #Menu.Wrap(text, font, w) * Menu.FontHeight(font)
		if self:GetTall() ~= h then self:SetTall(h) end
	end
	return label
end

-- @param text string question; @param on_yes function; @param danger boolean red confirm button
function Menu.Confirm(text, on_yes, danger, yes_text)
	Menu.Dialog(420, function(card)
		Menu.Paragraph(card, text, 'BGN.Menu.Body')
		Menu.DialogButtons(card, {
			{ Menu.Text('#bgn.menu.cancel'), 'secondary' },
			{ yes_text or Menu.Text('#bgn.menu.confirm'), danger and 'danger' or 'primary', on_yes },
		})
	end)
end

-- ---------------------------------------------------------------------------
-- Window
-- ---------------------------------------------------------------------------

function Menu.IsOpen()
	return IsValid(Menu.frame)
end

function Menu.Close()
	local frame = Menu.frame
	if not IsValid(frame) or frame.closing then return end
	frame.closing = true
	Menu.Sound('close')
	frame:AlphaTo(0, 0.1, 0, function() if IsValid(frame) then frame:Remove() end end)
end

local function StyleScrollBar(scroll, s)
	local bar = scroll:GetVBar()
	bar:SetWide(math.Round(10 * s))
	bar:SetHideButtons(true)
	bar.Paint = nil
	bar.btnGrip.Paint = function(self, w, h)
		local inset = math.Round(3 * s)
		draw.RoundedBox((w - inset * 2) / 2, inset, 0, w - inset * 2, h, (self:IsHovered() or self.Depressed) and C.muted or C.border)
	end
end

local function ResetContent(frame, title)
	local content = frame.content
	content:Clear()
	frame.page_title = title

	local canvas = content:GetCanvas()
	canvas:SetAlpha(0)
	canvas:AlphaTo(255, 0.15)
end

local function RunBuild(def, page)
	local ok, err = pcall(def.build, page)
	if not ok then
		ErrorNoHalt('[Background NPCs] Menu page "' .. def.id .. '" failed: ' .. tostring(err) .. '\n')
		if not page.filter then page:Note(Menu.Text('#bgn.menu.page_error')) end
	end
end

local function BuildPage(frame, def)
	frame.query = nil
	ResetContent(frame, Menu.Text(def.title))
	RunBuild(def, Menu.NewBuilder(frame.content))
end

-- Every page built with a filter: only the matching rows, under "Page › Section" headings
-- @param query string normalized (Menu.Normalize), not empty
local function BuildSearch(frame, query)
	frame.query = query
	ResetContent(frame, Menu.Text('#bgn.menu.search.results'))
	local results = { count = 0 }
	for _, def in ipairs(SortedPages()) do
		RunBuild(def, Menu.NewBuilder(frame.content, {
			query = query, page_id = def.id, page_title = Menu.Text(def.title), results = results,
		}))
	end
	if results.count == 0 then
		Menu.Paragraph(frame.content, Menu.Text('#bgn.menu.search.empty'), 'BGN.Menu.Body', C.muted)
	end
end

-- Shows a page in the open window (clears the search). Opens the window when it is closed.
function Menu.ShowPage(page_id)
	local frame = Menu.frame
	if not IsValid(frame) or not Menu.pages[page_id] then return Menu.Open(page_id) end
	if IsValid(frame.search) then frame.search:SetText('') end
	Menu.page_id = page_id
	BuildPage(frame, Menu.pages[page_id])
end

-- Pages this player sees: for non-admins, pages whose rows are all server settings are left out.
-- A search build (no network requests) with an empty query counts the rows.
local function VisiblePages()
	local pages = SortedPages()
	if Menu.IsAdmin() then return pages end

	local probe = vgui.Create('DPanel')
	probe:SetVisible(false)
	local list = {}
	for _, def in ipairs(pages) do
		local builder = Menu.NewBuilder(probe, { query = '', page_id = def.id, page_title = '', results = { count = 0 } })
		RunBuild(def, builder)
		if builder.rows == 0 or builder.visible > 0 then list[#list + 1] = def end
	end
	probe:Remove()
	return list
end

-- @param page_id string|nil page to show, the last one by default
function Menu.Open(page_id)
	if IsValid(Menu.frame) then Menu.frame:Remove() end
	CreateFonts()
	Menu.ApplyTheme(true)

	local pages = VisiblePages()
	if #pages == 0 then return end
	local shown = {}
	for _, def in ipairs(pages) do shown[def.id] = true end
	if not shown[page_id or ''] then page_id = shown[Menu.page_id or ''] and Menu.page_id or pages[1].id end

	local s = Menu.Scale()
	local W = math.min(math.Round(1000 * s), ScrW() - 32)
	local H = math.min(math.Round(720 * s), ScrH() - 32)
	local corner = math.Round(10 * s)
	local radius = corner

	local frame = vgui.Create('EditablePanel')
	Menu.frame = frame

	-- full screen: square corners, the content column keeps a readable width (content.PerformLayout)
	function frame.SetMaximized(on)
		Menu.maximized = on
		radius = on and 0 or corner
		if on then
			frame:SetPos(0, 0)
			frame:SetSize(ScrW(), ScrH())
		else
			frame:SetSize(W, H)
			frame:Center()
		end
		frame:InvalidateLayout()
		Menu.ContentChanged()
	end

	frame.SetMaximized(Menu.maximized or false)
	frame:MakePopup()
	frame:SetAlpha(0)
	frame:AlphaTo(255, 0.15)
	Menu.Sound('open')

	frame.Think = function(self)
		UpdateTheme()
		-- a row or card changed its height (Menu.ContentChanged): lay the page out again
		if self.relayout and IsValid(self.content) then
			self.relayout = false
			self.content:InvalidateLayout()
		end
		-- Ctrl+F: the search field
		local find = input.IsKeyDown(KEY_F) and (input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL))
		if find and not self.find_down and IsValid(self.search) then
			self.search:RequestFocus()
			self.search:SelectAllText()
		end
		self.find_down = find
	end
	frame.Paint = function(self, w, h)
		if radius == 0 then
			surface.SetDrawColor(C.bg)
			surface.DrawRect(0, 0, w, h)
			return
		end
		DisableClipping(true)
		for i = 1, 4 do
			draw.RoundedBox(radius + i * 2, -i * 2, -i * 2 + 4, w + i * 4, h + i * 4, Menu.Fade(C.shadow, 0.35 / i))
		end
		DisableClipping(false)
		draw.RoundedBox(radius, 0, 0, w, h, C.bg)
	end

	-- sidebar -----------------------------------------------------------------
	local sidebar = frame:Add('DPanel')
	sidebar:Dock(LEFT)
	sidebar:SetWide(math.Round(232 * s))
	local side_pad = math.Round(12 * s)
	sidebar:DockPadding(side_pad, math.Round(72 * s), side_pad, side_pad)
	sidebar.Paint = function(self, w, h)
		draw.RoundedBoxEx(radius, 0, 0, w, h, C.sidebar, true, false, true, false)
		surface.SetDrawColor(C.border)
		surface.DrawRect(w - 1, 0, 1, h)
		local icon = math.Round(28 * s)
		local x, y = math.Round(16 * s), math.Round(22 * s)
		draw.RoundedBox(math.Round(7 * s), x, y, icon, icon, C.accent)
		Menu.Icon(ICONS .. 'actors.png', x + icon * 0.15, y + icon * 0.15, icon * 0.7, C.on_accent)
		draw.SimpleText(Menu.Text('#bgn.menu.title'), 'BGN.Menu.Brand', x + icon + math.Round(10 * s), y + icon / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	-- search: rebuilds the content a moment after typing stops
	local search_box = sidebar:Add('DPanel')
	search_box:Dock(TOP)
	search_box:DockMargin(0, 0, 0, math.Round(10 * s))
	search_box:SetTall(math.Round(34 * s))
	local search_icon = math.Round(16 * s)
	search_box:DockPadding(math.Round(20 * s) + search_icon, 0, math.Round(8 * s), 0)
	local search = search_box:Add('DTextEntry')
	search:Dock(FILL)
	search:SetFont('BGN.Menu.Nav')
	search:SetUpdateOnType(true)
	frame.search = search
	search_box.Paint = function(self, w, h)
		local r = math.Round(6 * s)
		draw.RoundedBox(r, 0, 0, w, h, search:HasFocus() and C.accent or C.border)
		draw.RoundedBox(r, 1, 1, w - 2, h - 2, C.surface)
		Menu.Icon(ICONS .. 'search.png', math.Round(10 * s), (h - search_icon) / 2, search_icon, C.muted)
	end
	search.Paint = function(self, w, h)
		if self:GetText() == '' then
			draw.SimpleText(Menu.Text('#bgn.menu.search'), 'BGN.Menu.Nav', 3, h / 2, C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		self:DrawTextEntryText(C.text, C.accent, C.text)
	end
	search.OnChange = function(self)
		timer.Create('BGN_Menu_Search', 0.2, 1, function()
			if not IsValid(frame) or not IsValid(self) then return end
			local query = Menu.Normalize(string.Trim(self:GetText()))
			if query == (frame.query or '') then return end
			if query == '' then
				BuildPage(frame, Menu.pages[Menu.page_id])
			else
				BuildSearch(frame, query)
			end
		end)
	end

	local nav = sidebar:Add('DScrollPanel')
	nav:Dock(FILL)
	StyleScrollBar(nav, s)

	local last_group
	for _, def in ipairs(pages) do
		if def.group and def.group ~= last_group then
			local head = nav:Add('DPanel')
			head:Dock(TOP)
			head:DockMargin(math.Round(14 * s), last_group and math.Round(14 * s) or 0, 0, math.Round(4 * s))
			head:SetTall(Menu.FontHeight('BGN.Menu.Small'))
			local group = def.group
			head.Paint = function() draw.SimpleText(Menu.Text(group), 'BGN.Menu.Small', 0, 0, C.muted) end
		end
		last_group = def.group or last_group

		local item = nav:Add('DButton')
		item:Dock(TOP)
		item:DockMargin(0, 0, 0, math.Round(2 * s))
		item:SetTall(math.Round(38 * s))
		item:SetText('')
		item.hover = 0
		item.Paint = function(self, w, h)
			local active = Menu.page_id == def.id and not frame.query
			self.hover = Lerp(FrameTime() * 16, self.hover, (self:IsHovered() or active) and 1 or 0)
			local r = math.Round(6 * s)
			if active then
				draw.RoundedBox(r, 0, 0, w, h, C.nav_active)
				draw.RoundedBox(2, 0, h * 0.25, math.Round(3 * s), h * 0.5, C.accent)
			else
				-- def.highlight: a faint accent tint and icon, so the page stands out a little
				if def.highlight then draw.RoundedBox(r, 0, 0, w, h, Menu.Fade(C.accent, 0.1)) end
				if self.hover > 0.01 then draw.RoundedBox(r, 0, 0, w, h, Menu.Fade(C.hover, self.hover)) end
			end
			local icon = math.Round(18 * s)
			local x = math.Round(14 * s)
			if def.icon then
				Menu.Icon(def.icon, x, (h - icon) / 2, icon, (active or def.highlight) and C.accent or C.muted)
				x = x + icon + math.Round(12 * s)
			end
			draw.SimpleText(Menu.Text(def.title), 'BGN.Menu.Nav', x, h / 2, active and C.text or Menu.LerpColor(self.hover, C.muted, C.text), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		item.OnCursorEntered = function() Menu.Sound('hover') end
		item.DoClick = function()
			if Menu.page_id == def.id and not frame.query then return end
			Menu.Sound('click')
			Menu.ShowPage(def.id)
		end
	end

	-- main column -------------------------------------------------------------
	local main = frame:Add('DPanel')
	main:Dock(FILL)
	main.Paint = nil

	local header = main:Add('DPanel')
	header:Dock(TOP)
	header:SetTall(math.Round(72 * s))
	local pad = math.Round(32 * s)
	header.Paint = function(self, w, h)
		draw.SimpleText(frame.page_title or '', 'BGN.Menu.PageTitle', pad, h / 2 + math.Round(4 * s), C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	-- drag the window by the header, a double click maximizes / restores it
	header.OnMousePressed = function(self, code)
		if code ~= MOUSE_LEFT then return end
		if RealTime() - (self.last_click or 0) < 0.35 then
			self.last_click = 0
			frame.ToggleMaximized()
			return
		end
		self.last_click = RealTime()
		if Menu.maximized then return end
		local mx, my = gui.MousePos()
		self.drag = { mx - frame.x, my - frame.y }
		self:MouseCapture(true)
	end
	header.OnMouseReleased = function(self)
		self.drag = nil
		self:MouseCapture(false)
	end
	header.Think = function(self)
		if not self.drag then return end
		if not input.IsMouseDown(MOUSE_LEFT) then self:OnMouseReleased() return end
		local mx, my = gui.MousePos()
		frame:SetPos(math.Clamp(mx - self.drag[1], 0, ScrW() - frame:GetWide()), math.Clamp(my - self.drag[2], 0, ScrH() - frame:GetTall()))
	end

	local button_size = math.Round(36 * s)
	local close = IconButton(header, button_size, function() return ICONS .. 'close.png' end, Menu.Text('#bgn.menu.close'), Menu.Close)
	local theme = IconButton(header, button_size,
		function() return cvar_dark:GetBool() and ICONS .. 'sun.png' or ICONS .. 'moon.png' end,
		Menu.Text('#bgn.menu.theme'),
		function()
			Menu.Sound('click')
			RunConsoleCommand('bgn_menu_dark', cvar_dark:GetBool() and '0' or '1')
		end)
	local maximize = IconButton(header, button_size,
		function() return Menu.maximized and ICONS .. 'restore.png' or ICONS .. 'maximize.png' end,
		Menu.Text(Menu.maximized and '#bgn.menu.restore' or '#bgn.menu.maximize'),
		function() frame.ToggleMaximized() end)
	function frame.ToggleMaximized()
		Menu.Sound('click')
		frame.SetMaximized(not Menu.maximized)
		maximize:SetTooltip(Menu.Text(Menu.maximized and '#bgn.menu.restore' or '#bgn.menu.maximize'))
	end
	header.PerformLayout = function(self, w, h)
		local y = math.Round(18 * s)
		local gap = math.Round(8 * s)
		close:SetPos(w - math.Round(20 * s) - button_size, y)
		maximize:SetPos(close.x - gap - button_size, y)
		theme:SetPos(maximize.x - gap - button_size, y)
	end

	local content = main:Add('DScrollPanel')
	content:Dock(FILL)
	content:DockMargin(pad, math.Round(4 * s), math.Round(16 * s), math.Round(16 * s))
	StyleScrollBar(content, s)
	frame.content = content
	-- the column is capped and centred on wide (maximized) windows; the scroll bar stays on the right
	local max_width = math.Round(1100 * s)
	local base_layout = content.PerformLayout
	content.PerformLayout = function(self, w, h)
		local side = math.max(0, math.floor((self:GetWide() - max_width) / 2))
		if side ~= self.side then
			self.side = side
			self:GetCanvas():DockPadding(side, 0, math.Round(16 * s) + side, math.Round(16 * s))
			Menu.ContentChanged()
		end
		base_layout(self, w, h)
	end

	Menu.page_id = page_id
	BuildPage(frame, Menu.pages[page_id])
end

-- ---------------------------------------------------------------------------
-- Entry points
-- ---------------------------------------------------------------------------

concommand.Add('bgn_menu', function(_, _, args) Menu.Open(args[1]) end, nil, 'Opens the Background NPCs settings: bgn_menu [page]')

-- Debug: only what the window shows changes, the server still checks the rights
concommand.Add('bgn_menu_as_player', function(_, _, args)
	if args[1] then Menu.as_player = tobool(args[1]) else Menu.as_player = not Menu.as_player end
	MsgN('[Background NPCs] Settings window as a non-admin: ' .. (Menu.as_player and 'on' or 'off'))
	Menu.Open(Menu.page_id)
end, nil, 'Debug: opens the settings window as a non-admin sees it. bgn_menu_as_player [1/0], no argument toggles')

list.Set('DesktopWindows', 'BGN_Menu', {
	title = 'Background NPCs',
	icon = ICONS .. 'app.png',
	init = function(icon, window)
		window:Remove()
		Menu.Open()
	end,
})

-- Esc closes an open dialog, then the window, instead of opening the game menu
hook.Add('OnPauseMenuShow', 'BGN_Menu', function()
	local frame = Menu.frame
	if not IsValid(frame) then return end
	if IsValid(frame.dialog) then
		frame.dialog:Remove()
	elseif frame.query then
		Menu.ShowPage(Menu.page_id)
	else
		Menu.Close()
	end
	return false
end)

-- rebuilt for a new resolution or language
local function Reopen()
	font_scale = nil
	if Menu.IsOpen() then Menu.Open(Menu.page_id) end
end
hook.Add('OnScreenSizeChanged', 'BGN_Menu', Reopen)
cvars.AddChangeCallback('gmod_language', function() timer.Simple(0.2, Reopen) end, 'BGN_Menu')
cvars.AddChangeCallback('bgn_cl_ui_language', function() timer.Simple(0.2, Reopen) end, 'BGN_Menu')

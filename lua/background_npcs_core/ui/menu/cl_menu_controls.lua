--[[
	Page builder: the "page" object passed to a page's build function (see cl_menu.lua).

		page:Section(title, help)                       -- a titled group, the following controls go into its card
		page:Toggle(cvar, label, opts)                   -- on / off
		page:Slider(cvar, label, min, max, opts)         -- opts.decimals (0), opts.limit (max for typed values)
		page:Button(label, command|func, opts)           -- opts.text (caption), opts.confirm (true|text), opts.danger, opts.admin
		page:Choice(cvar, label, { { value, text }, ... }, opts)  -- one of a few values
		page:Color(label, { r_cvar, g_cvar, b_cvar }, opts)
		page:Note(text)                                  -- a muted paragraph
		page:Row(label, help, server, cvar)              -- an empty row: set row.control to your own panel
		page:Custom(function(panel) end)                 -- anything else, docked at the top

	Every label/help takes '#phrase', plain text or { en = '', ru = '' }. Without opts.help a '#key' label uses
	'#key.help' when it exists. opts.server (default: the cvar is a bgNPC.CVars server setting) hides the
	control from non-admins; a section without visible rows has no heading.

	Search builds every page with a filter (builder.filter): rows that don't match go into a hidden panel,
	so a page's build function works unchanged. Methods can be added to bgNPC.Menu.Builder by other addons.
--]]

local Menu = bgNPC.Menu
local C = Menu.colors

local Builder = Menu.Builder or {}
Builder.__index = Builder
Menu.Builder = Builder

-- Heights depend on the width, which is known only after layout: anything that changes its height asks
-- the window to lay the page out again on the next frame (it settles in a frame or two).
function Menu.ContentChanged()
	if IsValid(Menu.frame) then Menu.frame.relayout = true end
end

-- @param scroll DScrollPanel page content
-- @param search table|nil { query, page_id, page_title, results = { count } } builds only matching rows
-- builder.rows / builder.visible: rows built / rows shown to this player
function Menu.NewBuilder(scroll, search)
	local builder = setmetatable({ scroll = scroll, rows = 0, visible = 0 }, Builder)
	if search then
		builder.filter = search.query
		builder.search = search
		builder.emitted = false
		builder.page_match = Menu.Normalize(search.page_title):find(search.query, 1, true) ~= nil
	end
	return builder
end

-- Lower case for Latin and Cyrillic (string.lower is byte-wise), ё -> е.
function Menu.Normalize(text)
	local ok, result = pcall(function()
		local out = {}
		for _, code in utf8.codes(text) do
			if (code >= 0x41 and code <= 0x5A) or (code >= 0x410 and code <= 0x42F) then
				code = code + 32
			elseif code == 0x401 or code == 0x451 then
				code = 0x435
			end
			out[#out + 1] = utf8.char(code)
		end
		return table.concat(out)
	end)
	return ok and result or string.lower(text)
end

-- @return boolean the texts match the search query (or the page / section title does)
function Builder:Matches(...)
	if self.page_match or self.section_match then return true end
	local parts = {}
	for _, text in pairs({ ... }) do parts[#parts + 1] = text end
	return Menu.Normalize(table.concat(parts, ' ')):find(self.filter, 1, true) ~= nil
end

-- Hidden holder for the rows a search filtered out
function Builder:Trash()
	if not IsValid(self.trash) then
		self.trash = self.scroll:Add('DPanel')
		self.trash:SetVisible(false)
	end
	return self.trash
end

-- Search: the "Page › Section" heading before the first matching row of a section
function Builder:EmitHeading()
	if self.emitted == self.pending then return end
	self.emitted = self.pending
	local title = self.search.page_title
	if self.pending then title = title .. '  ›  ' .. Menu.Text(self.pending) end
	local head = self:SectionHead(title)
	local page_id = self.search.page_id
	head.link = true
	head:SetCursor('hand')
	head:SetMouseInputEnabled(true)
	head.OnMousePressed = function() Menu.Sound('click') Menu.ShowPage(page_id) end
end

local function Help(label, opts)
	if opts and opts.help ~= nil then return opts.help end
	if isstring(label) and label:sub(1, 1) == '#' then return Menu.Phrase(label .. '.help') end
end

local function IsServer(cvar, opts)
	if opts and opts.server ~= nil then return opts.server end
	return bgNPC.CVars.IsRegistered(cvar)
end

local function Smooth(x)
	return x * x * (3 - 2 * x)
end

-- ---------------------------------------------------------------------------
-- Structure
-- ---------------------------------------------------------------------------

-- @return Panel a panel docked at the top of the page
function Builder:Add(class)
	local panel = self.scroll:Add(class or 'DPanel')
	panel:Dock(TOP)
	return panel
end

function Builder:Section(title, help)
	if self.filter then
		self.pending = title
		self.section_match = false
		self.section_match = self:Matches(Menu.Text(title))
		self.card = nil
		return
	end
	-- the heading appears with the first visible row (FlushSection)
	self.pending_head = { title = title, help = help }
	self.card = nil
end

function Builder:FlushSection()
	local head = self.pending_head
	if not head then return end
	self.pending_head = nil
	return self:SectionHead(Menu.Text(head.title), head.help and Menu.Text(head.help))
end

-- @param title_text string; @param help_text string|nil (already translated)
function Builder:SectionHead(title_text, help_text)
	local s = Menu.Scale()
	local head = self:Add('DPanel')
	head:DockMargin(0, self.started and math.Round(24 * s) or 0, 0, math.Round(8 * s))
	self.started = true
	self.card = nil

	head.PerformLayout = function(panel, w)
		local h = Menu.FontHeight('BGN.Menu.Section')
		if help_text then h = h + math.Round(2 * s) + #Menu.Wrap(help_text, 'BGN.Menu.Small', w) * Menu.FontHeight('BGN.Menu.Small') end
		if panel:GetTall() ~= h then
			panel:SetTall(h)
			Menu.ContentChanged()
		end
	end
	head.Paint = function(panel, w)
		draw.SimpleText(title_text, 'BGN.Menu.Section', 0, 0, panel.link and panel:IsHovered() and C.accent or C.text)
		if not help_text then return end
		local y = Menu.FontHeight('BGN.Menu.Section') + math.Round(2 * s)
		local lh = Menu.FontHeight('BGN.Menu.Small')
		for i, line in ipairs(Menu.Wrap(help_text, 'BGN.Menu.Small', w)) do
			draw.SimpleText(line, 'BGN.Menu.Small', 0, y + (i - 1) * lh, C.muted)
		end
	end
	return head
end

-- The card that holds rows; a section starts a new one.
function Builder:Card()
	if IsValid(self.card) then return self.card end
	self:FlushSection()
	local s = Menu.Scale()
	local radius = math.Round(8 * s)
	local card = self:Add('DPanel')
	card:DockPadding(1, 1, 1, 1)
	self.started = true
	card.Paint = function(panel, w, h)
		draw.RoundedBox(radius, 0, 0, w, h, C.border)
		draw.RoundedBox(radius, 1, 1, w - 2, h - 2, C.surface)
	end
	card.PerformLayout = function(panel)
		local children = panel:GetChildren()
		local h = 2
		for i, child in ipairs(children) do
			child.is_first, child.is_last = i == 1, i == #children
			h = h + child:GetTall()
		end
		if panel:GetTall() ~= h then
			panel:SetTall(h)
			Menu.ContentChanged()
		end
	end
	self.card = card
	return card
end

local function RowLayout(row, w, h)
	local s = Menu.Scale()
	local pad, vpad = math.Round(16 * s), math.Round(14 * s)
	local control = row.control
	local reserved = IsValid(control) and control:GetWide() + math.Round(24 * s) or 0
	if row.locked then reserved = reserved + math.Round(22 * s) end
	local text_w = w - pad * 2 - reserved

	row.lines = Menu.Wrap(row.label, 'BGN.Menu.Body', text_w)
	row.help_lines = row.help and Menu.Wrap(row.help, 'BGN.Menu.Small', text_w) or {}
	local text_h = #row.lines * Menu.FontHeight('BGN.Menu.Body')
	if #row.help_lines ~= 0 then
		text_h = text_h + math.Round(3 * s) + #row.help_lines * Menu.FontHeight('BGN.Menu.Small')
	end

	local height = math.Round(math.max(text_h, IsValid(control) and control:GetTall() or 0) + vpad * 2)
	row.text_y = math.Round((height - text_h) / 2)
	if IsValid(control) then control:SetPos(w - pad - control:GetWide(), math.Round((height - control:GetTall()) / 2)) end
	if height ~= h then
		row:SetTall(height)
		row:GetParent():InvalidateLayout()
	end
end

local function RowPaint(row, w, h)
	local s = Menu.Scale()
	local pad = math.Round(16 * s)
	row.hover = Lerp(FrameTime() * 16, row.hover, (row.clickable and (row:IsHovered() or row:IsChildHovered())) and 1 or 0)
	if row.hover > 0.01 then
		draw.RoundedBoxEx(math.Round(7 * s), 0, 0, w, h, Menu.Fade(C.hover, row.hover), row.is_first, row.is_first, row.is_last, row.is_last)
	end
	if not row.is_first then
		surface.SetDrawColor(C.border)
		surface.DrawRect(pad, 0, w - pad * 2, 1)
	end
	if not row.lines then return end

	local y = row.text_y
	local body_h = Menu.FontHeight('BGN.Menu.Body')
	for _, line in ipairs(row.lines) do
		draw.SimpleText(line, 'BGN.Menu.Body', pad, y, row.locked and C.muted or C.text)
		y = y + body_h
	end
	y = y + math.Round(3 * s)
	local small_h = Menu.FontHeight('BGN.Menu.Small')
	for _, line in ipairs(row.help_lines) do
		draw.SimpleText(line, 'BGN.Menu.Small', pad, y, C.muted)
		y = y + small_h
	end

	if row.locked and IsValid(row.control) then
		local icon = math.Round(14 * s)
		Menu.Icon('background_npcs/vgui/menu/lock.png', row.control.x - math.Round(10 * s) - icon, (h - icon) / 2, icon, C.muted)
	end
end

-- @param server boolean the row changes a server setting (hidden from non-admins)
-- @param cvar string|nil searched by its name too
-- @param locked boolean|nil shown but can't be changed (opts.locked of the controls)
-- @return Panel the row; put your control into row.control (it is placed on the right)
function Builder:Row(label, help, server, cvar, locked)
	local label_text = Menu.Text(label)
	local help_text = help and Menu.Text(help) or nil
	if help_text == '' then help_text = nil end

	local hidden = server and not Menu.IsAdmin() -- non-admins don't see what they can't change
	self.rows = self.rows + 1

	local parent
	if hidden or (self.filter and not self:Matches(label_text, help_text, cvar)) then
		parent = self:Trash()
	else
		self.visible = self.visible + 1
		if self.filter then
			self:EmitHeading()
			self.search.results.count = self.search.results.count + 1
		end
		parent = self:Card()
	end

	local row = parent:Add('DPanel')
	row:Dock(TOP)
	row.label = label_text
	row.help = help_text
	row.locked = hidden or locked or false -- hidden rows stay disabled too
	row.hover = 0
	row.PerformLayout = RowLayout
	row.Paint = RowPaint
	return row
end

function Builder:Note(text)
	if self.filter then return Menu.Paragraph(self:Trash(), Menu.Text(text), 'BGN.Menu.Small') end
	self:FlushSection()
	local s = Menu.Scale()
	local note = Menu.Paragraph(self.scroll, Menu.Text(text), 'BGN.Menu.Small', C.muted)
	note:DockMargin(0, self.started and math.Round(12 * s) or 0, 0, math.Round(12 * s))
	local layout = note.PerformLayout
	note.PerformLayout = function(panel, w, h)
		layout(panel, w, h)
		if panel:GetTall() ~= h then Menu.ContentChanged() end
	end
	self.started = true
	self.card = nil
	return note
end

-- @param build function(panel) fills a panel docked at the top; set its height yourself
function Builder:Custom(build)
	if not self.filter then self:FlushSection() end
	local panel = self.filter and self:Trash():Add('DPanel') or self:Add('DPanel')
	panel.Paint = nil
	self.started = true
	self.card = nil
	build(panel)
	return panel
end

-- ---------------------------------------------------------------------------
-- Controls
-- ---------------------------------------------------------------------------

function Builder:Toggle(cvar, label, opts)
	opts = opts or {}
	local s = Menu.Scale()
	local row = self:Row(label, Help(label, opts), IsServer(cvar, opts), cvar, opts.locked)

	local function Get()
		local cv = GetConVar(cvar)
		return cv ~= nil and cv:GetBool()
	end

	local switch = row:Add('DPanel')
	switch:SetSize(math.Round(42 * s), math.Round(24 * s))
	switch:SetMouseInputEnabled(false) -- the whole row is the click target
	switch.anim = Get() and 1 or 0
	switch.Paint = function(panel, w, h)
		panel.anim = math.Approach(panel.anim, Get() and 1 or 0, FrameTime() * 7)
		local f = Smooth(panel.anim)
		local alpha = row.locked and 0.5 or 1
		draw.RoundedBox(h / 2, 0, 0, w, h, Menu.Fade(Menu.LerpColor(f, C.track, C.accent), alpha))
		local inset = math.Round(3 * s)
		local knob = h - inset * 2
		draw.RoundedBox(knob / 2, inset + (w - knob - inset * 2) * f, inset, knob, knob, Menu.Fade(C.knob, alpha))
	end
	row.control = switch

	row.clickable = not row.locked
	row:SetCursor(row.locked and 'no' or 'hand')
	row.OnMousePressed = function(panel, code)
		if code ~= MOUSE_LEFT then return end
		if panel.locked or not GetConVar(cvar) then
			Menu.Sound('denied')
			return
		end
		local enabled = not Get()
		RunConsoleCommand(cvar, enabled and '1' or '0')
		Menu.Sound(enabled and 'toggle_on' or 'toggle_off')
		if opts.on_change then opts.on_change(enabled) end
	end
	return row
end

function Builder:Slider(cvar, label, min, max, opts)
	opts = opts or {}
	local s = Menu.Scale()
	local decimals = opts.decimals or 0
	local row = self:Row(label, Help(label, opts), IsServer(cvar, opts), cvar, opts.locked)

	local function Get()
		local cv = GetConVar(cvar)
		return cv and cv:GetFloat() or min
	end
	local function Round(v)
		local m = 10 ^ decimals
		return math.Round(v * m) / m
	end
	local function Format(v)
		return decimals == 0 and tostring(math.Round(v)) or string.format('%.' .. decimals .. 'f', v)
	end
	local function Set(v)
		v = math.max(Round(v), min)
		if opts.limit then v = math.min(v, opts.limit) end
		if v == Round(Get()) then return false end
		RunConsoleCommand(cvar, Format(v))
		return true
	end

	local ctrl = row:Add('DPanel')
	ctrl:SetSize(math.Round(280 * s), math.Round(32 * s))
	ctrl.Paint = nil
	row.control = ctrl

	local entry_w = math.Round(72 * s)
	local knob_r = math.Round(8 * s)
	local track = ctrl:Add('DPanel')
	track:SetSize(ctrl:GetWide() - entry_w - math.Round(16 * s), ctrl:GetTall())
	track:SetCursor(row.locked and 'no' or 'hand')
	track.hover = 0

	local function Frac(v) return math.Clamp((v - min) / (max - min), 0, 1) end
	local function CursorValue(panel)
		local x = panel:CursorPos()
		return Round(min + math.Clamp((x - knob_r) / (panel:GetWide() - knob_r * 2), 0, 1) * (max - min))
	end

	track.Paint = function(panel, w, h)
		panel.hover = Lerp(FrameTime() * 16, panel.hover, (not row.locked and (panel:IsHovered() or panel.dragging)) and 1 or 0)
		local alpha = row.locked and 0.5 or 1
		local f = Frac(panel.dragging and panel.drag_value or Get())
		local bar = math.max(2, math.Round(4 * s))
		local y = h / 2
		local x0, x1 = knob_r, w - knob_r
		local kx = x0 + (x1 - x0) * f
		draw.RoundedBox(bar / 2, x0, y - bar / 2, x1 - x0, bar, Menu.Fade(C.track, alpha))
		draw.RoundedBox(bar / 2, x0, y - bar / 2, kx - x0, bar, Menu.Fade(C.accent, alpha))
		local r = knob_r + panel.hover * math.Round(2 * s)
		draw.RoundedBox(r, kx - r, y - r, r * 2, r * 2, Menu.Fade(C.accent, alpha))
		local inner = r - math.Round(3 * s)
		draw.RoundedBox(inner, kx - inner, y - inner, inner * 2, inner * 2, Menu.Fade(C.knob, alpha))
	end
	track.OnMousePressed = function(panel, code)
		if code ~= MOUSE_LEFT then return end
		if row.locked then
			Menu.Sound('denied')
			return
		end
		panel.dragging = true
		panel.drag_value = CursorValue(panel)
		panel:MouseCapture(true)
		Menu.Sound('tick')
	end
	-- the value is sent once on release: a server setting would flood the network while dragging
	track.Think = function(panel)
		if not panel.dragging then return end
		if not input.IsMouseDown(MOUSE_LEFT) then
			panel.dragging = false
			panel:MouseCapture(false)
			Set(panel.drag_value)
			Menu.Sound('click')
			return
		end
		local value = CursorValue(panel)
		if value ~= panel.drag_value then
			panel.drag_value = value
			if RealTime() - (panel.last_tick or 0) > 0.05 then
				panel.last_tick = RealTime()
				Menu.Sound('tick')
			end
		end
	end

	local entry = ctrl:Add('DTextEntry')
	entry:SetPos(ctrl:GetWide() - entry_w, 0)
	entry:SetSize(entry_w, ctrl:GetTall())
	entry:SetFont('BGN.Menu.Value')
	entry:SetNumeric(true)
	entry:SetUpdateOnType(false)
	entry:SetEnabled(not row.locked)
	entry.Paint = function(panel, w, h)
		local r = math.Round(6 * s)
		draw.RoundedBox(r, 0, 0, w, h, panel:HasFocus() and C.accent or C.border)
		draw.RoundedBox(r, 1, 1, w - 2, h - 2, C.surface)
		panel:DrawTextEntryText(row.locked and C.muted or C.text, C.accent, C.text)
	end
	entry.Think = function(panel)
		if panel:HasFocus() then return end
		local text = Format(track.dragging and track.drag_value or Get())
		if panel:GetText() ~= text then panel:SetText(text) end
	end
	-- typed values may go past the slider's max (up to opts.limit)
	local function Commit(panel)
		local value = tonumber(panel:GetText())
		if value and Set(value) then Menu.Sound('click') end
	end
	local base_lose_focus = entry.OnLoseFocus
	entry.OnEnter = Commit
	entry.OnLoseFocus = function(panel)
		Commit(panel)
		base_lose_focus(panel)
	end
	return row
end

function Builder:Button(label, action, opts)
	opts = opts or {}
	local row = self:Row(label, Help(label, opts), opts.admin, isstring(action) and action or nil)
	local caption = Menu.Text(opts.text or '#bgn.menu.run')

	local function Run()
		if isfunction(action) then
			action()
		else
			LocalPlayer():ConCommand(action)
		end
	end

	local button = Menu.Button(row, caption, opts.danger and 'danger' or 'secondary', function()
		if not opts.confirm then return Run() end
		local question = isstring(opts.confirm) and Menu.Text(opts.confirm) or Menu.Text('#bgn.menu.confirm_text')
		Menu.Confirm(question, Run, opts.danger, caption)
	end)
	button:SetEnabled(not row.locked)
	row.control = button
	return row
end

-- @param rgb table { red_cvar, green_cvar, blue_cvar }
function Builder:Color(label, rgb, opts)
	opts = opts or {}
	local s = Menu.Scale()
	local row = self:Row(label, Help(label, opts), IsServer(rgb[1], opts), rgb[1])

	local function Get()
		local values = {}
		for i = 1, 3 do
			local cv = GetConVar(rgb[i])
			values[i] = cv and cv:GetInt() or 255
		end
		return Color(values[1], values[2], values[3])
	end

	local swatch = row:Add('DButton')
	swatch:SetText('')
	swatch:SetSize(math.Round(48 * s), math.Round(28 * s))
	swatch:SetCursor(row.locked and 'no' or 'hand')
	swatch.Paint = function(panel, w, h)
		local r = math.Round(6 * s)
		draw.RoundedBox(r, 0, 0, w, h, panel:IsHovered() and C.muted or C.border)
		draw.RoundedBox(r - 1, 2, 2, w - 4, h - 4, Get())
	end
	swatch.OnCursorEntered = function() if not row.locked then Menu.Sound('hover') end end
	swatch.DoClick = function()
		if row.locked then
			Menu.Sound('denied')
			return
		end
		Menu.Sound('click')
		Menu.Dialog(380, function(card)
			Menu.Paragraph(card, row.label, 'BGN.Menu.Body')
			local mixer = card:Add('DColorMixer')
			mixer:Dock(TOP)
			mixer:DockMargin(0, math.Round(12 * s), 0, 0)
			mixer:SetTall(math.Round(220 * s))
			mixer:SetPalette(false)
			mixer:SetAlphaBar(false)
			mixer:SetWangs(true)
			mixer:SetColor(Get())
			Menu.DialogButtons(card, {
				{ Menu.Text('#bgn.menu.cancel'), 'secondary' },
				{ Menu.Text('#bgn.menu.apply'), 'primary', function()
					local color = mixer:GetColor()
					RunConsoleCommand(rgb[1], tostring(color.r))
					RunConsoleCommand(rgb[2], tostring(color.g))
					RunConsoleCommand(rgb[3], tostring(color.b))
				end },
			})
		end)
	end
	row.control = swatch
	return row
end

-- Segmented control. @param options table { { value, text }, ... } (text: '#phrase', plain or { en, ru })
function Builder:Choice(cvar, label, options, opts)
	opts = opts or {}
	local s = Menu.Scale()
	local row = self:Row(label, Help(label, opts), IsServer(cvar, opts), cvar, opts.locked)

	local function Get()
		local cv = GetConVar(cvar)
		return cv and cv:GetString() or ''
	end

	local ctrl = row:Add('DPanel')
	ctrl:SetTall(math.Round(32 * s))
	local inset = math.Round(3 * s)
	surface.SetFont('BGN.Menu.Value')
	local x = inset
	for _, option in ipairs(options) do
		local value, text = tostring(option[1]), Menu.Text(option[2])
		local segment = ctrl:Add('DButton')
		segment:SetText('')
		segment:SetPos(x, inset)
		segment:SetSize(surface.GetTextSize(text) + math.Round(24 * s), ctrl:GetTall() - inset * 2)
		segment:SetCursor(row.locked and 'no' or 'hand')
		segment.hover = 0
		segment.Paint = function(panel, w, h)
			local active = Get() == value
			panel.hover = Lerp(FrameTime() * 16, panel.hover, (panel:IsHovered() and not row.locked and not active) and 1 or 0)
			local alpha = row.locked and 0.5 or 1
			if active then
				draw.RoundedBox(math.Round(5 * s), 0, 0, w, h, Menu.Fade(C.accent, alpha))
			elseif panel.hover > 0.01 then
				draw.RoundedBox(math.Round(5 * s), 0, 0, w, h, Menu.Fade(C.hover, panel.hover))
			end
			draw.SimpleText(text, 'BGN.Menu.Value', w / 2, h / 2, Menu.Fade(active and C.on_accent or C.text, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		segment.OnCursorEntered = function() if not row.locked then Menu.Sound('hover') end end
		segment.DoClick = function()
			if row.locked then
				Menu.Sound('denied')
				return
			end
			if Get() == value then return end
			RunConsoleCommand(cvar, value)
			Menu.Sound('click')
			if opts.on_change then opts.on_change(value) end
		end
		x = x + segment:GetWide() + math.Round(2 * s)
	end
	ctrl:SetWide(x - math.Round(2 * s) + inset)
	ctrl.Paint = function(panel, w, h)
		local r = math.Round(7 * s)
		draw.RoundedBox(r, 0, 0, w, h, C.border)
		draw.RoundedBox(r, 1, 1, w - 2, h - 2, C.bg)
	end
	row.control = ctrl
	return row
end

bgNPC.Test.Add('menu.hide_server_rows', function(check)
	local was = Menu.as_player
	Menu.as_player = true
	local probe = vgui.Create('DPanel')
	probe:SetVisible(false)

	local page = Menu.NewBuilder(probe)
	page:Section('server')
	page:Toggle('bgn_enable', 'server row')
	check(page.rows == 1 and page.visible == 0, 'a server row is hidden from a non-admin')
	check(page.pending_head ~= nil, 'a section without visible rows has no heading')
	page:Toggle('bgn_menu_dark', 'client row')
	check(page.visible == 1 and page.pending_head == nil, 'a client row is shown under its heading')

	probe:Remove()
	Menu.as_player = was
end)

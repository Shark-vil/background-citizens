--[[
	Page builder: the "page" object passed to a page's build function (see cl_menu.lua).

		page:Section(title, help)                       -- a titled group, the following controls go into its card
		page:Toggle(cvar, label, opts)                   -- on / off
		page:Slider(cvar, label, min, max, opts)         -- opts.decimals (0), opts.limit (max for typed values)
		page:Button(label, command|func, opts)           -- opts.text (caption), opts.confirm (true|text), opts.danger, opts.admin
		page:Color(label, { r_cvar, g_cvar, b_cvar }, opts)
		page:Note(text)                                  -- a muted paragraph
		page:Row(label, help, server)                    -- an empty row: set row.control to your own panel
		page:Custom(function(panel) end)                 -- anything else, docked at the top

	Every label/help takes '#phrase', plain text or { en = '', ru = '' }. Without opts.help a '#key' label uses
	'#key.help' when it exists. opts.server (default: the cvar is a bgNPC.CVars server setting) locks the
	control for non-admins.

	Methods can be added to bgNPC.Menu.Builder by other addons.
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

-- @param scroll DScrollPanel page content; @param notice Panel "read-only" banner
function Menu.NewBuilder(scroll, notice)
	return setmetatable({ scroll = scroll, notice = notice }, Builder)
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
	local s = Menu.Scale()
	local head = self:Add('DPanel')
	head:DockMargin(0, self.started and math.Round(24 * s) or 0, 0, math.Round(8 * s))
	self.started = true
	self.card = nil

	local title_text = Menu.Text(title)
	local help_text = help and Menu.Text(help)
	head.PerformLayout = function(panel, w)
		local h = Menu.FontHeight('BGN.Menu.Section')
		if help_text then h = h + math.Round(2 * s) + #Menu.Wrap(help_text, 'BGN.Menu.Small', w) * Menu.FontHeight('BGN.Menu.Small') end
		if panel:GetTall() ~= h then
			panel:SetTall(h)
			Menu.ContentChanged()
		end
	end
	head.Paint = function(panel, w)
		draw.SimpleText(title_text, 'BGN.Menu.Section', 0, 0, C.muted)
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

-- @param server boolean the row changes a server setting (locked for non-admins)
-- @return Panel the row; put your control into row.control (it is placed on the right)
function Builder:Row(label, help, server)
	local row = self:Card():Add('DPanel')
	row:Dock(TOP)
	row.label = Menu.Text(label)
	row.help = help and Menu.Text(help) or nil
	if row.help == '' then row.help = nil end
	row.locked = server and not Menu.IsAdmin() or false
	row.hover = 0
	row.PerformLayout = RowLayout
	row.Paint = RowPaint
	if row.locked then
		row:SetTooltip(Menu.Text('#bgn.menu.admin_only'))
		if IsValid(self.notice) and not self.notice:IsVisible() then
			self.notice:SetVisible(true)
			Menu.ContentChanged()
		end
	end
	return row
end

function Builder:Note(text)
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
	local panel = self:Add('DPanel')
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
	local row = self:Row(label, Help(label, opts), IsServer(cvar, opts))

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
	local row = self:Row(label, Help(label, opts), IsServer(cvar, opts))

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
	local row = self:Row(label, Help(label, opts), opts.admin)
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
	local row = self:Row(label, Help(label, opts), IsServer(rgb[1], opts))

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

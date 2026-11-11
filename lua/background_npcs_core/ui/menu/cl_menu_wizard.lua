--[[
	Step by step setup of the most important settings: a title, a short text, a looped clip and the controls.
	Opens after the mode choice (cl_menu_welcome.lua), console "bgn_wizard", Settings -> Client.

	Clips are frame atlases (GMod can't play video): materials/background_npcs/wizard/<clip>.jpg, 2048x2048,
	CLIP_COLS x CLIP_ROWS frames of FRAME_W x FRAME_H, made by tools/make_wizard_clips.py.
	A step with "labels" shows the first label over the first half of the frames, the second over the rest.
--]]
local Menu = bgNPC.Menu
local C = Menu.colors
local ICONS = 'background_npcs/vgui/menu/'
local ATLAS, FRAME_W, FRAME_H, CLIP_COLS = 2048, 384, 216, 5
local CLIP_FPS = 10
-- modern: the step is skipped in the Classic mode (its settings are fixed there)
-- advanced: only "bgn_wizard all": the mode already decides these, the wizard must not override the choice
-- build(page): controls, the same builder as the settings pages; server rows are hidden from non-admins
-- Workshop card: what it is, Subscribe (all the ids at once). Clicking the card opens the first item's page.
local function SubscribeCard(page, key, ids, required)
  page:Custom(function(panel)
    local s = Menu.Scale()
    local pad = math.Round(14 * s)
    panel:DockMargin(0, math.Round(8 * s), 0, 0)
    local function AllSubscribed()
      for _, id in ipairs(ids) do
        if not steamworks.IsSubscribed(id) then return false end
      end
      return true
    end

    local button = Menu.Button(panel, '', 'primary', function() end)
    surface.SetFont('BGN.Menu.Value')
    local widest = math.max(surface.GetTextSize(Menu.Text('#bgn.menu.works.subscribed')), surface.GetTextSize(Menu.Text('#bgn.menu.works.subscribe')))
    button:SetWide(widest + math.Round(40 * s))
    local function Refresh()
      local done = AllSubscribed()
      button.text = Menu.Text(done and '#bgn.menu.works.subscribed' or '#bgn.menu.works.subscribe')
      button.style = done and 'secondary' or 'primary'
      button:SetEnabled(not done)
    end

    Refresh()
    button.DoClick = function()
      Menu.Sound('click')
      for _, id in ipairs(ids) do
        steamworks.Subscribe(id)
      end

      steamworks.ApplyAddons()
      Refresh()
    end

    local base = '#bgn.wizard.vehicles.' .. key
    local function Lines(w)
      return Menu.Wrap(Menu.Text(base .. '.desc'), 'BGN.Menu.Small', w - pad * 3 - button:GetWide())
    end

    panel.PerformLayout = function(self, w)
      local want = pad * 2 + Menu.FontHeight('BGN.Menu.Body') + math.Round(4 * s) + #Lines(w) * Menu.FontHeight('BGN.Menu.Small')
      want = math.max(want, button:GetTall() + pad * 2)
      button:SetPos(w - pad - button:GetWide(), (want - button:GetTall()) / 2)
      if self:GetTall() ~= want then
        self:SetTall(want)
        Menu.ContentChanged()
      end
    end

    panel.Paint = function(_, w, h)
      local r = math.Round(8 * s)
      draw.RoundedBox(r, 0, 0, w, h, required and not AllSubscribed() and C.warn or C.border)
      draw.RoundedBox(r, 1, 1, w - 2, h - 2, C.surface)
      local tag = Menu.Text(required and '#bgn.wizard.vehicles.required' or '#bgn.wizard.vehicles.optional')
      draw.SimpleText(Menu.Text(base) .. ' (' .. tag .. ')', 'BGN.Menu.Body', pad, pad, C.text)
      local y = pad + Menu.FontHeight('BGN.Menu.Body') + math.Round(4 * s)
      for _, line in ipairs(Lines(w)) do
        draw.SimpleText(line, 'BGN.Menu.Small', pad, y, C.muted)
        y = y + Menu.FontHeight('BGN.Menu.Small')
      end
    end

    panel.OnMousePressed = function(_, code) if code == MOUSE_LEFT then gui.OpenURL('https://steamcommunity.com/sharedfiles/filedetails/?id=' .. ids[1]) end end
    panel:SetCursor('hand')
  end)
end

local STEPS = {
  {
    id = 'density',
    clip = 'density',
    frames = 45,
    labels = {'#bgn.wizard.density.l1', '#bgn.wizard.density.l2'},
    build = function(page) Menu.DensityChoice(page) end,
  },
  {
    id = 'body',
    modern = true,
    advanced = true,
    clip = 'body',
    frames = 45,
    labels = {'#bgn.wizard.body.l1', '#bgn.wizard.body.l2'},
    build = function(page) page:Choice('bgn_actor_body', '#bgn.menu.body', {{'npc', 'NPC'}, {'nextbot', 'NextBot'}}) end,
  },
  {
    id = 'brain',
    modern = true,
    advanced = true,
    clip = 'brain',
    frames = 45,
    labels = {'#bgn.wizard.brain.l1', '#bgn.wizard.brain.l2'},
    build = function(page) page:Choice('bgn_brain', '#bgn.menu.brain', {{'auto', '#bgn.menu.auto'}, {'fsm', 'FSM'}, {'goap', 'GOAP'}}) end,
  },
  {
    id = 'ghosts',
    modern = true,
    advanced = true,
    clip = 'ghosts',
    frames = 45,
    labels = {'#bgn.wizard.ghosts.l1', '#bgn.wizard.ghosts.l2'},
    build = function(page)
      page:Toggle('bgn_ghost_crowd', '#bgn.menu.ghost_crowd_server')
      page:Toggle('bgn_cl_ghost_crowd', '#bgn.menu.ghost_crowd', {
        server = false
      })
    end,
  },
  {
    id = 'scenic',
    modern = true,
    clip = 'scenic',
    frames = 45,
    labels = {'#bgn.wizard.scenic.l1', '#bgn.wizard.scenic.l2'},
    build = function(page)
      page:Toggle('bgn_scenic', '#bgn.menu.scenic')
      page:Slider('bgn_scenic_max', '#bgn.menu.scenic_max', 0, 20)
    end,
  },
  {
    id = 'wanted',
    clip = 'wanted',
    frames = 45,
    build = function(page)
      page:Toggle('bgn_enable_wanted_mode', '#bgn.settings.wanted.enable_wanted_mode')
      page:Toggle('bgn_arrest_mode', '#bgn.settings.arrest.arrest_mode')
      page:Slider('bgn_wanted_time', '#bgn.settings.wanted.time', 0, 300)
    end,
  },
  {
    id = 'voices',
    clip = 'voices',
    frames = 45,
    build = function(page)
      page:Toggle('bgn_cl_voices', '#bgn.settings.client.cl_voices', {
        server = false
      })

      page:Toggle('bgn_cl_ambient_sound', '#bgn.settings.client.cl_ambient_sound', {
        server = false
      })
    end,
  },
  {
    id = 'vehicles',
    clip = 'vehicles',
    frames = 45,
    labels = {'#bgn.wizard.vehicles.l1', '#bgn.wizard.vehicles.l2'},
    build = function(page)
      page:Toggle('bgn_enable_dv_support', '#bgn.settings.addon.decent_vehicle')
      SubscribeCard(page, 'dv', {'1587455087'}, true)
      SubscribeCard(page, 'pack', {'771487490', '1737050476', '2512607394'})
    end,
  },
}

-- ---------------------------------------------------------------------------
-- Clip widget
-- ---------------------------------------------------------------------------
-- Plays the frames of an atlas in a loop. A missing atlas draws a plain placeholder.
-- @param step table the STEPS entry
function Menu.Clip(parent, step)
  local s = Menu.Scale()
  local panel = parent:Add('DPanel')
  local mat = Material('background_npcs/wizard/' .. step.clip .. '.jpg', 'smooth')
  local started = RealTime()
  panel.Paint = function(self, w, h)
    local r = math.Round(8 * s)
    draw.RoundedBox(r, 0, 0, w, h, C.border)
    draw.RoundedBox(r, 1, 1, w - 2, h - 2, C.sidebar)
    if mat:IsError() then
      draw.SimpleText(step.clip, 'BGN.Menu.Body', w / 2, h / 2, C.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
      return
    end

    local frame = math.floor((RealTime() - started) * CLIP_FPS) % step.frames
    local col, row = frame % CLIP_COLS, math.floor(frame / CLIP_COLS)
    local u0, v0 = col * FRAME_W / ATLAS, row * FRAME_H / ATLAS
    -- inset by half a texel so the neighbouring frame does not bleed in
    local e = 0.5 / ATLAS
    surface.SetMaterial(mat)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawTexturedRectUV(1, 1, w - 2, h - 2, u0 + e, v0 + e, u0 + FRAME_W / ATLAS - e, v0 + FRAME_H / ATLAS - e)
    if step.labels then
      local text = Menu.Text(step.labels[frame < step.frames / 2 and 1 or 2])
      surface.SetFont('BGN.Menu.Value')
      local tw, th = surface.GetTextSize(text)
      local pad = math.Round(10 * s)
      draw.RoundedBox(math.Round(6 * s), pad, pad, tw + pad * 2, th + pad, Color(0, 0, 0, 170))
      draw.SimpleText(text, 'BGN.Menu.Value', pad * 2, pad + (th + pad) / 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
  end
  return panel
end

-- ---------------------------------------------------------------------------
-- Window
-- ---------------------------------------------------------------------------
-- Does the step have anything this player can use (available addon, rows not hidden by the rights)?
local function StepUsable(step, classic)
  if step.modern and classic then return false end
  local probe = vgui.Create('DPanel')
  probe:SetVisible(false)
  local page = Menu.NewBuilder(probe)
  pcall(step.build, page)
  local visible = page.visible
  probe:Remove()
  return visible > 0
end

function Menu.CloseWizard()
  local frame = Menu.wizard
  if not IsValid(frame) or frame.closing then return end
  frame.closing = true
  Menu.Sound('close')
  frame:AlphaTo(0, 0.1, 0, function() if IsValid(frame) then frame:Remove() end end)
end

-- @param all boolean also the advanced steps (console: bgn_wizard all)
function Menu.OpenWizard(all)
  if IsValid(Menu.wizard) then Menu.wizard:Remove() end
  Menu.CreateFonts()
  Menu.ApplyTheme(true)
  local classic = GetConVar('bgn_mode'):GetString() == 'classic'
  local steps = {}
  for _, step in ipairs(STEPS) do
    -- "all" ignores the mode too: every step, even those the Classic mode fixes (rows hidden by the rights still hide a step)
    if (all or not step.advanced) and StepUsable(step, classic and not all) then steps[#steps + 1] = step end
  end

  if #steps == 0 then return end
  local s = Menu.Scale()
  local R = math.Round
  local W = math.min(R(1000 * s), ScrW() - 32)
  local pad, gap = R(28 * s), R(24 * s)
  local left_w = R(420 * s)
  local clip_h = R(left_w * FRAME_H / FRAME_W)
  local lh = Menu.FontHeight('BGN.Menu.Body')
  local radius = R(10 * s)
  local index = 1
  -- tall enough for the longest description and the longest control column
  local top = pad + Menu.FontHeight('BGN.Menu.PageTitle') + R(26 * s)
  local longest = 0
  for _, step in ipairs(steps) do
    longest = math.max(longest, #Menu.Wrap(Menu.Text('#bgn.wizard.' .. step.id .. '.desc'), 'BGN.Menu.Body', left_w))
  end

  local H = math.min(top + math.max(clip_h + R(16 * s) + longest * lh, R(260 * s)) + R(24 * s) + R(38 * s) + pad, ScrH() - 32)
  local frame = vgui.Create('EditablePanel')
  Menu.wizard = frame
  frame:SetSize(W, H)
  frame:Center()
  frame:MakePopup()
  frame:SetAlpha(0)
  frame:AlphaTo(255, 0.15)
  Menu.Sound('open')
  frame.OnRemove = function() if Menu.wizard == frame then Menu.wizard = nil end end
  local desc_lines = {}
  local title_text = ''
  frame.Think = function(self)
    Menu.UpdateTheme()
    if self.relayout and IsValid(self.content) then
      self.relayout = false
      self.content:InvalidateLayout()
    end
  end

  frame.Paint = function(self, w, h)
    DisableClipping(true)
    for i = 1, 4 do
      draw.RoundedBox(radius + i * 2, -i * 2, -i * 2 + 4, w + i * 4, h + i * 4, Menu.Fade(C.shadow, 0.35 / i))
    end

    DisableClipping(false)
    draw.RoundedBox(radius, 0, 0, w, h, C.bg)
    draw.SimpleText(title_text, 'BGN.Menu.PageTitle', pad, pad, C.text)
    -- progress: one dot per step
    local dot, dx = R(8 * s), pad
    for i = 1, #steps do
      local on = i <= index
      draw.RoundedBox(dot / 2, dx, pad + Menu.FontHeight('BGN.Menu.PageTitle') + R(10 * s), i == index and dot * 3 or dot, dot, on and C.accent or C.track)
      dx = dx + (i == index and dot * 3 or dot) + R(6 * s)
    end

    draw.SimpleText(string.format(Menu.Text('#bgn.wizard.step'), index, #steps), 'BGN.Menu.Small', dx + R(8 * s), pad + Menu.FontHeight('BGN.Menu.PageTitle') + R(8 * s), C.muted)
    for i, line in ipairs(desc_lines) do
      draw.SimpleText(line, 'BGN.Menu.Body', pad, top + clip_h + R(16 * s) + (i - 1) * lh, C.text)
    end
  end

  local clip
  local content = frame:Add('DScrollPanel')
  frame.content = content
  content:SetPos(pad + left_w + gap, top)
  content:SetSize(W - pad * 2 - left_w - gap, H - top - pad - R(54 * s))
  local bar = content:GetVBar()
  bar:SetWide(R(10 * s))
  bar:SetHideButtons(true)
  bar.Paint = nil
  bar.btnGrip.Paint = function(self, w, h) draw.RoundedBox(w / 2, 0, 0, w, h, (self:IsHovered() or self.Depressed) and C.muted or C.border) end
  local back, next_btn
  local function Show(i)
    index = i
    local step = steps[i]
    title_text = Menu.Text('#bgn.wizard.' .. step.id)
    desc_lines = Menu.Wrap(Menu.Text('#bgn.wizard.' .. step.id .. '.desc'), 'BGN.Menu.Body', left_w)
    if IsValid(clip) then clip:Remove() end
    clip = Menu.Clip(frame, step)
    clip:SetPos(pad, top)
    clip:SetSize(left_w, clip_h)
    content:Clear()
    local canvas = content:GetCanvas()
    canvas:SetAlpha(0)
    canvas:AlphaTo(255, 0.15)
    step.build(Menu.NewBuilder(content))
    back:SetEnabled(i > 1)
    next_btn.text = Menu.Text(i == #steps and '#bgn.wizard.done' or '#bgn.wizard.next')
  end

  local y = H - pad - R(38 * s)
  back = Menu.Button(frame, Menu.Text('#bgn.wizard.back'), 'secondary', function() Show(index - 1) end)
  next_btn = Menu.Button(frame, Menu.Text('#bgn.wizard.next'), 'primary', function()
    if index == #steps then
      Menu.Sound('toggle_on')
      Menu.CloseWizard()
    else
      Show(index + 1)
    end
  end)

  next_btn:SetWide(R(130 * s))
  next_btn:SetPos(W - pad - next_btn:GetWide(), y)
  back:SetPos(next_btn.x - R(8 * s) - back:GetWide(), y)
  local skip = Menu.Button(frame, Menu.Text('#bgn.wizard.skip'), 'secondary', Menu.CloseWizard)
  skip:SetPos(pad, y)
  local size = R(36 * s)
  local theme = Menu.IconButton(frame, size, function() return GetConVar('bgn_menu_dark'):GetBool() and ICONS .. 'sun.png' or ICONS .. 'moon.png' end, Menu.Text('#bgn.menu.theme'), function()
    Menu.Sound('click')
    RunConsoleCommand('bgn_menu_dark', GetConVar('bgn_menu_dark'):GetBool() and '0' or '1')
  end)

  theme:SetPos(W - pad + R(4 * s) - size, R(18 * s))
  frame.Show = Show
  Show(1)
end

concommand.Add('bgn_wizard', function(_, _, args) Menu.OpenWizard(args[1] == 'all') end, nil, 'Opens the step by step setup. bgn_wizard all: with the advanced steps')
hook.Add('OnPauseMenuShow', 'BGN_Wizard', function()
  if not IsValid(Menu.wizard) then return end
  Menu.CloseWizard()
  return false
end)

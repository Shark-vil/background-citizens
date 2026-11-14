--[[
	Setting change notices. Loaded FIRST (sh_init.lua) and depends on nothing else of the mod: its own network
	string, its own language check and its own drawing, so a script that fails later cannot silence it.

		bgNPC.Notice.Watch(name)   server: every change of the cvar is shown to all players (blue "SERVER")
		                           client: every change of the cvar is shown to this player (amber "CLIENT")
		bgNPC.Notice.Show(scope, name, old, new)   client: show a notice by hand, scope 'server' | 'client'

	A repeated change of one setting (a slider) updates its notice instead of stacking a new one.
--]]
bgNPC = bgNPC or {}
local Notice = bgNPC.Notice or {}
bgNPC.Notice = Notice
local CHANNEL = 'bgn_notice'
local watched = Notice.watched or {}
Notice.watched = watched
-- "1.000000" -> "1": console numbers are shown as numbers
local function Norm(value)
  local number = tonumber(value)
  return number and tostring(number) or value
end

-- prefix -> time: the changes the mod makes itself after another change (a limit rewrites the limits of its types)
local silenced = Notice.silenced or {}
Notice.silenced = silenced
function Notice.Silence(prefix, seconds)
  silenced[prefix] = RealTime() + seconds
end

local function IsSilenced(name)
  local now = RealTime()
  for prefix, untill in pairs(silenced) do
    if now > untill then
      silenced[prefix] = nil
    elseif string.StartWith(name, prefix) then
      return true
    end
  end
  return false
end

local function Watch(name, on_change)
  if watched[name] then return end
  watched[name] = true
  cvars.AddChangeCallback(name, function(_, old_value, new_value)
    old_value, new_value = Norm(old_value), Norm(new_value)
    if old_value ~= new_value and not IsSilenced(name) then on_change(name, old_value, new_value) end
  end, 'BGN_Notice')
end

if SERVER then
  util.AddNetworkString(CHANNEL)
  function Notice.Watch(name)
    Watch(name, function(cvar, old_value, new_value)
      net.Start(CHANNEL)
      net.WriteString(cvar)
      net.WriteString(old_value)
      net.WriteString(new_value)
      net.Broadcast()
    end)
  end
  return
end

-- ---------------------------------------------------------------------------
-- Client
-- ---------------------------------------------------------------------------
local COLORS = {
  server = Color(3, 169, 244), -- #03a9f4
  client = Color(222, 169, 9), -- #dea909
}

local TAGS = {
  server = {
    en = 'SERVER',
    ru = 'СЕРВЕР'
  },
  client = {
    en = 'CLIENT',
    ru = 'КЛИЕНТ'
  },
}

local LIFETIME, FADE, STAGGER = 6, 0.35, 0.4
local list = Notice.list or {}
Notice.list = list
local function IsRussian()
  local ui = GetConVar('bgn_cl_ui_language')
  local language = ui and ui:GetString() or 'auto'
  if language == 'auto' or language == '' then
    local game = GetConVar('gmod_language')
    language = game and game:GetString() or 'en'
  end

  language = language:lower()
  return language == 'ru' or language == 'russian'
end

local fonts = {}
local function Font(size)
  local name = 'BGN.Notice.' .. size
  -- Draw() asks for fonts every frame: create each size once, CreateFont per frame drops the FPS
  if fonts[name] then return name end
  fonts[name] = true
  surface.CreateFont(name, {
    font = 'Tahoma',
    size = size,
    weight = 600,
    extended = true
  })
  return name
end

local function Add(scope, name, old_value, new_value)
  local key = scope .. name
  local now = RealTime()
  -- Every switch (0/1) makes a new plate; only a slider, which fires on every step, updates its plate in place
  local is_switch = new_value == '0' or new_value == '1'
  for i, item in ipairs(list) do
    if item.key == key and not is_switch then
      item.new, item.dead = new_value, now + LIFETIME
      -- keep the leaving order: the plates after it wait for it
      for j = i + 1, #list do
        list[j].dead = math.max(list[j].dead, list[j - 1].dead + STAGGER)
      end
      return
    end
  end

  -- Like the engine's notices: no cap, each one lives its own time, and they leave one by one in the order
  -- they came (the list is ordered, so the gap to the previous one keeps `dead` increasing)
  local last = list[#list]
  list[#list + 1] = {
    key = key,
    scope = scope,
    name = name,
    old = old_value,
    new = new_value,
    born = now,
    dead = math.max(now + LIFETIME, last and last.dead + STAGGER or 0)
  }
end

local function Fallback(scope, name, new_value)
  notification.AddLegacy(scope .. ': ' .. name .. ' = ' .. new_value, NOTIFY_GENERIC, 4)
end

function Notice.Show(scope, name, old_value, new_value)
  scope, name, old_value, new_value = COLORS[scope] and scope or 'client', tostring(name), tostring(old_value), tostring(new_value)
  if not pcall(Add, scope, name, old_value, new_value) then Fallback(scope, name, new_value) end
  pcall(surface.PlaySound, scope == 'server' and 'UI/buttonclickrelease.wav' or 'UI/buttonclick.wav')
end

function Notice.Watch(name)
  Watch(name, function(cvar, old_value, new_value) Notice.Show('client', cvar, old_value, new_value) end)
end

net.Receive(CHANNEL, function() Notice.Show('server', net.ReadString(), net.ReadString(), net.ReadString()) end)
-- "old -> new", right aligned at x, centered on y; the arrow is drawn (a font may lack the glyph)
local function DrawChange(item, font, x, y, s, color)
  surface.SetFont(font)
  local new_w = surface.GetTextSize(item.new)
  local arrow = math.Round(26 * s)
  local gap = math.Round(8 * s)
  draw.SimpleText(item.new, font, x, y, color, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
  local ax2 = x - new_w - gap
  local ax1 = ax2 - arrow
  draw.SimpleText(item.old, font, ax1 - gap, y, Color(color.r, color.g, color.b, 150), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
  local head = math.Round(6 * s)
  surface.SetDrawColor(color)
  surface.DrawRect(ax1, y - math.max(1, math.Round(s)), arrow - head, math.max(2, math.Round(2 * s)))
  draw.NoTexture()
  surface.DrawPoly({
    {
      x = ax2 - head * 1.4,
      y = y - head
    },
    {
      x = ax2,
      y = y
    },
    {
      x = ax2 - head * 1.4,
      y = y + head
    }
  })
end

local function Draw()
  local now = RealTime()
  local s = ScrH() / 1080
  local w, h, gap, bar = math.Round(430 * s), math.Round(72 * s), math.Round(8 * s), math.Round(5 * s)
  local small, big, value = Font(math.max(12, math.Round(15 * s))), Font(math.max(14, math.Round(20 * s))), Font(math.max(18, math.Round(28 * s)))
  local ru = IsRussian()
  local x, y = ScrW() - w - math.Round(24 * s), ScrH() - math.Round(150 * s)
  for i = #list, 1, -1 do
    local item = list[i]
    if now > item.dead then
      table.remove(list, i)
    else
      local alpha = math.min(1, (now - item.born) / FADE, (item.dead - now) / FADE)
      local ease = 1 - (1 - math.min(1, (now - item.born) / FADE)) ^ 3
      local px, py = x + (1 - ease) * 40 * s, y - (#list - i) * (h + gap)
      local color = COLORS[item.scope]
      surface.SetAlphaMultiplier(alpha)
      draw.RoundedBox(6 * s, px, py, w, h, Color(22, 24, 29, 235))
      draw.RoundedBoxEx(6 * s, px, py, bar, h, color, true, false, true, false)
      draw.SimpleText(TAGS[item.scope][ru and 'ru' or 'en'], small, px + bar + 12 * s, py + 14 * s, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
      DrawChange(item, value, px + w - 14 * s, py + 8 * s + 14 * s, s, color)
      draw.SimpleText(item.name, big, px + bar + 12 * s, py + h - 8 * s, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
      surface.SetAlphaMultiplier(1)
    end
  end
end

-- DrawOverlay is drawn above the menu windows; an error is caught so it never spams or breaks the HUD
hook.Add('DrawOverlay', 'BGN_Notice', function()
  if #list == 0 then return end
  if not pcall(Draw) then surface.SetAlphaMultiplier(1) end
end)

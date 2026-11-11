--[[
	"Other works" page (always last, tinted in the sidebar): a random page of the author's Workshop items with
	a preview, the title, a short description and a Subscribe button (steamworks.Subscribe).
	The page count comes from the first page. Previews are cached in data/bgn_workshop/<id>.jpg|png.
	A failed load is not retried until the next map: the page then just says it couldn't load.
--]]
local Menu = bgNPC.Menu
local C = Menu.colors
local URL = 'https://steamcommunity.com/id/shark_vil/myworkshopfiles/?appid=4000&sort=score&browsefilter=myfiles&view=imagewall&p='
local CACHE_DIR = 'bgn_workshop'
local DESCRIPTION_LINES = 3
local state = {
  pages = nil,
  failed = false,
  loading = false,
  waiting = {}
}

-- @return table items { id, title, description, image }, number pages count
local function Parse(html)
  local items = {}
  for id, json in html:gmatch('SharedFileBindMouseHover%(%s*"sharedfile_(%d+)"%s*,%s*%a+%s*,%s*(%b{})') do
    local info = util.JSONToTable(json) or {}
    local image = html:match('id="sharedfile_' .. id .. '"[^>]*>%s*<img[^>]-src="([^"]+)"')
    items[#items + 1] = {
      id = id,
      title = info.title or id,
      description = info.description or '',
      image = image and image:gsub('&amp;', '&'),
    }
  end

  local pages = 1
  for page in html:gmatch('[?&;]p=(%d+)') do
    pages = math.max(pages, tonumber(page))
  end
  return items, pages
end

bgNPC.Test.Add('menu.workshop_parse', function(check)
  local html = '<div id="sharedfile_42" class="x"><img class="workshopItemPreviewImage " src="https://a/b.jpg?x=1&amp;y=2">' .. 'SharedFileBindMouseHover( "sharedfile_42", true, {"id":"42","title":"Mod","description":"Text {x}"} );' .. '<a href="?appid=4000&amp;p=2">2</a><a href="?appid=4000&amp;p=11">11</a><a href="?numperpage=30">'
  local items, pages = Parse(html)
  check(#items == 1 and items[1].id == '42' and items[1].title == 'Mod' and items[1].description == 'Text {x}', 'item')
  check(items[1].image == 'https://a/b.jpg?x=1&y=2', 'image url unescaped')
  check(pages == 11, 'pages from the paging links')
end)

-- @param done function(items|nil, pages|nil)
local function Fetch(page, done)
  http.Fetch(URL .. page, function(body, _, _, code)
    if code ~= 200 then return done() end
    local items, pages = Parse(body)
    if #items == 0 then return done() end
    done(items, pages)
  end, function() done() end)
end

-- @param callback function(items|nil) nil when the list couldn't be loaded
local function Load(callback)
  if state.failed then return callback() end
  table.insert(state.waiting, callback)
  if state.loading then return end
  state.loading = true
  local function Finish(items)
    state.loading = false
    if not items then state.failed = true end
    local waiting = state.waiting
    state.waiting = {}
    for _, cb in ipairs(waiting) do
      cb(items)
    end
  end

  if state.pages then return Fetch(math.random(state.pages), Finish) end
  Fetch(1, function(items, pages)
    if not items then return Finish() end
    state.pages = pages
    local page = math.random(pages)
    if page == 1 then return Finish(items) end
    Fetch(page, function(other) Finish(other or items) end)
  end)
end

local function CachedImage(id)
  for _, ext in ipairs({'jpg', 'png'}) do
    local path = CACHE_DIR .. '/' .. id .. '.' .. ext
    if file.Exists(path, 'DATA') then return path end
  end
end

-- @param callback function(IMaterial) not called when there is no usable preview (GIF and the like)
local function LoadImage(item, callback)
  local path = CachedImage(item.id)
  if path then return callback(Material('../data/' .. path, 'smooth mips')) end
  if not item.image then return end
  http.Fetch(item.image, function(body, _, _, code)
    if code ~= 200 then return end
    local ext = body:sub(1, 4) == '\137PNG' and 'png' or body:sub(1, 2) == '\255\216' and 'jpg'
    if not ext then return end
    file.CreateDir(CACHE_DIR)
    path = CACHE_DIR .. '/' .. item.id .. '.' .. ext
    file.Write(path, body)
    callback(Material('../data/' .. path, 'smooth mips'))
  end)
end

local function SubscribeText(id)
  return Menu.Text(steamworks.IsSubscribed(id) and '#bgn.menu.works.subscribed' or '#bgn.menu.works.subscribe')
end

local function ItemPanel(parent, item)
  local s = Menu.Scale()
  local pad, image_size, radius = math.Round(12 * s), math.Round(96 * s), math.Round(8 * s)
  local panel = parent:Add('DPanel')
  panel:Dock(TOP)
  panel:DockMargin(0, 0, 0, math.Round(8 * s))
  panel:SetTall(image_size + pad * 2)
  LoadImage(item, function(mat) panel.image = mat end)
  local button = Menu.Button(panel, SubscribeText(item.id), steamworks.IsSubscribed(item.id) and 'secondary' or 'primary', function() end)
  surface.SetFont('BGN.Menu.Value')
  local widest = math.max(surface.GetTextSize(Menu.Text('#bgn.menu.works.subscribe')), surface.GetTextSize(Menu.Text('#bgn.menu.works.subscribed')))
  button:SetWide(math.max(button:GetWide(), widest + math.Round(32 * s)))
  button:SetEnabled(not steamworks.IsSubscribed(item.id))
  button.DoClick = function(self)
    Menu.Sound('click')
    steamworks.Subscribe(item.id)
    steamworks.ApplyAddons()
    self.text = Menu.Text('#bgn.menu.works.subscribed')
    self.style = 'secondary'
    self:SetEnabled(false)
  end

  panel.PerformLayout = function(self, w, h) button:SetPos(w - pad - button:GetWide(), (h - button:GetTall()) / 2) end
  panel.Paint = function(self, w, h)
    draw.RoundedBox(radius, 0, 0, w, h, C.border)
    draw.RoundedBox(radius, 1, 1, w - 2, h - 2, C.surface)
    if self.image and not self.image:IsError() then
      surface.SetMaterial(self.image)
      surface.SetDrawColor(255, 255, 255)
      surface.DrawTexturedRect(pad, pad, image_size, image_size)
    else
      draw.RoundedBox(math.Round(6 * s), pad, pad, image_size, image_size, C.hover)
    end

    local x = pad * 2 + image_size
    local text_w = w - x - pad * 2 - button:GetWide()
    local title = Menu.Wrap(item.title, 'BGN.Menu.Body', text_w)[1] or ''
    draw.SimpleText(title, 'BGN.Menu.Body', x, pad, C.text)
    local line_h = Menu.FontHeight('BGN.Menu.Small')
    local lines = Menu.Wrap(item.description, 'BGN.Menu.Small', text_w)
    local y = pad + Menu.FontHeight('BGN.Menu.Body') + math.Round(4 * s)
    for i = 1, math.min(#lines, DESCRIPTION_LINES) do
      local line = lines[i]
      if i == DESCRIPTION_LINES and #lines > DESCRIPTION_LINES then line = line .. '…' end
      draw.SimpleText(line, 'BGN.Menu.Small', x, y, C.muted)
      y = y + line_h
    end
  end

  panel.OnMousePressed = function(_, code) if code == MOUSE_LEFT then gui.OpenURL('https://steamcommunity.com/sharedfiles/filedetails/?id=' .. item.id) end end
  panel:SetCursor('hand')
  return panel
end

-- Docked panel whose height follows its children
local function AutoHeight(panel)
  panel.PerformLayout = function(self)
    local h = 0
    for _, child in ipairs(self:GetChildren()) do
      local _, top, _, bottom = child:GetDockMargin()
      h = h + child:GetTall() + top + bottom
    end

    if self:GetTall() ~= h then
      self:SetTall(h)
      Menu.ContentChanged()
    end
  end
end

local function Status(parent, text)
  parent:Clear()
  -- a starting height: AutoHeight sums the children, the paragraph fits itself on layout
  Menu.Paragraph(parent, text, 'BGN.Menu.Body', C.muted):SetTall(Menu.FontHeight('BGN.Menu.Body'))
end

Menu.AddPage('other_works', {
  group = '#bgn.menu.group.other', -- its own sidebar heading, apart from the settings
  title = '#bgn.menu.page.other_works',
  icon = 'background_npcs/vgui/menu/app.png',
  order = math.huge, -- always the last page
  highlight = true,
  build = function(page)
    if page.filter then -- search: nothing to match, no requests
      return
    end

    page:Custom(function(panel)
      panel:SetTall(Menu.FontHeight('BGN.Menu.PageTitle') + math.Round(12 * Menu.Scale()))
      panel.Paint = function(_, _, h) draw.SimpleText(Menu.Text('#bgn.menu.works.header'), 'BGN.Menu.PageTitle', 0, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
    end)

    page:Custom(function(list)
      AutoHeight(list)
      Status(list, Menu.Text('#bgn.menu.works.loading'))
      Load(function(items)
        if not IsValid(list) then return end
        if not items then return Status(list, Menu.Text('#bgn.menu.works.failed')) end
        list:Clear()
        for _, item in ipairs(items) do
          ItemPanel(list, item)
        end

        list:InvalidateLayout()
      end)
    end)
  end,
})

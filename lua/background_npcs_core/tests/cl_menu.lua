local Menu = bgNPC.Menu
local Parse = Menu.ParseWorkshop
bgNPC.Test.Add('menu.workshop_parse', function(check)
  local html = '<div id="sharedfile_42" class="x"><img class="workshopItemPreviewImage " src="https://a/b.jpg?x=1&amp;y=2">' .. 'SharedFileBindMouseHover( "sharedfile_42", true, {"id":"42","title":"Mod","description":"Text {x}"} );' .. '<a href="?appid=4000&amp;p=2">2</a><a href="?appid=4000&amp;p=11">11</a><a href="?numperpage=30">'
  local items, pages = Parse(html)
  check(#items == 1 and items[1].id == '42' and items[1].title == 'Mod' and items[1].description == 'Text {x}', 'item')
  check(items[1].image == 'https://a/b.jpg?x=1&y=2', 'image url unescaped')
  check(pages == 11, 'pages from the paging links')
end)

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

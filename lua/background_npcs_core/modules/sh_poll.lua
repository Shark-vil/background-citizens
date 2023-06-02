local CURRENT_POLL_VERSION = 'B3jF88LrrdEYQKxe8'

if SERVER then
  hook.Add('PlayerSay', 'BGN_Poll_OpenMenu', function(ply, text)
    if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end

    if string.lower(text) == '!bgnpoll' then
      sgui.route('BGN_Poll_Menu', ply)
      return ''
    end
  end)
else
  hook.Add('slib.FirstPlayerSpawn', 'BGN_CheckAddonPulls', function(ply)
    if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end

    if file.Exists('background_npcs/poll.txt', 'DATA') then
      local poll_version = file.Read('background_npcs/poll.txt', 'DATA')
      if poll_version == CURRENT_POLL_VERSION then return end
    end

    timer.Simple(5, function()
      local text = slib.language({
        ['default'] = {
          ['message'] = 'Hey! I suggest you take a survey on the addon "Background NPCs". To do this, write the command to the chat: !bgnpoll (This message will appear only once)',
        },
        ['russian'] = {
          ['message'] = 'Привет! Предлагаю вам пройти опрос по аддону "Background NPCs". Для этого напишите в чат команду: !bgnpoll (Это сообщение появится только один раз)',
        }
      })

      chat.AddText(Color(255, 0, 0), '[ADMIN] ', Color(226, 213, 31), text.message)
      surface.PlaySound('UI/buttonclickrelease.wav')
      file.Write('background_npcs/poll.txt', CURRENT_POLL_VERSION)
    end)
  end)

  sgui.RouteRegister('BGN_Poll_Menu', function()
    local Width = ScrW() - 25
    local Height = ScrH() - 25
    local MainWindow, ParentUrlField, ParentUrlButton, ParentUrlButtonBack, ParnetHtmlPanel

    local lang = slib.language({
      ['default'] = {
        ['title'] = 'Background NPCs - Poll',
        ['html_button'] = 'Go to the link',
        ['html_button_back'] = 'Go back to the main',
        ['link'] = 'https://forms.gle/B3jF88LrrdEYQKxe8',
      },
      ['russian'] = {
        ['title'] = 'Фоновые NPCs - Опрос',
        ['html_button'] = 'Перейти по ссылке',
        ['html_button_back'] = 'Вернуться на главную',
        ['link'] = 'https://forms.gle/B3jF88LrrdEYQKxe8',
      }
    })

    MainWindow = vgui.Create('DFrame')
    MainWindow:SetSize(Width, Height)
    MainWindow:SetTitle(lang['title'])
    MainWindow:Center()
    MainWindow:MakePopup()

    MainWindow.OnClose = function()
      surface.PlaySound('buttons/button4.wav')
    end

    ParentUrlField = vgui.Create('DTextEntry', MainWindow)
    ParentUrlField:SetPos(10, 30)
    ParentUrlField:SetTall(25)
    ParentUrlField:SetWide(Width - 300 - 10)
    ParentUrlField:SetEnterAllowed(true)
    ParentUrlField:SetText(lang['link'])

    ParentUrlField.OnEnter = function()
      ParnetHtmlPanel:OpenURL(ParentUrlField:GetValue())
    end

    ParentUrlButton = vgui.Create('DButton', MainWindow)
    ParentUrlButton:SetPos(Width - 295, 30)
    ParentUrlButton:SetSize(140, 25)
    ParentUrlButton:SetText(lang['html_button'])
    ParentUrlButtonBack = vgui.Create('DButton', MainWindow)
    ParentUrlButtonBack:SetPos(Width - 150, 30)
    ParentUrlButtonBack:SetSize(140, 25)
    ParentUrlButtonBack:SetText(lang['html_button_back'])

    ParentUrlButtonBack.DoClick = function()
      ParnetHtmlPanel:OpenURL(lang['link'])
    end

    ParnetHtmlPanel = vgui.Create('DHTML', MainWindow)
    ParnetHtmlPanel:SetPos(10, 60)
    ParnetHtmlPanel:SetSize(Width - 20, Height - 70)
    ParnetHtmlPanel:OpenURL(lang['link'])

    ParnetHtmlPanel.OnBeginLoadingDocument = function(panel, link)
      ParentUrlField:SetText(link)
    end

    ParentUrlButton.DoClick = function()
      ParnetHtmlPanel:OpenURL(ParentUrlField:GetValue())
    end

    timer.Simple(2, function()
      surface.PlaySound('buttons/lever1.wav')
    end)
  end, { isAdmin = true })
end
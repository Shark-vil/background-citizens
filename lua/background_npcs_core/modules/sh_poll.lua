local CURRENT_POLL_VERSION = 'jiHTALv3NUG67L8d6'

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

    local info

    if file.Exists('background_npcs/poll.txt', 'DATA') then
      info = util.JSONToTable(file.Read('background_npcs/poll.txt', 'DATA'))
      if info and info.version == CURRENT_POLL_VERSION and info.time < os.time() then return end
    end

    timer.Simple(5, function()
      local text = slib.language({
        ['default'] = {
          ['message'] = 'Hey! I suggest you take a survey on the addon "Background NPCs - Stop updates". To do this, write the command to the chat: !bgnpoll (This message will stop appearing after 7 days)',
        },
        ['russian'] = {
          ['message'] = 'Привет! Предлагаю вам пройти опрос по аддону "Background NPCs - Прекращение обновлений". Для этого напишите в чат команду: !bgnpoll (Это сообщение прекратит появляться через 7 дней)',
        }
      })

      chat.AddText(Color(255, 0, 0), '[ADMIN] ', Color(226, 213, 31), text.message)
      surface.PlaySound('UI/buttonclickrelease.wav')

      if not info or info.version ~= CURRENT_POLL_VERSION then
        file.Write('background_npcs/poll.txt', util.TableToJSON({
          version = CURRENT_POLL_VERSION,
          time = os.time() + (60 * 60 * 24 * 7)
        }))
      end
    end)
  end)

  sgui.RouteRegister('BGN_Poll_Menu', function()
    local Width = ScrW() - 25
    local Height = ScrH() - 25
    local MainWindow, ParentUrlField, ParentUrlButton, ParentUrlButtonBack, ParnetHtmlPanel

    local lang = slib.language({
      ['default'] = {
        ['title'] = 'Background NPCs - Poll',
        ['html_button_steam'] = 'Open in STEAM',
        ['html_button'] = 'Go to the link',
        ['html_button_back'] = 'Go back to the main',
        ['link'] = 'https://forms.gle/jiHTALv3NUG67L8d6',
      },
      ['russian'] = {
        ['title'] = 'Фоновые NPCs - Опрос',
        ['html_button_steam'] = 'Открыть в STEAM',
        ['html_button'] = 'Перейти по ссылке',
        ['html_button_back'] = 'Вернуться на главную',
        ['link'] = 'https://forms.gle/jiHTALv3NUG67L8d6',
      }
    })

    file.Write('background_npcs/poll.txt', util.TableToJSON({
      version = CURRENT_POLL_VERSION,
      time = 0
    }))

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
    ParentUrlField:SetWide(Width - 445 - 10)
    ParentUrlField:SetEnterAllowed(true)
    ParentUrlField:SetText(lang['link'])
    ParentUrlField.OnEnter = function()
      ParnetHtmlPanel:OpenURL(ParentUrlField:GetValue())
    end

    ParentUrlButtonSteam = vgui.Create('DButton', MainWindow)
    ParentUrlButtonSteam:SetPos(Width - 440, 30)
    ParentUrlButtonSteam:SetSize(140, 25)
    ParentUrlButtonSteam:SetText(lang['html_button_steam'])
    ParentUrlButtonSteam.DoClick = function()
      gui.OpenURL(lang['link'])
    end

    ParentUrlButton = vgui.Create('DButton', MainWindow)
    ParentUrlButton:SetPos(Width - 295, 30)
    ParentUrlButton:SetSize(140, 25)
    ParentUrlButton:SetText(lang['html_button'])
    ParentUrlButton.DoClick = function()
      ParnetHtmlPanel:OpenURL(ParentUrlField:GetValue())
    end

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

    timer.Simple(2, function()
      surface.PlaySound('buttons/lever1.wav')
    end)
  end, { isAdmin = true })
end
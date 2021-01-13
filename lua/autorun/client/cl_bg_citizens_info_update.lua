
local filename = 'bgn_info.txt'

local ru_lang = {
	['title'] = 'Фоновые NPCs - ИНФОРМАЦИОННОЕ УВЕДОМЛЕНИЕ',
	['html_button'] = 'Перейти по ссылке',
	['html_button_back'] = 'Вернуться на главную',
	['link'] = 'https://itpony.ru/background-citizen/ru.html'
}

local en_lang = {
	['title'] = 'Background NPCs - INFORMATION NOTICE',
	['html_button'] = 'Go to the link',
	['html_button_back'] = 'Go back to the main',
	['link'] = 'https://itpony.ru/background-citizen/en.html'
}

local lang = GetConVar('cl_language'):GetString() == 'russian' and ru_lang or en_lang

net.Receive('bgn_player_initial_info_block', function()
	if file.Exists(filename, 'DATA') then return end

	file.Write(filename, 'https://github.com/Shark-vil/background-citizens')

	surface.PlaySound('buttons/lever2.wav')

	local w = ScrW() - 25
	local h = ScrH() - 25

	local MainWindow, ParentUrlField, ParentUrlButton, ParentUrlButtonBack, ParnetHtmlPanel

	MainWindow = vgui.Create('DFrame')
	MainWindow:SetSize(w, h)
	MainWindow:SetTitle(lang['title'])
	MainWindow:Center()
	MainWindow:MakePopup()
	MainWindow.OnClose = function()
		surface.PlaySound('buttons/button4.wav')
	end

	ParentUrlField = vgui.Create('DTextEntry', MainWindow )
	ParentUrlField:SetPos(10, 30)
	ParentUrlField:SetTall(25)
	ParentUrlField:SetWide(w - 300 - 10)
	ParentUrlField:SetEnterAllowed(true)
	ParentUrlField:SetText(lang['link'])
	ParentUrlField.OnEnter = function()
		ParnetHtmlPanel:OpenURL(ParentUrlField:GetValue())
	end

	ParentUrlButton = vgui.Create('DButton', MainWindow)
	ParentUrlButton:SetPos(w - 295, 30)
	ParentUrlButton:SetSize(140, 25)
	ParentUrlButton:SetText(lang['html_button'])

	ParentUrlButtonBack = vgui.Create('DButton', MainWindow)
	ParentUrlButtonBack:SetPos(w - 150, 30)
	ParentUrlButtonBack:SetSize(140, 25)
	ParentUrlButtonBack:SetText(lang['html_button_back'])
	ParentUrlButtonBack.DoClick = function()
		ParnetHtmlPanel:OpenURL(lang['link'])
	end

	ParnetHtmlPanel = vgui.Create( 'DHTML', MainWindow )
	ParnetHtmlPanel:SetPos(10, 60)
	ParnetHtmlPanel:SetSize(w - 20, h - 70)
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
end)
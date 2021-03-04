concommand.Add('bgn_open_updateinfo', function()
	surface.PlaySound('buttons/lever2.wav')

	local ru_lang = {
		['title'] = "Фоновые NPCs - Страница обновления",
		['html_button'] = "Перейти по ссылке",
		['html_button_back'] = "Вернуться на главную",
		['link'] = "https://itpony.ru/background-citizen/" .. bgNPC.VERSION .. "/ru.html"
	}

	local en_lang = {
		['title'] = "Background NPCs - Update page",
		['html_button'] = "Go to the link",
		['html_button_back'] = "Go back to the main",
		['link'] = "https://itpony.ru/background-citizen/" .. bgNPC.VERSION .. "/en.html"
	}

	local lang = GetConVar('cl_language'):GetString() == 'russian' and ru_lang or en_lang

	http.Fetch(lang['link'],
		function(github_version, length, headers, code)
			local Width = ScrW() - 25
			local Height = ScrH() - 25

			local MainWindow, ParentUrlField, ParentUrlButton, ParentUrlButtonBack, ParnetHtmlPanel

			MainWindow = vgui.Create( "DFrame" )
			MainWindow:SetSize( Width, Height )
			MainWindow:SetTitle( lang['title'] )
			MainWindow:Center()
			MainWindow:MakePopup()
			MainWindow.OnClose = function()
				surface.PlaySound('buttons/button4.wav')
			end

			ParentUrlField = vgui.Create( "DTextEntry", MainWindow )
			ParentUrlField:SetPos( 10, 30 )
			ParentUrlField:SetTall( 25 )
			ParentUrlField:SetWide( Width - 300 - 10 )
			ParentUrlField:SetEnterAllowed( true )
			ParentUrlField:SetText( lang['link'] )
			ParentUrlField.OnEnter = function()
				ParnetHtmlPanel:OpenURL( ParentUrlField:GetValue() )
			end

			ParentUrlButton = vgui.Create( "DButton", MainWindow )
			ParentUrlButton:SetPos( Width - 295, 30 )
			ParentUrlButton:SetSize( 140, 25 )
			ParentUrlButton:SetText( lang['html_button'] )

			ParentUrlButtonBack = vgui.Create( "DButton", MainWindow )
			ParentUrlButtonBack:SetPos( Width - 150, 30 )
			ParentUrlButtonBack:SetSize( 140, 25 )
			ParentUrlButtonBack:SetText( lang['html_button_back'] )
			ParentUrlButtonBack.DoClick = function ()
				ParnetHtmlPanel:OpenURL( lang['link'] )
			end

			ParnetHtmlPanel = vgui.Create( "DHTML", MainWindow )
			ParnetHtmlPanel:SetPos( 10, 60 )
			ParnetHtmlPanel:SetSize( Width - 20, Height - 70 )
			ParnetHtmlPanel:OpenURL( lang['link'] )
			ParnetHtmlPanel.OnBeginLoadingDocument = function( panel, link )
				ParentUrlField:SetText( link )
			end
			ParentUrlButton.DoClick = function()
				ParnetHtmlPanel:OpenURL( ParentUrlField:GetValue() )
			end

			timer.Simple(2, function()
				surface.PlaySound('buttons/lever1.wav')
			end)
		end,
		function()
			chat.AddText(Color(255, 0, 0), '[ERROR] ', Color(100, 100, 255), 'There is no info page for this version.')
		end
	)
end)
if SERVER then
	util.AddNetworkString('bgn_player_initial_info_block')
	local is_informated = {}

	hook.Add("PlayerSpawn", "BGN_PlayerSpawnInitInfoBlock", function(ply)
		if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end
		if not table.HasValue(is_informated, ply) then
			timer.Simple(4, function()
				if not IsValid(ply) then return end
				net.Start('bgn_player_initial_info_block')
				net.Send(ply)
			end)
			table.insert(is_informated, ply)
		end
	end)
else
	net.Receive('bgn_player_initial_info_block', function()
		local filename = "bgn_version.txt"
		
		if file.Exists(filename, "DATA") then
			local old_version = file.Read(filename, "DATA")
			if bgNPC.VERSION == old_version then
				return
			end
		end

		file.Write(filename, bgNPC.VERSION)

		surface.PlaySound('buttons/lever2.wav')

		local lang

		local ru_lang = {
			['title'] = "Фоновые NPCs - ИНФОРМАЦИОННОЕ УВЕДОМЛЕНИЕ",
			['html_button'] = "Перейти по ссылке",
			['html_button_back'] = "Вернуться на главную",
			['link'] = "https://itpony.ru/background-citizen/" .. bgNPC.VERSION .. "/ru.html"
		}

		local en_lang = {
			['title'] = "Background NPCs - INFORMATION NOTICE",
			['html_button'] = "Go to the link",
			['html_button_back'] = "Go back to the main",
			['link'] = "https://itpony.ru/background-citizen/" .. bgNPC.VERSION .. "/en.html"
		}

		local lang = GetConVar('cl_language'):GetString() == 'russian' and ru_lang or en_lang
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
	end)
end
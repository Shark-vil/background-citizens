if SERVER then
    util.AddNetworkString('bgn_error_slib_library')

    hook.Add('PlayerSpawn', 'BGN_SLIB_ERROR', function(ply)
        if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end
		if ply.sliberror then return end
		ply.sliberror = true

		timer.Simple(5, function()
            if not IsValid(ply) then return end

			net.Start('bgn_error_slib_library')
			net.Send(ply)
		end)
	end)
else
    net.Receive('bgn_error_slib_library', function()
        local MainMenu = vgui.Create("DFrame")
        MainMenu:SetPos(ScrW()/2 - 500/2, ScrH()/2 - 250/2)
        MainMenu:SetSize(500, 250)
        MainMenu:SetTitle("Background NPCs - Error slib library")
        MainMenu:SetDraggable(true)
        MainMenu:MakePopup()
        MainMenu.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(0, 0, 0, 250))
        end

        local maleImage = vgui.Create("DImage", MainMenu)
        maleImage:SetPos(10, 100)
        maleImage:SetSize(150, 150)
        maleImage:SetImage("background_npcs/vgui/missing_slib.png")

        local MainMenu_Label = vgui.Create("DLabel", MainMenu)
        MainMenu_Label:SetPos(170, 20)
        MainMenu_Label:SetSize(350, 150)
        MainMenu_Label:SetText([[You are missing the required dependency!
The mod won't work without it!
Subscribe for the addon at the workshop.

I understand perfectly well that you were better off when this 
mod did not require dependencies. But due to the fact that 
I use the same code in several addons, they break compatibility. 
This cannot be fixed without creating a separate library. 
I hope for your understanding.
:3]])

        local ButtonYes = vgui.Create("DButton", MainMenu)
        ButtonYes:SetText("Open workshop page")
        ButtonYes:SetPos(170, 200)
        ButtonYes:SetSize(155, 30)
        ButtonYes.DoClick = function()
            gui.OpenURL("https://google.ru")
            MainMenu:Close()
        end

        local ButtonNo = vgui.Create("DButton", MainMenu)
        ButtonNo:SetText("Close window")
        ButtonNo:SetPos(350, 200)
        ButtonNo:SetSize(100, 30)
        ButtonNo.DoClick = function()
            MainMenu:Close()
        end
    end)
end
if SERVER then
	util.AddNetworkString('bgNPCSaveRoute')
	util.AddNetworkString('bgNPCRemoveRoute')
	util.AddNetworkString('bgNPCSyncNavmeshInfoFromPlayer')

	net.Receive('bgNPCRemoveRoute', function(len, ply)
		if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end
		if not net.ReadBool() then return end

		local map_name = net.ReadString()
		local json_file = 'citizens_points/' .. map_name .. '.json'
		local dat_file = 'citizens_points/' .. map_name .. '.dat'

		if file.Exists(json_file, 'DATA') then
			file.Delete(json_file)
			bgNPC:Log('Remove route file - ' .. json_file, 'Route')
		end

		if file.Exists(dat_file, 'DATA') then
			file.Delete(dat_file)
			bgNPC:Log('Remove route file - ' .. dat_file, 'Route')
		end

		ply:ConCommand('cl_citizens_load_route')
	end)

	snet.RegisterCallback('bgn_save_routes', function(ply, bigdata)
		if bigdata.from_json then
			file.Write('citizens_points/' .. game.GetMap() .. '.json', bigdata.data)
		else
			file.Write('citizens_points/' .. game.GetMap() .. '.dat', util.Compress(bigdata.data))
		end

		bgNPC.LoadRoutes()
	end, false, true)

	hook.Add("SlibPlayerFirstSpawn", "BGN_SyncPlayerNavmeshInfo", function(ply)
		bgNPC.NavmeshIsLoaded = navmesh.IsLoaded()
		snet.Invoke('bgn_sync_navmesh_info', ply, bgNPC.NavmeshIsLoaded)
	end)
else
	concommand.Add('cl_citizens_remove_route', function (ply, cmd, args)
		if args[1] ~= nil and args[1] == 'yes' then
			local map_name = args[2] or game.GetMap()

			net.Start('bgNPCRemoveRoute')
			net.WriteBool(true)
			net.WriteString(map_name)
			net.SendToServer()
		else
			bgNPC:Log('If you want to delete the mesh file, add as the first command argument - yes', 'Route')
			bgNPC:Log('Example: cl_citizens_remove_route yes', 'Route')
		end
	end, nil, 'Removes the mesh file from the server. The first argument is confirmation, the second argument is the name of the card. If there is no second argument, then the current map is used.')

	snet.RegisterCallback('bgn_sync_navmesh_info', function(ply, is_load)
		bgNPC.NavmeshIsLoaded = is_load
	end)

	concommand.Add('cl_citizens_save_route', function(ply, cmd, args)
		if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end

		local jsonNodes = BGN_NODE:MapToJson()

		local from_json = false
		if args[1] == 'json' then
			from_json = true
		end

		if BGN_NODE:CountNodesOnMap() ~= 0 then
			snet.InvokeBigData('bgn_save_routes', nil, { 
				from_json = from_json, 
				data = jsonNodes
			}, nil, 'BgnLoadPoints', 'Sending the mesh to the server')
		else
			local MainMenu = vgui.Create("DFrame")
			MainMenu:SetPos(ScrW()/2 - 500/2, ScrH()/2 - 230/2)
			MainMenu:SetSize(500, 230)
			MainMenu:SetTitle("Background NPCs - Warning!")
			MainMenu:SetDraggable(true)
			MainMenu:MakePopup()
			MainMenu.Paint = function(self, w, h)
				draw.RoundedBox(8, 0, 0, w, h, Color(0, 0, 0, 250))
			end

			local maleImage = vgui.Create("DImage", MainMenu)
			maleImage:SetPos(10, 90)
			maleImage:SetSize(150, 150)
			maleImage:SetImage("background_npcs/vgui/missing_slib.png")

			local MainMenu_Label = vgui.Create("DLabel", MainMenu)
			MainMenu_Label:SetPos(170, 20)
			MainMenu_Label:SetSize(350, 150)
			if GetConVar('cl_language'):GetString() == 'russian' then
				MainMenu_Label:SetText([[ВНИМАНИЕ!

				Вы собирайтесь сохранить пустую карту передвижения.
				Вы окончательно замените старый файл на сервере.
				Нажмите "Save" если уверены в своих действиях.
				]])
			else
				MainMenu_Label:SetText([[ATTENTION!

				Are you going to keep a empty movement map.
				You will permanently replace the old file on the server.
				Click "Save" if you are sure of your actions.
				]])
			end

			local ButtonYes = vgui.Create("DButton", MainMenu)
			ButtonYes:SetText("Save")
			ButtonYes:SetPos(170, 170)
			ButtonYes:SetSize(155, 30)
			ButtonYes.DoClick = function()
				snet.InvokeBigData('bgn_save_routes', nil, { 
					from_json = from_json, 
					data = jsonNodes
				}, nil, 'BgnLoadPoints', 'Sending the mesh to the server')
		
				MainMenu:Close()
			end

			local ButtonNo = vgui.Create("DButton", MainMenu)
			ButtonNo:SetText("Cancel")
			ButtonNo:SetPos(350, 170)
			ButtonNo:SetSize(100, 30)
			ButtonNo.DoClick = function()
				MainMenu:Close()
			end
		end
	end, nil, 'Saves movement points (Only if the player has a tool weapon!)')
end
local function TOOL_MENU(panel)
	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.client.cl_ambient_sound',
		['Command'] = 'bgn_cl_ambient_sound',
		['Help'] = true,
	})
end

hook.Add('PopulateToolMenu', 'BGN_TOOL_CreateMenu_ClientSettings', function()
	spawnmenu.AddToolMenuOption('Options', 'Background NPCs', 'BGN_Client_Settings', '#bgn.settings.client', '', '', TOOL_MENU)
end)
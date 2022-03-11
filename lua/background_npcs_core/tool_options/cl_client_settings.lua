local function TOOL_MENU(Panel)
	Panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.general.bgn_cl_ambient_sound',
		['Command'] = 'bgn_cl_ambient_sound'
	}); Panel:AddControl('Label', {
		['Text'] = '#bgn.settings.general.bgn_cl_ambient_sound.description'
	})
end

hook.Add('PopulateToolMenu', 'BGN_TOOL_CreateMenu_ClientSettings', function()
	spawnmenu.AddToolMenuOption('Options', 'Background NPCs', 'BGN_Client_Settings', 
		'#bgn.settings.client_title', '', '', TOOL_MENU)
end)
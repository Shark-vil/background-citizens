local function TOOL_MENU(panel)
	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.arrest.arrest_mode',
		['Command'] = 'bgn_arrest_mode',
		['Help'] = true,
	})

	panel:AddControl('Slider', {
		['Label'] = '#bgn.settings.arrest.arrest_time',
		['Command'] = 'bgn_arrest_time',
		['Type'] = 'Float',
		['Min'] = '0',
		['Max'] = '100',
		['Help'] = true,
	})

	panel:AddControl('Slider', {
		['Label'] = '#bgn.settings.arrest.arrest_time_limit',
		['Command'] = 'bgn_arrest_time_limit',
		['Type'] = 'Float',
		['Min'] = '0',
		['Max'] = '100',
		['Help'] = true,
	})
end

hook.Add('PopulateToolMenu', 'BGN_TOOL_CreateMenu_ArrestSettings', function()
	spawnmenu.AddToolMenuOption('Options', 'Background NPCs', 'BGN_Arrest_Settings', '#bgn.settings.arrest', '', '', TOOL_MENU)
end)
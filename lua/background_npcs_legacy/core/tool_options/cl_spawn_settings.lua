local function TOOL_MENU(panel)
	panel:AddControl('Slider', {
		['Label'] = '#bgn.settings.spawn.spawn_radius',
		['Command'] = 'bgn_spawn_radius',
		['Type'] = 'Float',
		['Min'] = '0',
		['Max'] = '5000',
		['Help'] = true,
	})

	panel:AddControl('Slider', {
		['Label'] = '#bgn.settings.spawn.spawn_radius_visibility',
		['Command'] = 'bgn_spawn_radius_visibility',
		['Type'] = 'Float',
		['Min'] = '0',
		['Max'] = '5000',
		['Help'] = true,
	})

	panel:AddControl('Slider', {
		['Label'] = '#bgn.settings.spawn.spawn_block_radius',
		['Command'] = 'bgn_spawn_block_radius',
		['Type'] = 'Float',
		['Min'] = '0',
		['Max'] = '5000',
		['Help'] = true,
	})

	panel:AddControl('Slider', {
		['Label'] = '#bgn.settings.spawn.spawn_period',
		['Command'] = 'bgn_spawn_period',
		['Type'] = 'Float',
		['Min'] = '0',
		['Max'] = '50',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.spawn.fasted_teleport',
		['Command'] = 'bgn_fasted_teleport',
		['Help'] = true,
	})
end

hook.Add('PopulateToolMenu', 'BGN_TOOL_CreateMenu_SpawnSettings', function()
	spawnmenu.AddToolMenuOption('Options', 'Background NPCs', 'BGN_Spawn_Settings', '#bgn.settings.spawn', '', '', TOOL_MENU)
end)
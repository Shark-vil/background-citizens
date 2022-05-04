local function TOOL_MENU(Panel)
	Panel:AddControl('Slider', {
		['Label'] = '#bgn.settings.general.bgn_max_npc',
		['Command'] = 'bgn_max_npc',
		['Type'] = 'Integer',
		['Min'] = '0',
		['Max'] = '200',
		['Help'] = true,
	})

	Panel:AddControl('Label', { Text = '===========' });

	for npcType, v in SortedPairs(bgNPC.cfg.actors) do
		local name = v.name or npcType
		if v.hidden then continue end

		Panel:AddControl('CheckBox', {
			['Label'] = name,
			['Command'] = 'bgn_npc_type_' .. npcType
		})

		Panel:AddControl('CheckBox', {
			['Label'] = '#bgn.settings.active_npcs.bgn_disable_weapon_' .. npcType,
			['Command'] = 'bgn_disable_weapon_' .. npcType,
			['Help'] = true,
		})

		Panel:AddControl('Slider', {
			['Label'] = '#bgn.settings.active_npcs.max_npc_' .. npcType,
			['Command'] = 'bgn_npc_type_max_' .. npcType,
			['Type'] = 'Integer',
			['Min'] = '0',
			['Max'] = '200',
			['Help'] = true,
		});

		if DecentVehicleDestination then
			Panel:AddControl('Slider', {
				['Label'] = '#bgn.settings.active_npcs.max_npc_vehicle_' .. npcType,
				['Command'] = 'bgn_npc_vehicle_max_' .. npcType,
				['Type'] = 'Integer',
				['Min'] = '0',
				['Max'] = '200',
				['Help'] = true,
			});
		end

		Panel:AddControl('Label', { Text = '===========' });
	end

	Panel:AddControl('Label', {
		['Text'] = '#bgn.settings.active_npcs.help'
	})
end

hook.Add('PopulateToolMenu', 'BGN_TOOL_CreateMenu_ActiveNPCGroups', function()
	spawnmenu.AddToolMenuOption('Options', 'Background NPCs', 'BGN_Active_NPC_Groups',
		'#bgn.settings.active_title', '', '', TOOL_MENU)
end)
local function TOOL_MENU(panel)
	panel:AddControl('Header', {
		['Description'] = '==[ Total NPC ]==',
	})

	panel:AddControl('Slider', {
		['Label'] = '#bgn.settings.actor.total_max_npc',
		['Command'] = 'bgn_max_npc',
		['Type'] = 'Integer',
		['Min'] = '0',
		['Max'] = '200',
		['Help'] = true,
	})

	panel:AddControl('Header', {
		['Description'] = '==[ Selective setting ]==',
	})

	panel:AddControl('Label', {
		['Text'] = '#bgn.settings.actor.active_npcs.help'
	})

	for npc_type, v in SortedPairs(bgNPC.cfg.actors) do
		local name = v.name or npc_type
		if v.hidden then continue end

		panel:AddControl('CheckBox', {
			['Label'] = '---- | ' .. name,
			['Command'] = 'bgn_npc_type_' .. npc_type
		})

		panel:AddControl('CheckBox', {
			['Label'] = '#bgn.settings.actor.disable_weapon_' .. npc_type,
			['Command'] = 'bgn_disable_weapon_' .. npc_type,
			['Help'] = true,
		})

		panel:AddControl('Slider', {
			['Label'] = '#bgn.settings.actor.max_npc_' .. npc_type,
			['Command'] = 'bgn_npc_type_max_' .. npc_type,
			['Type'] = 'Integer',
			['Min'] = '0',
			['Max'] = '200',
			['Help'] = true,
		});

		if DecentVehicleDestination and v.vehicles and istable(v.vehicles) and #v.vehicles ~= 0 then
			panel:AddControl('Slider', {
				['Label'] = '#bgn.settings.actor.max_npc_vehicle_' .. npc_type,
				['Command'] = 'bgn_npc_vehicle_max_' .. npc_type,
				['Type'] = 'Integer',
				['Min'] = '0',
				['Max'] = '200',
				['Help'] = true,
			});
		end
	end
end

hook.Add('PopulateToolMenu', 'BGN_TOOL_CreateMenu_ActiveNPCGroups', function()
	spawnmenu.AddToolMenuOption('Options', 'Background NPCs', 'BGN_Active_NPC_Groups', '#bgn.settings.actor', '', '', TOOL_MENU)
end)
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

	for npcType, v in pairs(bgNPC.cfg.actors) do
		local name = v.name or npcType
		if v.hidden then continue end

		Panel:AddControl('CheckBox', {
			['Label'] = name,
			['Command'] = 'bgn_npc_type_' .. npcType
		})

		if npcType == 'citizen' then
			Panel:AddControl('CheckBox', {
				['Label'] = '#bgn.settings.active_npcs.bgn_disable_citizens_weapons',
				['Command'] = 'bgn_disable_citizens_weapons',
				['Help'] = true,
			})
		end

		Panel:AddControl('Label', {
			['Text'] = 'Max "' .. name .. '" npc on the map'
		}); Panel:AddControl('Slider', {
			['Label'] = 'Max ' .. name,
			['Command'] = 'bgn_npc_type_max_' .. npcType,
			['Type'] = 'Integer',
			['Min'] = '0',
			['Max'] = '200'
		});

		if DecentVehicleDestination then
			Panel:AddControl('Label', {
				['Text'] = 'Max "' .. name .. '" vehicle on the map'
			}); Panel:AddControl('Slider', {
				['Label'] = 'Max ' .. name .. ' vehicle',
				['Command'] = 'bgn_npc_vehicle_max_' .. npcType,
				['Type'] = 'Integer',
				['Min'] = '0',
				['Max'] = '200'
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
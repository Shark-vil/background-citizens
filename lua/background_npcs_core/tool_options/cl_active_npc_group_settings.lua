local function TOOL_MENU(Panel)
	local exists_types = {}
	
	Panel:AddControl("Slider", {
		["Label"] = "#bgn.settings.general.bgn_max_npc",
		["Command"] = "bgn_max_npc",
		["Type"] = "Integer",
		["Min"] = "0",
		["Max"] = "200"
	}); Panel:AddControl('Label', {
		Text = '#bgn.settings.general.bgn_max_npc.description'
	})

	Panel:AddControl('Label', { Text = '===========' });

	for npcType, v in pairs(bgNPC.cfg.npcs_template) do
		if not table.HasValue(exists_types, npcType) then
			Panel:AddControl('CheckBox', {
				Label = npcType,
				Command = 'bgn_npc_type_' .. npcType
			})
			table.insert(exists_types, npcType)

			if npcType == 'citizen' then
				Panel:AddControl('CheckBox', {
					Label = '#bgn.settings.active_npcs.bgn_disable_citizens_weapons',
					Command = 'bgn_disable_citizens_weapons' 
				}); Panel:AddControl('Label', {
					Text = '#bgn.settings.active_npcs.bgn_disable_citizens_weapons.description'
				})
			end

			Panel:AddControl('Label', {
				Text = 'Max "' .. (v.name or npcType) .. '" npc on the map'
			}); Panel:AddControl("Slider", {
				["Label"] = "Max " .. npcType,
				["Command"] = 'bgn_npc_type_max_' .. npcType,
				["Type"] = "Integer",
				["Min"] = "0",
				["Max"] = "200"
			});

			Panel:AddControl('Label', { Text = '===========' });
		end
	end

	Panel:AddControl('Label', {
		Text = '#bgn.settings.active_npcs.description'
	})
end

hook.Add("PopulateToolMenu", "BGN_TOOL_CreateMenu_ActiveNPCGroups", function()
	spawnmenu.AddToolMenuOption("Options", "Background NPCs", "BGN_Active_NPC_Groups", 
		"#bgn.settings.active_title", "", "", TOOL_MENU)
end)
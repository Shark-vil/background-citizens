--[[
	Built-in pages of the settings window (cl_menu.lua). Texts: resource/localization/*/bgn_*.properties.
--]]

local Menu = bgNPC.Menu
local ICONS = 'background_npcs/vgui/menu/'

Menu.AddPage('general', {
	title = '#bgn.menu.page.general',
	icon = ICONS .. 'general.png',
	order = 100,
	build = function(page)
		page:Section('#bgn.menu.section.main')
		page:Toggle('bgn_enable', '#bgn.settings.general.mod_enable')
		page:Toggle('bgn_debug', '#bgn.settings.general.debug')

		page:Section('#bgn.menu.section.modes')
		page:Toggle('bgn_peaceful_mode', '#bgn.settings.general.peaceful_mode')
		page:Toggle('bgn_friend_mode', '#bgn.settings.general.bgn_friend_mode')
		page:Toggle('bgn_agressive_mode', '#bgn.settings.general.bgn_agressive_mode')
		page:Toggle('bgn_ignore_another_npc', '#bgn.settings.general.ignore_another_npc')
		page:Toggle('bgn_team_damage', '#bgn.settings.general.team_damage')
	end,
})

Menu.AddPage('actors', {
	title = '#bgn.menu.page.actors',
	icon = ICONS .. 'actors.png',
	order = 200,
	build = function(page)
		page:Section('#bgn.menu.section.total')
		page:Slider('bgn_max_npc', '#bgn.settings.actor.total_max_npc', 0, 200)

		page:Note('#bgn.settings.actor.active_npcs.help')
		for actor_type, data in SortedPairs(bgNPC.cfg.actors) do
			if not data.hidden then
				page:Section(data.name or actor_type)
				page:Toggle('bgn_npc_type_' .. actor_type, '#bgn.menu.actor.enabled')
				page:Slider('bgn_npc_type_max_' .. actor_type, '#bgn.settings.actor.max_npc_' .. actor_type, 0, 200)
				if istable(data.weapons) and #data.weapons ~= 0 then
					page:Toggle('bgn_disable_weapon_' .. actor_type, '#bgn.settings.actor.disable_weapon_' .. actor_type)
				end
				if DecentVehicleDestination and istable(data.vehicles) and #data.vehicles ~= 0 then
					page:Slider('bgn_npc_vehicle_max_' .. actor_type, '#bgn.settings.actor.max_npc_vehicle_' .. actor_type, 0, 200)
				end
			end
		end
	end,
})

Menu.AddPage('spawn', {
	title = '#bgn.menu.page.spawn',
	icon = ICONS .. 'spawn.png',
	order = 300,
	build = function(page)
		page:Section('#bgn.menu.section.main')
		page:Slider('bgn_spawn_radius', '#bgn.settings.spawn.spawn_radius', 0, 5000)
		page:Slider('bgn_spawn_radius_visibility', '#bgn.settings.spawn.spawn_radius_visibility', 0, 5000)
		page:Slider('bgn_spawn_block_radius', '#bgn.settings.spawn.spawn_block_radius', 0, 5000)
		page:Slider('bgn_spawn_period', '#bgn.settings.spawn.spawn_period', 0, 50, { decimals = 1 })
		page:Toggle('bgn_fasted_teleport', '#bgn.settings.spawn.fasted_teleport')

		page:Section('#bgn.menu.section.teleport')
		page:Toggle('bgn_actors_teleporter', '#bgn.settings.spawn.actors_teleporter')
		page:Slider('bgn_actors_max_teleports', '#bgn.settings.spawn.actors_max_teleports', 1, 10)
	end,
})

Menu.AddPage('wanted', {
	title = '#bgn.menu.page.wanted',
	icon = ICONS .. 'wanted.png',
	order = 400,
	build = function(page)
		page:Section('#bgn.menu.section.main')
		page:Toggle('bgn_enable_wanted_mode', '#bgn.settings.wanted.enable_wanted_mode')
		page:Toggle('bgn_wanted_level', '#bgn.settings.wanted.level')
		page:Toggle('bgn_wanted_police_instantly', '#bgn.settings.wanted.police_instantly')
		page:Slider('bgn_wanted_time', '#bgn.settings.wanted.time', 0, 300)
		page:Slider('bgn_wanted_impunity_limit', '#bgn.settings.wanted.impunity_limit', 0, 50)
		page:Slider('bgn_wanted_impunity_reduction_period', '#bgn.settings.wanted.impunity_reduction_period', 0, 300)

		page:Section('#bgn.menu.section.hud')
		page:Toggle('bgn_cl_disable_hud_local', '#bgn.settings.wanted.cl_disable_hud_local')
		page:Toggle('bgn_wanted_hud_text', '#bgn.settings.wanted.hud_text')
		page:Toggle('bgn_wanted_hud_stars', '#bgn.settings.wanted.hud_stars')

		page:Section('#bgn.menu.section.halo')
		page:Toggle('bgn_cl_disable_halo', '#bgn.settings.wanted.cl_disable_halo')
		page:Toggle('bgn_cl_disable_self_halo_wanted', '#bgn.settings.wanted.cl_disable_self_halo_wanted')
		page:Toggle('bgn_disable_halo_calling', '#bgn.settings.wanted.disable_halo_calling')
		page:Toggle('bgn_disable_halo_wanted', '#bgn.settings.wanted.disable_halo_wanted')

		page:Section('#bgn.menu.section.colors')
		for _, name in ipairs({ 'calling_police_text', 'calling_police_halo', 'wanted_halo' }) do
			local prefix = 'bgn_wanted_color_' .. name
			page:Color('#bgn.settings.wanted.' .. name .. '_color', { prefix .. '_r', prefix .. '_g', prefix .. '_b' })
		end
	end,
})

Menu.AddPage('arrest', {
	title = '#bgn.menu.page.arrest',
	icon = ICONS .. 'arrest.png',
	order = 500,
	build = function(page)
		page:Toggle('bgn_arrest_mode', '#bgn.settings.arrest.arrest_mode')
		page:Slider('bgn_arrest_time', '#bgn.settings.arrest.arrest_time', 0, 100, { decimals = 1 })
		page:Slider('bgn_arrest_time_limit', '#bgn.settings.arrest.arrest_time_limit', 0, 100, { decimals = 1 })
	end,
})

Menu.AddPage('behavior', {
	title = '#bgn.menu.page.behavior',
	icon = ICONS .. 'behavior.png',
	order = 600,
	build = function(page)
		page:Section('#bgn.menu.section.ai')
		page:Choice('bgn_brain', '#bgn.menu.brain', {
			{ 'auto', '#bgn.menu.auto' }, { 'fsm', 'FSM' }, { 'goap', 'GOAP' },
		})
		page:Choice('bgn_actor_body', '#bgn.menu.body', {
			{ 'auto', '#bgn.menu.auto' }, { 'npc', 'NPC' }, { 'nextbot', 'NextBot' },
		})
		page:Toggle('bgn_module_tactical_groups', '#bgn.settings.extension.tactical_groups')

		page:Section('#bgn.menu.section.main')
		page:Toggle('bgn_shot_sound_mode', '#bgn.settings.extension.shot_sound_mode')
		page:Toggle('bgn_disable_dialogues', '#bgn.settings.extension.disable_dialogues')
		page:Toggle('bgn_module_replics_enable', '#bgn.settings.extension.replics_enable')
		page:Choice('bgn_module_replics_language', '#bgn.menu.replics_language', {
			{ 'auto', '#bgn.menu.auto' }, { 'english', 'English' }, { 'russian', 'Русский' },
		})
		page:Toggle('bgn_module_custom_gestures', '#bgn.settings.extension.custom_gestures')
		page:Toggle('bgn_all_models_random', '#bgn.settings.extension.all_models_random')
		page:Toggle('bgn_drop_money', '#bgn.settings.extension.drop_money')
	end,
})

Menu.AddPage('navigation', {
	title = '#bgn.menu.page.navigation',
	icon = ICONS .. 'navigation.png',
	order = 700,
	build = function(page)
		page:Section('#bgn.menu.section.main')
		page:Choice('bgn_nav_provider', '#bgn.menu.nav_provider', {
			{ 'auto', '#bgn.menu.auto' }, { 'navmesh', 'Navmesh' }, { 'nodegraph', 'Nodegraph' }, { 'custom', '#bgn.menu.nav_custom' },
		})
		page:Slider('bgn_point_z_limit', '#bgn.menu.point_z_limit', 0, 500)

		page:Section('#bgn.menu.section.generation')
		page:Toggle('bgn_dynamic_nodes', '#bgn.settings.generation.dynamic_nodes')
		page:Toggle('bgn_dynamic_nodes_save_progress', '#bgn.settings.generation.dynamic_nodes_save_progress')
		page:Slider('bgn_runtime_generator_grid_offset', '#bgn.settings.generation.runtime_generator_grid_offset', 50, 500)
		page:Slider('bgn_dynamic_nodes_radius', '#bgn.settings.generation.dynamic_nodes_radius', 0, 2000)
		page:Slider('bgn_nav_generator_max_nodes', '#bgn.menu.nav_max_nodes', 1000, 50000, { limit = 200000 })
	end,
})

Menu.AddPage('performance', {
	title = '#bgn.menu.page.performance',
	icon = ICONS .. 'performance.png',
	order = 800,
	build = function(page)
		page:Section('#bgn.menu.section.client')
		page:Toggle('bgn_cl_field_view_optimization', '#bgn.settings.optimization.cl_field_view_optimization')
		page:Slider('bgn_cl_field_view_optimization_range', '#bgn.settings.optimization.cl_field_view_optimization_range', 0, 2000)

		page:Section('#bgn.menu.section.server')
		page:Slider('bgn_disable_logic_radius', '#bgn.settings.optimization.disable_logic', 0, 1000)
		page:Slider('bgn_lod_near_radius', '#bgn.menu.lod_near_radius', 0, 10000)
	end,
})

Menu.AddPage('addons', {
	title = '#bgn.menu.page.addons',
	icon = ICONS .. 'addons.png',
	order = 900,
	build = function(page)
		page:Toggle('bgn_enable_dv_support', '#bgn.settings.addon.decent_vehicle')
		page:Toggle('bgn_enable_police_system_support', '#bgn.settings.addon.police_system')
		page:Toggle('bgn_module_stormfox2', '#bgn.settings.addon.stormfox2')
		page:Toggle('bgn_module_followers_mod_addon', '#bgn.settings.addon.followers_mod_addon')
		page:Toggle('bgn_module_n2money', '#bgn.settings.addon.n2money')
		page:Toggle('bgn_module_bio_annihilation_two_replacement', '#bgn.settings.addon.bio_annihilation_two_replacement')
		page:Toggle('bgn_module_arccw_weapon_replacement', '#bgn.settings.addon.arccw_weapon_replacement')
		page:Toggle('bgn_module_arc9_weapon_replacement', '#bgn.settings.addon.arc9_weapon_replacement')
		page:Toggle('bgn_module_tfa_weapon_replacement', '#bgn.settings.addon.tfa_weapon_replacement')
	end,
})

Menu.AddPage('client', {
	title = '#bgn.menu.page.client',
	icon = ICONS .. 'client.png',
	order = 1000,
	build = function(page)
		page:Section('#bgn.menu.section.client')
		page:Toggle('bgn_cl_ambient_sound', '#bgn.settings.client.cl_ambient_sound')
		page:Toggle('bgn_cl_draw_npc_path', '#bgn.menu.draw_npc_path')

		page:Section('#bgn.menu.section.menu')
		page:Toggle('bgn_menu_dark', '#bgn.menu.dark')
		page:Toggle('bgn_menu_sounds', '#bgn.menu.sounds')
	end,
})

Menu.AddPage('tools', {
	title = '#bgn.menu.page.tools',
	icon = ICONS .. 'tools.png',
	order = 1100,
	build = function(page)
		page:Section('#bgn.menu.section.mesh')
		page:Button('#bgn.settings.general.cl_citizens_load_route', 'cl_citizens_load_route', {
			admin = true, text = '#bgn.menu.load',
		})
		page:Button('#bgn.settings.general.clear_nodes', 'cl_citizens_clear_route', {
			admin = true, text = '#bgn.menu.clear', confirm = '#bgn.menu.confirm.clear',
		})
		page:Button('#bgn.settings.general.remove_routes', 'cl_citizens_remove_route yes', {
			admin = true, text = '#bgn.menu.delete', confirm = '#bgn.menu.confirm.remove', danger = true,
		})
		page:Button('#bgn.settings.workshop.save_to_script', 'bgn_compile', { admin = true, text = '#bgn.menu.save' })

		page:Section('#bgn.menu.section.maintenance')
		page:Button('#bgn.settings.general.updateinfo', 'bgn_updateinfo', { text = '#bgn.menu.open_page' })
		page:Button('#bgn.settings.general.reset_cvars_to_factory_settings', 'bgn_reset_cvars_to_factory_settings', {
			admin = true, text = '#bgn.menu.reset', confirm = '#bgn.menu.confirm.reset', danger = true,
		})
	end,
})

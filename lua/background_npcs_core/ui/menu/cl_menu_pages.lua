--[[
	Built-in pages of the settings window (cl_menu.lua). Texts: resource/localization/*/bgn_*.properties.
	Server settings live on the "server" group pages (admins only), everything of this computer on "client".
--]]

local Menu = bgNPC.Menu
local ICONS = 'background_npcs/vgui/menu/'
local SERVER_GROUP = '#bgn.menu.group.server'

-- Crowd density: one choice sets the NPC and ghost limits at once (type limits follow bgn_max_npc, sv_cvars.lua).
-- Single player only: it changes server and client settings together.
local DENSITY = {
	{ id = 'low', values = { bgn_max_npc = 15, bgn_ghost_crowd_max = 0, bgn_cl_ghost_crowd_max = 0 } },
	{ id = 'medium', values = { bgn_max_npc = 35, bgn_ghost_crowd_max = 40, bgn_cl_ghost_crowd_max = 40 } },
	{ id = 'high', values = { bgn_max_npc = 60, bgn_ghost_crowd_max = 80, bgn_cl_ghost_crowd_max = 80 } },
	{ id = 'ultra', values = { bgn_max_npc = 100, bgn_ghost_crowd_max = 150, bgn_cl_ghost_crowd_max = 150 } },
}

-- @return string the preset matching the current settings, '' when they were changed by hand
local function CurrentDensity()
	for _, preset in ipairs(DENSITY) do
		local match = true
		for name, value in pairs(preset.values) do
			local cv = GetConVar(name)
			if not cv or cv:GetInt() ~= value then match = false break end
		end
		if match then return preset.id end
	end
	return ''
end

concommand.Add('bgn_crowd_density', function(_, _, args)
	if not game.SinglePlayer() then return MsgN('[Background NPCs] bgn_crowd_density works in single player only') end
	for _, preset in ipairs(DENSITY) do
		if preset.id == args[1] then
			for name, value in pairs(preset.values) do RunConsoleCommand(name, tostring(value)) end
			return
		end
	end
	MsgN('[Background NPCs] bgn_crowd_density low | medium | high | ultra')
end)

Menu.AddPage('general', {
	group = SERVER_GROUP,
	title = '#bgn.menu.page.general',
	icon = ICONS .. 'general.png',
	order = 100,
	build = function(page)
		page:Section('#bgn.menu.section.main')
		page:Toggle('bgn_enable', '#bgn.settings.general.mod_enable')
		page:Toggle('bgn_debug', '#bgn.settings.general.debug')

		if game.SinglePlayer() then
			page:Section('#bgn.menu.section.crowd_density')
			local options = {}
			for i, preset in ipairs(DENSITY) do options[i] = { preset.id, '#bgn.menu.crowd_density.' .. preset.id } end
			page:Choice('bgn_crowd_density', '#bgn.menu.crowd_density', options, { get = CurrentDensity, server = false })
		end

		page:Section('#bgn.menu.section.modes')
		page:Toggle('bgn_peaceful_mode', '#bgn.settings.general.peaceful_mode')
		page:Toggle('bgn_friend_mode', '#bgn.settings.general.bgn_friend_mode')
		page:Toggle('bgn_agressive_mode', '#bgn.settings.general.bgn_agressive_mode')
		page:Toggle('bgn_ignore_another_npc', '#bgn.settings.general.ignore_another_npc')
		page:Toggle('bgn_team_damage', '#bgn.settings.general.team_damage')

		page:Section('#bgn.menu.section.doors')
		page:Toggle('bgn_npc_open_doors', '#bgn.settings.general.npc_open_doors')
		page:Toggle('bgn_npc_open_locked_doors', '#bgn.settings.general.npc_open_locked_doors')
	end,
})

Menu.AddPage('actors', {
	group = SERVER_GROUP,
	title = '#bgn.menu.page.actors',
	icon = ICONS .. 'actors.png',
	order = 200,
	build = function(page)
		page:Section('#bgn.menu.section.total')
		page:Slider('bgn_max_npc', '#bgn.settings.actor.total_max_npc', 0, 200)

		for actor_type, data in SortedPairs(bgNPC.cfg.actors) do
			if not data.hidden then
				page:Section(data.name or actor_type)
				local wanted = data.wanted_level and {
					badge = string.format(Menu.Phrase('bgn.menu.actor.wanted') or 'Wanted %d+', data.wanted_level),
					help = string.format(Menu.Phrase('bgn.menu.actor.wanted.help') or '', data.wanted_level),
				} or nil
				page:Toggle('bgn_npc_type_' .. actor_type, '#bgn.menu.actor.enabled', wanted)
				page:Slider('bgn_npc_type_max_' .. actor_type, '#bgn.menu.actor.max', 0, 200)
				if istable(data.weapons) and #data.weapons ~= 0 then
					page:Toggle('bgn_disable_weapon_' .. actor_type, '#bgn.menu.actor.no_weapons')
				end
				if DecentVehicleDestination and istable(data.vehicles) and #data.vehicles ~= 0 then
					page:Slider('bgn_npc_vehicle_max_' .. actor_type, '#bgn.menu.actor.max_vehicles', 0, 200)
				end
			end
		end
	end,
})

Menu.AddPage('spawn', {
	group = SERVER_GROUP,
	title = '#bgn.menu.page.spawn',
	icon = ICONS .. 'spawn.png',
	order = 300,
	build = function(page)
		page:Section('#bgn.menu.section.main')
		page:Slider('bgn_spawn_radius', '#bgn.settings.spawn.spawn_radius', 0, 5000)
		page:Slider('bgn_spawn_radius_visibility', '#bgn.settings.spawn.spawn_radius_visibility', 0, 5000)
		page:Slider('bgn_spawn_block_radius', '#bgn.settings.spawn.spawn_block_radius', 0, 5000)
		page:Slider('bgn_spawn_period', '#bgn.settings.spawn.spawn_period', 0, 50, { decimals = 1 })

		page:Section('#bgn.menu.section.teleport')
		page:Toggle('bgn_actors_teleporter', '#bgn.settings.spawn.actors_teleporter')
		page:Slider('bgn_actors_max_teleports', '#bgn.settings.spawn.actors_max_teleports', 1, 10)
		page:Toggle('bgn_fasted_teleport', '#bgn.settings.spawn.fasted_teleport')

		page:Section('#bgn.menu.section.experimental')
		page:Toggle('bgn_ghost_crowd', '#bgn.menu.ghost_crowd_server')
		page:Slider('bgn_ghost_crowd_max', '#bgn.menu.ghost_crowd_server_max', 0, 150)
	end,
})

Menu.AddPage('wanted', {
	group = SERVER_GROUP,
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
		page:Toggle('bgn_wanted_hud_text', '#bgn.settings.wanted.hud_text')
		page:Toggle('bgn_wanted_hud_stars', '#bgn.settings.wanted.hud_stars')

		page:Section('#bgn.menu.section.halo')
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
	group = SERVER_GROUP,
	title = '#bgn.menu.page.arrest',
	icon = ICONS .. 'arrest.png',
	order = 500,
	build = function(page)
		page:Toggle('bgn_arrest_mode', '#bgn.settings.arrest.arrest_mode')
		page:Slider('bgn_arrest_time', '#bgn.settings.arrest.arrest_time', 0, 100, { decimals = 1 })
		page:Slider('bgn_arrest_time_limit', '#bgn.settings.arrest.arrest_time_limit', 0, 100, { decimals = 1 })
		page:Slider('bgn_arrest_surrender_delay', '#bgn.settings.arrest.surrender_delay', 0, 120, { decimals = 1 })
		page:Slider('bgn_arrest_car_wait', '#bgn.settings.arrest.car_wait', 0, 60, { decimals = 1 })
		page:Slider('bgn_arrest_car_time', '#bgn.settings.arrest.car_time', 1, 60, { decimals = 1 })
	end,
})

Menu.AddPage('behavior', {
	group = SERVER_GROUP,
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
		page:Toggle('bgn_disable_dialogues', '#bgn.settings.extension.disable_dialogues')
		page:Toggle('bgn_module_replics_enable', '#bgn.settings.extension.replics_enable')
		page:Choice('bgn_module_replics_language', '#bgn.menu.replics_language', {
			{ 'auto', '#bgn.menu.auto' }, { 'english', 'English' }, { 'russian', 'Русский' },
		})
		page:Toggle('bgn_all_models_random', '#bgn.settings.extension.all_models_random')
		page:Toggle('bgn_drop_money', '#bgn.settings.extension.drop_money')

		page:Section('#bgn.menu.section.corpses')
		page:Toggle('bgn_corpse_cleanup', '#bgn.menu.corpse_cleanup')
		page:Slider('bgn_corpse_cleanup_time', '#bgn.menu.corpse_cleanup_time', 10, 600)

		page:Section('#bgn.menu.section.experimental')
		page:Toggle('bgn_module_custom_gestures', '#bgn.settings.extension.custom_gestures')
		page:Toggle('bgn_shot_sound_mode', '#bgn.settings.extension.shot_sound_mode')
	end,
})

Menu.AddPage('navigation', {
	group = SERVER_GROUP,
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
	group = SERVER_GROUP,
	title = '#bgn.menu.page.performance',
	icon = ICONS .. 'performance.png',
	order = 800,
	build = function(page)
		page:Slider('bgn_disable_logic_radius', '#bgn.settings.optimization.disable_logic', 0, 1000)
		page:Slider('bgn_lod_near_radius', '#bgn.menu.lod_near_radius', 0, 10000)
	end,
})

Menu.AddPage('addons', {
	group = SERVER_GROUP,
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
	group = '#bgn.menu.group.client',
	title = '#bgn.menu.page.client',
	icon = ICONS .. 'client.png',
	order = 1200,
	build = function(page)
		page:Section('#bgn.menu.section.graphics')
		page:Toggle('bgn_cl_field_view_optimization', '#bgn.settings.optimization.cl_field_view_optimization')
		page:Slider('bgn_cl_field_view_optimization_range', '#bgn.settings.optimization.cl_field_view_optimization_range', 0, 2000)
		page:Toggle('bgn_cl_ambient_sound', '#bgn.settings.client.cl_ambient_sound')
		page:Choice('bgn_cl_voices', '#bgn.settings.client.cl_voices', {
			{ 1, '#bgn.menu.voices.generated' }, { 2, '#bgn.menu.voices.classic' }, { 0, '#bgn.menu.voices.off' },
		})
		page:Choice('bgn_cl_voice_language', '#bgn.menu.voice_language', {
			{ 'auto', '#bgn.menu.auto' }, { 'english', 'English' }, { 'russian', 'Русский' },
		})

		page:Section('#bgn.menu.section.wanted')
		page:Toggle('bgn_cl_disable_hud_local', '#bgn.settings.wanted.cl_disable_hud_local')
		page:Toggle('bgn_cl_disable_halo', '#bgn.settings.wanted.cl_disable_halo')
		page:Toggle('bgn_cl_disable_self_halo_wanted', '#bgn.settings.wanted.cl_disable_self_halo_wanted')

		page:Section('#bgn.menu.section.experimental')
		-- the server runs the ghosts for everyone: this player's own ghost settings do nothing then
		local by_server = GetConVar('bgn_ghost_crowd'):GetBool() and { locked = true, badge = '#bgn.menu.by_server' } or nil
		page:Toggle('bgn_cl_ghost_crowd', '#bgn.menu.ghost_crowd', by_server)
		page:Slider('bgn_cl_ghost_crowd_max', '#bgn.menu.ghost_crowd_max', 0, 150, by_server)
		if by_server then page:Note('#bgn.menu.ghost_crowd.by_server', 'warn') end

		page:Section('#bgn.menu.section.menu')
		page:Choice('bgn_cl_ui_language', '#bgn.menu.ui_language', {
			{ 'auto', '#bgn.menu.auto' }, { 'english', 'English' }, { 'russian', 'Русский' },
		})
		page:Toggle('bgn_menu_dark', '#bgn.menu.dark')
		page:Toggle('bgn_menu_sounds', '#bgn.menu.sounds')

		page:Section('#bgn.menu.section.debug')
		page:Toggle('bgn_cl_draw_npc_path', '#bgn.menu.draw_npc_path')

		page:Section('#bgn.menu.section.about')
		page:Button('#bgn.settings.general.updateinfo', 'bgn_updateinfo', { text = '#bgn.menu.open_page' })
	end,
})

Menu.AddPage('tools', {
	group = SERVER_GROUP,
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
		page:Button('#bgn.settings.general.reset_cvars_to_factory_settings', 'bgn_reset_cvars_to_factory_settings', {
			admin = true, text = '#bgn.menu.reset', confirm = '#bgn.menu.confirm.reset', danger = true,
		})
	end,
})

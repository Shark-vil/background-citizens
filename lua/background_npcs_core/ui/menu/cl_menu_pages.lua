--[[
	Built-in pages of the settings window (cl_menu.lua). Texts: resource/localization/*/bgn_*.properties.
	Server settings live on the "server" group pages (admins only), everything of this computer on "client".
--]]
local Menu = bgNPC.Menu
local ICONS = 'background_npcs/vgui/menu/'
local SERVER_GROUP = '#bgn.menu.group.server'
-- Crowd density: one choice sets the NPC and ghost limits at once (type limits follow bgn_max_npc, sv_cvars.lua).
-- What it changes depends on the player: an admin sets the server limits and his own ghosts; a player who is
-- not an admin sets only his own ghosts, and only while the server does not run the ghost crowd (bgn_ghost_crowd 0).
local DENSITY = {
  {
    id = 'low',
    values = {
      bgn_max_npc = 25,
      bgn_ghost_crowd_max = 0,
      bgn_cl_ghost_crowd_max = 0
    }
  },
  {
    id = 'medium',
    values = {
      bgn_max_npc = 35,
      bgn_ghost_crowd_max = 40,
      bgn_cl_ghost_crowd_max = 40
    }
  },
  {
    id = 'high',
    values = {
      bgn_max_npc = 60,
      bgn_ghost_crowd_max = 80,
      bgn_cl_ghost_crowd_max = 80
    }
  },
  {
    id = 'ultra',
    values = {
      bgn_max_npc = 100,
      bgn_ghost_crowd_max = 150,
      bgn_cl_ghost_crowd_max = 150
    }
  },
}

local CLIENT_ONLY = {
  bgn_cl_ghost_crowd_max = true
}

-- @return string|nil 'all' (admin) | 'client' (own ghosts only) | nil (the server decides, nothing can be changed)
local function DensityScope()
  if Menu.IsAdmin() then return 'all' end
  local server_ghosts = GetConVar('bgn_ghost_crowd')
  if server_ghosts and not server_ghosts:GetBool() then return 'client' end
end

-- the values of a preset this player can change
local function DensityValues(preset)
  local scope = DensityScope()
  if scope == 'all' then return preset.values end
  if scope ~= 'client' then return {} end
  local values = {}
  for name, value in pairs(preset.values) do
    if CLIENT_ONLY[name] then values[name] = value end
  end
  return values
end

-- @return string the preset matching the current settings, '' when they were changed by hand
local function CurrentDensity()
  for _, preset in ipairs(DENSITY) do
    local match, any = true, false
    for name, value in pairs(DensityValues(preset)) do
      any = true
      local cv = GetConVar(name)
      if not cv or cv:GetInt() ~= value then
        match = false
        break
      end
    end

    if match and any then return preset.id end
  end
  return ''
end

Menu.DENSITY, Menu.CurrentDensity = DENSITY, CurrentDensity
concommand.Add('bgn_crowd_density', function(_, _, args)
  if not DensityScope() then return MsgN('[Background NPCs] bgn_crowd_density: the server controls the crowd') end
  for _, preset in ipairs(DENSITY) do
    if preset.id == args[1] then
      for name, value in pairs(DensityValues(preset)) do
        RunConsoleCommand(name, tostring(value))
      end
      return
    end
  end

  MsgN('[Background NPCs] bgn_crowd_density low | medium | high | ultra')
end)

-- The choice row (shared by the general page, the client page and the wizard); locked with the reason when
-- the server decides everything.
-- simple: the plain words of the wizard
function Menu.DensityChoice(page, simple)
  local options = {}
  for i, preset in ipairs(DENSITY) do
    options[i] = {preset.id, (simple and '#bgn.wizard.density.' or '#bgn.menu.crowd_density.') .. preset.id}
  end

  local locked = not DensityScope()
  page:Choice('bgn_crowd_density', simple and '#bgn.wizard.density.label' or '#bgn.menu.crowd_density', options, {
    get = CurrentDensity,
    server = false,
    locked = locked,
    badge = locked and '#bgn.menu.by_server' or nil,
  })

  if locked then page:Note('#bgn.menu.crowd_density.by_server', 'warn') end
end

local cvar_quick_hidden = CreateClientConVar('bgn_menu_quick_hidden', '0', true, false, 'Background NPCs menu: hide the quick settings block on the General page')

-- The quick settings block, tinted with the accent. The General page shows it until it is closed (closable), Tools always.
local function QuickSettings(page, closable)
  page:Custom(function(panel)
    local s = Menu.Scale()
    local pad, gap = math.Round(16 * s), math.Round(8 * s)
    local C = Menu.colors
    local first = Menu.Button(panel, Menu.Text('#bgn.menu.quick.wizard'), 'primary', function() RunConsoleCommand('bgn_wizard', 'all') end)
    local help = Menu.Text('#bgn.menu.quick.help')
    local close = closable and Menu.IconButton(panel, math.Round(28 * s), function() return ICONS .. 'close.png' end, Menu.Text('#bgn.menu.close'), function()
      Menu.Sound('click')
      RunConsoleCommand('bgn_menu_quick_hidden', '1')
      timer.Simple(0, function() Menu.ShowPage('general') end) -- after the cvar changed
    end)

    panel.PerformLayout = function(self, w)
      local lines = Menu.Wrap(help, 'BGN.Menu.Small', w - pad * 2)
      local h = pad + Menu.FontHeight('BGN.Menu.Section') + math.Round(4 * s) + #lines * Menu.FontHeight('BGN.Menu.Small') + math.Round(12 * s) + first:GetTall() + pad
      first:SetPos(pad, h - pad - first:GetTall())
      if close then close:SetPos(w - close:GetWide() - gap, gap) end
      if self:GetTall() ~= h then
        self:SetTall(h)
        Menu.ContentChanged()
      end
    end

    panel.Paint = function(_, w)
      local r = math.Round(8 * s)
      draw.RoundedBox(r, 0, 0, w, panel:GetTall(), Menu.Fade(C.accent, 0.55))
      draw.RoundedBox(r, 1, 1, w - 2, panel:GetTall() - 2, Menu.LerpColor(0.1, C.surface, C.accent))
      draw.SimpleText(Menu.Text('#bgn.menu.quick'), 'BGN.Menu.Section', pad, pad, C.text)
      local y = pad + Menu.FontHeight('BGN.Menu.Section') + math.Round(4 * s)
      for _, line in ipairs(Menu.Wrap(help, 'BGN.Menu.Small', w - pad * 2)) do
        draw.SimpleText(line, 'BGN.Menu.Small', pad, y, C.muted)
        y = y + Menu.FontHeight('BGN.Menu.Small')
      end
    end
  end)
end

Menu.AddPage('general', {
  group = SERVER_GROUP,
  title = '#bgn.menu.page.general',
  icon = ICONS .. 'general.png',
  order = 100,
  build = function(page)
    if not cvar_quick_hidden:GetBool() then QuickSettings(page, true) end

    page:Section('#bgn.menu.section.main')
    page:Toggle('bgn_enable', '#bgn.settings.general.mod_enable')
    page:Toggle('bgn_debug', '#bgn.settings.general.debug')
    page:Section('#bgn.menu.section.crowd_density')
    Menu.DensityChoice(page)
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
        if istable(bgNPC.Config.GetActor(actor_type).carry_items) then page:Toggle('bgn_carry_items_' .. actor_type, '#bgn.menu.actor.carry_items') end
        if istable(data.weapons) and #data.weapons ~= 0 then page:Toggle('bgn_disable_weapon_' .. actor_type, '#bgn.menu.actor.no_weapons') end
        if DecentVehicleDestination and istable(data.vehicles) and #data.vehicles ~= 0 then page:Slider('bgn_npc_vehicle_max_' .. actor_type, '#bgn.menu.actor.max_vehicles', 0, 200, {
          badge = 'Decent Vehicle',
          badge_color = 'accent'
        }) end
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
    page:Slider('bgn_spawn_period', '#bgn.settings.spawn.spawn_period', 0, 50, {
      decimals = 1
    })

    page:Section('#bgn.menu.section.teleport')
    page:Toggle('bgn_actors_teleporter', '#bgn.settings.spawn.actors_teleporter')
    page:Slider('bgn_actor_unseen_time', '#bgn.settings.spawn.actor_unseen_time', 0, 600)
    page:Slider('bgn_actors_max_teleports', '#bgn.settings.spawn.actors_max_teleports', 1, 10)
    page:Toggle('bgn_fasted_teleport', '#bgn.settings.spawn.fasted_teleport')
    page:Section('#bgn.menu.section.experimental')
    page:Toggle('bgn_ghost_crowd', '#bgn.menu.ghost_crowd_server')
    page:Slider('bgn_ghost_crowd_max', '#bgn.menu.ghost_crowd_server_max', 0, 150)
  end,
})

Menu.AddPage('behavior', {
  group = SERVER_GROUP,
  title = '#bgn.menu.page.behavior',
  icon = ICONS .. 'behavior.png',
  order = 500,
  build = function(page)
    page:Section('#bgn.menu.section.ai')
    page:Choice('bgn_brain', '#bgn.menu.brain', {{'auto', '#bgn.menu.auto'}, {'fsm', 'FSM'}, {'goap', 'GOAP'},})
    page:Choice('bgn_actor_body', '#bgn.menu.body', {{'npc', 'NPC'}, {'nextbot', 'NextBot'},})
    page:Toggle('bgn_module_tactical_groups', '#bgn.settings.extension.tactical_groups')
    page:Toggle('bgn_pick_up_weapons', '#bgn.menu.pick_up_weapons')
    page:Toggle('bgn_nextbot_jump', '#bgn.menu.nextbot_jump')
    page:Slider('bgn_enemy_share_period', '#bgn.menu.enemy_share_period', 0, 10)
    page:Slider('bgn_fight_cooldown', '#bgn.menu.fight_cooldown', 0, 120)
    page:Section('#bgn.menu.section.main')
    page:Toggle('bgn_disable_dialogues', '#bgn.settings.extension.disable_dialogues')
    page:Toggle('bgn_module_replics_enable', '#bgn.settings.extension.replics_enable')
    page:Choice('bgn_module_replics_language', '#bgn.menu.replics_language', {{'auto', '#bgn.menu.auto'}, {'english', 'English'}, {'russian', 'Русский'},})
    page:Toggle('bgn_all_models_random', '#bgn.settings.extension.all_models_random')
    page:Toggle('bgn_drop_money', '#bgn.settings.extension.drop_money')
    page:Section('#bgn.menu.section.corpses')
    page:Toggle('bgn_corpse_cleanup', '#bgn.menu.corpse_cleanup')
    page:Slider('bgn_corpse_cleanup_time', '#bgn.menu.corpse_cleanup_time', 10, 600)
    page:Section('#bgn.menu.section.medics')
    page:Slider('bgn_medic_danger_time', '#bgn.menu.medic_danger_time', 0, 600)
    page:Slider('bgn_medic_danger_radius', '#bgn.menu.medic_danger_radius', 0, 5000)
    page:Slider('bgn_medic_hopeless_chance', '#bgn.menu.medic_hopeless_chance', 0, 100)
    page:Section('#bgn.menu.section.experimental')
    page:Toggle('bgn_module_custom_gestures', '#bgn.settings.extension.custom_gestures')
    page:Toggle('bgn_shot_sound_mode', '#bgn.settings.extension.shot_sound_mode')
  end,
})

Menu.AddPage('navigation', {
  group = SERVER_GROUP,
  title = '#bgn.menu.page.navigation',
  icon = ICONS .. 'navigation.png',
  order = 400,
  build = function(page)
    page:Section('#bgn.menu.section.main')
    page:Choice('bgn_nav_provider', '#bgn.menu.nav_provider', {{'auto', '#bgn.menu.auto'}, {'navmesh', 'Navmesh'}, {'nodegraph', 'Nodegraph'}, {'custom', '#bgn.menu.nav_custom'},})
    page:Slider('bgn_point_z_limit', '#bgn.menu.point_z_limit', 0, 500)
    page:Section('#bgn.menu.section.generation')
    page:Toggle('bgn_dynamic_nodes', '#bgn.settings.generation.dynamic_nodes')
    page:Toggle('bgn_dynamic_nodes_save_progress', '#bgn.settings.generation.dynamic_nodes_save_progress')
    page:Slider('bgn_runtime_generator_grid_offset', '#bgn.settings.generation.runtime_generator_grid_offset', 50, 500)
    page:Slider('bgn_dynamic_nodes_radius', '#bgn.settings.generation.dynamic_nodes_radius', 0, 2000)
    page:Slider('bgn_nav_generator_max_nodes', '#bgn.menu.nav_max_nodes', 1000, 50000, {
      limit = 200000
    })
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
    page:Slider('bgn_logic_pause', '#bgn.menu.logic_pause', 0, 30, {
      decimals = 2
    })

    page:Slider('bgn_logic_active', '#bgn.menu.logic_active', 0.1, 30, {
      decimals = 2
    })

    page:Slider('bgn_logic_stagger', '#bgn.menu.logic_stagger', 0, 10, {
      decimals = 2
    })
  end,
})

-- Modules: a switch per module; the gear opens the module's own settings page (hidden from the sidebar, but searchable).
-- server / client: function(page) with the settings of that side; has_server: function() false when there is nothing to show.
local MODULES = {
  {
    id = 'wanted',
    title = '#bgn.menu.page.wanted',
    cvar = 'bgn_enable_wanted_mode',
    label = '#bgn.menu.page.wanted',
    help = '#bgn.settings.wanted.enable_wanted_mode.help',
    icon = 'wanted.png',
    server = function(page)
      page:Slider('bgn_wanted_detection_radius', '#bgn.settings.wanted.detection_radius', 0, 5000)
      page:Toggle('bgn_wanted_level', '#bgn.settings.wanted.level')
      page:Slider('bgn_wanted_level_up_period', '#bgn.settings.wanted.level_up_period', 0, 600)
      page:Toggle('bgn_wanted_police_instantly', '#bgn.settings.wanted.police_instantly')
      page:Slider('bgn_wanted_time', '#bgn.settings.wanted.time', 0, 300)
      page:Slider('bgn_wanted_impunity_limit', '#bgn.settings.wanted.impunity_limit', 0, 50)
      page:Slider('bgn_wanted_impunity_reduction_period', '#bgn.settings.wanted.impunity_reduction_period', 0, 300)
      page:Toggle('bgn_wanted_hud_text', '#bgn.settings.wanted.hud_text')
      page:Toggle('bgn_wanted_hud_stars', '#bgn.settings.wanted.hud_stars')
      page:Toggle('bgn_disable_halo_calling', '#bgn.settings.wanted.disable_halo_calling')
      page:Toggle('bgn_disable_halo_wanted', '#bgn.settings.wanted.disable_halo_wanted')
      for _, name in ipairs({'calling_police_text', 'calling_police_halo', 'wanted_halo'}) do
        local prefix = 'bgn_wanted_color_' .. name
        page:Color('#bgn.settings.wanted.' .. name .. '_color', {prefix .. '_r', prefix .. '_g', prefix .. '_b'})
      end
    end,
    client = function(page)
      page:Toggle('bgn_cl_disable_hud_local', '#bgn.settings.wanted.cl_disable_hud_local')
      page:Toggle('bgn_cl_disable_halo', '#bgn.settings.wanted.cl_disable_halo')
      page:Toggle('bgn_cl_disable_self_halo_wanted', '#bgn.settings.wanted.cl_disable_self_halo_wanted')
    end,
  },
  {
    id = 'arrest',
    title = '#bgn.menu.page.arrest',
    cvar = 'bgn_arrest_mode',
    label = '#bgn.menu.page.arrest',
    help = '#bgn.settings.arrest.arrest_mode.help',
    icon = 'arrest.png',
    server = function(page)
      page:Slider('bgn_arrest_time', '#bgn.settings.arrest.arrest_time', 0, 100, {
        decimals = 1
      })

      page:Slider('bgn_arrest_time_limit', '#bgn.settings.arrest.arrest_time_limit', 0, 100, {
        decimals = 1
      })

      page:Slider('bgn_arrest_surrender_delay', '#bgn.settings.arrest.surrender_delay', 0, 120, {
        decimals = 1
      })

      page:Slider('bgn_arrest_car_wait', '#bgn.settings.arrest.car_wait', 0, 60, {
        decimals = 1
      })

      page:Slider('bgn_arrest_car_time', '#bgn.settings.arrest.car_time', 1, 60, {
        decimals = 1
      })

      page:Slider('bgn_police_car_kill_time', '#bgn.settings.arrest.car_kill_time', 0, 300)
    end,
  },
  {
    id = 'scenic',
    title = '#bgn.menu.section.scenic',
    cvar = 'bgn_scenic',
    label = '#bgn.menu.scenic',
    icon = 'scenic.png',
    server = function(page)
      page:Slider('bgn_scenic_max', '#bgn.menu.scenic_max', 0, 20)
      page:Slider('bgn_scenic_period', '#bgn.menu.scenic_period', 5, 300)
      for id, scene in SortedPairs(bgNPC.cfg.scenic) do
        if (scene.weight or 10) > 0 then
          page:Toggle('bgn_scenic_' .. id, bgNPC.Util.Lang(scene.name or {
            default = id
          }))
        end
      end
    end,
  },
  {
    id = 'dv',
    title = '#bgn.settings.addon.decent_vehicle',
    cvar = 'bgn_enable_dv_support',
    label = '#bgn.settings.addon.decent_vehicle',
    icon = 'vehicle.png',
    has_server = function() return istable(DecentVehicleDestination) end,
    server = function(page) page:Slider('bgn_vehicle_spawn_visibility_radius', '#bgn.settings.spawn.vehicle_spawn_visibility_radius', 0, 5000) end,
  },
  {
    cvar = 'bgn_enable_police_system_support',
    label = '#bgn.settings.addon.police_system',
    icon = 'siren.png'
  },
  {
    cvar = 'bgn_module_stormfox2',
    label = '#bgn.settings.addon.stormfox2',
    icon = 'weather.png'
  },
  {
    cvar = 'bgn_module_followers_mod_addon',
    label = '#bgn.settings.addon.followers_mod_addon',
    icon = 'follow.png'
  },
  {
    cvar = 'bgn_module_n2money',
    label = '#bgn.settings.addon.n2money',
    icon = 'coin.png'
  },
  {
    cvar = 'bgn_module_bio_annihilation_two_replacement',
    label = '#bgn.settings.addon.bio_annihilation_two_replacement',
    icon = 'skull.png'
  },
  {
    cvar = 'bgn_module_arccw_weapon_replacement',
    label = '#bgn.settings.addon.arccw_weapon_replacement',
    icon = 'weapon.png'
  },
  {
    cvar = 'bgn_module_arc9_weapon_replacement',
    label = '#bgn.settings.addon.arc9_weapon_replacement',
    icon = 'weapon.png'
  },
  {
    cvar = 'bgn_module_tfa_weapon_replacement',
    label = '#bgn.settings.addon.tfa_weapon_replacement',
    icon = 'weapon.png'
  },
}

local function HasServerSettings(module)
  return module.server and (not module.has_server or module.has_server())
end

-- the gear is shown when the player has something on the module page: server rows for an admin, client rows for everybody
local function HasSettings(module)
  return module.client or (HasServerSettings(module) and Menu.IsAdmin())
end

for _, module in ipairs(MODULES) do
  if module.id then
    Menu.AddPage('module_' .. module.id, {
      hidden = true,
      parent = 'modules',
      title = module.title,
      order = 901,
      build = function(page)
        if not page.filter then -- not a search result
          page:Button('#bgn.menu.page.modules', function() Menu.ShowPage('modules') end, {
            text = '#bgn.menu.back'
          })
        end

        if HasServerSettings(module) then
          page:Section(SERVER_GROUP)
          module.server(page)
        end

        if module.client then
          page:Section('#bgn.menu.group.client')
          module.client(page)
        end
      end,
    })
  end
end

Menu.AddPage('modules', {
  group = SERVER_GROUP,
  title = '#bgn.menu.page.modules',
  icon = ICONS .. 'addons.png',
  order = 900,
  build = function(page)
    for _, module in ipairs(MODULES) do
      -- the switch is visible to everybody: a player who is not an admin sees it locked
      local row = page:Toggle(module.cvar, module.label, {
        server = false,
        locked = not Menu.IsAdmin(),
        help = module.help
      })

      row.icon = ICONS .. module.icon

      if module.id and HasSettings(module) then
        -- the gear is a sibling of the switch (the switch stays the row's control: the whole row toggles, as on other pages)
        local s = Menu.Scale()
        local size, gap = math.Round(32 * s), math.Round(12 * s)
        local gear = Menu.IconButton(row, size, function() return ICONS .. 'general.png' end, Menu.Text('#bgn.menu.module_settings'), function()
          Menu.Sound('click')
          Menu.ShowPage('module_' .. module.id)
        end)

        row.reserve = size + gap
        local layout = row.PerformLayout
        row.PerformLayout = function(panel, w, h)
          layout(panel, w, h)
          local lock = panel.locked and math.Round(24 * s) or 0 -- the lock icon sits left of the switch
          gear:SetPos(panel.control.x - lock - gap - size, math.Round((panel:GetTall() - size) / 2))
        end
      end
    end
  end,
})

Menu.AddPage('client', {
  group = '#bgn.menu.group.client',
  title = '#bgn.menu.page.client',
  icon = ICONS .. 'client.png',
  order = 1200,
  build = function(page)
    if not Menu.IsAdmin() then -- an admin has it on the general page
      page:Section('#bgn.menu.section.crowd_density')
      Menu.DensityChoice(page)
    end

    page:Section('#bgn.menu.section.graphics')
    page:Toggle('bgn_cl_field_view_optimization', '#bgn.settings.optimization.cl_field_view_optimization')
    page:Slider('bgn_cl_field_view_optimization_range', '#bgn.settings.optimization.cl_field_view_optimization_range', 0, 2000)
    page:Toggle('bgn_cl_ambient_sound', '#bgn.settings.client.cl_ambient_sound')
    page:Toggle('bgn_cl_voices', '#bgn.settings.client.cl_voices')
    page:Choice('bgn_cl_voice_language', '#bgn.menu.voice_language', {{'auto', '#bgn.menu.auto'}, {'english', 'English'}, {'russian', 'Русский'},})
    page:Section('#bgn.menu.section.experimental')
    -- the server runs the ghosts for everyone: this player's own ghost settings do nothing then
    local by_server = GetConVar('bgn_ghost_crowd'):GetBool() and {
      locked = true,
      badge = '#bgn.menu.by_server'
    } or nil

    page:Toggle('bgn_cl_ghost_crowd', '#bgn.menu.ghost_crowd', by_server)
    page:Slider('bgn_cl_ghost_crowd_max', '#bgn.menu.ghost_crowd_max', 0, 150, by_server)
    if by_server then page:Note('#bgn.menu.ghost_crowd.by_server', 'warn') end
    page:Section('#bgn.menu.section.menu')
    page:Choice('bgn_cl_ui_language', '#bgn.menu.ui_language', {{'auto', '#bgn.menu.auto'}, {'english', 'English'}, {'russian', 'Русский'},})
    page:Slider('bgn_cl_ui_scale', '#bgn.menu.ui_scale', 0.75, 2, {
      decimals = 2
    })

    page:Toggle('bgn_menu_dark', '#bgn.menu.dark')
    page:Toggle('bgn_menu_sounds', '#bgn.menu.sounds')
    page:Section('#bgn.menu.section.debug')
    page:Toggle('bgn_cl_draw_npc_path', '#bgn.menu.draw_npc_path')
    page:Section('#bgn.menu.section.about')
    page:Button('#bgn.wizard.title', 'bgn_wizard', {
      text = '#bgn.menu.open_page'
    })

    page:Button('#bgn.settings.general.updateinfo', 'bgn_updateinfo', {
      text = '#bgn.menu.open_page'
    })
  end,
})

Menu.AddPage('tools', {
  group = SERVER_GROUP,
  title = '#bgn.menu.page.tools',
  icon = ICONS .. 'tools.png',
  order = 1100,
  build = function(page)
    QuickSettings(page)
    page:Section('#bgn.menu.section.mesh')
    page:Button('#bgn.settings.general.cl_citizens_load_route', 'cl_citizens_load_route', {
      admin = true,
      text = '#bgn.menu.load',
    })

    page:Button('#bgn.settings.general.clear_nodes', 'cl_citizens_clear_route', {
      admin = true,
      text = '#bgn.menu.clear',
      confirm = '#bgn.menu.confirm.clear',
    })

    page:Button('#bgn.settings.general.remove_routes', 'cl_citizens_remove_route yes', {
      admin = true,
      text = '#bgn.menu.delete',
      confirm = '#bgn.menu.confirm.remove',
      danger = true,
    })

    page:Button('#bgn.settings.workshop.save_to_script', 'bgn_compile', {
      admin = true,
      text = '#bgn.menu.save'
    })

    page:Section('#bgn.menu.section.maintenance')
    page:Button('#bgn.settings.general.reset_cvars_to_factory_settings', 'bgn_reset_cvars_to_factory_settings', {
      admin = true,
      text = '#bgn.menu.reset',
      confirm = '#bgn.menu.confirm.reset',
      danger = true,
    })

    -- the test runs from debug/cl_diag.lua; the checks of rights and settings are open to everyone
    page:Section('#bgn.diag.section', nil, true)
    page:Button('#bgn.diag.run', 'bgn_test', {
      admin = true,
      text = '#bgn.menu.run'
    })

    page:Button('#bgn.diag.run_settings', 'bgn_test_settings', {
      text = '#bgn.menu.run'
    })

    page:Button('#bgn.diag.report', 'bgn_test_report', {
      text = '#bgn.menu.open_page'
    })

    page:Slider('bgn_test_server_value', '#bgn.diag.cvar_server', 0, 100)
    page:Slider('bgn_cl_test_value', '#bgn.diag.cvar_client', 0, 100, {
      server = false
    })

    page:Note('#bgn.diag.note')
  end,
})

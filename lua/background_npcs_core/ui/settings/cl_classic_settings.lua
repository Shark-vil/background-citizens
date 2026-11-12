--[[
	Spawn menu -> Options -> Background NPCs: the pages of the old versions ("for those who are used to it").
	Everything is generated from the PAGES table; text comes from resource/localization (en / ru, bgn_*.properties).
	An item is { kind, cvar_or_command, phrase_key, ... }. An item whose cvar / command no longer exists is skipped,
	so the table can only be ahead of the code, never break the menu.

		check  { 'check',  cvar, key }
		slider { 'slider', cvar, key, min, max, decimals }
		button { 'button', command, key, argument }   -- key .. '.help' is shown under it when it exists
		actors { 'actors' }                           -- per NPC type: enabled / how many / no weapons
	Pages with admin = true hold the server settings: others only see a note.
--]]
local PAGES = {
  {
    id = 'General',
    title = 'bgn.settings.general',
    admin = true,
    items = {{'check', 'bgn_enable', 'bgn.settings.general.mod_enable'}, {'check', 'bgn_peaceful_mode', 'bgn.settings.general.peaceful_mode'}, {'check', 'bgn_friend_mode', 'bgn.settings.general.bgn_friend_mode'}, {'check', 'bgn_agressive_mode', 'bgn.settings.general.bgn_agressive_mode'}, {'check', 'bgn_ignore_another_npc', 'bgn.settings.general.ignore_another_npc'}, {'check', 'bgn_debug', 'bgn.settings.general.debug'}, {'button', 'cl_citizens_load_route', 'bgn.settings.general.cl_citizens_load_route'}, {'button', 'cl_citizens_clear_route', 'bgn.settings.general.clear_nodes'}, {'button', 'cl_citizens_remove_route', 'bgn.settings.general.remove_routes', 'yes'}, {'button', 'bgn_updateinfo', 'bgn.settings.general.updateinfo'}, {'button', 'bgn_reset_cvars_to_factory_settings', 'bgn.settings.general.reset_cvars_to_factory_settings'},}
  },
  {
    id = 'Active_NPC_Groups',
    title = 'bgn.settings.actor',
    admin = true,
    items = {{'slider', 'bgn_max_npc', 'bgn.settings.actor.total_max_npc', 0, 200}, {'actors'},}
  },
  {
    id = 'Spawn',
    title = 'bgn.settings.spawn',
    admin = true,
    items = {{'slider', 'bgn_spawn_radius', 'bgn.settings.spawn.spawn_radius', 0, 5000}, {'slider', 'bgn_spawn_radius_visibility', 'bgn.settings.spawn.spawn_radius_visibility', 0, 5000}, {'slider', 'bgn_vehicle_spawn_visibility_radius', 'bgn.settings.spawn.vehicle_spawn_visibility_radius', 0, 5000}, {'slider', 'bgn_spawn_block_radius', 'bgn.settings.spawn.spawn_block_radius', 0, 5000}, {'slider', 'bgn_spawn_period', 'bgn.settings.spawn.spawn_period', 0, 50, 1}, {'check', 'bgn_fasted_teleport', 'bgn.settings.spawn.fasted_teleport'}, {'slider', 'bgn_actor_unseen_time', 'bgn.settings.spawn.actor_unseen_time', 0, 600}, {'scenes'},}
  },
  {
    id = 'Wanted',
    title = 'bgn.settings.wanted',
    admin = true,
    items = {{'check', 'bgn_enable_wanted_mode', 'bgn.settings.wanted.enable_wanted_mode'}, {'slider', 'bgn_wanted_detection_radius', 'bgn.settings.wanted.detection_radius', 0, 5000}, {'check', 'bgn_wanted_level', 'bgn.settings.wanted.level'}, {'slider', 'bgn_wanted_level_up_period', 'bgn.settings.wanted.level_up_period', 0, 600, 1}, {'check', 'bgn_wanted_police_instantly', 'bgn.settings.wanted.police_instantly'}, {'slider', 'bgn_wanted_time', 'bgn.settings.wanted.time', 0, 600, 1}, {'slider', 'bgn_wanted_impunity_limit', 'bgn.settings.wanted.impunity_limit', 0, 100}, {'slider', 'bgn_wanted_impunity_reduction_period', 'bgn.settings.wanted.impunity_reduction_period', 0, 600, 1}, {'check', 'bgn_wanted_hud_text', 'bgn.settings.wanted.hud_text'}, {'check', 'bgn_wanted_hud_stars', 'bgn.settings.wanted.hud_stars'}, {'check', 'bgn_disable_halo_calling', 'bgn.settings.wanted.disable_halo_calling'}, {'check', 'bgn_disable_halo_wanted', 'bgn.settings.wanted.disable_halo_wanted'}, {'check', 'bgn_cl_disable_hud_local', 'bgn.settings.wanted.cl_disable_hud_local'}, {'check', 'bgn_cl_disable_halo', 'bgn.settings.wanted.cl_disable_halo'}, {'check', 'bgn_cl_disable_self_halo_wanted', 'bgn.settings.wanted.cl_disable_self_halo_wanted'},}
  },
  {
    id = 'Arrest',
    title = 'bgn.settings.arrest',
    admin = true,
    items = {{'check', 'bgn_arrest_mode', 'bgn.settings.arrest.arrest_mode'}, {'slider', 'bgn_arrest_time', 'bgn.settings.arrest.arrest_time', 0, 100, 1}, {'slider', 'bgn_arrest_time_limit', 'bgn.settings.arrest.arrest_time_limit', 0, 100, 1},}
  },
  {
    id = 'States',
    title = 'bgn.settings.extension',
    admin = true,
    items = {{'check', 'bgn_drop_money', 'bgn.settings.extension.drop_money'}, {'check', 'bgn_shot_sound_mode', 'bgn.settings.extension.shot_sound_mode'}, {'check', 'bgn_disable_dialogues', 'bgn.settings.extension.disable_dialogues'}, {'check', 'bgn_module_replics_enable', 'bgn.settings.extension.replics_enable'}, {'check', 'bgn_all_models_random', 'bgn.settings.extension.all_models_random'}, {'check', 'bgn_module_custom_gestures', 'bgn.settings.extension.custom_gestures'}, {'check', 'bgn_module_tactical_groups', 'bgn.settings.extension.tactical_groups'},}
  },
  {
    id = 'Optimization',
    title = 'bgn.settings.optimization',
    items = {{'check', 'bgn_cl_field_view_optimization', 'bgn.settings.optimization.cl_field_view_optimization'}, {'slider', 'bgn_cl_field_view_optimization_range', 'bgn.settings.optimization.cl_field_view_optimization_range', 0, 2000}, {'slider', 'bgn_disable_logic_radius', 'bgn.settings.optimization.disable_logic', 0, 1000}, {'slider', 'bgn_logic_pause', 'bgn.menu.logic_pause', 0, 30, 2}, {'slider', 'bgn_logic_active', 'bgn.menu.logic_active', 0.1, 30, 2}, {'slider', 'bgn_logic_stagger', 'bgn.menu.logic_stagger', 0, 10, 2}, {'check', 'bgn_actors_teleporter', 'bgn.settings.spawn.actors_teleporter'}, {'slider', 'bgn_actors_max_teleports', 'bgn.settings.spawn.actors_max_teleports', 1, 10},}
  },
  {
    id = 'Addons',
    title = 'bgn.settings.addon',
    admin = true,
    items = {{'check', 'bgn_module_stormfox2', 'bgn.settings.addon.stormfox2'}, {'check', 'bgn_enable_dv_support', 'bgn.settings.addon.decent_vehicle'}, {'check', 'bgn_enable_police_system_support', 'bgn.settings.addon.police_system'}, {'check', 'bgn_module_bio_annihilation_two_replacement', 'bgn.settings.addon.bio_annihilation_two_replacement'}, {'check', 'bgn_module_arccw_weapon_replacement', 'bgn.settings.addon.arccw_weapon_replacement'}, {'check', 'bgn_module_arc9_weapon_replacement', 'bgn.settings.addon.arc9_weapon_replacement'}, {'check', 'bgn_module_tfa_weapon_replacement', 'bgn.settings.addon.tfa_weapon_replacement'}, {'check', 'bgn_module_followers_mod_addon', 'bgn.settings.addon.followers_mod_addon'}, {'check', 'bgn_module_n2money', 'bgn.settings.addon.n2money'},}
  },
  {
    id = 'Client',
    title = 'bgn.settings.client',
    items = {{'check', 'bgn_cl_ambient_sound', 'bgn.settings.client.cl_ambient_sound'},}
  },
  {
    id = 'Workshop',
    title = 'bgn.settings.workshop',
    admin = true,
    items = {{'button', 'bgn_compile', 'bgn.settings.workshop.save_to_script'}, {'button', 'bgn_save_map', 'bgn.settings.workshop.save_to_duplicate'},}
  },
}

-- the mod's own language (bgn_cl_ui_language) first, then the game's
local function Text(key)
  return bgNPC.Phrases and bgNPC.Phrases[key] or language.GetPhrase(key)
end

local function IsAdmin()
  local ply = LocalPlayer()
  return IsValid(ply) and (ply:IsAdmin() or ply:IsSuperAdmin())
end

local function Help(panel, key)
  local help = Text(key .. '.help')
  if help ~= key .. '.help' then panel:ControlHelp(help) end
end

local ITEMS = {}
function ITEMS.check(panel, cvar, key)
  if not GetConVar(cvar) then return end
  panel:CheckBox(Text(key), cvar)
  Help(panel, key)
end

function ITEMS.slider(panel, cvar, key, min, max, decimals)
  if cvar == 'bgn_vehicle_spawn_visibility_radius' and not istable(DecentVehicleDestination) then return end
  if not GetConVar(cvar) then return end
  panel:NumSlider(Text(key), cvar, min, max, decimals or 0)
  Help(panel, key)
end

function ITEMS.button(panel, command, key, argument)
  if not concommand.GetTable()[command] then return end
  panel:Button(Text(key), command, argument)
  Help(panel, key)
end

function ITEMS.actors(panel)
  for actor_type, data in SortedPairs(bgNPC.cfg.actors) do
    if not data.hidden then
      panel:Help(Text(data.name or actor_type))
      ITEMS.check(panel, 'bgn_npc_type_' .. actor_type, 'bgn.menu.actor.enabled')
      ITEMS.slider(panel, 'bgn_npc_type_max_' .. actor_type, 'bgn.menu.actor.max', 0, 200)
      if istable(bgNPC.Config.GetActor(actor_type).carry_items) then ITEMS.check(panel, 'bgn_carry_items_' .. actor_type, 'bgn.menu.actor.carry_items') end
      if istable(data.weapons) and #data.weapons ~= 0 then ITEMS.check(panel, 'bgn_disable_weapon_' .. actor_type, 'bgn.menu.actor.no_weapons') end
    end
  end
end

function ITEMS.scenes(panel)
  ITEMS.check(panel, 'bgn_scenic', 'bgn.menu.scenic')
  for id, scene in SortedPairs(bgNPC.cfg.scenic) do
    if (scene.weight or 10) > 0 then
      panel:CheckBox(bgNPC.Util.Lang(scene.name or {
        default = id
      }), 'bgn_scenic_' .. id)
    end
  end
end

-- The highlighted button lives on its own settings page.
local BUTTON_COLOR, BUTTON_HOVER = Color(46, 125, 214), Color(70, 150, 235)
local function OpenNewMenuButton(panel)
  local button = panel:Button(Text('bgn.menu.open_new'), 'bgn_menu')
  button:SetTall(34)
  button:SetTextColor(color_white)
  button.Paint = function(self, w, h) draw.RoundedBox(6, 0, 0, w, h, self:IsHovered() and BUTTON_HOVER or BUTTON_COLOR) end
end

hook.Add('PopulateToolMenu', 'BGN_TOOL_CreateMenu_Classic', function()
  -- '#' sorts first in the list, so this page stays on top
  spawnmenu.AddToolMenuOption('Options', 'Background NPCs', 'BGN_Settings', '#bgn.menu.new_menu', '', '', function(panel)
    panel:ClearControls()
    OpenNewMenuButton(panel)
    panel:Help(Text('bgn.menu.open.help'))
  end)

  for _, page in ipairs(PAGES) do
    spawnmenu.AddToolMenuOption('Options', 'Background NPCs', 'BGN_' .. page.id, Text(page.title), '', '', function(panel)
      panel:ClearControls()
      if page.admin and not IsAdmin() then
        panel:Help(Text('bgn.menu.admin_only'))
        return
      end

      for _, item in ipairs(page.items) do
        ITEMS[item[1]](panel, unpack(item, 2))
      end
    end)
  end
end)

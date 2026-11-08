--[[
	Background NPCs entry point (included from lua/autorun/background_npcs.lua).
	Docs: https://shark-vil.github.io/background-citizens

	Layout:
		core/      class system, scheduler, net, cvars, commands, utils (no external libraries)
		config/    actor configs and settings (user editable)
		api/       public namespaces (bgNPC.Actors, bgNPC.Points, ...); api/compat: OUTDATED bgNPC:Method() aliases, loaded last
		actor/     Actor class, body adapters, update loop, events, sync
		nav/       navigation providers, node graph, generator, route files
		brain/     FSM and GOAP brains
		systems/   own gameplay features (wanted, arrest, dialogue, modes, ...)
		spawner/   actor and vehicle spawners/removers
		modules/   integrations with other addons
		ui/        client menus and settings panels
		debug/     debug rendering
--]]

file.CreateDir('background_npcs')
file.CreateDir('background_npcs/nodes')
file.CreateDir('background_npcs/graph')
file.CreateDir('background_npcs/seats')
file.CreateDir('background_npcs/compile')

if SERVER then
	resource.AddWorkshop(2341497926)
end

bgNPC = bgNPC or {}
bgNPC.VERSION = '2.1.1'

-- Shared storage, filled by the API ----
bgNPC.LANGUAGES = bgNPC.LANGUAGES or {}
bgNPC.cfg = bgNPC.cfg or {}
bgNPC.respawn_actors_delay = bgNPC.respawn_actors_delay or {}
bgNPC.DVCars = bgNPC.DVCars or {}
bgNPC.SpawnArea = bgNPC.SpawnArea or {}
bgNPC.SpawnMenu = bgNPC.SpawnMenu or {}
bgNPC.SpawnMenu.Creator = bgNPC.SpawnMenu.Creator or { ['NPC'] = {}, ['Default'] = {} }
-- --------------------------------------

local ROOT = 'background_npcs_core'

-- Directories whose files are included by another script, never automatically.
local MANUAL_DIRS = {
	[ROOT .. '/config/replics/language'] = true,
	[ROOT .. '/ui/settings/lang/en'] = true,
	[ROOT .. '/ui/settings/lang/ru'] = true,
}

local included = {}

-- Includes a file by its realm prefix: sh_ (both), sv_ (server), cl_ (client).
-- send_only: only AddCSLuaFile, the file is included by another script.
local function Include(path, send_only)
	path = ROOT .. '/' .. path
	if included[path] then return end
	included[path] = true

	local prefix = string.match(path, '([^/]+)$'):sub(1, 3)

	if prefix == 'sv_' then
		if SERVER and not send_only then include(path) end
		return
	end

	if prefix ~= 'sh_' and prefix ~= 'cl_' then
		ErrorNoHalt('[Background NPCs] File without realm prefix is skipped: ' .. path .. '\n')
		return
	end

	if SERVER then AddCSLuaFile(path) end
	if send_only then return end
	if prefix == 'sh_' or CLIENT then include(path) end
end

-- Includes every file of a directory: sh_ first, then sv_, then cl_, then subdirectories.
-- Files that were already included explicitly are skipped.
local function IncludeDir(dir)
	local full_dir = ROOT .. '/' .. dir
	if MANUAL_DIRS[full_dir] then return end

	local files, directories = file.Find(full_dir .. '/*', 'LUA')
	table.sort(files)
	table.sort(directories)

	for _, prefix in ipairs({ 'sh_', 'sv_', 'cl_' }) do
		for _, name in ipairs(files) do
			if name:sub(1, 3) == prefix then Include(dir .. '/' .. name) end
		end
	end

	for _, sub_dir in ipairs(directories) do IncludeDir(dir .. '/' .. sub_dir) end
end

local function ExecutableScripts()
	included = {}

	-- Core layer (order matters)
	Include('core/sh_notice.lua') -- first and standalone: the setting notices must work whatever fails later
	Include('core/sh_class.lua')
	Include('core/sh_net.lua')
	Include('core/sh_util.lua')
	Include('core/sh_tasks.lua')
	IncludeDir('core')

	-- Configs (order matters, custom configs may override the defaults)
	Include('config/sh_main.lua')
	Include('config/sh_config.lua')
	IncludeDir('config/actors')
	Include('config/replics/sh_init.lua')
	Include('config/sh_names.lua')
	Include('config/sh_shot_sound.lua')
	Include('config/sh_player.lua')
	Include('config/sh_ambient.lua')
	IncludeDir('config/gamemodes')
	IncludeDir('config/states')
	IncludeDir('custom_modules/config')
	Include('config/sh_oldconfig.lua')

	-- Public API. Loaded before console variables, which already use it.
	Include('api/sh_assert.lua')
	Include('api/sh_core.lua')
	Include('api/sh_config.lua')
	IncludeDir('api')

	IncludeDir('cvars')
	IncludeDir('commands')

	IncludeDir('custom_modules/preload')

	-- Remember actor configs (including custom modules) for bgNPC.Config.Reset
	bgNPC.Config.SaveDefaults()

	Include('actor/sh_actor.lua')
	IncludeDir('actor/components')
	IncludeDir('actor/body')
	IncludeDir('actor')

	Include('nav/sh_astar.lua')
	Include('nav/sh_node_graph.lua')
	Include('nav/sv_nav.lua')
	Include('nav/providers/sv_graph_provider.lua')
	IncludeDir('nav')
	Include('modules/dv/sh_dv_vehicle.lua')

	-- Systems register modules (wanted, team_parent, ...) that states and integrations use.
	Include('systems/sv_team_parent.lua')
	IncludeDir('systems/wanted')
	IncludeDir('systems')
	Include('brain/sv_brain.lua')
	IncludeDir('brain')
	IncludeDir('spawner')
	IncludeDir('modules')

	Include('ui/settings/lang/sh_en.lua')
	Include('ui/settings/lang/sh_ru.lua')
	Include('ui/settings/cl_lang.lua')
	IncludeDir('ui')
	IncludeDir('debug')

	IncludeDir('custom_modules/postload')

	hook.Run('BGN_PostLoadScripts')
end

ExecutableScripts()

hook.Add('BGN_PostGamemodeLoaded', 'BGN_LoadConfig_SH_Player', function()
	include(ROOT .. '/config/sh_player.lua')
end)

hook.Add('PostGamemodeLoaded', 'BGN_PostGamemodeLoaded', function()
	hook.Run('BGN_PostGamemodeLoaded')
	hook.Remove('PostGamemodeLoaded', 'BGN_PostGamemodeLoaded')
end)

bgNPC.Commands.Register('bgn_scripts_reload', {
	admin = true,
	broadcast = true,
	help = 'Reloads all scripts of the addon.',
	server = function()
		ExecutableScripts()
		include(ROOT .. '/config/sh_player.lua')
		bgNPC.Nav.Load()
	end,
	client = function()
		ExecutableScripts()
		include(ROOT .. '/config/sh_player.lua')
	end,
})

--[[
	Public API of Background NPCs.

	Every group of functions lives in its own namespace and is called with a dot:
		bgNPC.Actors      - actor registry and lookups       (api/sh_actors.lua)
		bgNPC.Points      - movement points and path finding (api/sh_points.lua)
		bgNPC.Config      - actor configs and limits         (api/sh_config.lua)
		bgNPC.States      - state registration and calls     (api/sh_states.lua)
		bgNPC.Vision      - line of sight checks             (api/sh_vision.lua)
		bgNPC.Statistics  - kill statistics                  (api/sh_statistics.lua)
		bgNPC.Combat      - weapons and enemy resolving      (api/sv_combat.lua, server)
		bgNPC.Modes       - peaceful/friend/aggressive modes (api/sh_modes.lua)
		bgNPC.Modules     - optional modules registry        (this file)
		bgNPC.Util        - logging and small helpers        (this file)
		bgNPC.Assert      - argument validation              (api/sh_assert.lua)

	The old "bgNPC:Method()" functions still work, see api/sh_legacy.lua.
--]]

local bgNPC = bgNPC
local Assert = bgNPC.Assert
local IsValid = IsValid
local isstring = isstring
local tostring = tostring
local MsgN = MsgN
local bit_band = bit.band
local util_PointContents = util.PointContents
local CONTENTS_WATER = CONTENTS_WATER
--

bgNPC.Actors = bgNPC.Actors or {}
bgNPC.Points = bgNPC.Points or {}
bgNPC.Config = bgNPC.Config or {}
bgNPC.States = bgNPC.States or {}
bgNPC.Vision = bgNPC.Vision or {}
bgNPC.Statistics = bgNPC.Statistics or {}
bgNPC.Combat = bgNPC.Combat or {}
bgNPC.Modes = bgNPC.Modes or {}
bgNPC.Modules = bgNPC.Modules or {}
bgNPC.Util = bgNPC.Util or {}

local Util = bgNPC.Util
local Modules = bgNPC.Modules

-- ---------------------------------------------------------------------------
-- Util
-- ---------------------------------------------------------------------------

-- The API loads before console variables are created, so they are looked up lazily.
local cvars_cache = {}

-- Returns a ConVar object, caching it after the first successful lookup.
function Util.GetCVar(name)
	local cvar = cvars_cache[name]
	if cvar then return cvar end

	cvar = GetConVar(name)
	if cvar then cvars_cache[name] = cvar end
	return cvar
end

function Util.IsDebug()
	local cvar = Util.GetCVar('bgn_debug')
	return cvar ~= nil and cvar:GetBool()
end

-- Prints a message to the console when "bgn_debug" is enabled.
function Util.Log(message, tag)
	if not Util.IsDebug() then return end

	if tag ~= nil then
		MsgN('[Background NPCs][' .. tostring(tag) .. '] ' .. tostring(message))
	else
		MsgN('[Background NPCs] ' .. tostring(message))
	end
end

function Util.IsVectorInWater(pos)
	Assert.Arg(1, pos, 'vector', 'bgNPC.Util.IsVectorInWater')
	return bit_band(util_PointContents(pos), CONTENTS_WATER) == CONTENTS_WATER
end

-- Returns the player's tool object if the given tool mode is active.
-- @param tool_name string
-- @param ply entity|nil the local player on the client by default
function Util.GetActivePlayerTool(tool_name, ply)
	if not isstring(tool_name) then return end

	if not IsValid(ply) then
		if SERVER then return end
		ply = LocalPlayer()
	end

	local weapon = ply:GetActiveWeapon()
	if not IsValid(weapon) or weapon:GetClass() ~= 'gmod_tool' then return end

	local tool = ply:GetTool()
	if not tool or not tool.GetMode or tool:GetMode() ~= tool_name then return end
	return tool
end

-- Always printed, not only in debug mode.
function Util.Warning(message)
	MsgC(Color(255, 180, 60), '[Background NPCs] ' .. tostring(message) .. '\n')
end

-- ---------------------------------------------------------------------------
-- Modules
-- ---------------------------------------------------------------------------

local modules_list = list.GetForEdit('BGN_Modules')

-- Returns a module table registered with Modules.Register (or list.Set('BGN_Modules', ...)).
function Modules.Get(module_name)
	Assert.Arg(1, module_name, 'string', 'bgNPC.Modules.Get')
	return modules_list[module_name]
end

function Modules.Register(module_name, module_table)
	Assert.NonEmptyString(1, module_name, 'bgNPC.Modules.Register')
	Assert.Arg(2, module_table, 'table', 'bgNPC.Modules.Register')
	list.Set('BGN_Modules', module_name, module_table)
	return module_table
end

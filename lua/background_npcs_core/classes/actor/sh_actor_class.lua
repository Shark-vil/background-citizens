local BaseClass = include('background_npcs_core/classes/actor/sh_actor_base.lua')
local bgNPC = bgNPC
local Assert = bgNPC.Assert
local SERVER = SERVER
local SCHED_FORCED_GO = SCHED_FORCED_GO
local NULL = NULL
local setmetatable = setmetatable
local ipairs = ipairs
local isbool = isbool
local istable = istable
local isstring = isstring
local IsValid = IsValid
local table_RandomBySeq = table.RandomBySeq
local table_Copy = table.Copy
local slib_GetUID = slib.GetUID
local slib_chance = slib.chance
local snet_Request = snet.Request
local timer_Simple = timer.Simple
local hook_Run = hook.Run
--

BGN_ACTOR = {}
BGN_ACTOR.BaseClass = BaseClass

-- Mechanics that can be switched off per actor through the "mechanics" config table.
local DEFAULT_MECHANICS = {
	movement_controller = true,
	use_vehicle = true,
	call_for_help = true,
	fear = true,
	fear_scream = true,
	enemies_controller = true,
	targets_controller = true,
	states_controller = true,
	animator_controller = true,
	enhanced_npc_ignore = true,
	inpc_ignore = true,
}

-- CAP_* enums exist only on the server
local NPC_CAPABILITIES = SERVER and (CAP_DUCK + CAP_MOVE_SHOOT + CAP_USE + CAP_AUTO_DOORS
	+ CAP_OPEN_DOORS + CAP_TURN_HEAD + CAP_SQUAD + CAP_AIM_GUN) or 0

local function BuildMechanics(actor_data)
	local overrides = istable(actor_data.mechanics) and actor_data.mechanics or {}
	local mechanics = {}

	for name, default_value in pairs(DEFAULT_MECHANICS) do
		local value = overrides[name]
		mechanics[name] = isbool(value) and value or default_value
	end

	-- Custom mechanic flags (for example "ignore_limit") are passed through as is.
	for name, value in pairs(overrides) do
		if mechanics[name] == nil and isbool(value) then mechanics[name] = value end
	end

	return mechanics
end

local function PickWeapon(actor_type, actor_data)
	if not istable(actor_data.weapons) or #actor_data.weapons == 0 then return nil end

	local cvar_disable_weapon = GetConVar('bgn_disable_weapon_' .. actor_type)
	if cvar_disable_weapon and cvar_disable_weapon:GetBool() then return nil end

	if actor_data.getting_weapon_chance and not slib_chance(actor_data.getting_weapon_chance) then
		return nil
	end

	return table_RandomBySeq(actor_data.weapons)
end

local function PickIdentity(actor, actor_data)
	local names = bgNPC.cfg.npc_names
	local gender = actor:GetGenderByModel()

	if not names[gender] then
		gender = isstring(actor_data.gender) and names[actor_data.gender] and actor_data.gender
			or table_RandomBySeq({ 'male', 'female' })
	end

	local name
	if istable(actor_data.nicks) and #actor_data.nicks ~= 0 then
		name = table_RandomBySeq(actor_data.nicks)
	elseif names[gender] then
		name = table_RandomBySeq(names[gender])
	end

	actor.info.name = name or 'Unknown citizen'
	actor.info.gender = gender
end

-- Runs one tick after creation, when the entity is fully spawned.
local function PostInitialize(actor, actor_data, not_sync_actor_on_client, not_auto_added_to_list)
	local npc = actor.npc
	if not IsValid(npc) then return end

	if SERVER then
		actor:DropToFloor()
		actor:CreateFakePlayerMethodsForNPC()

		local start_random_state = actor_data.start_random_state
		if start_random_state == nil then
			start_random_state = actor_data.at_random ~= nil
		end

		if start_random_state or actor_data.start_state then
			timer_Simple(1, function()
				if not actor:IsAlive() then return end
				if start_random_state then
					actor:RandomState()
				else
					actor:SetState(actor_data.start_state)
				end
			end)
		end

		if not not_sync_actor_on_client then
			snet_Request('bgn_add_actor_from_client', npc, actor.type, actor.uid, actor.info).InvokeAll()
		end
	end

	if not not_auto_added_to_list then
		bgNPC.Actors.Register(actor)
	end

	hook_Run('BGN_InitActor', actor)

	actor.start_think = true
end

-- Creates an actor for an existing NPC entity.
-- @param npc entity NPC or NextBot
-- @param npc_type string actor type from the config
-- @param custom_uid number|string|nil unique id (used for client synchronization)
-- @param not_sync_actor_on_client boolean|nil
-- @param not_auto_added_to_list boolean|nil
-- @return table|nil actor
function BGN_ACTOR:Instance(npc, npc_type, custom_uid, not_sync_actor_on_client, not_auto_added_to_list)
	Assert.Arg(1, npc, 'entity', 'BGN_ACTOR:Instance')
	Assert.NonEmptyString(2, npc_type, 'BGN_ACTOR:Instance')
	Assert.Arg(4, not_sync_actor_on_client, 'boolean|nil', 'BGN_ACTOR:Instance')
	Assert.Arg(5, not_auto_added_to_list, 'boolean|nil', 'BGN_ACTOR:Instance')

	if not IsValid(npc) then return end

	local npc_data = bgNPC.Config.GetActor(npc_type)
	if not npc_data then return end

	local data = table_Copy(npc_data)
	local obj = setmetatable({}, BaseClass)

	obj.isBgnClass = true
	obj.uid = custom_uid or slib_GetUID()
	obj.type = npc_type
	obj.data = data
	obj.info = { name = 'Unknown citizen', gender = 'unknown' }
	obj.mechanics = BuildMechanics(data)
	obj.relationship = data.relationship or {}
	obj.weapon = PickWeapon(npc_type, data)
	obj.reaction = ''
	obj.eternal = false
	obj.vehicle = nil
	obj.is_removed = false

	-- Entity snapshot
	obj.npc = npc
	obj.npc_index = npc:EntIndex()
	obj.class = npc:GetClass()
	obj.skin = npc:GetSkin()
	obj.model = npc:GetModel()
	obj.collision_group = npc:GetCollisionGroup()
	obj.model_scale = npc:GetModelScale()
	obj.bodygroups = {}
	for _, bodygroup in ipairs(npc:GetBodyGroups() or {}) do
		obj.bodygroups[bodygroup.id] = npc:GetBodygroup(bodygroup.id)
	end
	if SERVER then
		obj.keyvalues = npc:GetKeyValues()
	end
	obj.sync_players_hash = {}

	-- States
	obj.state_data = { state = 'none', data = {} }
	obj.old_state = { state = 'none', data = {} }
	obj.state_delay = -1
	obj.state_lock = false

	-- Targets and enemies
	obj.targets = {}
	obj.targets_count = 0
	obj.enemies = {}
	obj.enemies_count = 0
	obj.enemies_always_visible = {}
	obj.enemies_always_visible_count = 0

	-- Animations
	obj.next_anim = nil
	obj.sync_animation_delay = 0
	obj.anim_time = 0
	obj.anim_time_normal = 0
	obj.loop_time = 0
	obj.loop_time_normal = 0
	obj.anim_is_loop = false
	obj.anim_name = ''
	obj.is_animated = false
	obj.anim_action = nil

	-- Movement
	obj.walkPath = {}
	obj.walkPos = nil
	obj.walkTarget = NULL
	obj.walkType = SCHED_FORCED_GO
	obj.walkUpdatePathDelay = 0
	obj.waitUpdateMovementDelay = 0
	obj.pathType = nil
	obj.isChase = false

	obj.npc_schedule = -1
	obj.npc_state = -1

	PickIdentity(obj, data)

	npc.BGN_ACTOR_OBJECT = obj
	npc.isBgnActor = true
	function npc:GetActor() return obj end

	if obj.mechanics.inpc_ignore then
		-- Unsupported iNPC - Artificial Intelligence Module (Improved NPC AI)
		-- https://steamcommunity.com/sharedfiles/filedetails/?id=632126111
		npc.inpcIgnore = true
	end

	if SERVER and npc:IsNPC() then
		npc:CapabilitiesAdd(NPC_CAPABILITIES)
	end

	timer_Simple(0, function()
		PostInitialize(obj, data, not_sync_actor_on_client, not_auto_added_to_list)
	end)

	return obj
end

snet.RegisterValidator('actor', function(ply, uid, actor_uid)
	return bgNPC.Actors.GetByUid(actor_uid) ~= nil
end)

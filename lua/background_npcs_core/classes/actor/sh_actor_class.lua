local BaseClass = include('background_npcs_core/classes/actor/sh_actor_base.lua')
local bgNPC = bgNPC
local SERVER = SERVER
local SCHED_FORCED_GO = SCHED_FORCED_GO
local setmetatable = setmetatable
local table_RandomBySeq = table.RandomBySeq
local table_Copy = table.Copy
local isstring = isstring
local slib_GetUid = slib.GetUid
local slib_chance = slib.chance
local snet_Request = snet.Request
local isbool = isbool
local istable = istable
local timer_Simple = timer.Simple
local hook_Run = hook.Run
--
BGN_ACTOR = {}

local function set_mechanic(obj, mechanic_type, default_value)
	local value = true
	local npc_data = obj.data

	if isbool(default_value) then
		value = default_value
	end

	if istable(npc_data) and istable(npc_data.mechanics) and isbool(npc_data.mechanics[mechanic_type]) then
		value = npc_data.mechanics[mechanic_type]
	end

	obj.mechanics = obj.mechanics or {}
	obj.mechanics[mechanic_type] = value
end

function BGN_ACTOR:Instance(npc, npc_type, custom_uid, not_sync_actor_on_client, not_auto_added_to_list)
	local npc_data = bgNPC:GetActorConfig(npc_type)
	if not npc_data then return end

	not_sync_actor_on_client = not_sync_actor_on_client or false
	not_auto_added_to_list = not_auto_added_to_list or false

	local default_name = 'Unknown citizen'
	if npc_data.nicks and istable(npc_data.nicks) then
		default_name = table_RandomBySeq(npc_data.nicks)
	end

	local default_gender = 'unknown'
	if npc_data.gender and isstring(npc_data.gender) then
		default_gender = npc_data.gender
	end

	local data = table_Copy(npc_data)
	local obj = {}
	obj.info = {
		name = default_name,
		gender = default_gender,
	}
	obj.uid = custom_uid or slib_GetUid()
	obj.npc = npc
	obj.npc_index = npc:EntIndex()
	obj.class = npc:GetClass()
	obj.bodygroups = {}
	for _, bodygroup in ipairs(npc:GetBodyGroups()) do
		obj.bodygroups[bodygroup.id] = npc:GetBodygroup(bodygroup.id)
	end
	obj.skin = npc:GetSkin()
	obj.model = npc:GetModel()
	if SERVER then
		obj.keyvalues = npc:GetKeyValues()
	end
	obj.collision_group = npc:GetCollisionGroup()
	obj.model_scale = npc:GetModelScale()
	obj.data = data
	obj.weapon = nil
	obj.sync_players_hash = {}
	obj.state_delay = -1
	obj.mechanics = {}

	set_mechanic(obj, 'movement_controller', true)
	set_mechanic(obj, 'use_vehicle', true)
	set_mechanic(obj, 'call_for_help', true)
	set_mechanic(obj, 'fear_scream', true)
	set_mechanic(obj, 'enemies_controller', true)
	set_mechanic(obj, 'targets_controller', true)
	set_mechanic(obj, 'states_controller', true)
	set_mechanic(obj, 'animator_controller', true)
	set_mechanic(obj, 'enhanced_npc_ignore', true)
	set_mechanic(obj, 'inpc_ignore', true)

	local cvar_disable_weapon = GetConVar('bgn_disable_weapon_' .. npc_type)

	if data.weapons
		and (not cvar_disable_weapon or not cvar_disable_weapon:GetBool())
		and (not data.getting_weapon_chance or slib_chance(data.getting_weapon_chance))
	then
		obj.weapon = table_RandomBySeq(data.weapons)
	end

	obj.type = npc_type
	obj.reaction = ''
	obj.eternal = false
	obj.vehicle = nil

	obj.state_data = {
		state = 'none',
		data = {}
	}

	if SERVER then
		obj.next_anim = nil
		obj.sync_animation_delay = 0
	end

	obj.anim_time = 0
	obj.anim_time_normal = 0
	obj.loop_time = 0
	obj.loop_time_normal = 0
	obj.anim_is_loop = false
	obj.anim_name = ''
	obj.is_animated = false
	obj.anim_action = nil
	obj.old_state = {
		state = 'none',
		data = {}
	}
	obj.state_lock = false

	obj.walkPath = {}
	obj.walkPos = nil
	obj.walkTarget = NULL
	obj.walkType = SCHED_FORCED_GO
	obj.walkUpdatePathDelay = 0
	obj.waitUpdateMovementDelay = 0
	obj.pathType = nil
	obj.isChase = false

	obj.isBgnClass = true
	obj.targets = {}
	obj.enemies = {}
	obj.enemies_always_visible = {}

	obj.npc_schedule = -1
	obj.npc_state = -1
	obj.relationship = npc_data.relationship or {}

	setmetatable(obj, BaseClass)

	local gender = obj:GetGenderByModel()
	if gender and bgNPC.cfg.npc_names[gender] then
		obj.info.name = table_RandomBySeq( bgNPC.cfg.npc_names[gender] )
		obj.info.gender = gender
	else
		gender = table_RandomBySeq( { 'male', 'female' } )
		obj.info.name = table_RandomBySeq( bgNPC.cfg.npc_names[gender] )
		obj.info.gender = gender
	end

	function npc:GetActor()
		return obj
	end

	npc.isBgnActor = true

	if obj.mechanics.inpc_ignore then
		-- ------------------------------------------------------------------
		-- Unsopported iNPC - Artifical Intelligence Module (Improved NPC AI)
		-- https://steamcommunity.com/sharedfiles/filedetails/?id=632126111
		npc.inpcIgnore = true
		-- ------------------------------------------------------------------
	end

	if SERVER and npc:IsNPC() and isfunction(npc.CapabilitiesAdd) then
		npc:CapabilitiesAdd(CAP_DUCK + CAP_MOVE_SHOOT + CAP_USE + CAP_AUTO_DOORS + CAP_OPEN_DOORS + CAP_TURN_HEAD + CAP_SQUAD + CAP_AIM_GUN)
	end

	if SERVER and not not_sync_actor_on_client then
		snet_Request('bgn_add_actor_from_client', npc, npc_type, obj.uid, obj.info).InvokeAll()
	end

	if not not_auto_added_to_list then
		bgNPC:AddNPC(obj)
	end

	hook_Run('BGN_InitActor', obj)

	timer_Simple(0, function()
		if not IsValid(npc) then return end
		obj:DropToFloor()
		obj:CreateFakePlayerMethodsForNPC()

		if npc_data.start_random_state or npc_data.start_state then
			timer_Simple(1, function()
				if not obj:IsAlive() then return end
				if npc_data.start_random_state then
					obj:RandomState()
				elseif npc_data.start_state then
					obj:SetState(npc_data.start_state)
				end
			end)
		end
	end)

	return obj
end

snet.RegisterValidator('actor', function(ply, uid, actor_uid)
	return bgNPC:GetActorByUid(actor_uid) ~= nil
end)
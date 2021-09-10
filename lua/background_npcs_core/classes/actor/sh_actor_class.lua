local BaseClass = include('sh_actor_base.lua')
local slib = slib
local table = table
local math = math
local SERVER = SERVER
local snet = snet
local bgNPC = bgNPC
local setmetatable = setmetatable
--
BGN_ACTOR = {}

function BGN_ACTOR:Instance(npc, npc_type, custom_uid, not_sync_actor_on_client, not_auto_added_to_list)
	local npc_data = bgNPC:GetActorConfig(npc_type)
	if not npc_data then return end

	not_sync_actor_on_client = not_sync_actor_on_client or false
	not_auto_added_to_list = not_auto_added_to_list or false

	local data = table.Copy(npc_data)
	local obj = {}

	obj.uid = custom_uid or slib.GetUid()
	obj.npc = npc
	obj.npc_index = npc:EntIndex()
	obj.class = npc:GetClass()
	obj.collision_group = npc:GetCollisionGroup()
	obj.model_scale = npc:GetModelScale()
	obj.data = data
	obj.weapon = nil
	obj.sync_players_hash = {}
	obj.state_delay = -1

	if data.weapons and (not data.getting_weapon_chance or math.random(0, 100) < data.getting_weapon_chance) then
		obj.weapon = table.RandomBySeq(data.weapons)
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
	obj.pathType = nil
	obj.isChase = false

	obj.isBgnClass = true
	obj.targets = {}
	obj.enemies = {}

	obj.npc_schedule = -1
	obj.npc_state = -1

	setmetatable(obj, BaseClass)

	function npc:GetActor()
		return obj
	end

	npc.isBgnActor = true

	if SERVER and not not_sync_actor_on_client then
		snet.Create('bgn_add_actor_from_client', npc, npc_type, obj.uid).InvokeAll()
	end

	if not not_auto_added_to_list then
		bgNPC:AddNPC(obj)
	end

	return obj
end

snet.RegisterValidator('actor', function(ply, uid, actor_uid)
	return bgNPC:GetActorByUid(actor_uid) ~= nil
end)
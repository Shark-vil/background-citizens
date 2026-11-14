--[[
	Actor: a character with an NPC/NextBot body on foot and a DV visual while seated.

	The class is split into partial files, each adds one group of methods:
		actor/components/sh_state.lua      states and random reactions
		actor/components/sh_targets.lua    targets (entities used by state logic)
		actor/components/sh_enemies.lua    enemies and engine relationships
		actor/components/sh_movement.lua   walking along paths
		actor/components/sh_team.lua       teams and config relationships
		actor/components/sh_animation.lua  static sequences
		actor/components/sh_combat.lua     fear, help calls, weapons
		actor/components/sh_vehicle.lua    Decent Vehicle driving
		actor/components/sh_speech.lua     voice and text

	On the server every actor has a body (actor.body, see actor/body/) and a brain (actor.brain, see brain/).
	Create actors with bgNPC.Actor.New(npc, type) (BGN_ACTOR:Instance is the old name).
--]]
local Assert = bgNPC.Assert
local NextId = bgNPC.Util.NextId
local Chance = bgNPC.Util.Chance
local table_RandomBySeq = bgNPC.Table.Random
local Net = bgNPC.Net
--
local Actor = bgNPC.Class('BGN_Actor')
bgNPC.Actor = Actor
-- Actor initialization owns inpcIgnore; retire the duplicate hook on script reload.
if SERVER then hook.Remove('BGN_InitActor', 'BGN_iNPC_IgnoreActors') end
-- Shared helpers for the partial files.
local H = {}
Actor.Helpers = H
local FEMALE_WORDS = {'female', 'woman', 'women'}
local MALE_WORDS = {'male', 'man', 'men'}
function H.GenderByModel(model)
  if not isstring(model) then return 'unknown' end
  -- the file name only ("models/humans/..." has "man" in it); female words first: "male" is inside "female",
  -- "man"/"men" inside "woman"/"women"
  local name = string.GetFileFromFilename(model):lower()
  for _, word in ipairs(FEMALE_WORDS) do
    if string.find(name, word, 1, true) then return 'female' end
  end

  for _, word in ipairs(MALE_WORDS) do
    if string.find(name, word, 1, true) then return 'male' end
  end
  return 'unknown'
end

-- @return entity|NULL the valid entity nearest to origin
function H.FindNearest(list, count, origin)
  local nearest, nearest_dist = NULL, nil
  for i = 1, count do
    local ent = list[i]
    if IsValid(ent) then
      local dist = origin:DistToSqr(ent:GetPos())
      if not nearest_dist or dist < nearest_dist then nearest, nearest_dist = ent, dist end
    end
  end
  return nearest
end

function H.FindFirstValid(list, from, to, step)
  for i = from, to, step do
    local ent = list[i]
    if IsValid(ent) then return ent end
  end
  return NULL
end

-- Picks a key from a { key = weight } table. Higher weight - higher chance.
-- Works with fractional weights and never fails on an empty or zero-weight table.
function H.PickWeighted(weights)
  if not istable(weights) then return 'none' end
  local total = 0
  for _, weight in pairs(weights) do
    if isnumber(weight) and weight > 0 then total = total + weight end
  end

  if total <= 0 then return 'none' end
  local roll = math.random() * total
  local last_key = 'none'
  for key, weight in pairs(weights) do
    if isnumber(weight) and weight > 0 then
      last_key = key
      roll = roll - weight
      if roll <= 0 then return key end
    end
  end
  return last_key
end

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------
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

local function BuildMechanics(actor_data)
  local overrides = istable(actor_data.mechanics) and actor_data.mechanics or {}
  local mechanics = {}
  for name, default_value in pairs(DEFAULT_MECHANICS) do
    local value = overrides[name]
    if not isbool(value) then value = default_value end
    mechanics[name] = value
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
  if actor_data.getting_weapon_chance and not Chance(actor_data.getting_weapon_chance) then return nil end
  return table_RandomBySeq(actor_data.weapons)
end

local function PickIdentity(actor, actor_data)
  local names = bgNPC.cfg.npc_names
  local gender = actor:GetGenderByModel()
  if not names[gender] then gender = isstring(actor_data.gender) and names[actor_data.gender] and actor_data.gender or table_RandomBySeq({'male', 'female'}) end
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
local function PostInitialize(actor, not_sync_actor_on_client, not_auto_added_to_list)
  local npc = actor.npc
  -- removed in its first tick: registering it would keep a dead actor in the lists and its limit slot taken
  if not IsValid(npc) or actor.is_removed then return end
  local data = actor.data
  if SERVER then
    actor:DropToFloor()
    actor:CreateFakePlayerMethodsForNPC()
    local start_random_state = data.start_random_state
    if start_random_state == nil then start_random_state = data.at_random ~= nil end
    if start_random_state or data.start_state then
      timer.Simple(1, function()
        if not actor:IsAlive() then return end
        if start_random_state then
          actor:RandomState()
        else
          actor:SetState(data.start_state)
        end
      end)
    end

    if not not_sync_actor_on_client then Net.Send('bgn_add_actor_from_client', nil, npc, actor.type, actor.uid, actor.info) end
  end

  if not not_auto_added_to_list then bgNPC.Actors.Register(actor) end
  hook.Run('BGN_InitActor', actor)
  actor.start_think = true
end

-- @param npc entity NPC or NextBot
-- @param npc_type string actor type from the config
-- @param custom_uid number|string|nil unique id (used for client synchronization)
-- @param not_sync_actor_on_client boolean|nil
-- @param not_auto_added_to_list boolean|nil
function Actor:Init(npc, npc_type, custom_uid, not_sync_actor_on_client, not_auto_added_to_list)
  local data = table.Copy(bgNPC.Config.GetActor(npc_type))
  self.isBgnClass = true
  self.uid = custom_uid or NextId()
  self.type = npc_type
  self.data = data
  self.info = {
    name = 'Unknown citizen',
    gender = 'unknown'
  }

  self.mechanics = BuildMechanics(data)
  self.relationship = data.relationship or {}
  self.weapon = PickWeapon(npc_type, data)
  self.reaction = ''
  self.eternal = false
  self.vehicle = nil
  self.is_removed = false
  -- Entity snapshot
  self.npc = npc
  self.npc_index = npc:EntIndex()
  self.class = npc.bgn_npc_class or npc:GetClass()
  self.skin = npc:GetSkin()
  self.model = npc:GetModel()
  self.collision_group = npc:GetCollisionGroup()
  self.model_scale = npc:GetModelScale()
  self.bodygroups = {}
  for _, bodygroup in ipairs(npc:GetBodyGroups() or {}) do
    self.bodygroups[bodygroup.id] = npc:GetBodygroup(bodygroup.id)
  end

  if SERVER then self.keyvalues = npc:GetKeyValues() end
  self.sync_players_hash = setmetatable({}, {
    __mode = 'k' -- players that left are dropped
  })

  -- States
  self.state_data = {
    state = 'none',
    data = {}
  }

  self.old_state = {
    state = 'none',
    data = {}
  }

  self.state_delay = -1
  self.state_lock = false
  -- Targets and enemies
  self.targets = {}
  self.targets_count = 0
  self.enemies = {}
  self.enemies_count = 0
  self.enemies_always_visible = {}
  self.enemies_always_visible_count = 0
  -- Animations
  self.next_anim = nil
  self.anim_time = 0
  self.anim_time_normal = 0
  self.loop_time = 0
  self.loop_time_normal = 0
  self.anim_is_loop = false
  self.anim_name = ''
  self.is_animated = false
  self.anim_action = nil
  -- Movement
  self.walkPath = {}
  self.walkPos = nil
  self.walkTarget = NULL
  self.walkType = SCHED_FORCED_GO
  self.walkUpdatePathDelay = 0
  self.waitUpdateMovementDelay = 0
  self.pathType = nil
  self.isChase = false
  self.npc_schedule = -1
  self.npc_state = -1
  PickIdentity(self, data)
  npc.BGN_ACTOR_OBJECT = self
  npc.isBgnActor = true
  if SERVER then -- clients see it even without the actor object (systems/cl_corpses.lua)
    npc:SetNW2Bool('bgn_actor', true)
  end

  local actor = self
  function npc:GetActor()
    return actor
  end

  if self.mechanics.inpc_ignore then
    -- iNPC takes over every NPC without this flag
    npc.inpcIgnore = true
  end

  if SERVER then
    self.body = bgNPC.Body.For(self, npc)
    self.brain = bgNPC.Brain.For(self)
  end

  timer.Simple(0, function() PostInitialize(self, not_sync_actor_on_client, not_auto_added_to_list) end)
end

-- @return table|nil actor
function Actor.Create(npc, npc_type, custom_uid, not_sync_actor_on_client, not_auto_added_to_list)
  Assert.Arg(1, npc, 'entity', 'bgNPC.Actor.Create')
  Assert.NonEmptyString(2, npc_type, 'bgNPC.Actor.Create')
  Assert.Arg(4, not_sync_actor_on_client, 'boolean|nil', 'bgNPC.Actor.Create')
  Assert.Arg(5, not_auto_added_to_list, 'boolean|nil', 'bgNPC.Actor.Create')
  if not IsValid(npc) or not bgNPC.Config.GetActor(npc_type) then return nil end
  return Actor.New(npc, npc_type, custom_uid, not_sync_actor_on_client, not_auto_added_to_list)
end

-- OUTDATED: old factory, use bgNPC.Actor.Create
BGN_ACTOR = BGN_ACTOR or {}
BGN_ACTOR.BaseClass = Actor
function BGN_ACTOR:Instance(...)
  return Actor.Create(...)
end

-- ---------------------------------------------------------------------------
-- Networking
-- ---------------------------------------------------------------------------
function Actor:SyncFunction(name, ply, data)
  if CLIENT then return end
  Assert.NonEmptyString(1, name, 'ACTOR:SyncFunction')
  Assert.Arg(2, ply, 'entity|nil', 'ACTOR:SyncFunction')
  if not self:IsAlive() then return end
  if ply then
    if IsValid(ply) then Net.Send(name, ply, self.uid, data) end
  else
    Net.Send(name, nil, self.uid, data)
  end
end

-- ---------------------------------------------------------------------------
-- Info
-- ---------------------------------------------------------------------------
function Actor:SetName(name)
  Assert.Arg(1, name, 'string|nil', 'ACTOR:SetName')
  if name then self.info.name = name end
end

function Actor:GetName()
  return self.info.name
end

function Actor:SetGender(gender_name)
  Assert.Arg(1, gender_name, 'string|nil', 'ACTOR:SetGender')
  self.info.gender = gender_name or 'unknown'
end

function Actor:GetGender()
  return self.info.gender or 'unknown'
end

function Actor:GetGenderByModel()
  if not IsValid(self.npc) then return 'unknown' end
  return H.GenderByModel(self:InVehicle() and self.model or self.npc:GetModel())
end

function Actor:Health()
  local npc = self.npc
  if IsValid(npc) and isfunction(npc.Health) then return npc:Health() end
  return self.vehicle_body and self.vehicle_body.health or 0
end

function Actor:GetHealth()
  return self:Health()
end

function Actor:GetMaxHealth()
  local npc = self.npc
  if IsValid(npc) and isfunction(npc.GetMaxHealth) then return npc:GetMaxHealth() end
  return self.vehicle_body and self.vehicle_body.max_health or 0
end

-- ---------------------------------------------------------------------------
-- Lifetime
-- ---------------------------------------------------------------------------
-- Checks if the actor is alive. A dead actor is unregistered once.
-- ! The client has a simpler check (no body).
function Actor:IsAlive()
  if self.is_removed then return false end
  local is_dead
  if self.vehicle_body then
    is_dead = self:Health() <= 0 or not self.vehicle or not self.vehicle:IsValid()
  elseif self.body then
    is_dead = self.body:IsDead()
  else
    local npc = self.npc
    is_dead = not IsValid(npc) or self:Health() <= 0
  end

  if is_dead then
    if SERVER then self:RemoveActor() end
    return false
  end
  return true
end

-- Unregisters the actor without removing the entity.
function Actor:RemoveActor()
  if self.is_removed then return end
  self.is_removed = true
  if self.brain then self.brain:Stop() end
  bgNPC.Actors.UnregisterActor(self)
  local provider = self.vehicle
  self.vehicle, self.vehicle_body = nil, nil
  if provider then
    if provider.driver == self then
      provider:SetDriver(nil)
    else
      provider:RemovePassenger(self)
    end
  end
end

-- Unregisters the actor and removes the entity.
function Actor:Remove()
  self:RemoveActor()
  if IsValid(self.npc) then self.npc:Remove() end
end

function Actor:IsValid()
  return IsValid(self.npc)
end

function Actor:IsNPC()
  return IsValid(self.npc) and self.npc:IsNPC()
end

function Actor:IsNextBot()
  return IsValid(self.npc) and self.npc:IsNextBot()
end

-- In a vehicle this is the DV anim entity, not an NPC/NextBot.
-- ! Can return NULL during body replacement; validate before using the entity.
function Actor:GetNPC()
  return self.npc
end

-- @return table|nil body (server only)
function Actor:GetBody()
  return self.body
end

-- @return table|nil brain (server only)
function Actor:GetBrain()
  return self.brain
end

-- ! The data is copied on creation. Config changes do not affect existing actors.
function Actor:GetData()
  return self.data
end

-- Returns the entity class of the actor.
function Actor:GetClass()
  return self.class
end

-- Returns the actor type from the config, for example "citizen".
function Actor:GetType()
  return self.type
end

function Actor:GetPos()
  if not IsValid(self.npc) then return Vector(0, 0, 0) end
  return self.npc:GetPos()
end

function Actor:GetAngles()
  if not IsValid(self.npc) then return Angle(0, 0, 0) end
  return self.npc:GetAngles()
end

function Actor:DropToFloor()
  if self.body then
    self.body:DropToFloor()
  elseif IsValid(self.npc) then
    self.npc:DropToFloor()
  end
end

-- OUTDATED: the brain is updated by the actor update loop.
function Actor:Think()
  if self.brain then self.brain:Update() end
end

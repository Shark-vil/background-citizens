local bgNPC = bgNPC
local Assert = bgNPC.Assert
local SERVER = SERVER
local CLIENT = CLIENT
local EFL_NO_THINK_FUNCTION = EFL_NO_THINK_FUNCTION
local SCHED_FORCED_GO = SCHED_FORCED_GO
local SCHED_FORCED_GO_RUN = SCHED_FORCED_GO_RUN
local SOLID_BBOX = SOLID_BBOX
local CurTime = CurTime
local RealTime = RealTime
local Vector = Vector
local Angle = Angle
local IsValid = IsValid
local ipairs = ipairs
local pairs = pairs
local istable = istable
local isentity = isentity
local isnumber = isnumber
local isstring = isstring
local isbool = isbool
local isvector = isvector
local isfunction = isfunction
local NULL = NULL
local table_remove = table.remove
local table_RandomBySeq = bgNPC.Table.Random
local table_HasValueBySeq = bgNPC.Table.HasValue
local table_RemoveByValue = table.RemoveByValue
local table_insert = table.insert
local table_isArray = bgNPC.Table.IsArray
local string_find = string.find
local string_lower = string.lower
local hook_Run = hook.Run
local Net = bgNPC.Net
local math_random = math.random
--

local MALE_SCREAMS = {
	'ambient/voices/m_scream1.wav',
	'vo/coast/bugbait/sandy_help.wav',
	'vo/npc/male01/help01.wav',
	'vo/Streetwar/sniper/male01/c17_09_help01.wav',
	'vo/Streetwar/sniper/male01/c17_09_help02.wav',
	'vo/npc/male01/no01.wav',
	'vo/npc/male01/no02.wav',
}

local FEMALE_SCREAMS = {
	'ambient/voices/f_scream1.wav',
	'vo/canals/arrest_helpme.wav',
	'vo/npc/female01/help01.wav',
	'vo/npc/female01/no01.wav',
	'vo/npc/female01/no02.wav',
}

local ANY_SCREAMS = {}
for _, path in ipairs(MALE_SCREAMS) do ANY_SCREAMS[#ANY_SCREAMS + 1] = path end
for _, path in ipairs(FEMALE_SCREAMS) do ANY_SCREAMS[#ANY_SCREAMS + 1] = path end

-- Schedules the engine runs while the NPC is fighting. Movement updates must
-- not interrupt them, otherwise the NPC never gets to shoot or reload.
local COMBAT_SCHEDULES = {}
for _, schedule in ipairs({
	SCHED_HIDE_AND_RELOAD,
	SCHED_RELOAD,
	SCHED_ESTABLISH_LINE_OF_FIRE,
	SCHED_RANGE_ATTACK1,
	SCHED_RANGE_ATTACK2,
	SCHED_SPECIAL_ATTACK1,
	SCHED_SPECIAL_ATTACK2,
	SCHED_MELEE_ATTACK1,
	SCHED_MELEE_ATTACK2,
	SCHED_FAIL,
	SCHED_FAIL_ESTABLISH_LINE_OF_FIRE,
	SCHED_SLEEP,
}) do
	if schedule then COMBAT_SCHEDULES[schedule] = true end
end

local MOVEMENT_FINISHED_DIST_SQR = 150 ^ 2
local MOVEMENT_UPDATE_PERIOD = .5

-- Picks a key from a { key = weight } table. Higher weight - higher chance.
-- Works with fractional weights and never fails on an empty or zero-weight table.
local function PickWeighted(weights)
	if not istable(weights) then return 'none' end

	local total = 0
	for _, weight in pairs(weights) do
		if isnumber(weight) and weight > 0 then total = total + weight end
	end

	if total <= 0 then return 'none' end

	local roll = math_random() * total
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

local function GenderByModel(model)
	if not isstring(model) then return 'unknown' end
	-- "female" must be checked first, because "male_" is a substring of it
	if string_find(model, 'female', 1, true) then return 'female' end
	if string_find(model, 'male_', 1, true) then return 'male' end
	return 'unknown'
end

local function IsNPCEntity(ent)
	return IsValid(ent) and ent:IsNPC()
end

local BaseClass = {}

-- ---------------------------------------------------------------------------
-- State delay
-- ---------------------------------------------------------------------------

function BaseClass:SetStateDelay(time)
	Assert.Arg(1, time, 'number', 'ACTOR:SetStateDelay')
	self.state_delay = CurTime() + time
end

function BaseClass:IsStateDelay()
	return self.state_delay > CurTime()
end

function BaseClass:ResetStateDelay()
	self.state_delay = 0
end

-- ---------------------------------------------------------------------------
-- Networking
-- ---------------------------------------------------------------------------

function BaseClass:SyncFunction(name, ply, data)
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

function BaseClass:SetName(name)
	Assert.Arg(1, name, 'string|nil', 'ACTOR:SetName')
	if name then self.info.name = name end
end

function BaseClass:GetName()
	return self.info.name
end

function BaseClass:SetGender(gender_name)
	Assert.Arg(1, gender_name, 'string|nil', 'ACTOR:SetGender')
	self.info.gender = gender_name or 'unknown'
end

function BaseClass:GetGender()
	return self.info.gender or 'unknown'
end

function BaseClass:GetGenderByModel()
	if not IsValid(self.npc) then return 'unknown' end
	return GenderByModel(self.npc:GetModel())
end

function BaseClass:Health()
	local npc = self.npc
	if IsValid(npc) and npc.Health then return npc:Health() end
	return 0
end

-- ---------------------------------------------------------------------------
-- Random reactions
-- ---------------------------------------------------------------------------

-- Sets the random state of the NPC from the "at_random" table.
function BaseClass:RandomState()
	if not hook_Run('PreRandomState', self) then
		local state = self:GetRandomState()
		if state ~= 'none' and self:GetState() ~= state then
			self:SetState(state)
		end
	end
	return self:GetState()
end

-- Gets a random identifier from the "at_random" table.
-- ? The result depends on the set weights. The higher the value, the greater the chance of falling out.
-- @return string state identifier, or 'none'
function BaseClass:GetRandomState()
	return PickWeighted(self.data.at_random)
end

function BaseClass:GetReactionForDamage()
	return PickWeighted(self.data.at_damage)
end

function BaseClass:GetReactionForProtect()
	return PickWeighted(self.data.at_protect)
end

-- Sets the reaction to the event.
-- ? Used in system computing, and does nothing by itself.
function BaseClass:SetReaction(reaction)
	Assert.Arg(1, reaction, 'string|nil', 'ACTOR:SetReaction')
	self.reaction = reaction
end

-- Will return the last result specified in the reaction variable.
function BaseClass:GetLastReaction()
	return self.reaction
end

-- ---------------------------------------------------------------------------
-- Lifetime
-- ---------------------------------------------------------------------------

-- Checks if the actor is alive or not. A dead actor is unregistered once.
-- ! The client has a simpler and less reliable check.
-- @return boolean is_alive
function BaseClass:IsAlive()
	if self.is_removed then return false end

	local npc = self.npc
	local is_dead = not IsValid(npc)
		or (npc.Health and npc:Health() <= 0)
		or (SERVER and npc:IsNPC() and npc:IsCurrentSchedule(SCHED_DIE))

	if is_dead then
		self:RemoveActor()
		return false
	end

	return true
end

-- Unregisters the actor without removing the entity.
function BaseClass:RemoveActor()
	if self.is_removed then return end
	self.is_removed = true
	bgNPC.Actors.Unregister(self.npc)
end

-- Unregisters the actor and removes the entity.
function BaseClass:Remove()
	self:RemoveActor()
	if IsValid(self.npc) then self.npc:Remove() end
end

-- Checks the existence of an NPC entity.
function BaseClass:IsValid()
	return IsValid(self.npc)
end

function BaseClass:IsNPC()
	return IsNPCEntity(self.npc)
end

function BaseClass:IsNextBot()
	return IsValid(self.npc) and self.npc:IsNextBot()
end

-- Returns the entity of the actor's NPC.
-- ! Can return NULL, use IsAlive before working with the entity.
function BaseClass:GetNPC()
	return self.npc
end

-- Will return the actor's data specified in the config.
-- ! The data is copied on creation. Config changes do not affect existing actors.
function BaseClass:GetData()
	return self.data
end

-- Returns the real NPC class that is associated with the actor.
function BaseClass:GetClass()
	return self.class
end

-- Returns the actor type specified in the config. For example - citizen.
function BaseClass:GetType()
	return self.type
end

function BaseClass:GetPos()
	if not IsValid(self.npc) then return Vector(0, 0, 0) end
	return self.npc:GetPos()
end

function BaseClass:GetAngles()
	if not IsValid(self.npc) then return Angle(0, 0, 0) end
	return self.npc:GetAngles()
end

-- ---------------------------------------------------------------------------
-- Schedules
-- ---------------------------------------------------------------------------

-- Clears NPC schedule data.
function BaseClass:ClearSchedule()
	local npc = self.npc
	if not IsNPCEntity(npc) then return end

	npc:SetNPCState(NPC_STATE_IDLE)
	npc:ClearSchedule()

	self.npc_schedule = npc:GetCurrentSchedule()
	self.npc_state = npc:GetNPCState()
end

function BaseClass:SetSchedule(schedule)
	Assert.Arg(1, schedule, 'number', 'ACTOR:SetSchedule')
	if not self:IsAlive() or not self:IsNPC() then return end
	if not self:IsSequenceFinished() then return end

	local npc = self.npc
	npc:SetSchedule(schedule)

	self.npc_schedule = npc:GetCurrentSchedule()
	self.npc_state = npc:GetNPCState()
end

function BaseClass:IsExecutingCombatSchedule()
	local npc = self.npc
	if not IsNPCEntity(npc) then return false end
	return COMBAT_SCHEDULES[npc:GetCurrentSchedule()] == true
end

-- ---------------------------------------------------------------------------
-- Targets
-- ? A target doesn't have to be an enemy. Targets are used by state logic.
-- ---------------------------------------------------------------------------

function BaseClass:AddTarget(ent)
	Assert.Arg(1, ent, 'entity|nil', 'ACTOR:AddTarget')

	if not self.mechanics.targets_controller then return end
	if not IsValid(ent) or ent == self.npc or ent.BGN_HasBuildMode then return end
	if not self:IsAlive() or table_HasValueBySeq(self.targets, ent) then return end

	self.targets_count = self.targets_count + 1
	self.targets[self.targets_count] = ent
end

-- Removes an entity from the target list.
-- ! Removing a target does not change NPC relationships.
-- @param ent entity|nil target to remove
-- @param index number|nil target index, takes priority over ent
-- @return number targets count after removal
function BaseClass:RemoveTarget(ent, index)
	Assert.Arg(2, index, 'number|nil', 'ACTOR:RemoveTarget')

	if not self.mechanics.targets_controller then return self.targets_count end

	if index then ent = self.targets[index] end
	if ent == nil then return self.targets_count end

	if hook_Run('BGN_RemoveActorTarget', self, ent) then return self.targets_count end

	local old_count = self.targets_count

	if ent == self.walkTarget then self.walkTarget = NULL end

	if index and self.targets[index] == ent then
		table_remove(self.targets, index)
	else
		table_RemoveByValue(self.targets, ent)
	end

	self.targets_count = #self.targets

	if old_count > 0 and self.targets_count == 0 then
		hook_Run('BGN_ResetTargetsForActor', self)
	end

	return self.targets_count
end

function BaseClass:RemoveAllTargets()
	if not self.mechanics.targets_controller then return end

	for i = self.targets_count, 1, -1 do
		self:RemoveTarget(nil, i)
	end

	-- Hooks may reject a removal; make sure the list is consistent anyway.
	if self.targets_count ~= 0 then
		self.targets = {}
		self.targets_count = 0
		hook_Run('BGN_ResetTargetsForActor', self)
	end
end

-- Removes dead or no longer existing targets.
-- @return table targets
function BaseClass:RecalculationTargets()
	if not self.mechanics.targets_controller then return self.targets end

	self.targets_count = #self.targets

	for i = self.targets_count, 1, -1 do
		local target = self.targets[i]
		if not IsValid(target) or (target:IsPlayer() and target:Health() <= 0) then
			self:RemoveTarget(nil, i)
		end
	end

	return self.targets
end

function BaseClass:HasTarget(ent)
	return table_HasValueBySeq(self.targets, ent)
end

function BaseClass:TargetsCount()
	return self.targets_count
end

function BaseClass:HasNoTargets()
	return self.targets_count == 0
end

local function FindNearest(list, count, origin)
	local nearest = NULL
	local nearest_dist

	for i = 1, count do
		local ent = list[i]
		if IsValid(ent) then
			local dist = origin:DistToSqr(ent:GetPos())
			if not nearest_dist or dist < nearest_dist then
				nearest = ent
				nearest_dist = dist
			end
		end
	end

	return nearest
end

local function FindFirstValid(list, from, to, step)
	for i = from, to, step do
		local ent = list[i]
		if IsValid(ent) then return ent end
	end
	return NULL
end

-- @return entity|NULL nearest target
function BaseClass:GetNearTarget()
	if not IsValid(self.npc) then return NULL end
	return FindNearest(self.targets, self.targets_count, self.npc:GetPos())
end

function BaseClass:GetTarget(index)
	Assert.Arg(1, index, 'number|nil', 'ACTOR:GetTarget')
	if index == nil then return self:GetFirstTarget() end
	return self.targets[index] or NULL
end

function BaseClass:GetFirstTarget()
	return FindFirstValid(self.targets, 1, self.targets_count, 1)
end

function BaseClass:GetLastTarget()
	return FindFirstValid(self.targets, self.targets_count, 1, -1)
end

-- ---------------------------------------------------------------------------
-- Enemies
-- ---------------------------------------------------------------------------

-- @param ent entity enemy (NPC, NextBot or player)
-- @param reaction string|nil 'fear' makes the NPC afraid instead of hostile
-- @param always_visible boolean|nil the enemy is never forgotten when out of sight
function BaseClass:AddEnemy(ent, reaction, always_visible)
	Assert.Arg(1, ent, 'entity|actor|nil', 'ACTOR:AddEnemy')
	Assert.Arg(2, reaction, 'string|nil', 'ACTOR:AddEnemy')
	Assert.Arg(3, always_visible, 'boolean|nil', 'ACTOR:AddEnemy')

	if not self.mechanics.enemies_controller then return end
	if bgNPC.Modes.IsPeaceful() then return end

	if istable(ent) then ent = ent:GetNPC() end
	if not IsValid(ent) or ent.BGN_HasBuildMode then return end
	if not ent:IsNPC() and not ent:IsNextBot() and not ent:IsPlayer() then return end
	if not self:IsAlive() then return end

	local npc = self.npc
	if npc == ent or table_HasValueBySeq(self.enemies, ent) then return end
	if self:HasTeam(ent) then return end
	if hook_Run('BGN_AddActorEnemy', self, ent) then return end

	local relationship = reaction == 'fear' and D_FR or D_HT

	self.enemies_count = self.enemies_count + 1
	self.enemies[self.enemies_count] = ent

	if always_visible then
		self.enemies_always_visible_count = self.enemies_always_visible_count + 1
		self.enemies_always_visible[self.enemies_always_visible_count] = ent
	end

	if npc:IsNPC() then
		npc:AddEntityRelationship(ent, relationship, 99)
		npc:SetNPCState(relationship == D_HT and NPC_STATE_COMBAT or NPC_STATE_ALERT)
	end
end

-- @param ent entity|nil enemy to remove
-- @param index number|nil enemy index, takes priority over ent
-- @return number enemies count after removal
function BaseClass:RemoveEnemy(ent, index)
	Assert.Arg(2, index, 'number|nil', 'ACTOR:RemoveEnemy')

	if not self.mechanics.enemies_controller then return self.enemies_count end

	if index then ent = self.enemies[index] end
	if ent == nil then return self.enemies_count end

	if hook_Run('BGN_RemoveActorEnemy', self, ent) then return self.enemies_count end

	local old_count = self.enemies_count
	local npc = self.npc

	if ent == self.walkTarget then self.walkTarget = NULL end

	if IsValid(ent) and IsNPCEntity(npc) then
		if npc:GetEnemy() == ent then npc:SetEnemy(NULL) end
		npc:AddEntityRelationship(ent, D_NU, 99)
	end

	if index and self.enemies[index] == ent then
		table_remove(self.enemies, index)
	else
		table_RemoveByValue(self.enemies, ent)
	end

	table_RemoveByValue(self.enemies_always_visible, ent)

	self.enemies_count = #self.enemies
	self.enemies_always_visible_count = #self.enemies_always_visible

	if old_count > 0 and self.enemies_count == 0 then
		hook_Run('BGN_ResetEnemiesForActor', self)
	end

	return self.enemies_count
end

function BaseClass:RemoveAllEnemies()
	if not self.mechanics.enemies_controller then return end

	for i = self.enemies_count, 1, -1 do
		self:RemoveEnemy(nil, i)
	end

	-- Hooks may reject a removal; make sure the list is consistent anyway.
	if self.enemies_count ~= 0 then
		self.enemies = {}
		self.enemies_count = 0
		self.enemies_always_visible = {}
		self.enemies_always_visible_count = 0
		hook_Run('BGN_ResetEnemiesForActor', self)
	end
end

-- @param ent entity|actor
function BaseClass:HasEnemy(ent)
	if istable(ent) and ent.isBgnClass then ent = ent.npc end
	if not IsValid(ent) then return false end
	return table_HasValueBySeq(self.enemies, ent)
end

function BaseClass:EnemiesCount()
	return self.enemies_count
end

function BaseClass:HasNoEnemies()
	return self.enemies_count == 0
end

-- Points the NPC at the driven vehicle when the enemy player is inside one.
-- @return boolean true if the enemy was redirected to a vehicle
local function RedirectEnemyToVehicle(npc, enemy)
	local active_enemy = npc:GetEnemy()

	if IsValid(enemy) and IsValid(active_enemy) and active_enemy:IsVehicle()
		and (not enemy:IsPlayer() or enemy:GetVehicle() ~= active_enemy)
	then
		npc:AddEntityRelationship(active_enemy, D_NU, 99)
	end

	if not IsValid(enemy) or not enemy:IsPlayer() or not enemy:InVehicle() then
		return false
	end

	local vehicle = enemy:GetVehicle()
	local vehicle_parent = vehicle:GetParent()
	local new_enemy = IsValid(vehicle_parent) and vehicle_parent or vehicle

	npc:SetEnemy(new_enemy)
	npc:SetTarget(new_enemy)
	npc:UpdateEnemyMemory(new_enemy, enemy:GetPos())
	npc:AddEntityRelationship(new_enemy, D_HT, 99)

	return true
end

-- Removes dead enemies, forgets enemies that were not seen for a long time
-- and points the NPC at the nearest one.
function BaseClass:EnemiesRecalculate()
	if not self.mechanics.enemies_controller then return end

	local npc = self.npc
	if not IsValid(npc) then return end

	self.enemies_count = #self.enemies
	self.enemies_always_visible_count = #self.enemies_always_visible

	local is_npc = npc:IsNPC()
	if is_npc and RedirectEnemyToVehicle(npc, self:GetNearEnemy()) then return end

	for i = self.enemies_count, 1, -1 do
		local enemy = self.enemies[i]
		if not IsValid(enemy) or enemy:Health() <= 0 then
			self:RemoveEnemy(nil, i)
		end
	end

	if not is_npc then return end

	local enemy = self:GetNearEnemy()
	if not IsValid(enemy) then return end

	if bgNPC.Vision.HasLineOfSight(npc, enemy) or enemy.bgn_always_visible then
		npc:SetEnemy(enemy)
		npc:SetTarget(enemy)
		npc:UpdateEnemyMemory(enemy, enemy:GetPos())
		return
	end

	local WantedModule = bgNPC.Modules.Get('wanted')
	if WantedModule:HasWanted(enemy) then return end
	if table_HasValueBySeq(self.enemies_always_visible, enemy) then return end

	if npc:GetEnemyLastTimeSeen(enemy) + 20 < CurTime() then
		self:RemoveEnemy(enemy)
	end
end

function BaseClass:GetEnemy()
	return self:GetNearEnemy()
end

function BaseClass:GetFirstEnemy()
	return FindFirstValid(self.enemies, 1, self.enemies_count, 1)
end

function BaseClass:GetLastEnemy()
	return FindFirstValid(self.enemies, self.enemies_count, 1, -1)
end

function BaseClass:GetNearEnemy()
	if not IsValid(self.npc) then return NULL end
	return FindNearest(self.enemies, self.enemies_count, self.npc:GetPos())
end

-- ---------------------------------------------------------------------------
-- Physics
-- ---------------------------------------------------------------------------

function BaseClass:DropToFloor()
	local npc = self.npc
	if not IsValid(npc) then return end

	if npc:IsNPC() then
		local hull = npc:GetHullType()
		npc:SetSolid(SOLID_BBOX)
		npc:SetPos(npc:GetPos() + npc:GetUp() * 6)
		npc:SetHullType(hull)
		npc:SetHullSizeNormal()
	end

	npc:DropToFloor()
end

-- ---------------------------------------------------------------------------
-- States
-- ---------------------------------------------------------------------------

function BaseClass:StateLock(lock)
	Assert.Arg(1, lock, 'boolean|nil', 'ACTOR:StateLock')
	self.state_lock = lock or false
end

function BaseClass:IsStateLock()
	return self.state_lock
end

function BaseClass:CallStateAction(state_name, func_name, ...)
	Assert.Arg(1, state_name, 'string|nil', 'ACTOR:CallStateAction')
	Assert.NonEmptyString(2, func_name, 'ACTOR:CallStateAction')
	return bgNPC.States.Call(state_name or self.state_data.state, func_name, self, ...)
end

-- Switches the actor to a new state.
-- @param state string|nil state name, nil means 'none'
-- @param data table|nil state data
-- @param forced boolean|nil skip locks, delays and validators
-- @return table|nil new state data, or nil if the change was rejected
function BaseClass:SetState(state, data, forced)
	Assert.Arg(1, state, 'string|nil', 'ACTOR:SetState')
	Assert.Arg(2, data, 'table|nil', 'ACTOR:SetState')
	Assert.Arg(3, forced, 'boolean|nil', 'ACTOR:SetState')

	if not self.mechanics.states_controller then return end
	if not self:IsAlive() then return end

	state = state or 'none'
	data = data or {}

	if not forced then
		if state == 'ignore' then return end
		if self.data.disable_states then return end
		if self.state_lock then return end
		if self.state_data.state == state then return end
		if self.state_delay > CurTime() then return end
	end

	local current_state = self.state_data.state
	local current_data = self.state_data.data

	if self:CallStateAction(nil, 'not_stop', current_state, current_data, state, data) and not forced then
		return
	end

	local hook_result = hook_Run('BGN_PreSetState', self, state, data)
	if isbool(hook_result) then
		if hook_result then return end
	elseif isstring(hook_result) then
		state = hook_result
	elseif istable(hook_result) then
		state = hook_result.state or state
		data = hook_result.data or data
	end

	if not forced and bgNPC.States.HasAction(state, 'validator')
		and not self:CallStateAction(state, 'validator', state, data)
	then
		return
	end

	local new_state, new_data = self:CallStateAction(state, 'pre_start', state, data)
	if new_state == true then return end

	state = isstring(new_state) and new_state or state
	data = istable(new_data) and new_data or data

	if SERVER then
		self:StopWalk()
		self.anim_action = nil
		self:ResetSequence()
	end

	self:CallStateAction(current_state, 'stop', current_state, current_data)

	self.old_state = self.state_data
	self.state_data = { state = state, data = data }

	self:CallStateAction(state, 'start', state, data)
	hook_Run('BGN_SetState', self, state, data)

	return self.state_data
end

function BaseClass:UpdateStateData(data)
	Assert.Arg(1, data, 'table', 'ACTOR:UpdateStateData')
	self.state_data.data = data
end

-- @param state string|table state name or list of names
function BaseClass:HasState(state)
	local current_state = self.state_data.state

	if isstring(state) then return current_state == state end

	if istable(state) then
		for i = 1, #state do
			if current_state == state[i] then return true end
		end
	end

	return false
end

function BaseClass:GetOldState()
	return self.old_state.state
end

function BaseClass:GetOldStateData()
	return self.old_state.data
end

function BaseClass:GetState()
	return self.state_data.state
end

function BaseClass:GetStateData()
	return self.state_data.data
end

function BaseClass:EqualStateGroup(group_name)
	return self:HasStateGroup(self:GetState(), group_name)
end

function BaseClass:GetStateGroupName()
	return bgNPC.States.GetGroup(self:GetState())
end

-- @param state_name string
-- @param group_name string|table group name or list of names
function BaseClass:HasStateGroup(state_name, group_name)
	local state_group = bgNPC.States.GetGroup(state_name)

	if isstring(group_name) then return state_group == group_name end

	if istable(group_name) then
		for i = 1, #group_name do
			if state_group == group_name[i] then return true end
		end
	end

	return false
end

-- ---------------------------------------------------------------------------
-- Movement
-- ---------------------------------------------------------------------------

-- @param move_type string|number|nil 'walk', 'run' or a schedule id
function BaseClass:SetWalkType(move_type)
	Assert.Arg(1, move_type, 'string|number|nil', 'ACTOR:SetWalkType')

	if isnumber(move_type) then
		self.walkType = move_type
	elseif move_type == 'run' then
		self.walkType = SCHED_FORCED_GO_RUN
	else
		self.walkType = SCHED_FORCED_GO
	end
end

function BaseClass:StopWalk()
	if self.walkPos or IsValid(self.walkTarget) then
		self:ClearSchedule()
	end

	self.walkTarget = NULL
	self.walkPath = {}
	self.walkPos = nil
	self.walkUpdatePathDelay = 0
	self.pathType = nil
	self.isChase = false
	self:SetWalkType()
end

function BaseClass:WalkDestinationExists()
	return self.walkPos ~= nil or IsValid(self.walkTarget)
end

local function FinishWalk(actor, pos, move_type)
	return hook_Run('BGN_ActorFinishedWalk', actor, pos, move_type or 'walk')
end

-- Starts following an entity. The path is rebuilt periodically by the movement service.
-- @param target entity|nil target to follow, nil stops walking
function BaseClass:WalkToTarget(target, move_type, path_type)
	Assert.Arg(1, target, 'entity|nil', 'ACTOR:WalkToTarget')
	Assert.Arg(3, path_type, 'string|nil', 'ACTOR:WalkToTarget')

	if not self.mechanics.movement_controller then return end
	if not IsValid(self.npc) or self.npc:IsNextBot() then return end

	if not IsValid(target) then
		self:StopWalk()
		return
	end

	local target_pos = target:GetPos()
	if self.npc:GetPos():DistToSqr(target_pos) <= MOVEMENT_FINISHED_DIST_SQR then
		FinishWalk(self, target_pos, move_type)
		return
	end

	self:SetWalkType(move_type)

	if self.walkTarget == target then return end

	self.pathType = path_type
	self.walkUpdatePathDelay = 0
	self.walkPos = nil
	self.walkPath = {}
	self.walkTarget = target

	if IsValid(self:GetVehicleAI()) then
		self.isChase = true
		self:WalkToPos(target_pos, move_type, path_type)
	end
end

-- Builds a path to the position and starts walking.
-- @param pos vector|node|nil destination, nil stops walking
function BaseClass:WalkToPos(pos, move_type, path_type)
	Assert.Arg(1, pos, 'vector|node|nil', 'ACTOR:WalkToPos')
	Assert.Arg(3, path_type, 'string|nil', 'ACTOR:WalkToPos')

	if istable(pos) then pos = pos:GetPos() end

	if not self.mechanics.movement_controller then return end

	if pos == nil then
		self:StopWalk()
		return
	end

	local npc = self.npc
	if not IsValid(npc) or npc:IsNextBot() then return end
	if self.walkPos == pos then return end

	local pre_set_result = hook_Run('BGN_PreSetWalkPos', self, pos, move_type, path_type)
	if pre_set_result == false then return end
	if isvector(pre_set_result) then pos = pre_set_result end

	if npc:GetPos():DistToSqr(pos) <= MOVEMENT_FINISHED_DIST_SQR then
		FinishWalk(self, pos, move_type)
		return
	end

	local walk_path = {}

	if not self:InVehicle() then
		if npc:IsEFlagSet(EFL_NO_THINK_FUNCTION) then return end

		walk_path = bgNPC.Points.FindPath(npc:GetPos(), pos, nil, path_type)
		if #walk_path == 0 then return end

		self.pathType = path_type
		self:SetWalkType(move_type)
	else
		local decentvehicle = self:GetVehicleAI()
		if not IsValid(decentvehicle) then
			bgNPC.Util.Log('Trying to build a path for a vehicle that doesn\'t exist', 'ACTOR:WalkToPos')
			return
		end

		local route = DecentVehicleDestination.GetRouteVector(decentvehicle:GetPos(), pos)
		if not route then return end

		decentvehicle.WaypointList = route
		decentvehicle.Waypoint = nil
		decentvehicle.NextWaypoint = nil

		for i = 1, #route do
			walk_path[i] = route[i].Target
		end
	end

	if not self.isChase then
		self.walkTarget = NULL
	end

	self.walkPos = pos
	self.walkPath = walk_path

	hook_Run('BGN_ActorSetWalkPath', self, walk_path, pos)
end

-- Returns true once per period for the given tag. Used to throttle state logic.
function BaseClass:CheckMoveUpdate(tag, time)
	Assert.Arg(1, tag, 'string', 'ACTOR:CheckMoveUpdate')
	Assert.Arg(2, time, 'number|nil', 'ACTOR:CheckMoveUpdate')

	self.checkMoveUpdateData = self.checkMoveUpdateData or {}

	local entry = self.checkMoveUpdateData[tag]
	local is_update = entry ~= nil and entry.state

	if is_update or not entry then
		self.checkMoveUpdateData[tag] = { state = false, time = CurTime() + (time or 0) }
	end

	return is_update
end

function BaseClass:GetWalkTarget()
	return self.walkTarget
end

function BaseClass:GetWalkPos()
	return self.walkPos
end

function BaseClass:Walking()
	return IsNPCEntity(self.npc) and self.npc:IsMoving()
end

local function UpdateVehicleMovement(actor, walk_pos)
	local vehicle = actor:GetVehicle()
	if not IsValid(vehicle) then return end
	if vehicle:GetPos():DistToSqr(walk_pos) > MOVEMENT_FINISHED_DIST_SQR then return end

	if not FinishWalk(actor, walk_pos, actor.walkType) then
		actor:WalkToPos(nil)
	end
end

-- Moves the NPC along the current path. Called by the movement service.
function BaseClass:UpdateMovement()
	if not self.mechanics.movement_controller then return end
	if self.is_animated or not self:IsAlive() then return end

	local walk_target = self.walkTarget
	local has_target = IsValid(walk_target)
	local walk_pos = has_target and walk_target:GetPos() or self.walkPos

	if not walk_pos or self:IsAnimationPlayed() then return end

	if self:InVehicle() then
		UpdateVehicleMovement(self, walk_pos)
		return
	end

	local npc = self.npc
	if not npc:IsNPC() then return end

	local npc_pos = npc:GetPos()
	local walk_path = self.walkPath
	local next_position
	local reached_node = false

	if #walk_path ~= 0 then
		next_position = walk_path[1]

		if npc_pos:DistToSqr(next_position) <= MOVEMENT_FINISHED_DIST_SQR then
			table_remove(walk_path, 1)

			if #walk_path == 0 and not has_target then
				if not FinishWalk(self, next_position, self.walkType) then
					self:WalkToPos(nil)
				end
				return
			end

			next_position = walk_path[1]
			reached_node = true
		end
	end

	if has_target then
		-- Close enough to the followed entity, there is no need to push into it.
		if npc_pos:DistToSqr(walk_pos) <= MOVEMENT_FINISHED_DIST_SQR then return end
		-- No path to the target (yet) - let the engine navigate straight to it.
		next_position = next_position or walk_pos
	end

	if not reached_node then
		if npc:IsEFlagSet(EFL_NO_THINK_FUNCTION) then return end
		if self.waitUpdateMovementDelay > CurTime() then return end
		self.waitUpdateMovementDelay = CurTime() + MOVEMENT_UPDATE_PERIOD
	end

	if self:IsExecutingCombatSchedule() then return end

	if next_position then npc:SetLastPosition(next_position) end

	self:SetSchedule(self.walkType)
end

-- ---------------------------------------------------------------------------
-- Relationships and teams
-- ---------------------------------------------------------------------------

-- Returns the relationship from the actor's config for the given entity or actor.
function BaseClass:GetRelationship(value, default)
	local relationship = self.relationship
	local actor

	if istable(value) and value.isBgnClass then
		actor = value
	elseif IsValid(value) then
		actor = bgNPC.Actors.Get(value)
	end

	if actor then
		if self:HasTeam(actor) then
			return relationship['@team'] or default
		end
		return relationship['@actor'] or default
	end

	if not IsValid(value) or not isentity(value) then return default end

	local by_class = relationship[value:GetClass()]
	if by_class then return by_class end

	if value:IsNPC() or value:IsNextBot() then
		return relationship['@npc'] or default
	elseif value:IsPlayer() then
		return relationship['@player'] or default
	end

	return default
end

local function TeamsIntersect(team_a, team_b)
	for i = 1, #team_a do
		local name = team_a[i]
		for k = 1, #team_b do
			if name == team_b[k] then return true end
		end
	end
	return false
end

-- Checks whether the value belongs to one of the actor's teams.
-- @param value string|entity|actor|table team name, entity, actor or list of team names
function BaseClass:HasTeam(value)
	local own_team = self.data and self.data.team
	if not own_team or value == nil then return false end

	if isstring(value) then
		return table_HasValueBySeq(own_team, value)
	end

	if isentity(value) then
		if not IsValid(value) then return false end

		if value:IsPlayer() then
			return table_HasValueBySeq(own_team, 'player')
				or bgNPC.Modules.Get('team_parent'):HasParent(value, self)
		end

		value = bgNPC.Actors.Get(value)
		if not value then return false end
	end

	if not istable(value) then return false end

	if value.isBgnClass then
		local data = value:GetData()
		value = data and data.team
		if not istable(value) then return false end
	end

	if not table_isArray(value) then return false end

	return TeamsIntersect(own_team, value)
end

function BaseClass:SetTeam(team_data)
	Assert.Arg(1, team_data, 'table|nil', 'ACTOR:SetTeam')
	self.data.team = team_data
end

function BaseClass:AddTeam(team_name)
	Assert.NonEmptyString(1, team_name, 'ACTOR:AddTeam')

	self.data.team = self.data.team or {}
	if not table_HasValueBySeq(self.data.team, team_name) then
		table_insert(self.data.team, team_name)
	end
end

-- ---------------------------------------------------------------------------
-- Movement points
-- ---------------------------------------------------------------------------

local function FindPointByDistanceTo(actor, pos, radius, want_far)
	if not actor:IsAlive() then return nil end

	local points = bgNPC.Points.GetInRadius(actor.npc:GetPos(), radius or 500)
	local result, result_dist

	for i = 1, #points do
		local position = points[i].position
		local dist = position:DistToSqr(pos)
		if not result_dist or (want_far and dist > result_dist) or (not want_far and dist < result_dist) then
			result = position
			result_dist = dist
		end
	end

	return result
end

-- Returns the movement point within the radius that is farthest from pos.
function BaseClass:GetDistantPointToPoint(pos, radius)
	Assert.Arg(1, pos, 'vector', 'ACTOR:GetDistantPointToPoint')
	Assert.Arg(2, radius, 'number|nil', 'ACTOR:GetDistantPointToPoint')
	return FindPointByDistanceTo(self, pos, radius, true)
end

-- Returns the movement point within the radius that is closest to pos.
function BaseClass:GetClosestPointToPoint(pos, radius)
	Assert.Arg(1, pos, 'vector', 'ACTOR:GetClosestPointToPoint')
	Assert.Arg(2, radius, 'number|nil', 'ACTOR:GetClosestPointToPoint')
	return FindPointByDistanceTo(self, pos, radius, false)
end

function BaseClass:GetDistantPointInRadius(radius)
	Assert.Arg(1, radius, 'number|nil', 'ACTOR:GetDistantPointInRadius')
	if not self:IsAlive() then return nil end
	return bgNPC.Points.GetDistantInRadius(self.npc:GetPos(), radius)
end

function BaseClass:GetClosestPointInRadius(radius)
	Assert.Arg(1, radius, 'number|nil', 'ACTOR:GetClosestPointInRadius')
	if not self:IsAlive() then return nil end
	return bgNPC.Points.GetClosestInRadius(self.npc:GetPos(), radius)
end

-- ---------------------------------------------------------------------------
-- Static animations
-- ---------------------------------------------------------------------------

function BaseClass:IsValidSequence(sequence_name)
	return isstring(sequence_name) and IsValid(self.npc) and self.npc:LookupSequence(sequence_name) ~= -1
end

-- Plays a sequence, holding the NPC in a scripted state while it plays.
-- @param sequence_name string
-- @param loop boolean|nil
-- @param loop_time number|nil loop duration, 0 or nil - endless
-- @param action function|nil called with the actor; when it returns true on stop, the stop is rejected
-- @return boolean true if the animation is playing
function BaseClass:PlayStaticSequence(sequence_name, loop, loop_time, action)
	Assert.Arg(1, sequence_name, 'string|nil', 'ACTOR:PlayStaticSequence')
	Assert.Arg(2, loop, 'boolean|nil', 'ACTOR:PlayStaticSequence')
	Assert.Arg(3, loop_time, 'number|nil', 'ACTOR:PlayStaticSequence')
	Assert.Arg(4, action, 'function|nil', 'ACTOR:PlayStaticSequence')

	if not self.mechanics.animator_controller
		or not self:IsNPC()
		or not self:IsValidSequence(sequence_name)
	then
		if action then action(self) end
		return false
	end

	if self:HasSequence(sequence_name) and (
		(self.anim_is_loop and not self:IsSequenceLoopFinished())
		or (not self.anim_is_loop and not self:IsSequenceFinished())
	) then
		if action then action(self) end
		return true
	end

	if hook_Run('BGN_PreNPCStartAnimation', self, sequence_name, loop, loop_time) == false then
		return false
	end

	local npc = self.npc
	local now = RealTime()
	local sequence = npc:LookupSequence(sequence_name)

	self.anim_is_loop = loop or false
	self.anim_name = string_lower(sequence_name)

	if loop_time and loop_time ~= 0 then
		self.loop_time = now + loop_time
		self.loop_time_normal = loop_time
	else
		self.loop_time = 0
	end

	self.anim_time = now + npc:SequenceDuration(sequence)
	self.anim_time_normal = self.anim_time - now
	self.is_animated = true
	self.anim_action = action
	self.anim_sequence = sequence

	npc:SetNPCState(NPC_STATE_SCRIPT)
	npc:SetSchedule(SCHED_SLEEP)
	npc:ResetSequenceInfo()
	npc:ResetSequence(sequence)
	npc:PhysWake()

	self.npc_schedule = npc:GetCurrentSchedule()
	self.npc_state = npc:GetNPCState()

	hook_Run('BGN_StartedNPCAnimation', self, sequence_name, loop, loop_time)

	return true
end

function BaseClass:SetNextSequence(sequence_name, loop, loop_time, action)
	Assert.Arg(1, sequence_name, 'string', 'ACTOR:SetNextSequence')
	Assert.Arg(4, action, 'function|nil', 'ACTOR:SetNextSequence')

	if not self.mechanics.animator_controller then
		if action then action(self) end
		return
	end

	self.next_anim = {
		sequence_name = sequence_name,
		loop = loop,
		loop_time = loop_time,
		action = action,
	}
end

function BaseClass:HasSequence(sequence_name)
	return isstring(sequence_name) and self.anim_name == string_lower(sequence_name)
end

function BaseClass:IsAnimationPlayed()
	if self.is_animated then return true end
	return IsValid(self.npc) and bgNPC.Animator.IsPlaying(self.npc)
end

function BaseClass:IsLoopSequence()
	return self.anim_is_loop
end

function BaseClass:IsSequenceLoopFinished()
	if not self:IsAnimationPlayed() then return true end
	if not self.anim_is_loop then return true end
	if self.loop_time == 0 then return false end

	local now = RealTime()
	self.loop_time_normal = math.max(0, self.loop_time - now)

	return self.loop_time < now
end

function BaseClass:IsSequenceFinished()
	if not self:IsAnimationPlayed() then return true end

	local now = RealTime()
	self.anim_time_normal = math.max(0, self.anim_time - now)

	return self.anim_time <= now
end

function BaseClass:PlayNextStaticSequence()
	if not self.mechanics.animator_controller then return false end

	local next_anim = self.next_anim
	if not next_anim or next_anim.sequence_name == self.anim_name then return false end

	self.next_anim = nil
	self:PlayStaticSequence(next_anim.sequence_name, next_anim.loop, next_anim.loop_time)

	if next_anim.action then next_anim.action(self) end

	return true
end

-- Stops the current static animation and returns the NPC to AI control.
function BaseClass:ResetSequence()
	if self.anim_action and self.anim_action(self) then
		bgNPC.Util.Log('Reject: ACTOR:ResetSequence')
		return
	end

	self.anim_name = ''
	self.is_animated = false
	self.next_anim = nil
	self.anim_sequence = nil
	self.anim_action = nil

	if IsValid(self.npc) then bgNPC.Animator.Stop(self.npc) end

	self:ClearSchedule()
end

BaseClass.StopStaticSequence = BaseClass.ResetSequence

-- ---------------------------------------------------------------------------
-- Fear and help
-- ---------------------------------------------------------------------------

function BaseClass:FearScream()
	if not self.mechanics.fear_scream then return end
	if not self:IsAlive() then return end

	local gender = GenderByModel(self.npc:GetModel())
	local screams = gender == 'female' and FEMALE_SCREAMS
		or gender == 'male' and MALE_SCREAMS
		or ANY_SCREAMS

	self.npc:EmitSound(table_RandomBySeq(screams), 100, 100, 1, CHAN_AUTO)
end

function BaseClass:Fear()
	if not self.mechanics.fear then return end
	if not self:IsAlive() or not self:IsNPC() then return end

	self.npc:SetNPCState(NPC_STATE_ALERT)
	self.npc:SetSchedule(SCHED_COWER)
end

-- Screams and asks nearby teammates who can see the enemy to protect the actor.
function BaseClass:CallForHelp(enemy)
	Assert.Arg(1, enemy, 'entity|nil', 'ACTOR:CallForHelp')

	if not self.mechanics.call_for_help then return end
	if not IsValid(enemy) or not self:IsAlive() then return end
	if hook_Run('BGN_PreCallForHelp', self, enemy) then return end

	self:FearScream()

	local near_actors = bgNPC.Actors.GetInRadius(self.npc:GetPos(), 1000)
	for i = 1, #near_actors do
		local near_actor = near_actors[i]
		if near_actor ~= self
			and near_actor:IsAlive()
			and near_actor:HasTeam(self)
			and bgNPC.Vision.HasLineOfSight(near_actor.npc, enemy)
		then
			near_actor:SetState(near_actor:GetReactionForProtect())
			near_actor:AddEnemy(enemy)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Weapons
-- ---------------------------------------------------------------------------

function BaseClass:CreateFakePlayerMethodsForNPC()
	local npc = self.npc
	if not IsValid(npc) then return end

	-- Fixes some weapon mods that expect player methods on the owner.
	if not isfunction(npc.LagCompensation) then
		function npc:LagCompensation() end
	end

	if not isfunction(npc.GetViewModel) then
		function npc:GetViewModel() end
	end
end

function BaseClass:IsMeleeWeapon()
	if not self:IsAlive() then return false end

	local weapon = self:GetActiveWeapon()
	local weapon_class = IsValid(weapon) and weapon:GetClass() or self.weapon

	-- No weapon in hand and no intended weapon: treat as ranged, so the
	-- defense state holds distance instead of rushing the enemy.
	if not weapon_class then return false end

	return table_HasValueBySeq(bgNPC.cfg.melee_weapons, weapon_class)
end

-- Returns the weapon class assigned to the actor on creation.
function BaseClass:GetActorWeapon()
	return self.weapon
end

function BaseClass:GetActiveWeapon()
	if not self:IsAlive() or not self:IsNPC() then return NULL end
	local weapon = self.npc:GetActiveWeapon()
	return IsValid(weapon) and weapon or NULL
end

function BaseClass:HasActiveWeapon()
	return IsValid(self:GetActiveWeapon())
end

-- Gives and selects a weapon. Without a class, the actor's own weapon is used.
function BaseClass:PrepareWeapon(weapon_class, switching)
	Assert.Arg(1, weapon_class, 'string|nil', 'ACTOR:PrepareWeapon')
	Assert.Arg(2, switching, 'boolean|nil', 'ACTOR:PrepareWeapon')
	bgNPC.Combat.EquipActor(self, weapon_class, switching)
end

function BaseClass:FoldWeapon()
	if self.disable_fold_weapon then return end
	local weapon = self:GetActiveWeapon()
	if IsValid(weapon) then weapon:Remove() end
end

function BaseClass:GiveWeapon(weapon_class)
	Assert.Arg(1, weapon_class, 'string|nil', 'ACTOR:GiveWeapon')
	self.weapon = weapon_class
end

-- ---------------------------------------------------------------------------
-- Vehicles
-- ---------------------------------------------------------------------------

local function ResolveVehicleGroup(actor)
	local vehicle_group = actor.data.vehicle_group
	if vehicle_group then return vehicle_group end
	if actor:HasTeam('police') then return 'police' end
	if actor:HasTeam('taxi') then return 'taxi' end
	return nil
end

function BaseClass:EnterVehicle(vehicle)
	Assert.Arg(1, vehicle, 'entity', 'ACTOR:EnterVehicle')

	if not self.mechanics.use_vehicle then return end
	if not DecentVehicleDestination then return end
	if not IsValid(vehicle) or not vehicle:IsVehicle() then return end

	local vehicle_provider = BGN_VEHICLE:GetVehicleProvider(vehicle)
	if not vehicle_provider then
		vehicle_provider = BGN_VEHICLE:Instance(vehicle, ResolveVehicleGroup(self), self:GetType())
		if not vehicle_provider then return end
		BGN_VEHICLE:AddToList(vehicle_provider)
	end

	local npc = self.npc

	bgNPC.Util.EntityTimer(vehicle, 'bgn_actor_enter_vehicle', 0.5, 1, function(self_vehicle)
		if not IsValid(self_vehicle) or not self:IsAlive() then return end

		if not vehicle_provider:GetDriver() then
			vehicle_provider:SetDriver(self)
		elseif not vehicle_provider:AddPassenger(self) then
			return
		end

		self.eternal = true
		self.vehicle = vehicle_provider
		self.walkUpdatePathDelay = 0

		npc:SetNoDraw(true)
		npc:SetNW2Bool('bgn_vehicle_entered', true)
		npc:SetCollisionGroup(COLLISION_GROUP_WORLD)
		npc:SetPos(self_vehicle:GetPos() + self_vehicle:GetUp() * 300)
		npc:SetModelScale(0)
		npc:SetParent(self_vehicle)
		npc:AddEFlags(EFL_NO_THINK_FUNCTION)

		hook_Run('BGN_OnEnterVehicle', self, vehicle_provider)
	end)
end

local EXIT_TRACE_OFFSET = Vector(0, 0, 500)
local EXIT_FLOOR_OFFSET = Vector(0, 0, 15)

local function FindVehicleExitPos(vehicle, npc)
	local min, max = vehicle:GetModelBounds()
	local side_dist = min:Distance(max) / 2
	local pos = vehicle:GetPos()
	local forward, right, up = vehicle:GetForward(), vehicle:GetRight(), vehicle:GetUp()
	local side = bgNPC.Util.Chance(50) and -side_dist or side_dist
	local exit_pos = pos + up * 50

	for _ = 1, 4 do
		exit_pos = pos + right * side + forward * math_random(-100, 100) + up * 50

		local tr = util.TraceLine({
			start = exit_pos,
			endpos = exit_pos - EXIT_TRACE_OFFSET,
			filter = npc,
		})

		if tr.Hit then exit_pos = tr.HitPos + EXIT_FLOOR_OFFSET end

		if util.IsInWorld(exit_pos) and #ents.FindInSphere(exit_pos, 15) <= 2 then
			break
		end
	end

	return exit_pos
end

function BaseClass:ExitVehicle()
	if not self.mechanics.use_vehicle then return end
	if not DecentVehicleDestination then return end

	local vehicle_provider = self.vehicle
	local npc = self.npc

	if vehicle_provider and vehicle_provider:IsValid() and IsValid(npc) then
		hook_Run('BGN_OnExitVehicle', self, vehicle_provider)

		npc:SetNW2Bool('bgn_vehicle_entered', false)
		npc:SetParent(nil)
		npc:SetPos(FindVehicleExitPos(vehicle_provider:GetVehicle(), npc))
		npc:SetAngles(Angle(0, npc:GetAngles().y, 0))
		npc:SetCollisionGroup(self.collision_group)
		npc:SetModelScale(self.model_scale)
		npc:RemoveEFlags(EFL_NO_THINK_FUNCTION)
		npc:PhysWake()
		npc:SetNoDraw(false)
		self:DropToFloor()
	end

	if vehicle_provider then
		if vehicle_provider.driver == self then
			vehicle_provider:SetDriver(nil)
		else
			vehicle_provider:RemovePassenger(self)
		end
	end

	self.eternal = false
	self.vehicle = nil
	self.vehicle_data = {}
end

function BaseClass:InVehicle()
	if SERVER then
		return self.vehicle ~= nil and self.vehicle:IsValid()
	end
	return IsValid(self.npc) and self.npc:GetNW2Bool('bgn_vehicle_entered', false)
end

function BaseClass:GetVehicle()
	if not self.vehicle or not self:InVehicle() then return nil end
	return self.vehicle:GetVehicle()
end

function BaseClass:GetVehicleAI()
	if not self.vehicle or not self:InVehicle() then return nil end
	return self.vehicle:GetVehicleAI()
end

-- ---------------------------------------------------------------------------
-- Speech
-- ---------------------------------------------------------------------------

function BaseClass:VoiceSay(sound_path, sound_level, pitch_percent, volume, channel, sound_flags, dsp)
	Assert.Arg(1, sound_path, 'string|nil', 'ACTOR:VoiceSay')

	if not sound_path or not self:IsAlive() then return end

	self.npc:EmitSound(sound_path,
		sound_level or 75,
		pitch_percent or 100,
		volume or 1,
		channel or CHAN_AUTO,
		sound_flags or 0,
		dsp or 0)
end

function BaseClass:Say(say_text, say_time, voice_sound, animation_sequence)
	Assert.Arg(1, say_text, 'string|nil', 'ACTOR:Say')
	Assert.Arg(2, say_time, 'number|nil', 'ACTOR:Say')

	if say_text then
		Net.Send('bgn_actor_text_say', nil, self.uid, say_text, say_time or 5)
	end

	self:VoiceSay(voice_sound)
	if animation_sequence then self:PlayStaticSequence(animation_sequence) end
end

function BaseClass:SayReplic(replic_id, replic_index, say_time, voice_sound, animation_sequence)
	Assert.Arg(1, replic_id, 'string', 'ACTOR:SayReplic')
	Assert.Arg(2, replic_index, 'number', 'ACTOR:SayReplic')

	local replics = bgNPC.cfg.replics[replic_id]
	if not replics or not replics[replic_index] then return end

	Net.Send('bgn_actor_text_say_replic', nil, self.uid, replic_id, replic_index, say_time or 5)
	self:VoiceSay(voice_sound)
	if animation_sequence then self:PlayStaticSequence(animation_sequence) end
end

-- ---------------------------------------------------------------------------
-- Think
-- ---------------------------------------------------------------------------

function BaseClass:Think()
	if self:GetState() == 'none' and self.data.at_random and not self:InVehicle() then
		self:RandomState()
	end
end

BaseClass.__index = BaseClass

return BaseClass

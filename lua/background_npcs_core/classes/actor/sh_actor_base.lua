local bgNPC = bgNPC
local SERVER = SERVER
local CLIENT = CLIENT
local EFL_NO_THINK_FUNCTION = EFL_NO_THINK_FUNCTION
local SCHED_FORCED_GO = SCHED_FORCED_GO
local SCHED_FORCED_GO_RUN = SCHED_FORCED_GO_RUN
local SOLID_BBOX = SOLID_BBOX
local CurTime = CurTime
local Vector = Vector
local IsValid = IsValid
local ipairs = ipairs
local istable = istable
local isentity = isentity
local isnumber = isnumber
local isstring = isstring
local type = type
local tobool = tobool
local isfunction = isfunction
local table_remove = table.remove
local table_RandomOpt = table.RandomOpt
local table_RandomBySeq = table.RandomBySeq
local table_HasValueBySeq = table.HasValueBySeq
local table_RemoveByValue = table.RemoveByValue
local table_Copy = table.Copy
local table_Add = table.Add
local table_insert = table.insert
local string_find = string.find
local string_lower = string.lower
local hook_Run = hook.Run
local snet_Invoke = snet.Invoke
local snet_InvokeAll = snet.InvokeAll
local math_random = math.random
--
local vector_0_0_0 = Vector(0, 0, 0)
local male_scream = {
	'ambient/voices/m_scream1.wav',
	'vo/coast/bugbait/sandy_help.wav',
	'vo/npc/male01/help01.wav',
	'vo/Streetwar/sniper/male01/c17_09_help01.wav',
	'vo/Streetwar/sniper/male01/c17_09_help02.wav',
	'vo/npc/male01/no01.wav',
	'vo/npc/male01/no02.wav',
}

local female_scream = {
	'ambient/voices/f_scream1.wav',
	'vo/canals/arrest_helpme.wav',
	'vo/npc/female01/help01.wav',
	'vo/npc/female01/help01.wav',
	'vo/npc/female01/no01.wav',
	'vo/npc/female01/no02.wav',
}

local schedule_white_list = {
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
}

-- local _movement_finished_distance = 250
-- local _movement_finished_distance = 10000
local _movement_finished_distance = 150 ^ 2
local _collision_min_bounds = Vector(13, 13, 72)
local _collision_max_bounds = Vector(_collision_min_bounds.x * -1, _collision_min_bounds.y * -1, 0)

local BaseClass = {}

function BaseClass:SetStateDelay(time)
	self.state_delay = CurTime() + time
end

function BaseClass:IsStateDelay()
	return self.state_delay > CurTime()
end

function BaseClass:ResetStateDelay()
	self.state_delay = 0
end

function BaseClass:SyncFunction(name, ply, data)
	if CLIENT then return end
	if not self:IsAlive() then return end

	if ply then
		if IsValid(ply) then
			snet_Invoke(name, ply, self.uid, data)
		end
	else
		snet_InvokeAll(name, self.uid, data)
	end
end

function BaseClass:SetName(name)
	self.info.name = name
end

function BaseClass:GetName()
	return self.info.name
end

function BaseClass:SetGender(gender_name)
	gender_name = gender_name or 'unknown'
	self.info.gender = gender_name
end

function BaseClass:GetGender()
	return self.info.gender ~= nil and self.info.gender or 'unknown'
end

function BaseClass:GetGenderByModel()
	local gender = 'unknown'

	local npc = self.npc
	if not IsValid(npc) then return gender end

	local model = npc:GetModel()
	if not model then return gender end

	if tobool(string_find(model, 'female_*')) then
		return 'female'
	elseif tobool(string_find(model, 'male_*')) then
		return 'male'
	end

	return gender
end

-- Sets the random state of the NPC from the "at_random" table.
function BaseClass:RandomState()
	if not hook_Run('PreRandomState', self) then
		local state = self:GetRandomState()
		if state ~= 'none' and self:GetState() ~= state then
			self:SetState(state)
		end
	end
end

-- Gets a random identifier from the "at_random" table.
-- ? The result depends on the set weights. The higher the value, the greater the chance of falling out.
-- @return string identifier state identifier
function BaseClass:GetRandomState()
	if self.data.at_random == nil then
		return 'none'
	end

	local probability = math_random(1, self.data.at_random_range or 100)
	local percent, state = table_RandomOpt(self.data.at_random)

	if probability > percent then
		local last_percent = 0

		for _state, _percent in next, self.data.at_random do
			if _percent > last_percent then
				percent = _percent
				state = _state
				last_percent = _percent
			end
		end
	end

	state = state or 'none'

	return state
end

function BaseClass:Health()
	if IsValid(self.npc) and self.npc.Health then return self.npc:Health() end
	return 0
end

if SERVER then
	-- Checks if the actor is alive or not.
	-- @return boolean is_alive return true if the actor is alive, otherwise false
	function BaseClass:IsAlive()
		-- local vehicle_provider = self.vehicle
		-- if vehicle_provider and not vehicle_provider:IsDestroyed() then
		-- 	return true
		-- end

		local npc = self.npc
		if not IsValid(npc) or (npc.Health and npc:Health() <= 0) or (npc:IsNPC()
			and npc.IsCurrentSchedule and npc:IsCurrentSchedule(SCHED_DIE)
		) then
			self:RemoveActor()
			return false
		end
		return true
	end
else
	-- local ents_FindByClass = ents.FindByClass
	-- local table_WhereHasValueBySeq = table.WhereHasValueBySeq

	-- Checks if the actor is alive or not.
	--! The client has a simpler and less reliable check.
	-- @return boolean is_alive return true if the actor is alive, otherwise false
	function BaseClass:IsAlive()
		local npc = self.npc
		if not IsValid(npc) or (npc.Health and npc:Health() <= 0) then
			-- local entities = ents_FindByClass('npc_decentvehicle_passenger')
			-- if #entities ~= 0 and table_WhereHasValueBySeq(entities, function(_, ent)
			-- 	return IsValid(ent) and ent:GetNWString('actor_uid') == self.uid
			-- end) then
			-- 	return true
			-- end
			self:RemoveActor()
			return false
		end
		return true
	end
end

function BaseClass:RemoveActor()
	bgNPC:RemoveNPC(self.npc)
end

function BaseClass:Remove()
	bgNPC:RemoveNPC(self.npc)
	if self:IsValid() then self.npc:Remove() end
end

-- Sets the reaction to the event.
-- ? Used in system computing, and does nothing by itself.
-- @param reaction string reaction to event
function BaseClass:SetReaction(reaction)
	if self.reaction ~= reaction then self.reaction = reaction end
end

-- Will return the last result specified in the reaction variable.
-- @return string reaction last set reaction
function BaseClass:GetLastReaction()
	return self.reaction
end

function BaseClass:IsNPC()
	if not self:IsValid() then return false end
	return self.npc:IsNPC()
end

function BaseClass:IsNextBot()
	if not self:IsValid() then return false end
	return self.npc:IsNextBot()
end

-- Returns the entity of the actor's NPC.
-- ! Under certain circumstances, it can return NULL, it is recommended to use the IsAlive method before receiving the NPC.
-- @return entity npc npc entity
function BaseClass:GetNPC()
	return self.npc
end

-- Will return the actor's data specified in the config.
-- ! The data is bound to the actor. If you update the config, then the data will not be updated for the already created actors.
-- @return table actor_data actor data from config
function BaseClass:GetData()
	return self.data
end

-- Returns the real NPC class that is associated with the actor.
-- @return string npc_class npc class
function BaseClass:GetClass()
	return self.class
end

-- Returns the npc type specified in the config.
-- ? For example - citizen
-- @return string actor_type type of actor from config
function BaseClass:GetType()
	return self.type
end

-- Checks the existence of an NPC entity.
-- @return boolean is_valid_npc will return true if the NPC exists, otherwise false
function BaseClass:IsValid()
	return IsValid(self.npc)
end

-- Clears NPC schedule data and synchronizes changes for clients.
function BaseClass:ClearSchedule()
	if not self:IsNPC() then return end

	self.npc:SetNPCState(NPC_STATE_IDLE)
	self.npc:ClearSchedule()

	self.npc_schedule = self.npc:GetCurrentSchedule()
	self.npc_state = self.npc:GetNPCState()
end

-- Adds a target for the actor and syncs new targets for clients.
-- ? The target doesn't have to be the enemy. This is used in state calculations.
-- @param ent entity any entity other than the actor himself
function BaseClass:AddTarget(ent)
	if not self.mechanics.targets_controller then return end
	if not self:IsAlive() or not IsValid(ent) or not isentity(ent) then return end
	if ent.BGN_HasBuildMode then return end

	if self.npc ~= ent and not table_HasValueBySeq(self.targets, ent) then
		self.targets_count = self.targets_count + 1
		self.targets[self.targets_count] = ent
	end
end

-- Removes an entity from the target list and syncs new list for clients.
-- ! If you simply remove an entity from the list, it will not automatically cancel the relationship with the NPC.
-- @param ent entity|NULL any entity
-- @param index number|nil target id in table
-- ? If there is no entity, use an index. If there is no index, use entity.
function BaseClass:RemoveTarget(ent, index)
	if not self.mechanics.targets_controller then return self.targets_count end
	if isnumber(index) then
		ent = self.targets[index]
		if not ent or not IsValid(ent) then return self.targets_count end
	end

	local old_count = self.targets_count

	if not hook_Run('BGN_RemoveActorTarget', self, ent) then
		if ent == self.walkTarget then self.walkTarget = NULL end

		if table_RemoveByValue(self.targets, ent)  then
			self.targets_count = self.targets_count - 1
		end

		if old_count > 0 and self.targets_count == 0 then
			hook_Run('BGN_ResetTargetsForActor', self)
		end
	end

	return self.targets_count
end

-- Removes all targets from the list.
-- ? Actually calls method "RemoveTarget" for all targets in the list.
function BaseClass:RemoveAllTargets()
	if not self.mechanics.targets_controller then return end

	local last_count = 0
	for i = self.targets_count, 1, -1 do
		last_count = self:RemoveTarget(nil, i)
	end

	-- Safety bag. It may be removed in the future.
	if last_count > 0 then
		self.targets = {}
		hook_Run('BGN_ResetTargetsForActor', self)
	end
end

-- Recalculates targets, and removes them if they are dead or no longer exist on the map.
-- @return table new_targets new target list
function BaseClass:RecalculationTargets()
	if not self.mechanics.targets_controller then return end

	self.targets_count = #self.targets

	for i = self.targets_count, 1, -1 do
		local target = self.targets[i]
		if not IsValid(target) then
			self:RemoveTarget(nil, i)
		elseif target:IsPlayer() and target:Health() <= 0 then
			self:RemoveTarget(nil, i)
		end
	end

	return self.targets
end

-- Checks for the existence of an entity in the target list.
-- @param ent entity any entity
-- @return boolean is_exist will return true if the entity is the target, otherwise false
function BaseClass:HasTarget(ent)
	return table_HasValueBySeq(self.targets, ent)
end

-- Returns the number of existing targets for the actor.
-- @return number targets_number number of targets
function BaseClass:TargetsCount()
	-- self:RecalculationTargets()
	return self.targets_count
end

function BaseClass:HasNoTargets()
	return self.targets_count == 0
end

-- Returns the closest target to the actor.
-- @return entity|NULL target_entity nearest target which is entity
function BaseClass:GetNearTarget()
	local target = NULL
	local dist = 0
	local self_npc = self.npc

	for i = 1, self.targets_count do
		local ent = self.targets[i]
		if IsValid(ent) then
			if not IsValid(target) then
				target = ent
				dist = ent:GetPos():DistToSqr(self_npc:GetPos())
			elseif ent:GetPos():DistToSqr(self_npc:GetPos()) < dist then
				target = ent
				dist = ent:GetPos():DistToSqr(self_npc:GetPos())
			end
		end
	end

	return target
end

function BaseClass:GetTarget(id)
	if id == nil then return self:GetFirstTarget() end
	return self.targets[id] or NULL
end

function BaseClass:GetFirstTarget()
	for i = 1, self.targets_count do
		local ent = self.targets[i]
		if IsValid(ent) then return ent end
	end
	return NULL
end

function BaseClass:GetLastTarget()
	for i = self.targets_count, 1, -1 do
		local ent = self.targets[i]
		if IsValid(ent) then return ent end
	end
	return NULL
end

function BaseClass:AddEnemy(ent, reaction, always_visible)
	if not self.mechanics.enemies_controller then return end
	if bgNPC:IsPeacefulMode() then return end
	if not self:IsAlive() or not IsValid(ent) or not isentity(ent) then return end
	if not ent:IsNPC() and not ent:IsNextBot() and not ent:IsPlayer() then return end
	if self:HasTeam(ent) then return end
	if ent.BGN_HasBuildMode then return end

	local npc = self.npc

	if npc ~= ent and not table_HasValueBySeq(self.enemies, ent) and not hook_Run('BGN_AddActorEnemy', self, ent) then
		if npc:IsNPC() then
			local relationship = D_HT
			if reaction == 'fear' then relationship = D_FR end
			npc:AddEntityRelationship(ent, relationship, 99)
		end
		self.enemies_count = self.enemies_count + 1
		self.enemies[self.enemies_count] = ent
		if always_visible then
			self.enemies_always_visible_count = self.enemies_always_visible_count + 1
			self.enemies_always_visible[self.enemies_always_visible_count] = ent
		end
		if IsValid(self.npc) and self.npc:IsNPC() and isfunction(self.npc.SetNPCState) then
			self.npc:SetNPCState(NPC_STATE_ALERT)
		end
		-- self:EnemiesRecalculate()
	end
end

function BaseClass:RemoveEnemy(ent, index)
	if not self.mechanics.enemies_controller then return self.enemies_count end
	if not IsValid(ent) then return self.enemies_count end
	if isnumber(index) then
		ent = self.enemies[index]
		if not ent or not IsValid(ent) then return self.enemies_count end
	end

	local old_count = self.enemies_count

	if not hook_Run('BGN_RemoveActorEnemy', self, ent) then
		local npc = self.npc

		if ent == self.walkTarget then self.walkTarget = NULL end

		if IsValid(npc) and npc:IsNPC() then
			if npc:GetEnemy() == ent then npc:SetEnemy(NULL) end
			npc:AddEntityRelationship(ent, D_NU, 99)
		end

		if table_RemoveByValue(self.enemies, ent) then
			self.enemies_count = self.enemies_count - 1
		end

		if table_RemoveByValue(self.enemies_always_visible, ent) then
			self.enemies_always_visible_count = self.enemies_always_visible_count - 1
		end

		if old_count > 0 and self.enemies_count == 0 then
			hook_Run('BGN_ResetEnemiesForActor', self)
		end
	end

	return self.enemies_count
end

function BaseClass:RemoveAllEnemies()
	if not self.mechanics.enemies_controller then return end

	local last_count = 0
	for i = self.enemies_count, 1, -1 do
		last_count = self:RemoveEnemy(nil, i)
	end

	-- Safety bag. It may be removed in the future.
	if last_count > 0 then
		self.enemies = {}
		hook_Run('BGN_ResetEnemiesForActor', self)
	end
end

function BaseClass:HasEnemy(ent)
	if not ent then return false end

	if istable(ent) and ent.isBgnClass then
		ent = ent.npc
	end

	if IsValid(ent)
		and ent:IsNPC()
		and isfunction(ent.Disposition)
		and ent:Disposition(self.npc) == D_HT
	then
		return true
	end

	return table_HasValueBySeq(self.enemies, ent)
end

function BaseClass:EnemiesCount()
	return self.enemies_count
end

function BaseClass:HasNoEnemies()
	return self.enemies_count == 0
end

function BaseClass:EnemiesRecalculate()
	if not self.mechanics.enemies_controller then return end

	self.enemies_count = #self.enemies
	self.enemies_always_visible_count = #self.enemies_always_visible

	local npc = self.npc

	if npc:IsNPC() then
		local enemy = self:GetNearEnemy()
		local active_enemy = npc:GetEnemy()
		local is_valid_enemy = IsValid(enemy)
		local is_valid_active_enemy = IsValid(active_enemy)

		if is_valid_enemy and is_valid_active_enemy
			and active_enemy:IsVehicle()
			and (not enemy:IsPlayer() or enemy:GetVehicle() ~= active_enemy)
		then
			npc:AddEntityRelationship(active_enemy, D_NU, 99)
		end

		if is_valid_enemy and enemy:IsPlayer() and enemy:InVehicle() then
			local vehicle = enemy:GetVehicle()
			local vehicle_parent = vehicle:GetParent()
			local new_enemy

			if IsValid(vehicle_parent) then
				new_enemy = vehicle_parent
			else
				new_enemy = vehicle
			end

			npc:SetEnemy(new_enemy)
			npc:SetTarget(new_enemy)
			npc:UpdateEnemyMemory(new_enemy, enemy:GetPos())
			npc:AddEntityRelationship(new_enemy, D_HT, 99)

			return
		end
	end

	if self.enemies_count == 0 then return end

	for i = 1, self.enemies_count do
		local enemy = self.enemies[i]
		if not IsValid(enemy) or enemy:Health() <= 0 then
			self:RemoveEnemy(enemy)
		end
	end

	if npc:IsNPC() then
		local enemy = self:GetNearEnemy()
		if IsValid(enemy) then
			local WantedModule = bgNPC:GetModule('wanted')
			if bgNPC:IsTargetRay(npc, enemy) or enemy.bgn_always_visible then
				npc:SetEnemy(enemy)
				npc:SetTarget(enemy)
				npc:UpdateEnemyMemory(enemy, enemy:GetPos())
			elseif not WantedModule:HasWanted(enemy) and
				not table_HasValueBySeq(self.enemies_always_visible, enemy)
			then
				local time = npc:GetEnemyLastTimeSeen(enemy)
				if time + 20 < CurTime() then
					self:RemoveEnemy(enemy)
				end
			end
		end
	end
end

function BaseClass:GetEnemy()
	return self:GetNearEnemy()
end

function BaseClass:GetFirstEnemy()
	for i = 1, self.enemies_count do
		local enemy = self.enemies[i]
		if IsValid(enemy) then return enemy end
	end
	return NULL
end

function BaseClass:GetNearEnemy()
	local enemy = NULL
	local dist = nil
	local npcPos = self.npc:GetPos()

	for i = 1, self.enemies_count do
		local ent = self.enemies[i]
		if IsValid(ent) then
			local new_dist = npcPos:DistToSqr(ent:GetPos())
			if not IsValid(enemy) then
				enemy = ent
				dist = new_dist
			elseif new_dist < dist then
				enemy = ent
				dist = new_dist
			end
		end
	end

	return enemy
end

function BaseClass:GetLastEnemy()
	for i = self.enemies_count, 1, -1 do
		local enemy = self.enemies[i]
		if IsValid(enemy) then return enemy end
	end
	return NULL
end

function BaseClass:DropToFloor()
	local npc = self.npc
	if not IsValid(npc) then return end

	if npc.SetSolid and npc.GetHullType and npc.SetHullType and npc.SetHullSizeNormal then
		local hull = npc:GetHullType()
		npc:SetSolid(SOLID_BBOX)
		npc:SetPos(npc:GetPos() + npc:GetUp() * 6)
		npc:SetHullType(hull)
		npc:SetHullSizeNormal()
	end

	-- if npc.SetCollisionBounds then
	-- 	npc:SetCollisionBounds(_collision_min_bounds, _collision_max_bounds)
	-- end

	if npc.DropToFloor then
		npc:DropToFloor()
	end
end

function BaseClass:StateLock(lock)
	lock = lock or false
	self.state_lock = lock
end

function BaseClass:IsStateLock()
	return self.state_lock
end

function BaseClass:CallStateAction(current_state, func_name, ...)
	current_state = current_state or self.state_data.state
	return bgNPC:CallStateAction(current_state, func_name, self, ...)
end

function BaseClass:SetState(state, data, forced)
	if not self.mechanics.states_controller then return end
	if not self:IsAlive() then return end

	forced = forced or false

	if not forced then
		if state == 'ignore' then return end
		if self:GetData().disable_states then return end
		if self.state_lock then return end
		if self.state_data.state == state then return end
		if self.state_delay > CurTime() then return end
	end

	state = state or 'none'
	data = data or {}

	local current_state = self.state_data.state
	local current_data = self.state_data.data

	local is_locked = self:CallStateAction(nil, 'not_stop', current_state, current_data, state, data)
	if not forced and is_locked then return end

	local hook_result = hook_Run('BGN_PreSetState', self, state, data)
	if hook_result then
		if isbool(hook_result) then
			return
		elseif isstring(hook_result) then
			state = hook_result
		elseif istable(hook_result) then
			state = hook_result.state or state
			data = hook_result.data or data
		end
	end

	if not forced and bgNPC:StateActionExists(state, 'validator') and not self:CallStateAction(state, 'validator', state, data) then
		return
	end

	local new_state, new_data = self:CallStateAction(state, 'pre_start', state, data)
	if type(new_state) == 'boolean' and new_state == true then return end

	state = new_state or state
	data = new_data or data

	if SERVER then
		self:StopWalk()
		self.anim_action = nil
		self:ResetSequence()
	end

	self:CallStateAction(nil, 'stop', current_state, current_data)

	state = new_state or state
	data = new_data or data

	self.old_state = self.state_data
	self.state_data = { state = state, data = data }

	self:CallStateAction(state, 'start', self.state_data.state, self.state_data.data)
	hook_Run('BGN_SetState', self, self.state_data.state, self.state_data.data)

	return self.state_data
end

function BaseClass:SetWalkType(moveType)
	moveType = moveType or 'walk'

	local schedule = SCHED_FORCED_GO
	local valueType =  type(moveType)

	if valueType == 'number' then
		schedule = moveType
	elseif valueType == 'string' and moveType == 'run' then
		schedule = SCHED_FORCED_GO_RUN
	end

	self.walkType = schedule
end

function BaseClass:StopWalk()
	if self.walkPos then
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
	return self.walkPos ~= nil
end

function BaseClass:WalkToTarget(target, moveType, pathType)
	if not self.mechanics.movement_controller then return end
	if self.npc:IsNextBot() then return end

	if target == nil or not IsValid(target) then
		self:StopWalk()
	else
		local npc = self.npc
		if npc:GetPos():DistToSqr(target:GetPos()) <= _movement_finished_distance then
			local walk_type = moveType or 'walk'
			hook_Run('BGN_ActorFinishedWalk', self, target:GetPos(), walk_type)
			return
		end

		self:SetWalkType(moveType)

		if self.walkTarget ~= target then
			self.pathType = pathType
			self.walkUpdatePathDelay = 0
			self.walkPos = nil
			self.walkTarget = target

			local decentvehicle = self:GetVehicleAI()
			if IsValid(decentvehicle) then
				self.isChase = true
				self:WalkToPos(target:GetPos(), moveType, pathType)
			end
		end
	end
end

function BaseClass:WalkToPos(pos, moveType, pathType)
	if not self.mechanics.movement_controller then return end
	if self.npc:IsNextBot() or not isvector(pos) then return end

	if not pos then
		self:StopWalk()
		return
	end

	if self.walkPos == pos then return end

	local pre_set_result = hook_Run('BGN_PreSetWalkPos', self, pos, moveType, pathType)
	if isbool(pre_set_result) and not pre_set_result then return end
	if isvector(pre_set_result) then pos = pre_set_result end

	local npc = self.npc
	if npc:GetPos():DistToSqr(pos) <= _movement_finished_distance then
		local walk_type = moveType or 'walk'
		hook_Run('BGN_ActorFinishedWalk', self, pos, walk_type)
		return
	end

	local walkPath = {}
	if not self:InVehicle() then
		if npc:IsEFlagSet(EFL_NO_THINK_FUNCTION) then return end

		walkPath = bgNPC:FindWalkPath(npc:GetPos(), pos, nil, pathType)
		if #walkPath == 0 then return end

		self.pathType = pathType
		self:SetWalkType(moveType)
	else
		local dvd = DecentVehicleDestination
		local decentvehicle = self:GetVehicleAI()
		if IsValid(decentvehicle) then
			local route = dvd.GetRouteVector(decentvehicle:GetPos(), pos)
			if not route then return end

			decentvehicle.WaypointList = route
			decentvehicle.Waypoint = nil
			decentvehicle.NextWaypoint = nil

			for index = 1, #route do
				walkPath[index] = route[index].Target
			end
		else
			bgNPC:Log('Trying to build a path for a vehicle that doesn\'t exist', 'sh_actor_class:WalkToPos')
		end
	end

	if not self.isChase then
		self.walkTarget = NULL
	end

	self.walkPos = pos
	self.walkPath = walkPath
end

function BaseClass:CheckMoveUpdate(tag, time)
	self.checkMoveUpdateData = self.checkMoveUpdateData or {}
	local is_update = false
	if self.checkMoveUpdateData[tag] and self.checkMoveUpdateData[tag].state then
		is_update = true
	end
	if is_update or not self.checkMoveUpdateData[tag] then
		self.checkMoveUpdateData[tag] = { state = false,  time = CurTime() + (time or 0) }
	end
	return is_update
end

function BaseClass:GetWalkTarget()
	return self.walkTarget
end

function BaseClass:GetWalkPos()
	return self.walkPos
end

function BaseClass:UpdateMovement()
	if not self.mechanics.movement_controller then return end
	if self.is_animated or not self:IsAlive() then return end

	local walkPos = self.walkPos

	if self.walkTarget and IsValid(self.walkTarget) then
		walkPos = self.walkTarget:GetPos()
	end

	if not walkPos or self:IsAnimationPlayed() then return end

	if self:InVehicle() then
		local vehicle = self:GetVehicle()
		if IsValid(vehicle)
			and vehicle:GetPos():DistToSqr(walkPos) <= _movement_finished_distance
			and not hook_Run('BGN_ActorFinishedWalk', self, walkPos, self.walkType)
		then
			self:WalkToPos(nil)
		end
	else
		local npc = self.npc
		if not IsValid(npc) then return end

		local npc_pos = npc:GetPos()
		local hasNext = false
		local targetPosition

		if self.walkPath and #self.walkPath ~= 0 then
			targetPosition = self.walkPath[1]

			if npc_pos:DistToSqr(targetPosition) <= _movement_finished_distance then
				table_remove(self.walkPath, 1)

				if #self.walkPath == 0 then
					if not hook_Run('BGN_ActorFinishedWalk', self, targetPosition, self.walkType) then
						self:WalkToPos(nil)
					end
					return
				end

				hasNext = true
			end
		end

		if not hasNext then
			if isfunction(npc.IsEFlagSet) and npc:IsEFlagSet(EFL_NO_THINK_FUNCTION) then return end
			-- if isfunction(npc.IsMoving) and npc:IsMoving() then return end
			if self.waitUpdateMovementDelay > CurTime() then return end
			self.waitUpdateMovementDelay = CurTime() + .5
		end

		if isfunction(npc.GetCurrentSchedule) then
			local current_schedule = npc:GetCurrentSchedule()
			for i = 1, #schedule_white_list do
				if schedule_white_list[i] == current_schedule then return end
			end
		end

		if targetPosition and isfunction(npc.SetLastPosition) then
			npc:SetLastPosition(targetPosition)
		end

		self:SetSchedule(self.walkType)
	end
end

function BaseClass:Walking()
	return self.npc:IsMoving()
end

function BaseClass:GetRelationship(value, default)
	local isEntity = IsValid(value) and isentity(value)
	local actor

	if istable(value) and value.isBgnClass then
		actor = value
	elseif isEntity then
		actor = bgNPC:GetActor(value)
	end

	if actor then
		if self:HasTeam(actor) then
			return self.relationship['@team'] or default
		else
			return self.relationship['@actor'] or default
		end
	end

	if isEntity then
		local ent = value
		local entity_class = ent:GetClass()
		if self.relationship[entity_class] then
			return self.relationship[entity_class]
		end

		if ent:IsNPC() or ent:IsNextBot() then
			return self.relationship['@npc'] or default
		elseif ent:IsPlayer() then
			return self.relationship['@player'] or default
		end
	end

	return default
end

function BaseClass:HasTeam(value)
	local value = value
	if self.data.team ~= nil and value ~= nil then
		if isstring(value) then
			return table_HasValueBySeq(self.data.team, value)
		end

		if isentity(value) then
			if value:IsPlayer() then
				if table_HasValueBySeq(self.data.team, 'player') then
					return true
				else
					return bgNPC:GetModule('team_parent'):HasParent(value, self)
				end
			elseif value.isBgnActor and (value:IsNPC() or value:IsNextBot()) then
				local actor = bgNPC:GetActor(value)
				if not actor then return false end
				value = actor:GetData().team
			end
		end

		if istable(value) then
			if value.isBgnClass then value = value:GetData().team end

			for i = 1, #self.data.team do
				for k = 1, #value do
					if self.data.team[i] == value[k] then return true end
				end
			end
		end
	end
	return false
end

function BaseClass:UpdateStateData(data)
	self.state_data.data = data
end

function BaseClass:HasState(state)
	local current_state = self.state_data.state
	local type_value = type(state)
	if type_value == 'string' then
		return current_state == state
	elseif type_value == 'table' then
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

function BaseClass:GetDistantPointToPoint(pos, radius)
	if not self:IsAlive() or not isvector(pos) then return nil end
	radius = radius or 500

	local get_position = nil
	local dist = 0
	local npc = self.npc
	local points = bgNPC:GetAllPointsInRadius(npc:GetPos(), radius)

	for i = 1, #points do
		local point = points[i]
		if not get_position then
			get_position = point.position
			dist = get_position:DistToSqr(pos)
		elseif point.position:DistToSqr(pos) > dist then
			get_position = point.position
			dist = get_position:DistToSqr(pos)
		end
	end

	return get_position
end

function BaseClass:GetClosestPointToPoint(pos, radius)
	if not self:IsAlive() or not isvector(pos) then return nil end
	radius = radius or 500

	local get_position = nil
	local dist = 0
	local npc = self.npc
	local points = bgNPC:GetAllPointsInRadius(npc:GetPos(), radius)

	for i = 1, #points do
		local point = points[i]
		if not get_position then
			get_position = point.position
			dist = get_position:DistToSqr(pos)
		elseif point.position:DistToSqr(pos) < dist then
			get_position = point.position
			dist = get_position:DistToSqr(pos)
		end
	end

	return get_position
end

function BaseClass:GetDistantPointInRadius(radius)
	if not self:IsAlive() then return nil end
	return bgNPC:GetDistantPointInRadius(self.npc:GetPos(), radius)
end

function BaseClass:GetClosestPointInRadius(radius)
	if not self:IsAlive() then return nil end
	return bgNPC:GetClosestPointInRadius(self.npc:GetPos(), radius)
end

function BaseClass:GetReactionForDamage()
	local percent, reaction

	if self.data.at_damage then
		local probability = math_random(1, self.data.at_damage_range or 100)
		percent, reaction = table_RandomOpt(self.data.at_damage)

		if probability > percent then
			local last_percent = 0

			for _reaction, _percent in next, self.data.at_damage do
				if _percent > last_percent then
					percent = _percent
					reaction = _reaction
					last_percent = _percent
				end
			end
		end
	end

	reaction = reaction or 'ignore'

	return reaction
end

function BaseClass:GetReactionForProtect()
	local percent, reaction

	if self.data.at_protect then
		local probability = math_random(1, self.data.at_protect_range or 100)
		percent, reaction = table_RandomOpt(self.data.at_protect)

		if probability > percent then
			local last_percent = 0

			for _reaction, _percent in next, self.data.at_protect do
				if _percent > last_percent then
					percent = _percent
					reaction = _reaction
					last_percent = _percent
				end
			end
		end
	end

	reaction = reaction or 'ignore'

	return reaction
end

function BaseClass:SetSchedule(schedule)
	if not self:IsAlive() then return end

	local npc = self.npc
	if isfunction(npc.SetSchedule) and self:IsSequenceFinished() then
		npc:SetSchedule(schedule)

		self.npc_schedule = npc:GetCurrentSchedule()
		self.npc_state = npc:GetNPCState()
	end
end

function BaseClass:IsValidSequence(sequence_name)
	return IsValid(self.npc) and self.npc:LookupSequence(sequence_name) ~= -1
end

function BaseClass:PlayStaticSequence(sequence_name, loop, loop_time, action)
	if not self.mechanics.animator_controller then return end
	if not sequence_name or not self:IsValidSequence(sequence_name) then return false end

	if self:HasSequence(sequence_name) then
		if self.anim_is_loop and not self:IsSequenceLoopFinished() then
			return true
		elseif not self.anim_is_loop and not self:IsSequenceFinished() then
			return true
		end
	end

	local hook_result = hook_Run('BGN_PreNPCStartAnimation', self, sequence_name, loop, loop_time)
	if hook_result ~= nil and isbool(hook_result) and not hook_result then
		return false
	end

	self.anim_is_loop = loop or false
	self.anim_name = string_lower(sequence_name)
	if loop_time ~= nil and loop_time ~= 0 then
		self.loop_time = RealTime() + loop_time
		self.loop_time_normal = self.loop_time - RealTime()
	else
		self.loop_time = 0
	end
	local sequence = self.npc:LookupSequence(sequence_name)
	self.anim_time = RealTime() + self.npc:SequenceDuration(sequence)
	self.anim_time_normal = self.anim_time - RealTime()
	self.is_animated = true
	self.anim_action = action

	self.npc_schedule = SCHED_SLEEP
	self.npc_state = NPC_STATE_SCRIPT

	self.npc:SetNPCState(NPC_STATE_SCRIPT)
	self.npc:SetSchedule(SCHED_SLEEP)
	self.npc:ResetSequenceInfo()
	self.npc:ResetSequence(sequence)

	self.npc_schedule = self.npc:GetCurrentSchedule()
	self.npc_state = self.npc:GetNPCState()

	self.npc:PhysWake()

	hook_Run('BGN_StartedNPCAnimation', self, sequence_name, loop, loop_time)

	return true
end

function BaseClass:SetNextSequence(sequence_name, loop, loop_time, action)
	if not self.mechanics.animator_controller then return end

	self.next_anim = {
		sequence_name = sequence_name,
		loop = loop,
		loop_time = loop_time,
		action = action,
	}
end

function BaseClass:HasSequence(sequence_name)
	return self.anim_name == string_lower(sequence_name)
end

function BaseClass:IsAnimationPlayed()
	if self.is_animated then
		return true
	end
	return slib.Animator.InAnimation(self.npc)
end

function BaseClass:IsSequenceLoopFinished()
	if self:IsLoopSequence() then
		if self.loop_time == 0 then return false end

		if self.loop_time_normal > 0 then
			self.loop_time_normal = self.loop_time - RealTime()
		end

		return self.loop_time < RealTime()
	end
	return true
end

function BaseClass:IsLoopSequence()
	return self.anim_is_loop
end

function BaseClass:IsSequenceFinished()
	if self.anim_time_normal > 0 then
		self.anim_time_normal = self.anim_time - RealTime()
	else
		self.anim_time_normal = 0
	end

	return self.anim_time <= RealTime()
end

function BaseClass:PlayNextStaticSequence()
	if not self.mechanics.animator_controller then return end
	if self.next_anim ~= nil and self.next_anim.sequence_name ~= self.anim_name then

		self:PlayStaticSequence(self.next_anim.sequence_name,
			self.next_anim.loop, self.next_anim.loop_time)

		if self.next_anim.action ~= nil then
			self.next_anim.action(self)
		end

		self.next_anim = nil
		return true
	end

	return false
end

function BaseClass:StopStaticSequence()
	self.anim_name = ''
	self.is_animated = false
	self.next_anim = nil
	self.anim_action = nil

	self:ClearSchedule()
end

function BaseClass:ResetSequence()
	if self.anim_action ~= nil and not self.anim_action(self) then return end

	self.anim_name = ''
	self.is_animated = false
	self.next_anim = nil
	self.anim_action = nil

	self:ClearSchedule()
end

function BaseClass:FearScream()
	if not self.mechanics.fear_scream then return end
	if not self:IsAlive() then return end

	local npc = self.npc
	local npc_model = npc:GetModel()
	local scream_sound = nil
	if tobool(string_find(npc_model, 'female_*')) then
		scream_sound = table_RandomBySeq(female_scream)
	elseif tobool(string_find(npc_model, 'male_*')) then
		scream_sound = table_RandomBySeq(male_scream)
	else
		local concatenated_table = table_Copy(male_scream)
		table_Add(concatenated_table, female_scream)
		scream_sound = table_RandomBySeq(concatenated_table)
	end

	if scream_sound ~= nil and isstring(scream_sound) then
		npc:EmitSound(scream_sound, 100, 100, 1, CHAN_AUTO)
	end
end

function BaseClass:CallForHelp(enemy)
	if not self.mechanics.call_for_help then return end
	if not IsValid(enemy) then return end
	if hook_Run('BGN_PreCallForHelp', self, enemy) then return end

	self:FearScream()

	local npc = self.npc
	local near_actors = bgNPC:GetAllByRadius(npc:GetPos(), 1000)
	for i = 1, #near_actors do
		local NearActor = near_actors[i]
		local NearNPC = NearActor.npc
		if NearActor:IsAlive() and NearActor:HasTeam(self) and bgNPC:IsTargetRay(NearNPC, enemy) then
			NearActor:SetState(NearActor:GetReactionForProtect())
			NearActor:AddEnemy(enemy)
		end
	end

	local TargetActor = bgNPC:GetActor(target)
	if TargetActor ~= nil and not TargetActor:HasTeam(self) then
		if not TargetActor:HasState('impingement') and not TargetActor:HasState('defense') then
			TargetActor:SetState('defense')
		end
		TargetActor:AddEnemy(enemy)
	end
end

function BaseClass:EqualStateGroup(group_name)
	return self:HasStateGroup(self:GetState(), group_name)
end

function BaseClass:GetStateGroupName()
	return bgNPC:GetStateGroupName(self:GetState())
end

function BaseClass:HasStateGroup(state_name, group_name)
	if isstring(group_name) then
		return bgNPC:GetStateGroupName(state_name) == group_name
	elseif istable(group_name) then
		for i = 1, #group_name do
			local result = bgNPC:GetStateGroupName(state_name) == group_name[i]
			if result then return true end
		end
	end
	return false
end

function BaseClass:CreateFakePlayerMethodsForNPC()
	local npc = self.npc
	if not IsValid(npc) then return end

	-- Fixes some weapon mods.
	if not isfunction(npc.LagCompensation) then
		function npc:LagCompensation() end
	end

	-- Fixes some weapon mods.
	if not isfunction(npc.GetViewModel) then
		function npc:GetViewModel() end
	end
end

function BaseClass:IsMeleeWeapon()
	if not self:IsAlive() then return false end

	local npc = self.npc
	local wep = npc:GetActiveWeapon()
	if not IsValid(wep) then return true end

	return table_HasValueBySeq(bgNPC.cfg.melee_weapons, wep:GetClass())
end

function BaseClass:EnterVehicle(vehicle)
	if not self.mechanics.use_vehicle then return end
	if not IsValid(vehicle) then return end
	if not DecentVehicleDestination or not vehicle:IsVehicle() then return end

	local vehicle_provider = BGN_VEHICLE:GetVehicleProvider(vehicle)
	if not vehicle_provider then
		local actor_type = self:GetType()
		local data = self:GetData()
		local vehicle_group = data.vehicle_group

		if vehicle_group then
			vehicle_provider = BGN_VEHICLE:Instance(vehicle, vehicle_group, actor_type)
		else
			if self:HasTeam('police') then
				vehicle_provider = BGN_VEHICLE:Instance(vehicle, 'police', actor_type)
			elseif self:HasTeam('taxi') then
				vehicle_provider = BGN_VEHICLE:Instance(vehicle, 'taxi', actor_type)
			else
				vehicle_provider = BGN_VEHICLE:Instance(vehicle, nil, actor_type)
			end
		end

		if not vehicle_provider then return end
		BGN_VEHICLE:AddToList(vehicle_provider)
	end

	if not vehicle_provider:GetDriver() then
		local all_seats_are_taken = true
		for _, ent in ipairs(vehicle:GetChildren()) do
			if ent:GetClass() == 'prop_vehicle_prisoner_pod' and not IsValid(ent:GetDriver()) then
				all_seats_are_taken = false
				break
			end
		end
		if all_seats_are_taken then return end
	end

	-- vehicle:slibCreateTimer('bgn_actor_enter_vehicle', 0.5, 1, function()
	-- 	if not vehicle_provider or not IsValid(vehicle) then return end

	-- 	self.eternal = true
	-- 	self.vehicle = vehicle_provider
	-- 	self.keyvalues = self.npc:GetKeyValues()

	-- 	if not vehicle_provider:GetDriver() then
	-- 		vehicle_provider:SetDriver(self)
	-- 	elseif not vehicle_provider:AddPassenger(self) then
	-- 		return
	-- 	end

	-- 	hook_Run('BGN_OnEnterVehicle', self, vehicle_provider)

	-- 	self.npc:Remove()
	-- end)

	local npc = self.npc
	vehicle:slibCreateTimer('bgn_actor_enter_vehicle', 0.5, 1, function(self_vehicle)
		if not vehicle_provider or not IsValid(self_vehicle) then return end
		if not self or not self:IsAlive() then return end

		self.eternal = true
		self.vehicle = vehicle_provider

		-- npc:SetNoDraw(true)

		if not vehicle_provider:GetDriver() then
			vehicle_provider:SetDriver(self)
		else
			if not vehicle_provider:AddPassenger(self) then
				--  npc:SetNoDraw(false)
				return
			end
		end

		npc:SetNoDraw(true)
		npc:slibSetVar('bgn_vehicle_entered', true)
		npc:SetCollisionGroup(COLLISION_GROUP_WORLD)
		npc:SetPos(self_vehicle:GetPos() + self_vehicle:GetUp() * 300)
		-- npc:SetPos(vector_0_0_0)
		-- npc:SetModelScale(0.1)
		npc:SetModelScale(0)
		npc:SetParent(self_vehicle)
		npc:AddEFlags(EFL_NO_THINK_FUNCTION)

		self.walkUpdatePathDelay = 0

		hook_Run('BGN_OnEnterVehicle', self, vehicle_provider)
	end)
end

function BaseClass:ExitVehicle()
	if not self.mechanics.use_vehicle then return end
	if not DecentVehicleDestination then return end

	local vehicle_provider = self.vehicle
	if vehicle_provider and IsValid(vehicle_provider) then
		hook_Run('BGN_OnExitVehicle', self, vehicle_provider)

		local vehicle = vehicle_provider:GetVehicle()
		local min, max = vehicle:GetModelBounds()
		local dist = min:Distance(max) / 2
		local pos = vehicle:GetPos()
		local forward = vehicle:GetForward()
		local right = vehicle:GetRight()
		local up = vehicle:GetUp()
		local npc = self.npc
		local add_forward = math_random(-100, 100)
		local add_right = dist
		local exit_pos
		if slib.chance(50) then add_right = -dist end

		npc:slibSetVar('bgn_vehicle_entered', false)
		npc:SetParent(nil)

		-- local npc = ents.Create(self.class)
		-- npc:SetModel(self.model)
		-- npc:SetSkin(self.skin)

		-- for k, v in pairs(self.bodygroups) do
		-- 		npc:SetBodygroup(k, v)
		-- end

		-- for k, v in pairs(self.keyvalues) do
		-- 	if isstring(k) and isstring(v) then
		-- 		npc:SetKeyValue(k, v)
		-- 	end
		-- end

		for i = 1, 4 do
			exit_pos = pos + (right * add_right) + (forward * add_forward) + (up * 50)

			local tr = util.TraceLine({
				start = exit_pos,
				endpos = exit_pos - Vector(0, 0, 500),
				filter = function(ent)
					if ent ~= npc then return true end
					-- return true
				end
			})

			if tr.Hit then
				exit_pos = tr.HitPos + Vector(0, 0, 15)
			end

			if exit_pos and util.IsInWorld(exit_pos) and #ents.FindInSphere(exit_pos, 15) <= 2 then
				break
			end
		end

		npc:SetPos(exit_pos)
		npc:SetAngles(Angle(0, npc:GetAngles().y, 0))
		npc:SetCollisionGroup(self.collision_group)
		npc:SetModelScale(self.model_scale)
		npc:RemoveEFlags(EFL_NO_THINK_FUNCTION)
		npc:PhysWake()
		npc:SetNoDraw(false)
		-- npc:Spawn()
		self:DropToFloor()

		-- snet.Request('bgn_add_actor_from_client', npc, self.type, self.uid, self.info).InvokeAll()

		-- timer.Simple(0, function()
		-- 	if not IsValid(npc) then return end
		-- 	self:DropToFloor()
		-- 	self:CreateFakePlayerMethodsForNPC()
		-- end)

		if vehicle_provider:GetDriver() == self then
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
		return IsValid(self.vehicle)
	else
		return IsValid(self.npc) and self.npc:slibGetVar('bgn_vehicle_entered', false)
	end
end

function BaseClass:GetVehicle()
	if not self:InVehicle() then return nil end
	return self.vehicle:GetVehicle()
end

function BaseClass:GetVehicleAI()
	if not self:InVehicle() then return nil end
	return self.vehicle:GetVehicleAI()
end

function BaseClass:GetActorWeapon()
	return self.weapon
end

function BaseClass:GetActiveWeapon()
	if self:IsAlive() then
		local npc = self.npc
		if isfunction(npc.GetActiveWeapon) then
			local weapon  = npc:GetActiveWeapon()
			if weapon and IsValid(weapon) then return weapon end
		end
	end
	return NULL
end

function BaseClass:PrepareWeapon(weapon_class, switching)
	if weapon_class then
		bgNPC:SetActorWeapon(self, weapon_class, switching)
	else
		bgNPC:SetActorWeapon(self)
	end
end

function BaseClass:FoldWeapon()
	if not self:IsAlive() or self.disable_fold_weapon then return end
	local weapon  = self:GetActiveWeapon()
	if weapon and IsValid(weapon) and isfunction(weapon.Remove) then weapon:Remove() end
end

function BaseClass:GiveWeapon(weapon_class)
	self.weapon = weapon_class
end

function BaseClass:SetTeam(team_data)
	self.data.team = team_data
end

function BaseClass:AddTeam(team_name)
	table_insert(self.data.team, team_name)
end

function BaseClass:VoiceSay(sound_path, soundLevel, pitchPercent, volume, channel, soundFlags, dsp)
	if not sound_path or not self:IsAlive() then return end

	soundLevel = soundLevel or 75
	pitchPercent = pitchPercent or 100
	volume = volume or 1
	channel = channel or CHAN_AUTO
	soundFlags = soundFlags or 0
	dsp = dsp or 0

	self.npc:EmitSound(sound_path, soundLevel, pitchPercent, volume, channel, soundFlags, dsp)
end

function BaseClass:Say(say_text, say_time, voice_sound, animation_sequence)
	if say_text then
		snet_InvokeAll('bgn_actor_text_say', self.uid, say_text, say_time or 5)
	end

	self:VoiceSay(voice_sound)
	self:PlayStaticSequence(animation_sequence)
end

function BaseClass:SayReplic(replic_id, replic_index, say_time, voice_sound, animation_sequence)
	if not bgNPC.cfg.replics[replic_id] or not bgNPC.cfg.replics[replic_id][replic_index] then return end

	snet_InvokeAll('bgn_actor_text_say_replic', self.uid, replic_id, replic_index, say_time or 5)
	self:VoiceSay(voice_sound)
	self:PlayStaticSequence(animation_sequence)
end

function BaseClass:GetPos()
	if not self:IsValid() then return Vector(0, 0, 0) end
	return self.npc:GetPos()
end

function BaseClass:GetAngles()
	if not self:IsValid() then return Angle(0, 0, 0) end
	return self.npc:GetAngles()
end

BaseClass.__index = BaseClass

return BaseClass
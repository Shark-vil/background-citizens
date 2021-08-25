BGN_ACTOR = {}

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
	SCHED_MELEE_ATTACK2
}

function BGN_ACTOR:Instance(npc, npc_type, custom_uid, not_sync_actor_on_client, not_auto_added_to_list)
	local npc_data = bgNPC:GetActorConfig(npc_type)
	if not npc_data then return end

	local not_sync_actor_on_client = not_sync_actor_on_client or false
	local not_auto_added_to_list = not_auto_added_to_list or false
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

	function obj:SetStateDelay(time)
		self.state_delay = CurTime() + time
	end

	function obj:IsStateDelay()
		return self.state_delay > CurTime()
	end

	function obj:ResetStateDelay()
		self.state_delay = 0
	end

	function obj:SyncFunction(name, ply, data)
		if CLIENT then return end
		if not self:IsAlive() then return end
		
		if ply then
			if IsValid(ply) then
				snet.Invoke(name, ply, self.uid, data)
			end
		else
			snet.InvokeAll(name, self.uid, data)
		end
	end

	-- Sets the random state of the NPC from the "at_random" table.
	function obj:RandomState()
		if not hook.Run('PreRandomState', self) then
			local state = self:GetRandomState()
			if state ~= 'none' and self:GetState() ~= state then
				self:SetState(state)
			end
		end
	end

	-- Gets a random identifier from the "at_random" table.
	-- ? The result depends on the set weights. The higher the value, the greater the chance of falling out.
	-- @return string identifier state identifier
	function obj:GetRandomState()
		if self.data.at_random == nil then
			return 'none'
		end

		local probability = math.random(1, (self.data.at_random_range or 100))
		local percent, state = table.Random(self.data.at_random)

		if probability > percent then
			local last_percent = 0
			
			for _state, _percent in pairs(self.data.at_random) do
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

	if SERVER then
		-- Checks if the actor is alive or not.
		-- @return boolean is_alive return true if the actor is alive, otherwise false
		function obj:IsAlive()
			local npc = self.npc
			if not IsValid(npc) or npc:Health() <= 0 or (npc:IsNPC() and npc:IsCurrentSchedule(SCHED_DIE)) then
				bgNPC:RemoveNPC(npc)
				return false
			end
			return true
		end
	else
		-- Checks if the actor is alive or not.
		--! The client has a simpler and less reliable check.
		-- @return boolean is_alive return true if the actor is alive, otherwise false
		function obj:IsAlive()
			local npc = self.npc
			return IsValid(npc) and npc:Health() > 0
		end
	end

	-- Sets the reaction to the event.
	-- ? Used in system computing, and does nothing by itself.
	-- @param reaction string reaction to event
	function obj:SetReaction(reaction)
		if self.reaction ~= reaction then self.reaction = reaction end
	end

	-- Will return the last result specified in the reaction variable.
	-- @return string reaction last set reaction
	function obj:GetLastReaction()
		return self.reaction
	end

	-- Returns the entity of the actor's NPC.
	-- ! Under certain circumstances, it can return NULL, it is recommended to use the IsAlive method before receiving the NPC.
	-- @return entity npc npc entity
	function obj:GetNPC()
		return self.npc
	end

	-- Will return the actor's data specified in the config.
	-- ! The data is bound to the actor. If you update the config, then the data will not be updated for the already created actors.
	-- @return table actor_data actor data from config
	function obj:GetData()
		return self.data
	end

	-- Returns the real NPC class that is associated with the actor.
	-- @return string npc_class npc class
	function obj:GetClass()
		return self.class
	end

	-- Returns the npc type specified in the config.
	-- ? For example - citizen
	-- @return string actor_type type of actor from config
	function obj:GetType()
		return self.type
	end

	-- Checks the existence of an NPC entity.
	-- @return boolean is_valid_npc will return true if the NPC exists, otherwise false
	function obj:IsValid()
		return IsValid(self.npc)
	end

	-- Clears NPC schedule data and synchronizes changes for clients.
	function obj:ClearSchedule()
		if not IsValid(self.npc) then return end
		if not self.npc:IsNPC() then return end

		self.npc:SetNPCState(NPC_STATE_IDLE)
		self.npc:ClearSchedule()

		self.npc_schedule = self.npc:GetCurrentSchedule()
		self.npc_state = self.npc:GetNPCState()
	end

	-- Adds a target for the actor and syncs new targets for clients.
	-- ? The target doesn't have to be the enemy. This is used in state calculations.
	-- @param ent entity any entity other than the actor himself
	function obj:AddTarget(ent)
		if not IsValid(ent) or not isentity(ent) then return end

		if self:GetNPC() ~= ent and not table.HasValueBySeq(self.targets, ent) then
			table.insert(self.targets, ent)
		end
	end

	-- Removes an entity from the target list and syncs new list for clients.
	-- ! If you simply remove an entity from the list, it will not automatically cancel the relationship with the NPC.
	-- @param ent entity|NULL any entity
	-- @param index number|nil target id in table
	-- ? If there is no entity, use an index. If there is no index, use entity.
	function obj:RemoveTarget(ent, index)
		local ent = ent
		local index_type = type(index)

		if isnumber(index) then ent = self.targets[index] end

		local old_count = #self.targets

		if not hook.Run('BGN_RemoveActorTarget', self, ent) then
			local npc = self:GetNPC()

			if isentity(ent) and ent == self.walkTarget then self.walkTarget = NULL end

			if isnumber(index) then
				table.remove(self.targets, index)
			elseif isentity(ent) then
				table.RemoveValueBySeq(self.targets, ent)
			end

			if old_count > 0 and #self.targets == 0 then
				hook.Run('BGN_ResetTargetsForActor', self)
			end
		end

		return #self.targets
	end

	-- Removes all targets from the list.
	-- ? Actually calls method "RemoveTarget" for all targets in the list.
	function obj:RemoveAllTargets()
		local last_count = 0
		for i = #self.targets, 1, -1 do
			last_count = self:RemoveTarget(nil, i)
		end

		-- Safety bag. It may be removed in the future.
		if last_count > 0 then
			table.Empty(self.targets)
			hook.Run('BGN_ResetTargetsForActor', self)
		end
	end

	-- Checks for the existence of an entity in the target list.
	-- @param ent entity any entity
	-- @return boolean is_exist will return true if the entity is the target, otherwise false
	function obj:HasTarget(ent)
		return table.HasValueBySeq(self.targets, ent)
	end

	-- Returns the number of existing targets for the actor.
	-- @return number targets_number number of targets
	function obj:TargetsCount()
		return table.Count(self.targets)
	end

	-- Returns the closest target to the actor.
	-- @return entity|NULL target_entity nearest target which is entity
	function obj:GetNearTarget()
		local target = NULL
		local dist = 0
		local self_npc = self:GetNPC()

		for i = 1, #self.targets do
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

	function obj:GetTarget(id)
		if id == nil then return self:GetFirstTarget() end
		return self.targets[id] or NULL
	end

	function obj:GetFirstTarget()
		for i = 1, #self.targets do
			local ent = self.targets[i]
			if IsValid(ent) then return ent end
		end
		return NULL
	end

	function obj:GetLastTarget()
		for i = #self.targets, 1, -1 do
			local ent = self.targets[i]
			if IsValid(ent) then return ent end
		end
		return NULL
	end

	function obj:AddEnemy(ent, reaction)
		if not IsValid(ent) or not isentity(ent) then return end
		if not ent:IsNPC() and not ent:IsNextBot() and not ent:IsPlayer() then return end
		if self:HasTeam(ent) then return end

		local npc = self:GetNPC()

		if npc ~= ent and not table.HasValueBySeq(self.enemies, ent) and not hook.Run('BGN_AddActorEnemy', self, ent) then
			if npc:IsNPC() then
				local relationship = D_HT
				if reaction == 'fear' then relationship = D_FR end
				npc:AddEntityRelationship(ent, relationship, 99)
			end
			table.insert(self.enemies, ent)
			self:EnemiesRecalculate()
		end
	end

	function obj:RemoveEnemy(ent, index)
		local ent = ent

		if isnumber(index) then ent = self.enemies[index] end

		local old_count = #self.enemies

		if not hook.Run('BGN_RemoveActorEnemy', self, ent) then
			local npc = self:GetNPC()

			if isentity(ent) then
				if ent == self.walkTarget then self.walkTarget = NULL end
				
				if IsValid(npc) and npc:IsNPC() then
					if npc:GetEnemy() == ent then npc:SetEnemy(NULL) end
					if IsValid(ent) then npc:AddEntityRelationship(ent, D_NU, 99) end
				end
			end

			if isnumber(index) then
				table.remove(self.enemies, index)
			elseif isentity(ent) then
				table.RemoveValueBySeq(self.enemies, ent)
			end

			if old_count > 0 and #self.enemies == 0 then
				hook.Run('BGN_ResetEnemiesForActor', self)
			end
		end

		return #self.enemies
	end

	function obj:RemoveAllEnemies()
		local last_count = 0
		for i = #self.enemies, 1, -1 do
			last_count = self:RemoveEnemy(nil, i)
		end

		-- Safety bag. It may be removed in the future.
		if last_count > 0 then
			table.Empty(self.enemies)
			hook.Run('BGN_ResetEnemiesForActor', self)
		end
	end

	function obj:HasEnemy(ent)
		local _ent = ent
		if _ent.isBgnClass then _ent = ent:GetNPC() end
		if IsValid(_ent) and _ent:IsNPC() and _ent:Disposition(self:GetNPC()) == D_HT then return true end
		return table.HasValueBySeq(self.enemies, _ent)
	end

	function obj:EnemiesCount()
		return table.Count(self.enemies)
	end

	function obj:EnemiesRecalculate()
		local npc = self:GetNPC()
		local active_enemy = npc:GetEnemy()
		if IsValid(active_enemy) and active_enemy:IsVehicle() then
			npc:AddEntityRelationship(active_enemy, D_NU, 99)
		end

    if #self.enemies == 0 then return end

		for i = 1, #self.enemies do
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
				elseif not WantedModule:HasWanted(enemy) then
					local time = npc:GetEnemyLastTimeSeen(enemy)
					if time + 20 < CurTime() then
						self:RemoveEnemy(enemy)
						-- print(self.uid, 'remove enemy - ', enemy)
					end
				end
			end
		end
	end

	function obj:GetNearEnemy()
		local enemy = NULL
		local dist = 0
		local self_npc = self:GetNPC()

		for i = 1, #self.enemies do
			local ent = self.enemies[i]
			if IsValid(ent) then
				if not IsValid(enemy) then
					enemy = ent
					dist = ent:GetPos():DistToSqr(self_npc:GetPos())
				elseif ent:GetPos():DistToSqr(self_npc:GetPos()) < dist then
					enemy = ent
					dist = ent:GetPos():DistToSqr(self_npc:GetPos())
				end
			end
		end

		return enemy
	end

	function obj:GetEnemy()
		return self:GetNearEnemy()
	end

	function obj:GetFirstEnemy()
		for i = 1, #self.enemies do
			local enemy = self.enemies[i]
			if IsValid(enemy) then return enemy end
		end
		return NULL
	end

	function obj:GetNearEnemy()
		local enemy = NULL
		local dist = nil
		local npcPos = self:GetNPC():GetPos()

		for i = 1, #self.enemies do
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

	function obj:GetLastEnemy()
		for i = #self.enemies, 1, -1 do
			local enemy = self.enemies[i]
			if IsValid(enemy) then return enemy end
		end
		return NULL
	end

	-- Recalculates targets, and removes them if they are dead or no longer exist on the map.
	-- @return table new_targets new target list
	function obj:RecalculationTargets()
		for i = #self.targets, 1, -1 do
			local target = self.targets[i]
			if not IsValid(target) then
				self:RemoveTarget(nil, i)
			elseif target:IsPlayer() and target:Health() <= 0 then
				self:RemoveTarget(nil, i)
			end
		end

		return self.targets
	end

	function obj:StateLock(lock)
		lock = lock or false
		self.state_lock = lock
	end

	function obj:IsStateLock()
		return self.state_lock
	end

	function obj:CallStateAction(current_state, func_name, ...)
		current_state = current_state or self.state_data.state
		return bgNPC:CallStateAction(current_state, func_name, self, ...)
	end

	function obj:SetState(state, data, forced)
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

		-- local hook_result = hook.Run('BGN_PreSetNPCState', self, state, data)
		-- if hook_result then
		-- 	if isbool(hook_result) then
		-- 		return
		-- 	elseif isstring(hook_result) then
		-- 		state = hook_result
		-- 	elseif istable(hook_result) then
		-- 		state = hook_result.state or state
		-- 		data = hook_result.data or {}
		-- 	end
		-- end

		if not forced and bgNPC:StateActionExists(state, 'validator') then
			if not self:CallStateAction(state, 'validator', state, data) then return end
		end

		local new_state, new_data = self:CallStateAction(state, 'pre_start', state, data)
		if type(new_state) == 'boolean' and new_state == true then return end

		state = new_state or state
		data = new_data or data

		self:CallStateAction(nil, 'stop', current_state, current_data)

		if SERVER then
			self:StopWalk()
			self.anim_action = nil
			self:ResetSequence()
		end

		state = new_state or state
		data = new_data or data

		self.old_state = self.state_data
		self.state_data = { state = state, data = data }

		self:CallStateAction(state, 'start', self.state_data.state, self.state_data.data)
		hook.Run('BGN_SetNPCState', self, self.state_data.state, self.state_data.data)
		
		return self.state_data
	end

	function obj:SetWalkType(moveType)
		local moveType = moveType or 'walk'
		local schedule = SCHED_FORCED_GO

		if isnumber(moveType) then
			schedule = moveType
		elseif isstring(moveType) then
			if moveType == 'run' then
				schedule = SCHED_FORCED_GO_RUN
			end
		end

		self.walkType = schedule
	end

	function obj:StopWalk()
		self.walkTarget = NULL
		self.walkPath = {}
		self.walkPos = nil
		self.walkUpdatePathDelay = 0
		self.pathType = nil
		self.isChase = false
		self:SetWalkType()
	end

	function obj:WalkToTarget(target, moveType, pathType)
		if self:GetNPC():IsNextBot() then return end
		
		if target == nil or not IsValid(target) then
			self:StopWalk()
		else
			local npc = self.npc
			if npc:GetPos():DistToSqr(target:GetPos()) <= 2500 then
				local walk_type = moveType or 'walk'
				hook.Run('BGN_ActorFinishedWalk', self, target:GetPos(), walk_type)	
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

	function obj:WalkToPos(pos, moveType, pathType)
		if self:GetNPC():IsNextBot() then return end

		if pos == nil then 
			self:StopWalk()
			return
		end

		if self.walkPos == pos then
			return
		end

		local npc = self.npc
		if npc:GetPos():DistToSqr(pos) <= 2500 then 
			local walk_type = moveType or 'walk'
			hook.Run('BGN_ActorFinishedWalk', self, pos, walk_type)	
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

				for _, v in ipairs(route) do
					table.insert(walkPath, v.Target)
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

	function obj:UpdateMovement()
		if self.is_animated or not self:IsAlive() then return end

		if self:InVehicle() then
			local vehicle = self:GetVehicle()
			if vehicle:GetPos():DistToSqr(self.walkPos) <= 2500 then
				hook.Run('BGN_ActorFinishedWalk', self, self.walkPos, self.walkType)
			end
		else
			if #self.walkPath == 0 then return end
			
			local npc = self.npc
			local hasNext = false
			local targetPosition = self.walkPath[1]

			if npc:GetPos():DistToSqr(targetPosition) <= 2500 then
				table.remove(self.walkPath, 1)
				
				if #self.walkPath == 0 then
					if not hook.Run('BGN_ActorFinishedWalk', self, targetPosition, self.walkType) then
						self:WalkToPos(nil)
					end
					return
				end

				hasNext = true
			end

			local current_schedule = npc:GetCurrentSchedule()

			if (self.walkType == SCHED_FORCED_GO and current_schedule == SCHED_FORCED_GO_RUN) or (self.walkType == SCHED_FORCED_GO_RUN and current_schedule == SCHED_FORCED_GO) then
				npc:SetSchedule(self.walkType)
			end

			if not hasNext then
				if npc:IsEFlagSet(EFL_NO_THINK_FUNCTION) then return end
				if npc:IsMoving() then return end
			end

			for i = 1, #schedule_white_list do
				if schedule_white_list[i] == current_schedule then return end
			end

			npc:SetLastPosition(targetPosition)
			npc:SetSchedule(self.walkType)
		end
	end

	function obj:Walking()
		return npc:IsMoving()
	end

	function obj:HasTeam(value)
		local value = value
		if self.data.team ~= nil and value ~= nil then
			if isstring(value) then
				return table.HasValueBySeq(self.data.team, value)
			end

			if isentity(value) then
				if value:IsPlayer() then
					if table.HasValueBySeq(self.data.team, 'player') then
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

	function obj:UpdateStateData(data)
		self.state_data.data = data
	end

	function obj:HasState(state)
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

	function obj:GetOldState()
		return self.old_state.state
	end

	function obj:GetOldStateData()
		return self.old_state.data
	end

	function obj:GetState()
		return self.state_data.state
	end

	function obj:GetStateData()
		return self.state_data.data
	end

	function obj:GetDistantPointToPoint(pos, radius)
		if not self:IsAlive() or not isvector(pos) then return nil end
		radius = radius or 500
		
		local point = nil
		local dist = 0
		local npc = self:GetNPC()
		local points = bgNPC:GetAllPointsInRadius(npc:GetPos(), radius)

		for i = 1, #points do
			local point = points[i]
			if point == nil then
				point = point.position
				dist = point:DistToSqr(pos)
			elseif point.position:DistToSqr(pos) > dist then
				point = point.position
				dist = point:DistToSqr(pos)
			end
		end

		return point 
	end

	function obj:GetClosestPointToPoint(pos, radius)
		if not self:IsAlive() or not isvector(pos) then return nil end
		radius = radius or 500
		
		local point = nil
		local dist = 0
		local npc = self:GetNPC()
		local points = bgNPC:GetAllPointsInRadius(npc:GetPos(), radius)

		for i = 1, #points do
			local point = points[i]
			if point == nil then
				point = point.position
				dist = point:DistToSqr(pos)
			elseif point.position:DistToSqr(pos) < dist then
				point = point.position
				dist = point:DistToSqr(pos)
			end
		end

		return point 
	end

	function obj:GetDistantPointInRadius(radius)
		if not self:IsAlive() then return nil end
		return bgNPC:GetDistantPointInRadius(npc:GetPos(), radius)
	end

	function obj:GetClosestPointInRadius(radius)
		if not self:IsAlive() then return nil end
		return bgNPC:GetClosestPointInRadius(npc:GetPos(), radius)
	end

	function obj:GetReactionForDamage()
		local probability = math.random(1, (self.data.at_damage_range or 100))
		local percent, reaction = table.Random(self.data.at_damage)

		if probability > percent then
			local last_percent = 0
			
			for _reaction, _percent in pairs(self.data.at_damage) do
				if _percent > last_percent then
					percent = _percent
					reaction = _reaction
					last_percent = _percent
				end
			end
		end

		reaction = reaction or 'ignore'
		
		if reaction == 'defense' and self.type == 'citizen' 
			and GetConVar('bgn_disable_citizens_weapons'):GetBool()
		then
			reaction = 'fear'
		end

		return reaction
	end

	function obj:GetReactionForProtect()
		local probability = math.random(1, (self.data.at_protect_range or 100))
		local percent, reaction = table.Random(self.data.at_protect)

		if probability > percent then
			local last_percent = 0
			
			for _reaction, _percent in pairs(self.data.at_protect) do
				if _percent > last_percent then
					percent = _percent
					reaction = _reaction
					last_percent = _percent
				end
			end
		end

		reaction = reaction or 'ignore'

		if reaction == 'defense' and self.type == 'citizen' 
			and GetConVar('bgn_disable_citizens_weapons'):GetBool()
		then
			reaction = 'fear'
		end

		return reaction
	end

	function obj:SetSchedule(schedule)
		if self:IsSequenceFinished() then
			self.npc:SetSchedule(schedule)
			
			self.npc_schedule = self.npc:GetCurrentSchedule()
			self.npc_state = self.npc:GetNPCState()
		end
	end

	function obj:IsValidSequence(sequence_name)
		return self.npc:LookupSequence(sequence_name) ~= -1
	end

	function obj:PlayStaticSequence(sequence_name, loop, loop_time, action)
		if not self:IsValidSequence(sequence_name) then return false end
		
		if self:HasSequence(sequence_name) then
			if self.anim_is_loop and not self:IsSequenceLoopFinished() then
				return true
			elseif not self.anim_is_loop and not self:IsSequenceFinished() then
				return true
			end
		end

		local hook_result = hook.Run('BGN_PreNPCStartAnimation', 
			self, sequence_name, loop, loop_time)

		if hook_result ~= nil and isbool(hook_result) and not hook_result then
			return false
		end

		self.anim_is_loop = loop or false
		self.anim_name = string.lower(sequence_name)
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

		hook.Run('BGN_StartedNPCAnimation', self, sequence_name, loop, loop_time)

		return true
	end

	function obj:SetNextSequence(sequence_name, loop, loop_time, action)
		self.next_anim = {
			sequence_name = sequence_name,
			loop = loop,
			loop_time = loop_time,
			action = action,
		}
	end

	function obj:HasSequence(sequence_name)
		return self.anim_name == string.lower(sequence_name)
	end

	function obj:IsAnimationPlayed()
		return self.is_animated
	end

	function obj:IsSequenceLoopFinished()
		if self:IsLoopSequence() then
			if self.loop_time == 0 then return false end

			if self.loop_time_normal > 0 then
				self.loop_time_normal = self.loop_time - RealTime()
			end

			return self.loop_time < RealTime()
		end
		return true
	end

	function obj:IsLoopSequence()
		return self.anim_is_loop
	end

	function obj:IsSequenceFinished()
		if self.anim_time_normal > 0 then
			self.anim_time_normal = self.anim_time - RealTime()
		end

		return self.anim_time <= RealTime()
	end

	function obj:PlayNextStaticSequence()
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

	function obj:ResetSequence()
		if self.anim_action ~= nil and not self.anim_action(self) then return end

		self.is_animated = false
		self.next_anim = nil
		self.anim_action = nil

		self:ClearSchedule()
	end

	function obj:FearScream()
		if not self:IsAlive() then return end

		local npc_model = self.npc:GetModel()
		local scream_sound = nil
		if tobool(string.find(npc_model, 'female_*')) then
			scream_sound = table.RandomBySeq(female_scream)
		elseif tobool(string.find(npc_model, 'male_*')) then
			scream_sound = table.RandomBySeq(male_scream)
		else
			local concatenated_table = table.Copy(male_scream)
			table.Add(concatenated_table, female_scream)
			scream_sound = table.RandomBySeq(concatenated_table)
		end

		if scream_sound ~= nil and isstring(scream_sound) then
			self.npc:EmitSound(scream_sound, 100, 100, 1, CHAN_AUTO)
		end
	end

	function obj:CallForHelp(enemy)
		if not IsValid(enemy) then return end
		if hook.Run('BGN_PreCallForHelp', self, enemy) then return end

		self:FearScream()

		local near_actors = bgNPC:GetAllByRadius(npc:GetPos(), 1000)
		for i = 1, #near_actors do
			local NearActor = near_actors[i]
			local NearNPC = NearActor:GetNPC()
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

	function obj:EqualStateGroup(group_name)
		return bgNPC:GetStateGroupName(self:GetState()) == group_name
	end

	function obj:HasStateGroup(state_name, group_name)
		return bgNPC:GetStateGroupName(state_name) == group_name
	end

	function obj:IsMeleeWeapon()
		if not self:IsAlive() then return false end

		local npc = self:GetNPC()
		local wep = npc:GetActiveWeapon()
		if not IsValid(wep) then return false end

		return table.HasValueBySeq(bgNPC.cfg.weapons['melee'], wep:GetClass())
	end

	function obj:IsFirearmsWeapon()
		if not self:IsAlive() then return false end

		local npc = self:GetNPC()
		local wep = npc:GetActiveWeapon()
		if not IsValid(wep) then return false end

		return not table.HasValueBySeq(bgNPC.cfg.weapons['not_firearms'], wep:GetClass())
	end

	function obj:EnterVehicle(vehicle)
		if not DecentVehicleDestination or not vehicle:IsVehicle() then return end

		local vehicle_provider = BGN_VEHICLE:GetVehicleProvider(vehicle)
		if not vehicle_provider then
			if self:HasTeam('police') then
				vehicle_provider = BGN_VEHICLE:Instance(vehicle, 'police')
			elseif self:HasTeam('taxi') then
				vehicle_provider = BGN_VEHICLE:Instance(vehicle, 'taxi')
			else
				vehicle_provider = BGN_VEHICLE:Instance(vehicle)
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

		local npc = self:GetNPC()
		vehicle:slibCreateTimer('bgn_actor_enter_vehicle', 0.5, 1, function(vehicle)
			if not vehicle_provider or not IsValid(vehicle) then return end
			if not self or not self:IsAlive() then return end

			self.eternal = true
			self.vehicle = vehicle_provider

			npc:SetNoDraw(true)

			if not vehicle_provider:GetDriver() then
				vehicle_provider:SetDriver(self)
			else
				if not vehicle_provider:AddPassenger(self) then
					npc:SetNoDraw(false)
					return
				end
			end

			npc:slibSetVar('bgn_vehicle_entered', true)
			npc:SetCollisionGroup(COLLISION_GROUP_WORLD)
			npc:SetPos(vehicle:GetPos() + vehicle:GetUp() * 300)
			npc:SetModelScale(0.1)
			npc:SetParent(vehicle)
			npc:AddEFlags(EFL_NO_THINK_FUNCTION)

			self.walkUpdatePathDelay = 0
		end)
	end

	function obj:ExitVehicle()
		if not DecentVehicleDestination then return end

		local vehicle_provider = self.vehicle
		if vehicle_provider and IsValid(vehicle_provider) then
			local vehicle = vehicle_provider:GetVehicle()
			local min, max = vehicle:GetModelBounds()
			local dist = min:Distance(max) / 2
			local pos = vehicle:GetPos()
			local forward = vehicle:GetForward()
			local right = vehicle:GetRight()
			local up = vehicle:GetUp()
			local npc = self:GetNPC()
			local add_forward = math.random(-100, 100)
			local add_right = dist
			if math.random(0, 100) > 50 then
				add_right = -dist
			end

			npc:slibSetVar('bgn_vehicle_entered', false)
			npc:SetParent(nil)

			local exit_pos = pos + (right * add_right) + (forward * add_forward) + (up * 50)
			local tr = util.TraceLine({
				start = exit_pos,
				endpos = exit_pos - Vector(0, 0, 500),
				filter = function(ent)
					if ent ~= npc then return true end
				end
			})

			if tr.Hit then
				exit_pos = tr.HitPos + Vector(0, 0, 15)
			end

			npc:SetPos(exit_pos)
			npc:SetAngles(Angle(0, npc:GetAngles().y, 0))
			npc:SetCollisionGroup(self.collision_group)
			npc:SetModelScale(self.model_scale)
			npc:RemoveEFlags(EFL_NO_THINK_FUNCTION)
			npc:PhysWake()
			npc:SetNoDraw(false)

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

	function obj:InVehicle()
		if SERVER then
			return ( self.vehicle and IsValid(self.vehicle) )
		else
			return self:GetNPC():slibGetVar('bgn_vehicle_entered', false)
		end
	end

	function obj:GetVehicle()
		if not self:InVehicle() then return nil end
		return self.vehicle:GetVehicle()
	end

	function obj:GetVehicleAI()
		if not self:InVehicle() then return nil end
		return self.vehicle:GetVehicleAI()
	end

	function obj:GetActorWeapon()
		return self.weapon
	end

	function obj:GetActiveWeapon()
		if self:IsAlive() then
			local npc = self:GetNPC()
			local weapon  = npc:GetActiveWeapon()
			if IsValid(weapon) then return weapon end
		end
		return NULL
	end

	function obj:PrepareWeapon(weapon_class, switching)
		if weapon_class then
			bgNPC:SetActorWeapon(self, weapon_class, switching)
		elseif self.weapon then
			bgNPC:SetActorWeapon(self)
		end
	end

	function obj:FoldWeapon()
		if not self:IsAlive() then return end
		local npc = self:GetNPC()
		local weapon  = npc:GetActiveWeapon()
		if IsValid(weapon) then weapon:Remove() end
	end

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
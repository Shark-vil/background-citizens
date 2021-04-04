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

local uid = 0
function BGN_ACTOR:Instance(npc, type, data, custom_uid)
	local obj = {}
	
	uid = custom_uid or (uid + 1)

	obj.uid = uid
	obj.npc = npc
	obj.class = npc:GetClass()
	obj.data = data
	obj.type = type
	obj.reaction = ''
	obj.eternal = false

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

	obj.isBgnClass = true
	obj.targets = {}
	obj.enemies = {}

	obj.npc_schedule = -1
	obj.npc_state = -1

	function obj:SyncFunction(name, ply, data)
		if CLIENT then return end
		if not self:IsAlive() then return end

		local npc = self:GetNPC()
		
		if ply then
			if IsValid(ply) then
				snet.Invoke(name, ply, npc, data)
			end
		else
			snet.InvokeAll(name, npc, data)
		end
	end

	-- Synchronizes all required variables with clients.
	-- @param ply entity|nil The entity of the player for which you want to sync data (If not, then sync will be for everyone)
	function obj:SyncData(ply)
		self:SyncAnimation(ply)
		self:SyncEnemies(ply)
		self:SyncReaction(ply)
		self:SyncSchedule(ply)
		self:SyncState(ply)
		self:SyncTargets(ply)
	end

	-- Synchronizes the "reaction" setting for all clients.
	function obj:SyncReaction(ply)
		self:SyncFunction('bgn_actor_sync_data_reaction_client', ply, {
			reaction = self.reaction,
		})
	end

	-- Synchronizes the "schedule" setting for all clients.
	function obj:SyncSchedule(ply)
		self:SyncFunction('bgn_actor_sync_data_schedule_client', ply, {
			npc_schedule = self.npc_schedule,
			npc_state = self.npc_state,
		})
	end

	-- Synchronizes the "targets" setting for all clients.
	function obj:SyncTargets(ply)
		self:SyncFunction('bgn_actor_sync_data_targets_client', ply, {
			targets = self.targets,
		})
	end

	-- Synchronizes the "state" setting for all clients.
	function obj:SyncState(ply)
		if not bgNPC.cfg.EnableEasySyncStateDataForClient then
			self:SyncFunction('bgn_actor_sync_data_state_client', ply, {
				old_state = self.old_state,
				state_lock = self.state_lock,
				state = self.state_data,
			})
		else
			self:SyncFunction('bgn_actor_easy_sync_data_state_client', ply, {
				old_state = self.old_state.state,
				state_lock = self.state_lock,
				state = self.state_data.state,
			})
		end
	end

	-- Synchronizes the "animation" setting for all clients.
	function obj:SyncAnimation(ply)
		self:SyncFunction('bgn_actor_sync_data_animation_client', ply, {
			anim_name = self.anim_name,
			anim_time = self.anim_time,
			loop_time = self.loop_time,
			anim_is_loop = self.anim_is_loop,
			is_animated = self.is_animated,
			anim_time_normal = self.anim_time_normal,
			loop_time_normal = self.loop_time_normal,
		})
	end

	function obj:SyncEnemies(ply)
		self:SyncFunction('bgn_actor_sync_data_enemies', ply, {
			enemies = self.enemies,
		})
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
		self.reaction = reaction
		self:SyncReaction()
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

		-- self.walkPos = nil
		-- self.walkPath = {}
		
		self.npc:SetNPCState(NPC_STATE_IDLE)
		self.npc:ClearSchedule()

		self.npc_schedule = self.npc:GetCurrentSchedule()
		self.npc_state = self.npc:GetNPCState()

		self:SyncSchedule()
	end

	-- Adds a target for the actor and syncs new targets for clients.
	-- ? The target doesn't have to be the enemy. This is used in state calculations.
	-- @param ent entity any entity other than the actor himself
	function obj:AddTarget(ent)
		if not IsValid(ent) or not isentity(ent) then return end
		
		if self:GetNPC() ~= ent and not table.IHasValue(self.targets, ent) then            
			table.insert(self.targets, ent)

			self:SyncTargets()
		end
	end

	-- Removes an entity from the target list and syncs new list for clients.
	-- ! If you simply remove an entity from the list, it will not automatically cancel the relationship with the NPC.
	-- @param ent entity|NULL any entity
	-- @param index number|nil target id in table
	-- ? If there is no entity, use an index. If there is no index, use entity.
	function obj:RemoveTarget(ent, index)
		local ent = ent

		if index ~= nil then
			if not isnumber(index) then return end
			ent = self.targets[index]
		end

		if not isentity(ent) then return end

		local old_count = #self.targets

		if ent == self.walkTarget then
			self.walkTarget = NULL
		end

		if index ~= nil then
			table.remove(self.targets, index)
		else
			table.RemoveByValue(self.targets, ent)
		end

		if old_count > 0 and #self.targets <= 0 then
			hook.Run('BGN_ResetTargetsForActor', self)
		end

		self:SyncTargets()
	end

	-- Removes all targets from the list.
	-- ? Actually calls method "RemoveTarget" for all targets in the list.
	function obj:RemoveAllTargets()
		for i = 1, #self.targets do
			self:RemoveTarget(self.targets[i])
		end
	end

	-- Checks for the existence of an entity in the target list.
	-- @param ent entity any entity
	-- @return boolean is_exist will return true if the entity is the target, otherwise false
	function obj:HasTarget(ent)
		return table.IHasValue(self.targets, ent)
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

		if npc ~= ent and not table.IHasValue(self.enemies, ent) then
			if not hook.Run('BGN_AddActorEnemy', self, ent) then
				if npc:IsNPC() then
					local relationship = D_HT
					if reaction == 'fear' then relationship = D_FR end
					npc:AddEntityRelationship(ent, relationship, 99)
				end
				table.insert(self.enemies, ent)
				self:EnemiesRecalculate()
				self:SyncEnemies()
			end
		end
	end

	function obj:RemoveEnemy(ent, index)
		local ent = ent

		if index ~= nil then
			if not isnumber(index) then return end
			ent = self.enemies[index]
		end

		if not isentity(ent) then return end

		local old_count = #self.enemies

		if ent == self.walkTarget then
			self.walkTarget = NULL
		end

		if not hook.Run('BGN_RemoveActorEnemy', self, ent) then
			local npc = self:GetNPC()
			
			if npc:IsNPC() then
				if npc:GetEnemy() == ent then
					npc:SetEnemy(NULL)
				end

				if IsValid(ent) then
					npc:AddEntityRelationship(ent, D_NU, 99)
				end
			end

			if index ~= nil then
				table.remove(self.enemies, index)
			else
				table.RemoveByValue(self.enemies, ent)
			end

			if old_count > 0 and #self.enemies <= 0 then
				hook.Run('BGN_ResetEnemiesForActor', self)
			end

			self:SyncEnemies()
		end
	end

	function obj:RemoveAllEnemies()
		for i = 1, #self.enemies do
			self:RemoveEnemy(self.enemies[i])
		end
	end

	function obj:HasEnemy(ent)
		return table.IHasValue(self.enemies, ent)
	end

	function obj:EnemiesCount()
		return table.Count(self.enemies)
	end

	function obj:EnemiesRecalculate()
		local npc = self:GetNPC()

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

		self:SyncState()
	end

	function obj:IsStateLock()
		return self.state_lock
	end

	function obj:SetOldState()
		if self:GetData().disable_states then return end
		if self.state_lock then return end
		
		if self.old_state ~= nil then
			self.state_data = self.old_state
			self.old_state = nil

			if IsValid(self.npc) then
				hook.Run('BGN_SetNPCState', self, self.state_data.state, self.state_data.data)
			end

			self:SyncState()
		end
	end

	function obj:SetState(state, data)
		if self:GetData().disable_states then return end
		if self.state_lock then return end
		if state == 'ignore' then return end

		data = data or {}

		local hook_result = hook.Run('BGN_PreSetNPCState', self, state, data)
		if hook_result then
			if isbool(hook_result) then
				return
			elseif istable(hook_result) then
				state = hook_result.state or state
				data = hook_result.data or {}
			end
		end

		if self.old_state.state ~= state then
			self:StopWalk()
		end

		self.old_state = self.state_data
		self.state_data = { state = state, data = data }

		if SERVER then
			self.anim_action = nil
			self:ResetSequence()
		end

		if IsValid(self.npc) then
			hook.Run('BGN_SetNPCState', self, self.state_data.state, self.state_data.data)
		end

		self:SyncState()
		
		return self.state_data
	end

	function obj:SetWalkType(type)
		local type = type or 'walk'
		local schedule = SCHED_FORCED_GO

		if isnumber(type) then
			schedule = type
		elseif isstring(type) then
			if type == 'run' then
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
		self:SetWalkType()
	end

	function obj:WalkToTarget(target, type, pathType)
		if self:GetNPC():IsNextBot() then return end
		
		if target == nil or not IsValid(target) then
			self:StopWalk()
		else
			local npc = self.npc
			if npc:GetPos():DistToSqr(target:GetPos()) <= 2500 then return end

			self:SetWalkType(type)

			if self.walkTarget ~= target then
				self.pathType = pathType
				self.walkUpdatePathDelay = 0
				self.walkPos = nil
				self.walkTarget = target
			end
		end
	end

	function obj:WalkToPos(pos, type, pathType)
		if self:GetNPC():IsNextBot() then return end

		if pos == nil then 
			self:StopWalk()
			return
		end

		if self.walkPos == pos then
			return
		end

		local npc = self.npc
		if npc:GetPos():DistToSqr(pos) <= 2500 then return end
		if npc:IsEFlagSet(EFL_NO_THINK_FUNCTION) then return end

		local walkPath = bgNPC:FindWalkPath(npc:GetPos(), pos, nil, pathType)
		if #walkPath == 0 then return end

		self.pathType = pathType
		self.walkTarget = NULL
		self:SetWalkType(type)
		self.walkPos = pos
		self.walkPath = walkPath
	end

	function obj:UpdateMovement()
		if self.is_animated or #self.walkPath == 0 or not self:IsAlive() then return end
		
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

		if not hasNext then
			if npc:IsEFlagSet(EFL_NO_THINK_FUNCTION) then return end
			if npc:IsMoving() then return end
		end

		local current_schedule = npc:GetCurrentSchedule()
		for i = 1, #schedule_white_list do
			if schedule_white_list[i] == current_schedule then return end
		end

		npc:SetLastPosition(targetPosition)
		npc:SetSchedule(self.walkType)
	end

	function obj:Walking()
		return npc:IsMoving()
	end

	function obj:HasTeam(value)
		if self.data.team ~= nil and value ~= nil then
			if isstring(value) then
				return table.IHasValue(self.data.team, value)
			end

			if isentity(value) then
				if value:IsPlayer() then
					if table.IHasValue(self.data.team, 'player') then
						return true
					else
						local TeamParentModule = bgNPC:GetModule('team_parent')
						return TeamParentModule:HasParent(value, self)
					end
				elseif value.isBgnActor and (value:IsNPC() or value:IsNextBot()) then
					local actor = bgNPC:GetActor(value)
					if actor then value = actor:GetData().team end
				end
			end
			
			if istable(value) then
				for i = 1, #self.data.team do
					local team_1 = self.data.team[i]
					for k = 1, #value do
						local team_2 = value[k]
						if team_1 == team_2 then return true end
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
		if current_state == state then
			return true
		elseif istable(state) then
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
				point = value.position
				dist = point:DistToSqr(pos)
			elseif value.position:DistToSqr(pos) > dist then
				point = value.position
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
				point = value.position
				dist = point:DistToSqr(pos)
			elseif value.position:DistToSqr(pos) < dist then
				point = value.position
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

			self:SyncSchedule()
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

		self:SyncAnimation()

		return true
	end

	function obj:SetNextSequence(sequence_name, loop, loop_time, action)
		self.next_anim = {
			sequence_name = sequence_name,
			loop = loop,
			loop_time = loop_time,
			action = action,
		}

		self:SyncAnimation()
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
				if bgNPC.cfg.SyncUpdateAnimationForClient and self.sync_animation_delay < CurTime() then
					self:SyncAnimation()
					self.sync_animation_delay = CurTime() + 0.5
				end
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
			if bgNPC.cfg.SyncUpdateAnimationForClient and self.sync_animation_delay < CurTime() then
				self:SyncAnimation()
				self.sync_animation_delay = CurTime() + 0.5
			end
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
		-- self.anim_name = ''
		-- self.anim_time = 0
		-- self.anim_is_loop = false

		if self.anim_action ~= nil then
			if not self.anim_action(self) then
				return
			end
		end
		
		self.is_animated = false
		self.next_anim = nil
		self.anim_action = nil
		
		self:SyncAnimation()
		self:ClearSchedule()
	end

	function obj:FearScream()
		if not self:IsAlive() then return end

		local npc_model = self.npc:GetModel()
		local scream_sound = nil
		if tobool(string.find(npc_model, 'female_*')) then
			scream_sound = table.Random(female_scream)
		elseif tobool(string.find(npc_model, 'male_*')) then
			scream_sound = table.Random(male_scream)
		else
			scream_sound = table.Random(table.Inherit(male_scream, female_scream))
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

	function obj:InDangerState()
		return table.IHasValue(bgNPC.cfg.npcs_states['danger'], self:GetState())
	end

	function obj:InCalmlyState()
		return table.IHasValue(bgNPC.cfg.npcs_states['calmly'], self:GetState())
	end

	function obj:HasDangerState(state_name)
		return table.IHasValue(bgNPC.cfg.npcs_states['danger'], state_name)
	end

	function obj:HasCalmlyState(state_name)
		return table.IHasValue(bgNPC.cfg.npcs_states['calmly'], state_name)
	end

	function obj:IsMeleeWeapon()
		if not self:IsAlive() then return false end

		local npc = self:GetNPC()
		local wep = npc:GetActiveWeapon()
		if not IsValid(wep) then return false end

		return table.IHasValue(bgNPC.cfg.weapons['melee'], wep:GetClass())
	end

	function obj:IsFirearmsWeapon()
		if not self:IsAlive() then return false end

		local npc = self:GetNPC()
		local wep = npc:GetActiveWeapon()
		if not IsValid(wep) then return false end

		return not table.IHasValue(bgNPC.cfg.weapons['not_firearms'], wep:GetClass())
	end

	function npc:GetActor()
		return obj
	end

	npc.isBgnActor = true

	return obj
end

snet.RegisterValidator('actor', function(ply, uid, ent)
	return bgNPC:GetActor(ent) ~= nil
end)
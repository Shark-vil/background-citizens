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
	obj.old_state = nil
	obj.state_lock = false

	obj.isBgnClass = true
	obj.targets = {}

	obj.npc_schedule = -1
	obj.npc_state = -1

	-- Synchronizes all required variables with clients.
	-- @param ply entity|nil The entity of the player for which you want to sync data (If not, then sync will be for everyone)
	function obj:SyncData(ply)
		ply = ply or NULL
		if CLIENT then return end
		if not self:IsAlive() then return end

		local sync_data = {
			uid = self.uid,
			anim_name = self.anim_name,
			reaction = self.reaction,
			anim_time = self.anim_time,
			loop_time = self.loop_time,
			anim_is_loop = self.anim_is_loop,
			is_animated = self.is_animated,
			old_state = self.old_state,
			state_lock = self.state_lock,
			targets = self.targets,
			state_data = self.state_data,
			npc_schedule = self.npc_schedule,
			npc_state = self.npc_state,
			anim_time_normal = self.anim_time_normal,
			loop_time_normal = self.loop_time_normal,
		}

		if not IsValid(ply) then
			snet.InvokeAll('bgn_actor_sync_data_client', npc, sync_data)
		else
			snet.Invoke('bgn_actor_sync_data_client', ply, npc, sync_data)
		end
	end

	-- Synchronizes the "reaction" setting for all clients.
	function obj:SyncReaction()
		if CLIENT then return end
		if not self:IsAlive() then return end

		snet.InvokeAll('bgn_actor_sync_data_reaction_client', npc, {
			reaction = self.reaction,
		})
	end

	-- Synchronizes the "schedule" setting for all clients.
	function obj:SyncSchedule()
		if CLIENT then return end
		if not self:IsAlive() then return end

		snet.InvokeAll('bgn_actor_sync_data_schedule_client', npc, {
			npc_schedule = self.npc_schedule,
			npc_state = self.npc_state,
		})
	end

	-- Synchronizes the "targets" setting for all clients.
	function obj:SyncTargets()
		if CLIENT then return end
		if not self:IsAlive() then return end

		snet.InvokeAll('bgn_actor_sync_data_targets_client', npc, {
			targets = self.targets,
		})
	end

	-- Synchronizes the "state" setting for all clients.
	function obj:SyncState()
		if CLIENT then return end
		if not self:IsAlive() then return end

		snet.InvokeAll('bgn_actor_sync_data_state_client', npc, {
			old_state = self.old_state,
			state_lock = self.state_lock,
			state_data = self.state_data,
		})
	end

	-- Synchronizes the "animation" setting for all clients.
	function obj:SyncAnimation()
		if CLIENT then return end
		if not self:IsAlive() then return end

		snet.InvokeAll('bgn_actor_sync_data_animation_client', npc, {
			anim_name = self.anim_name,
			anim_time = self.anim_time,
			loop_time = self.loop_time,
			anim_is_loop = self.anim_is_loop,
			is_animated = self.is_animated,
			anim_time_normal = self.anim_time_normal,
			loop_time_normal = self.loop_time_normal,
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

	-- Checks if the actor is alive or not.
	-- @return boolean is_alive return true if the actor is alive, otherwise false
	function obj:IsAlive()
		if IsValid(self.npc) and self.npc:Health() > 0 then
			return true
		end
		return false
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
		
		if self:GetNPC() ~= ent and not table.HasValue(self.targets, ent) then            
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
		if not IsValid(ent) or not isentity(ent) then return end

		local count = #self.targets

		if IsValid(self.npc) and ent:IsPlayer() then
			self.npc:AddEntityRelationship(ent, D_NU, 99)
		end

		if index ~= nil and isnumber(index) then
			table.remove(self.targets, index)
		else
			table.RemoveByValue(self.targets, ent)
		end

		if count > 0 and #self.targets <= 0 then
			hook.Run('BGN_ResetTargetsForActor', self)
		end

		self:SyncTargets()
	end

	-- Removes all targets from the list.
	-- ? Actually calls method "RemoveTarget" for all targets in the list.
	function obj:RemoveAllTargets()
		for _, t in ipairs(self.targets) do
			self:RemoveTarget(t)
		end
	end

	-- Checks for the existence of an entity in the target list.
	-- @param ent entity any entity
	-- @return boolean is_exist will return true if the entity is the target, otherwise false
	function obj:HasTarget(ent)
		return table.HasValue(self.targets, ent)
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

		for _, npc in ipairs(self.targets) do
			if IsValid(npc) then
				if not IsValid(target) then
					target = npc
					dist = npc:GetPos():DistToSqr(self_npc:GetPos())
				elseif npc:GetPos():DistToSqr(self_npc:GetPos()) < dist then
					target = npc
					dist = npc:GetPos():DistToSqr(self_npc:GetPos())
				end
			end
		end

		return target
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
		if self:GetData().disableStates then return end
		if self.state_lock then return end
		
		if self.old_state ~= nil then
			self.state_data = self.old_state
			self.old_state = nil

			if IsValid(self.npc) then
				hook.Run('BGN_SetNPCState', self, 
					self.state_data.state, self.state_data.data)
			end

			self:SyncState()
		end
	end

	function obj:SetState(state, data)
		if self:GetData().disableStates then return end
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

		self.old_state = self.state_data
		self.state_data = { state = state, data = data }

		if SERVER then
			snet.InvokeAll('bgn_actor_set_state_client', self:GetNPC(), 
				self.state_data.state, self.state_data.data)

			self.anim_action = nil
			self:ResetSequence()
		end

		if IsValid(self.npc) then
			hook.Run('BGN_SetNPCState', self, 
				self.state_data.state, self.state_data.data)
		end

		self:SyncState()
		
		return self.state_data
	end

	function obj:Walk()
		self:SetState('walk', {
			schedule = SCHED_FORCED_GO,
			runReset = 0
		})
	end

	function obj:Idle(idle_time)
		idle_time = idle_time or 10
		self:SetState('idle', {
			delay = CurTime() + idle_time
		})
	end

	function obj:Fear()
		self:SetState('fear', {
			delay = 0
		})
	end

	function obj:Defense()
		self:SetState('defense', {
			delay = 0
		})
	end

	function obj:HasTeam(value)
		if self.data.team ~= nil and value ~= nil then
			if isentity(value) then
				if value:IsPlayer() then
					if table.HasValue(self.data.team, 'player') then
						return true
					else
						local TeamParentModule = bgNPC:GetModule('team_parent')
						return TeamParentModule:HasParent(value, self)
					end
				elseif value:IsNPC() and value.isActor then
					local actor = bgNPC:GetActor(value)
					if actor ~= nil then
						value = actor
					end
				end
			end
			
			if istable(value) then
				if value.isBgnClass then
					value = value:GetData().team
				end

				for _, team_1 in ipairs(self.data.team) do
					for _, team_2 in ipairs(value) do
						if team_1 == team_2 then
							return true
						end
					end
				end
			elseif isstring(value) then
				return table.HasValue(self.data.team, value)
			end
		end
		return false
	end

	function obj:UpdateStateData(data)
		self.state_data.data = data
	end

	function obj:HasState(state)
		return (self:GetState() == state)
	end

	function obj:GetOldState()
		if self.old_state == nil then
			return 'none'
		end
		return self.old_state.state
	end

	function obj:GetOldStateData()
		if self.old_state == nil then
			return {}
		end
		return self.old_state.data
	end

	function obj:GetState()
		if self.state_data == nil then
			return 'none'
		end
		return self.state_data.state
	end

	function obj:GetStateData()
		if self.state_data == nil then
			return {}
		end
		return self.state_data.data
	end

	function obj:GetDistantPointInRadius(pos, radius)
		radius = radius or 500
		
		local point = nil
		local dist = 0
		local npc = self:GetNPC()
		local points = bgNPC:GetAllPointsInRadius(npc:GetPos(), radius)

		for _, value in ipairs(points) do
			if point == nil then
				point = value.pos
				dist = point:DistToSqr(pos)
			elseif value.pos:DistToSqr(pos) > dist then
				point = value.pos
				dist = point:DistToSqr(pos)
			end
		end

		return point 
	end

	function obj:GetClosestPointToPosition(pos, radius)
		radius = radius or 500
		
		local point = nil
		local dist = 0
		local npc = self:GetNPC()
		local points = bgNPC:GetAllPointsInRadius(npc:GetPos(), radius)

		for _, value in ipairs(points) do
			if point == nil then
				point = value.pos
				dist = point:DistToSqr(pos)
			elseif value.pos:DistToSqr(pos) < dist then
				point = value.pos
				dist = point:DistToSqr(pos)
			end
		end

		return point 
	end

	function obj:GetFarPointToPosition(pos, radius)
		radius = radius or 500
		
		local point = nil
		local dist = 0
		local npc = self:GetNPC()
		local points = bgNPC:GetAllPointsInRadius(npc:GetPos(), radius)

		for _, value in ipairs(points) do
			if point == nil then
				point = value.pos
				dist = point:DistToSqr(pos)
			elseif value.pos:DistToSqr(pos) > dist then
				point = value.pos
				dist = point:DistToSqr(pos)
			end
		end

		return point 
	end

	function obj:GetClosestPointInRadius(radius)
		radius = radius or 500
		
		local point = nil
		local dist = 0
		local npc = self:GetNPC()
		local pos = npc:GetPos()
		local points = bgNPC:GetAllPointsInRadius(pos, radius)

		for _, value in ipairs(points) do
			if point == nil then
				point = value.pos
				dist = point:DistToSqr(pos)
			elseif value.pos:DistToSqr(pos) < dist then
				point = value.pos
				dist = point:DistToSqr(pos)
			end
		end

		return point 
	end

	function obj:GetFarPointInRadius(radius)
		radius = radius or 500
		
		local point = nil
		local dist = 0
		local npc = self:GetNPC()
		local pos = npc:GetPos()
		local points = bgNPC:GetAllPointsInRadius(pos, radius)

		for _, value in ipairs(points) do
			if point == nil then
				point = value.pos
				dist = point:DistToSqr(pos)
			elseif value.pos:DistToSqr(pos) > dist then
				point = value.pos
				dist = point:DistToSqr(pos)
			end
		end

		return point 
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
		if self.npc:LookupSequence(sequence_name) == -1 then return false end
		return true
	end

	function obj:PlayStaticSequence(sequence_name, loop, loop_time, action)
		if self:IsValidSequence(sequence_name) then
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
				return
			end

			self.anim_is_loop = loop or false
			self.anim_name = sequence_name
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

		return false
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
		return self.anim_name == sequence_name
	end

	function obj:IsAnimationPlayed()
		return self.is_animated
	end

	function obj:IsSequenceLoopFinished()
		if self:IsLoopSequence() then
			if self.loop_time == 0 then return false end
			
			if self.loop_time_normal > 0 then
				self.loop_time_normal = self.loop_time - RealTime()
				if bgNPC.cfg.syncUpdateAnimationForClient and self.sync_animation_delay < CurTime() then
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
			if bgNPC.cfg.syncUpdateAnimationForClient and self.sync_animation_delay < CurTime() then
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

	function obj:CallForHelp(target)
		self:FearScream()

		if not IsValid(target) then
			target = self:GetNearTarget()
			if not IsValid(target) then return end
		end
				
		local near_actors = bgNPC:GetAllByRadius(npc:GetPos(), 1000)
		for _, NearActor in ipairs(near_actors) do
			local NearNPC = NearActor:GetNPC()
			if NearActor:IsAlive() and NearActor:HasTeam(self) and bgNPC:IsTargetRay(NearNPC, target) then
				NearActor:SetState(NearActor:GetReactionForProtect())
				NearActor:AddTarget(target)
			end
		end

		local TargetActor = bgNPC:GetActor(target)
		if TargetActor ~= nil and not TargetActor:HasTeam(self) then
			if not TargetActor:HasState('impingement') and not TargetActor:HasState('defense') then
				TargetActor:SetState('defense')
			end
			TargetActor:AddTarget(npc)
		end
	end

	function npc:GetActor()
		return obj
	end

	npc.isBgnActor = true

	return obj
end
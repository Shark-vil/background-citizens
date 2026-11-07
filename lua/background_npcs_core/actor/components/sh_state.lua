local Actor = bgNPC.Actor
local Assert = bgNPC.Assert
local H = Actor.Helpers
--

-- ---------------------------------------------------------------------------
-- State delay
-- ---------------------------------------------------------------------------
function Actor:SetStateDelay(time)
	Assert.Arg(1, time, 'number', 'ACTOR:SetStateDelay')
	self.state_delay = CurTime() + time
end

function Actor:IsStateDelay()
	return self.state_delay > CurTime()
end

function Actor:ResetStateDelay()
	self.state_delay = 0
end

-- ---------------------------------------------------------------------------
-- Random reactions
-- ---------------------------------------------------------------------------
-- Sets the random state of the NPC from the "at_random" table.
function Actor:RandomState()
	if not hook.Run('PreRandomState', self) then
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
function Actor:GetRandomState()
	return H.PickWeighted(self.data.at_random)
end

-- A brain with PickReaction (GOAP) chooses by the situation, otherwise a weighted random pick.
local function PickReaction(actor, reactions, enemy)
	local brain = actor.brain
	if brain and brain.PickReaction and istable(reactions) then return brain:PickReaction(reactions, enemy) end
	return H.PickWeighted(reactions)
end

-- @param enemy entity|nil who the actor reacts to (lets a planning brain judge the threat)
function Actor:GetReactionForDamage(enemy)
	return PickReaction(self, self.data.at_damage, enemy)
end

-- @param enemy entity|nil who the actor reacts to
function Actor:GetReactionForProtect(enemy)
	return PickReaction(self, self.data.at_protect, enemy)
end

-- Sets the reaction to the event.
-- ? Used in system computing, and does nothing by itself.
function Actor:SetReaction(reaction)
	Assert.Arg(1, reaction, 'string|nil', 'ACTOR:SetReaction')
	self.reaction = reaction
end

-- Will return the last result specified in the reaction variable.
function Actor:GetLastReaction()
	return self.reaction
end

-- ---------------------------------------------------------------------------
-- States
-- ---------------------------------------------------------------------------
function Actor:StateLock(lock)
	Assert.Arg(1, lock, 'boolean|nil', 'ACTOR:StateLock')
	self.state_lock = lock or false
end

function Actor:IsStateLock()
	return self.state_lock
end

function Actor:CallStateAction(state_name, func_name, ...)
	Assert.Arg(1, state_name, 'string|nil', 'ACTOR:CallStateAction')
	Assert.NonEmptyString(2, func_name, 'ACTOR:CallStateAction')
	return bgNPC.States.Call(state_name or self.state_data.state, func_name, self, ...)
end

-- Switches the actor to a new state.
-- @param state string|nil state name, nil means 'none'
-- @param data table|nil state data
-- @param forced boolean|nil skip locks, delays and validators
-- @return table|nil new state data, or nil if the change was rejected
function Actor:SetState(state, data, forced)
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

	local hook_result = hook.Run('BGN_PreSetState', self, state, data)
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
	hook.Run('BGN_SetState', self, state, data)

	return self.state_data
end

-- Client side: stores the state received from the server without running state callbacks.
function Actor:SyncState(state)
	state = state or 'none'
	if self.state_data.state == state then return end
	self.old_state = self.state_data
	self.state_data = { state = state, data = {} }
	hook.Run('BGN_SetState', self, state, self.state_data.data)
end

function Actor:UpdateStateData(data)
	Assert.Arg(1, data, 'table', 'ACTOR:UpdateStateData')
	self.state_data.data = data
end

-- @param state string|table state name or list of names
function Actor:HasState(state)
	local current_state = self.state_data.state

	if isstring(state) then return current_state == state end

	if istable(state) then
		for i = 1, #state do
			if current_state == state[i] then return true end
		end
	end

	return false
end

function Actor:GetOldState()
	return self.old_state.state
end

function Actor:GetOldStateData()
	return self.old_state.data
end

function Actor:GetState()
	return self.state_data.state
end

function Actor:GetStateData()
	return self.state_data.data
end

function Actor:EqualStateGroup(group_name)
	return self:HasStateGroup(self:GetState(), group_name)
end

function Actor:GetStateGroupName()
	return bgNPC.States.GetGroup(self:GetState())
end

-- @param state_name string
-- @param group_name string|table group name or list of names
function Actor:HasStateGroup(state_name, group_name)
	local state_group = bgNPC.States.GetGroup(state_name)

	if isstring(group_name) then return state_group == group_name end

	if istable(group_name) then
		for i = 1, #group_name do
			if state_group == group_name[i] then return true end
		end
	end

	return false
end

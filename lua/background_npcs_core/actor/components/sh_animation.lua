local Actor = bgNPC.Actor
local Assert = bgNPC.Assert
--

-- ---------------------------------------------------------------------------
-- Static animations
-- ---------------------------------------------------------------------------
function Actor:IsValidSequence(sequence_name)
	return not self:InVehicle() and isstring(sequence_name) and IsValid(self.npc) and self.npc:LookupSequence(sequence_name) ~= -1
end

-- Plays a sequence, holding the NPC in a scripted state while it plays.
-- @param sequence_name string
-- @param loop boolean|nil
-- @param loop_time number|nil loop duration, 0 or nil - endless
-- @param action function|nil called with the actor; when it returns true on stop, the stop is rejected
-- @return boolean true if the animation is playing
function Actor:PlayStaticSequence(sequence_name, loop, loop_time, action)
	Assert.Arg(1, sequence_name, 'string|nil', 'ACTOR:PlayStaticSequence')
	Assert.Arg(2, loop, 'boolean|nil', 'ACTOR:PlayStaticSequence')
	Assert.Arg(3, loop_time, 'number|nil', 'ACTOR:PlayStaticSequence')
	Assert.Arg(4, action, 'function|nil', 'ACTOR:PlayStaticSequence')

	if not self.mechanics.animator_controller
		or not self.body
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

	if hook.Run('BGN_PreNPCStartAnimation', self, sequence_name, loop, loop_time) == false then
		return false
	end

	local npc = self.npc
	local now = CurTime()
	local sequence = npc:LookupSequence(sequence_name)

	self.anim_is_loop = loop or false
	self.anim_name = string.lower(sequence_name)

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
	self.anim_cycle = 0

	self.body:PlaySequence(sequence)

	hook.Run('BGN_StartedNPCAnimation', self, sequence_name, loop, loop_time)

	return true
end

function Actor:SetNextSequence(sequence_name, loop, loop_time, action)
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

function Actor:HasSequence(sequence_name)
	return isstring(sequence_name) and self.anim_name == string.lower(sequence_name)
end

function Actor:IsAnimationPlayed()
	if self.is_animated then return true end
	return IsValid(self.npc) and bgNPC.Animator.IsPlaying(self.npc)
end

function Actor:IsLoopSequence()
	return self.anim_is_loop
end

function Actor:IsSequenceLoopFinished()
	if not self:IsAnimationPlayed() then return true end
	if not self.anim_is_loop then return true end
	if self.loop_time == 0 then return false end

	local now = CurTime()
	self.loop_time_normal = math.max(0, self.loop_time - now)

	return self.loop_time < now
end

function Actor:IsSequenceFinished()
	if not self:IsAnimationPlayed() then return true end
	-- a loop lasts its loop time, not one sequence: movement must wait, or the NPC flickers between running and the loop
	if self.anim_is_loop then return self:IsSequenceLoopFinished() end

	local now = CurTime()
	self.anim_time_normal = math.max(0, self.anim_time - now)

	return self.anim_time <= now
end

function Actor:PlayNextStaticSequence()
	if not self.mechanics.animator_controller then return false end

	local next_anim = self.next_anim
	if not next_anim or next_anim.sequence_name == self.anim_name then return false end

	self.next_anim = nil
	self:PlayStaticSequence(next_anim.sequence_name, next_anim.loop, next_anim.loop_time)

	if next_anim.action then next_anim.action(self) end

	return true
end

-- Stops the current static animation and returns the NPC to AI control.
function Actor:ResetSequence()
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

	if self.body then self.body:StopSequence() end
end

Actor.StopStaticSequence = Actor.ResetSequence

--[[
	FSMBrain: runs the "update" callback of the actor's current state (see bgNPC.States)
	and picks a random state from the actor config when the actor has none.
--]]

local States = bgNPC.States

local FSMBrain = bgNPC.Class('BGN_FSMBrain', bgNPC.Brain)
bgNPC.FSMBrain = FSMBrain

function FSMBrain:Update()
	local actor = self.actor
	local state = actor:GetState()

	if state == 'none' then
		if actor.data.at_random and not actor:InVehicle() then actor:RandomState() end
		return
	end

	States.Call(state, 'update', actor, state, actor:GetStateData())
end

bgNPC.Brain.Register('fsm', FSMBrain)

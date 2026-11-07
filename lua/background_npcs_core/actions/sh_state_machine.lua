local bgNPC = bgNPC
local Actors = bgNPC.Actors
local States = bgNPC.States
local EFL_NO_THINK_FUNCTION = EFL_NO_THINK_FUNCTION
--

-- Calls the "update" callback of every actor's current state, one actor per tick.
bgNPC.Tasks.Add('BGN_StateMachine', function(yield)
	while true do
		local actors = Actors.GetAll()

		for i = 1, #actors do
			local actor = actors[i]

			if actor and actor:IsAlive() and not actor:GetNPC():IsEFlagSet(EFL_NO_THINK_FUNCTION) then
				local state_name = actor:GetState()
				States.Call(state_name, 'update', actor, state_name, actor:GetStateData())
			end

			yield()
		end

		yield()
	end
end)

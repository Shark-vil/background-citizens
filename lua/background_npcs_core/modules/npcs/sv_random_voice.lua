local delay_actors = {}

local replics = {
	'ambient/voices/cough1.wav',
	'ambient/voices/cough2.wav',
	'ambient/voices/cough3.wav',
	'ambient/voices/cough4.wav'
}

timer.Create('BGN_ActorsResidentsRandomVoice', 10, 0, function()
	if #replics == 0 then return end

	for i = #delay_actors, 1, -1 do
		local value = delay_actors[i]
		local actor = value.actor
		local delay = value.delay

		if actor == nil or not actor:IsAlive() or delay < CurTime() then
			table.remove(delay_actors, i)
		end
	end

	for _, actor in ipairs(bgNPC:GetAllByTeam('residents')) do
		if not actor:IsAlive() or not actor:HasState('walk') and not actor:HasState('walk') then
			continue
		end

		local is_skip = false

		for _, value in ipairs(delay_actors) do
			if value.actor == actor then
				is_skip = true
				break
			end
		end

		if is_skip then
			continue
		end

		local rnd = math.random(0, 100)

		if rnd < 20 then
			local sound = table.RandomBySeq(replics)
			actor:GetNPC():EmitSound(sound, math.random(50, 70), 100, 1, CHAN_AUTO)

			table.insert(delay_actors, {
				actor = actor,
				delay = CurTime() + math.random(10, 60)
			})
		end
	end
end)
hook.Add("BGN_PreSetNPCState", "BGN_OverrideDyspneaDangerStateToCallingPolice", function(actor, state)
	if state == 'dyspnea_danger' and math.random(0, 100) < 10 then return 'calling_police' end
end)

bgNPC:SetStateAction('dyspnea_danger', {
	update = function(actor)
		local npc = actor:GetNPC()
		local data = actor:GetStateData()
		local enemy = actor:GetNearEnemy()
		data.isAnimationPlayed = data.isAnimationPlayed or false

		if not data.isAnimationPlayed then
			actor:PlayStaticSequence('d2_coast03_PostBattle_Idle02_Entry', false, nil, function()
				actor:PlayStaticSequence('d2_coast03_PostBattle_Idle02', true, math.random(5, 15), function()
					actor:SetState('run_from_danger')
				end)
			end)

			data.isAnimationPlayed = true
		end

		if not IsValid(enemy) or enemy:Health() <= 0 then return end
		local dist = npc:GetPos():DistToSqr(enemy:GetPos())

		if dist < 1000000 then
			if dist < 40000 then
				actor:SetState('fear')
			elseif math.random(0, 100) < 30 then
				actor:SetState('run_from_danger', {
					dyspnea_delay = CurTime() + math.random(10, 20)
				})
			end
		end
	end,
	stop = function(actor)
		actor:ResetSequence()
	end
})
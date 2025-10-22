local _math_random = math.random

hook.Add('BGN_PreSetNPCState', 'BGN_OverrideDyspneaDangerStateToCallingPolice', function(actor, state)
	if state == 'dyspnea_danger' and _math_random(0, 100) < 10 then
		return 'calling_police'
	end
end)

bgNPC:SetStateAction('dyspnea_danger', 'danger', {
	update = function(actor)
		if actor:HasNoEnemies() then
			actor:RandomState()
			return
		end

		local npc = actor:GetNPC()
		local data = actor:GetStateData()
		local enemy = actor:GetNearEnemy()
		data.isAnimationPlayed = data.isAnimationPlayed or false

		if not data.isAnimationPlayed then
			actor:PlayStaticSequence('d2_coast03_PostBattle_Idle02_Entry', false, nil, function()
				actor:PlayStaticSequence('d2_coast03_PostBattle_Idle02', true, math.random(5, 15), function()
					actor:SetState('run_from_danger', {
						dyspnea_delay = CurTime() + math.random(10, 20)
					})
				end)
			end)

			data.isAnimationPlayed = true
		end

		if not IsValid(enemy) or enemy:Health() <= 0 then
			actor:RandomState()
			return
		end

		local dist = npc:GetPos():DistToSqr(enemy:GetPos())
		if dist >= 1000000 then return end
		if dist < 40000 then
			actor:SetState('fear')
		elseif _math_random(0, 100) < 40 then
			actor:SetState('run_from_danger', {
				dyspnea_delay = CurTime() + math.random(10, 20)
			})
		end
	end
})
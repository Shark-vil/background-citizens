hook.Add('PlayerDeath', 'BGN_ClearingTargetsForNPCsInThePlayerDeath', function(victim, inflictor, attacker)
	bgNPC.killing_statistic[victim] = {}
	bgNPC.arrest_players[victim] = nil

	for _, actor in ipairs(bgNPC:GetAll()) do
		actor:RemoveTarget(victim)
	end
end)

timer.Create('BGN_Timer_ResetFearAndDefenseStateIfNoEnemies', 0.5, 0, function()
	for _, actor in ipairs(bgNPC:GetAll()) do
		local npc = actor:GetNPC()

		if not IsValid(npc) then continue end

		local state = actor:GetState()

		if state ~= 'idle' and state ~= 'walk' then
			actor:RecalculationTargets()

			if actor:TargetsCount() == 0 then
				local wep = npc:GetActiveWeapon()
				if IsValid(wep) then
					wep:Remove()
				end

				if math.random(0, 10) > 5 then
					actor:Walk()
				else
					actor:Idle()
				end

				goto skip
			end
		end

		::skip::
	end
end)
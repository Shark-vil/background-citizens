local asset = bgNPC:GetModule('wanted')
local TeamParentModule = bgNPC:GetModule('team_parent')

hook.Add("BGN_PreReactionTakeDamage", "BGN_WantedModule_UpdateWantedTimeForAttacker", function(attacker)
	if asset:HasWanted(attacker) then
		local c_Wanted = asset:GetWanted(attacker)
		c_Wanted:UpdateWanted()
	end
end)

hook.Add("BGN_OnKilledActor", "BGN_WantedModule_UpdateWantedOnKilledActor", function(actor, attacker)	
	if asset:HasWanted(attacker) then
		local c_Wanted = asset:GetWanted(attacker)
		c_Wanted:UpdateWanted()

		local kills = bgNPC:GetWantedKillingStatisticSumm(attacker)
		if c_Wanted.next_kill_update <= kills then
			c_Wanted:LevelUp()
		end
	elseif not TeamParentModule:HasParent(attacker, actor) and actor:HasTeam('police') then
		asset:AddWanted(attacker)
	end
end)

hook.Add("BGN_AddWantedTarget", "BGN_AddWantedTargetFromResidents", function(target)
	for _, actor in ipairs(bgNPC:GetAll()) do
		if IsValid(actor:GetNPC()) and actor:HasTeam('residents') then
			actor:AddTarget(target)

			if actor:HasState('idle') or actor:HasState('walk') then
				actor:SetState(actor:GetReactionForProtect())
			end
		end
	end
end)

hook.Add("BGN_RemoveWantedTarget", "BGN_RemoveWantedTargetFromResidents", function(target)
	for _, actor in ipairs(bgNPC:GetAll()) do
		if IsValid(actor:GetNPC()) and actor:HasTeam('residents') then
			actor:RemoveTarget(target)
		end
	end

	bgNPC:ResetKillingStatistic(target)
	bgNPC:ResetWantedKillingStatistic(target)
end)

hook.Add("BGN_InitActor", "BGN_AddWantedTargetsForNewNPCs", function(actor)
	local wanted_list = asset:GetAllWanted()

	if table.Count(wanted_list) == 0 then return end

	if actor:HasTeam('residents') then
		for enemy, c_Wanted in pairs(wanted_list) do
			actor:AddTarget(enemy)
			if actor:HasTeam('police') then
				actor:Defense()
			elseif actor:HasTeam('residents') then
				actor:SetState(actor:GetReactionForProtect())
			end
		end
	end
end)

hook.Add("PlayerDeath", "BGN_ResetWantedModeForDeceasedPlayer", function(victim, inflictor, attacker)
	if asset:HasWanted(victim) then
		asset:RemoveWanted(victim)
	end
end)

timer.Create('BGN_Timer_CheckingTheWantesStatusOfTargets', 1, 0, function()
	local wanted_list = asset:GetAllWanted()

	if table.Count(wanted_list) == 0 then return end

	local polices = bgNPC:GetAllByType('police')
	local citizens = bgNPC:GetAllByType('citizen')

	local witnesses = {}
	table.Inherit(witnesses, polices)
	table.Inherit(witnesses, citizens)

	for enemy, c_Wanted in pairs(wanted_list) do
		if IsValid(enemy) and enemy:IsPlayer() then
			local wait_time = c_Wanted.time_reset - CurTime()
			if wait_time < 0 then wait_time = 0 end
			c_Wanted:UpdateWaitTime(math.Round(wait_time))
			
			for _, actor in ipairs(witnesses) do
				local npc = actor:GetNPC()
				if IsValid(npc) and table.HasValue(actor.targets, enemy) then
					local dist = npc:GetPos():DistToSqr(enemy:GetPos())

					if dist <= 360000 then -- 600 ^ 2
						c_Wanted:UpdateWanted()
						
						actor:AddTarget(enemy)
						if actor:HasState('idle') or actor:HasState('walk') then
							actor:SetState(actor:GetReactionForProtect())
						end
						goto skip
					end

					if dist <= 2250000 then -- 1500 ^ 2
						if bgNPC:IsTargetRay(npc, enemy) then
							c_Wanted:UpdateWanted()
							
							actor:AddTarget(enemy)
							if actor:HasState('idle') or actor:HasState('walk') then
								actor:SetState(actor:GetReactionForProtect())
							end
							goto skip
						end
					end
				end
			end
			
			if c_Wanted.time_reset < CurTime() then
				asset:RemoveWanted(enemy)
			end
		end

		::skip::
	end

	asset:ClearDeath()
end)
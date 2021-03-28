local asset = bgNPC:GetModule('wanted')
local TeamParentModule = bgNPC:GetModule('team_parent')

hook.Add("BGN_PreReactionTakeDamage", "BGN_WantedModule_UpdateWantedTimeForAttacker", function(attacker, target)
	if asset:HasWanted(attacker) then
		asset:GetWanted(attacker):UpdateWanted()
	elseif asset:HasWanted(target) then
		asset:GetWanted(target):UpdateWanted()
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
			actor:AddEnemy(target)

			if actor:HasState('idle') or actor:HasState('walk') then
				actor:SetState(actor:GetReactionForProtect())
			end
		end
	end
end)

hook.Add("BGN_RemoveWantedTarget", "BGN_RemoveWantedTargetFromResidents", function(target)
	for _, actor in ipairs(bgNPC:GetAll()) do
		if IsValid(actor:GetNPC()) and actor:HasTeam('residents') then
			actor:RemoveEnemy(target)
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
			actor:AddEnemy(enemy)
			if actor:HasTeam('police') then
				actor:SetState('defense')
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

	local polices = bgNPC:GetAllByTeam('police')
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
				if actor:IsAlive() and not actor:HasEnemy(enemy) then
					local npc = actor:GetNPC()
					local dist = npc:GetPos():DistToSqr(enemy:GetPos())

					if dist <= 360000 then -- 600 ^ 2
						c_Wanted:UpdateWanted()
						
						actor:SetState(actor:GetReactionForProtect())
						actor:AddEnemy(enemy)
					elseif dist <= 2250000 and bgNPC:IsTargetRay(npc, enemy) then -- 1500 ^ 2
						c_Wanted:UpdateWanted()
						
						actor:SetState(actor:GetReactionForProtect())
						actor:AddEnemy(enemy)
					end
				end
			end
			
			if c_Wanted.time_reset < CurTime() then
				asset:RemoveWanted(enemy)
			end
		end
	end

	asset:ClearDeath()
end)
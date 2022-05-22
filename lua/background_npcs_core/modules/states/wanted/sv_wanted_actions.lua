local asset = bgNPC:GetModule('wanted')
local TeamParentModule = bgNPC:GetModule('team_parent')
local cvar_bgn_enable_wanted_mode = GetConVar('bgn_enable_wanted_mode')

hook.Add('BGN_PreReactionTakeDamage', 'BGN_WantedModule_UpdateWantedTimeForAttacker',
function(attacker, target)
	if asset:HasWanted(attacker) then
		asset:GetWanted(attacker):UpdateWanted()
	elseif asset:HasWanted(target) then
		asset:GetWanted(target):UpdateWanted()
	end
end)

hook.Add('BGN_OnKilledActor', 'BGN_WantedModule_UpdateWantedOnKilledActor', function(actor, attacker)
	if bgNPC:IsPeacefulMode() or not cvar_bgn_enable_wanted_mode:GetBool() then return end

	local AttackerActor = bgNPC:GetActor(attacker)
	if AttackerActor and AttackerActor:HasTeam('residents') then return end

	if asset:HasWanted(attacker) then
		local WantedClass = asset:GetWanted(attacker)
		WantedClass:UpdateWanted()

		local kills = bgNPC:GetWantedKillingStatisticSumm(attacker)
		if WantedClass.next_kill_update <= kills then
			WantedClass:LevelUp()
		end
	else
		local can_see, see_actor = bgNPC:CanActorsSeeEntity(attacker)
		if not can_see or see_actor == actor then return end

		if attacker:IsPlayer() then
			if not TeamParentModule:HasParent(attacker, actor) and actor:HasTeam('police') then
				asset:AddWanted(attacker)
			end
		else
			if actor:HasTeam('police') then
				asset:AddWanted(attacker)
			end
		end
	end
end)

hook.Add('BGN_AddWantedTarget', 'BGN_AddWantedTargetFromResidents', function(target)
	for _, actor in ipairs(bgNPC:GetAll()) do
		if IsValid(actor:GetNPC()) and actor:HasTeam('residents') then
			actor:AddEnemy(target)

			if actor:HasState('idle') or actor:HasState('walk') then
				actor:SetState(actor:GetReactionForProtect())
			end
		end
	end
end)

hook.Add('BGN_RemoveWantedTarget', 'BGN_RemoveWantedTargetFromResidents', function(target)
	for _, actor in ipairs(bgNPC:GetAll()) do
		if IsValid(actor:GetNPC()) and actor:HasTeam('residents') then
			actor:RemoveEnemy(target)
		end
	end

	bgNPC:ResetKillingStatistic(target)
	bgNPC:ResetWantedKillingStatistic(target)
end)

hook.Add('BGN_InitActor', 'BGN_AddWantedTargetsForNewNPCs', function(actor)
	local wanted_list = asset:GetAllWanted()
	local wanted_count = #wanted_list

	if wanted_count == 0 then return end

	if actor:HasTeam('residents') then
		for i = 1, wanted_count do
			local enemy = wanted_list[i].target
			actor:AddEnemy(enemy)

			if actor:HasTeam('police') then
				actor:SetState('defense')
			elseif actor:HasTeam('residents') then
				actor:SetState(actor:GetReactionForProtect())
			end
		end
	end
end)

hook.Add('PlayerDeath', 'BGN_ResetWantedModeForDeceasedPlayer', function(victim, inflictor, attacker)
	if not asset:HasWanted(victim) then return end
	asset:RemoveWanted(victim)
end)

local function UpdateWantedAndSetReaction(actor, enemy)
	if not actor:EqualStateGroup('danger') then
		local reaction = actor:GetReactionForProtect()
		if reaction == 'arrest' and not GetConVar('bgn_arrest_mode'):GetBool() then
			reaction = 'defense'
		end
		actor:SetState(reaction)
	end

	actor:AddEnemy(enemy)
end

timer.Create('BGN_Timer_CheckingTheWantesStatusOfTargets', 1, 0, function()
	local wanted_list = asset:GetAllWanted()
	local wanted_count = #wanted_list

	if wanted_count == 0 then return end

	local residents = bgNPC:GetAllByTeam('residents')

	for i = wanted_count, 1, -1 do
		local WantedClass = wanted_list[i]
		local enemy = WantedClass.target
		local is_update = false

		if IsValid(enemy) then
			local wait_time = WantedClass.time_reset - CurTime()
			if wait_time < 0 then wait_time = 0 end
			WantedClass:UpdateWaitTime(math.Round(wait_time))

			for _, actor in ipairs(residents) do
				if actor:IsAlive() then
					local npc = actor:GetNPC()
					local dist = npc:GetPos():DistToSqr(enemy:GetPos())

					if dist <= 360000 then -- 600 ^ 2
						UpdateWantedAndSetReaction(actor, enemy); is_update = true
					elseif dist <= 2250000 and bgNPC:IsTargetRay(npc, enemy) then -- 1500 ^ 2
						UpdateWantedAndSetReaction(actor, enemy); is_update = true
					end
				end
			end

			if is_update then WantedClass:UpdateWanted() end

			if WantedClass.time_reset < CurTime() then
				asset:RemoveWanted(enemy); is_update = false
			end
		end
	end

	asset:ClearDeath()
end)
local CurTime = CurTime
local player_GetHumans = player.GetHumans
local ipairs = ipairs
local IsValid = IsValid
--
local asset = bgNPC:GetModule('wanted')
local TeamParentModule = bgNPC:GetModule('team_parent')
local enable_wanted_mode = GetConVar('bgn_enable_wanted_mode'):GetBool()
local enable_wanted_police_instantly = GetConVar('bgn_wanted_police_instantly'):GetBool()
local enable_arrest_mode = GetConVar('bgn_arrest_mode'):GetBool()
local impunity_limit = GetConVar('bgn_wanted_impunity_limit'):GetInt()
local impunity_limit_reduction_period = GetConVar('bgn_wanted_impunity_reduction_period'):GetFloat()
local impunity_last_reduction_period = 0

-- Just registered for the RPC
-- cl_visual_wanted.lua
slib.GlobalCvarRegisterChangeCallback('bgn_disable_halo_wanted', 'bgn_cl_wanted_module_bgn_disable_halo_wanted')
slib.GlobalCvarRegisterChangeCallback('bgn_disable_halo_calling', 'bgn_cl_wanted_module_bgn_disable_halo_calling')

cvars.AddChangeCallback('bgn_enable_wanted_mode', function(_, _, newValue)
	enable_wanted_mode = tonumber(newValue) == 1

	bgNPC:Log('New value for "enable_wanted_mode" - ' .. tostring(enable_wanted_mode), 'Wanted Module')

	local wanted_list = asset:GetAllWanted()
	local wanted_count = #wanted_list
	if wanted_count == 0 then return end

	for i = 1, wanted_count do
		local WantedClass = wanted_list[i]
		if WantedClass and WantedClass.target then
			asset:RemoveWanted(WantedClass.target)
			bgNPC:Log('Reset wanted for - ' .. tostring(WantedClass.target), 'Wanted Module')
		end
	end
end, 'bgn_wanted_module_cvar_bgn_enable_wanted_mode')

cvars.AddChangeCallback('bgn_wanted_police_instantly', function(_, _, newValue)
	enable_wanted_police_instantly = tonumber(newValue) == 1

	bgNPC:Log('New value for "enable_wanted_police_instantly" - ' .. tostring(enable_wanted_police_instantly), 'Wanted Module')
end, 'bgn_wanted_module_cvar_bgn_wanted_police_instantly')

cvars.AddChangeCallback('bgn_arrest_mode', function(_, _, newValue)
	enable_arrest_mode = tonumber(newValue) == 1

	bgNPC:Log('New value for "enable_arrest_mode" - ' .. tostring(enable_arrest_mode), 'Wanted Module')
end, 'bgn_wanted_module_cvar_bgn_arrest_mode')

cvars.AddChangeCallback('bgn_wanted_impunity_limit', function(_, _, newValue)
	impunity_limit = tonumber(newValue)

	bgNPC:Log('New value for "impunity_limit" - ' .. tostring(impunity_limit), 'Wanted Module')
end, 'bgn_wanted_module_cvar_bgn_wanted_impunity_limit')

cvars.AddChangeCallback('bgn_wanted_impunity_reduction_period', function(_, _, newValue)
	impunity_limit_reduction_period = tonumber(newValue)
	impunity_last_reduction_period = 0

	bgNPC:Log('New value for "impunity_limit_reduction_period" - ' .. tostring(impunity_limit_reduction_period), 'Wanted Module')
	bgNPC:Log('New value for "impunity_last_reduction_period" - ' .. tostring(impunity_last_reduction_period), 'Wanted Module')
end, 'bgn_wanted_module_cvar_bgn_wanted_impunity_reduction_period')

hook.Add('BGN_PreReactionTakeDamage', 'BGN_WantedModule_UpdateWantedTimeForAttacker', function(attacker, target)
	if asset:HasWanted(attacker) then
		asset:GetWanted(attacker):UpdateWanted()
	elseif asset:HasWanted(target) then
		asset:GetWanted(target):UpdateWanted()
	end
end)

hook.Add('BGN_OnKilledActor', 'BGN_WantedModule_UpdateWantedOnKilledActor', function(actor, attacker)
	if bgNPC:IsPeacefulMode() or not enable_wanted_mode then return end

	local AttackerActor = bgNPC:GetActor(attacker)
	if AttackerActor and AttackerActor:HasTeam('residents') then return end

	if asset:HasWanted(attacker) then
		if attacker:slibGetLocalVar('bgn_wanted_module_impunity', 0) > 0 then
			attacker:slibSetLocalVar('bgn_wanted_module_impunity', 0)
		end

		local WantedClass = asset:GetWanted(attacker)
		WantedClass:UpdateWanted()

		local kills = bgNPC:GetWantedKillingStatisticSumm(attacker)
		if WantedClass.next_kill_update <= kills then
			WantedClass:LevelUp()
		end
	else
		local can_see, see_actor = bgNPC:CanAnyActorSeeEntity(attacker)
		if not can_see or see_actor == actor then return end

		local is_player = attacker:IsPlayer()
		if impunity_limit ~= 0 and is_player then
			local current_impunity = attacker:slibGetLocalVar('bgn_wanted_module_impunity', 0)
			if current_impunity >= impunity_limit then
				asset:AddWanted(attacker)
				return
			else
				attacker:slibSetLocalVar('bgn_wanted_module_impunity', current_impunity + 1)
			end
		end

		if not is_player or (enable_wanted_police_instantly and not TeamParentModule:HasParent(attacker, actor) and actor:HasTeam('police')) then
			asset:AddWanted(attacker)
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
	-- bgNPC:ResetWantedKillingStatistic(target)
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
	if not IsValid(victim) then return end

	if victim:slibGetLocalVar('bgn_wanted_module_impunity', 0) > 0 then
		victim:slibSetLocalVar('bgn_wanted_module_impunity', 0)
	end

	if not asset:HasWanted(victim) then return end
	asset:RemoveWanted(victim)
end)

local function UpdateWantedAndSetReaction(actor, enemy)
	if not actor:EqualStateGroup('danger') then
		local reaction = actor:GetReactionForProtect()
		if reaction == 'arrest' and not enable_arrest_mode then
			reaction = 'defense'
		end
		actor:SetState(reaction)
	end

	actor:AddEnemy(enemy)
end

timer.Create('BGN_Timer_ResetPlayersImpunityLimit', 1, 0, function()
	if impunity_limit_reduction_period == 0 then return end

	if impunity_last_reduction_period > CurTime() then return end
	impunity_last_reduction_period = CurTime() + impunity_limit_reduction_period

	for _, ply in ipairs(player_GetHumans()) do
		if IsValid(ply) then
			local current_impunity = ply:slibGetLocalVar('bgn_wanted_module_impunity', 0)
			if current_impunity > 0 then
				ply:slibSetLocalVar('bgn_wanted_module_impunity', current_impunity - 1)
			end
		end
	end
end)

timer.Create('BGN_Timer_CheckingTheWantesStatusOfTargets', 1, 0, function()
	if bgNPC:IsPeacefulMode() or not enable_wanted_mode then return end

	local wanted_list = asset:GetAllWanted()
	local wanted_count = #wanted_list

	if wanted_count == 0 then return end

	local residents = bgNPC:GetAllByTeam('residents')

	-- 600 ^ 2
	local min_distance_detect = 360000

	-- 1500 ^ 2
	local ray_distance_detect = 2250000

	for i = wanted_count, 1, -1 do
		local WantedClass = wanted_list[i]
		local enemy = WantedClass.target
		local is_update = false

		if IsValid(enemy) then
			local wait_time = WantedClass.time_reset - CurTime()
			if wait_time < 0 then wait_time = 0 end
			WantedClass:UpdateWaitTime(wait_time)

			for _, actor in ipairs(residents) do
				if actor:IsAlive() then
					local npc = actor:GetNPC()
					local dist = npc:GetPos():DistToSqr(enemy:GetPos())

					if dist <= min_distance_detect then
						UpdateWantedAndSetReaction(actor, enemy)
						is_update = true
					elseif dist <= ray_distance_detect and bgNPC:IsTargetRay(npc, enemy) then
						UpdateWantedAndSetReaction(actor, enemy)
						is_update = true
					end
				end
			end

			if is_update then WantedClass:UpdateWanted() end

			if WantedClass.time_reset < CurTime() then
				asset:RemoveWanted(enemy)
			end
		end
	end

	asset:ClearDeath()
end)
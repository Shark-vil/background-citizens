local table_WhereFindBySeq = bgNPC.Table.FindWhere
--
local TeamParentModule
local cvar_team_damage = GetConVar('bgn_team_damage')

hook.Add('EntityTakeDamage', 'BGN_ActorTakeDamageEvent', function(target, dmginfo)
	if not target:IsPlayer() and not target:IsNPC() and not target:IsNextBot() then return end

	local attacker = bgNPC.Combat.ResolveVehicleAttacker(dmginfo:GetAttacker())
	if not IsValid(attacker) or not attacker:IsPlayer() and not attacker:IsNPC() and not attacker:IsNextBot() then return end
	if attacker.BGN_HasBuildMode or attacker.bgNPCIgnore or attacker == target then return end

	local result

	if target:IsNPC() or target:IsNextBot() then
		result = hook.Run('BGN_TakeDamageFromNPC', attacker, target, dmginfo)
	elseif target:IsPlayer() then
		result = hook.Run('BGN_TakeDamageFromPlayer', attacker, target, dmginfo)
	end

	if isbool(result) then return result end
end)

local function CheckDamageIgnore(attacker, target)
	target.LastDamageHistory = target.LastDamageHistory or {}
	local _, value = table_WhereFindBySeq(target.LastDamageHistory, function(_, v) return v.enemy == attacker end)
	if value then
		if value.time + 1 > CurTime() then
			value.count = value.count + 1
			value.time = CurTime()
		else
			value.count = 0
		end
	else
		table.insert(target.LastDamageHistory, {
			enemy = attacker,
			count = 1,
			time = CurTime()
		})
	end
end

local function GetLastDamageCount(attacker, target)
	target.LastDamageHistory = target.LastDamageHistory or {}
	local _, value = table_WhereFindBySeq(target.LastDamageHistory, function(_, v)
		return v.enemy == attacker
	end)
	if value then return value.count end
	return 0
end

hook.Add('BGN_TakeDamageFromNPC', 'BGN_NPCDamageReaction', function(attacker, target, dmginfo)
	local ActorTarget = bgNPC.Actors.Get(target)
	local ActorAttacker = bgNPC.Actors.Get(attacker)
	TeamParentModule = TeamParentModule or bgNPC.Modules.Get('team_parent')

	-- a fist fight with this player (sv_conversation.lua): the hit lands, nobody calls the police for it
	if ActorTarget and ActorTarget:HasState('brawl') and ActorTarget:GetStateData().enemy == attacker then return end

	if ActorTarget ~= nil then
		if attacker:IsPlayer() then
			if TeamParentModule:HasParent(attacker, ActorTarget) or ActorTarget:HasTeam('player') then
				if bgNPC.cfg.EnablePlayerKilledTeamActors then
					return
				end
				return true
			elseif ActorTarget ~= nil then
				local hp = target:Health() - dmginfo:GetDamage()
				local max_hp = target:GetMaxHealth()
				-- An HL2 NPC still reacts to these hits with its engine AI; a NextBot has none and would keep walking.
				if hp > 0 and max_hp > 0 and hp > math.Round(max_hp / 2) and not ActorTarget:HasEnemy(attacker)
					and not target:IsNextBot()
				then
					return
				end
			end
		elseif ActorAttacker ~= nil then
			if ActorTarget:HasTeam(ActorAttacker) then
				ActorTarget:RemoveEnemy(attacker)
				ActorAttacker:RemoveEnemy(target)
				-- a teammate's stray bullet: a calm civilian runs from whoever the shooter fights
				local danger = ActorAttacker:GetNearEnemy()
				if ActorTarget:IsCivilian() and ActorTarget:EqualStateGroup('calm') and IsValid(danger) and danger ~= target then
					ActorTarget:AddEnemy(danger, 'fear')
					ActorTarget:SetState('fear')
					ActorTarget:StayOutOfFight()
				end
				-- nil lets the damage through without a reaction
				if not cvar_team_damage:GetBool() then return true end
				return
			end
		end

		-- Stray hit: the shooter fights someone else. A civilian runs instead of answering.
		local stray = ActorAttacker ~= nil and ActorAttacker:EnemiesCount() > 0 and not ActorAttacker:HasEnemy(target)
		local reaction
		if stray and ActorTarget:IsCivilian() then
			reaction = 'fear'
			ActorTarget:StayOutOfFight()
		else
			reaction = ActorTarget:GetReactionForDamage(attacker)
		end
		ActorTarget:SetReaction(reaction)

		local hook_result = hook.Run('BGN_PreReactionTakeDamage', attacker, target, reaction, dmginfo)
		if isbool(hook_result) then return hook_result end

		reaction = ActorTarget:GetLastReaction()

		if ActorTarget:EqualStateGroup('calm') then
			if reaction == 'ignore' or reaction == 'none' then return true end
			-- if reaction == 'ignore' then return true end
			ActorTarget:RemoveAllTargets()
			ActorTarget:SetState(reaction)
		end

		CheckDamageIgnore(attacker, target)

		if ActorTarget:EnemiesCount() == 0 or GetLastDamageCount(attacker, target) >= 3 then
			ActorTarget:AddEnemy(attacker, reaction)
		end
	end

	return hook.Run('BGN_PostReactionTakeDamage', attacker, target, reaction, dmginfo)
end)

hook.Add('BGN_TakeDamageFromPlayer', 'BGN_PlayerDamageReaction', function(attacker, target, dmginfo)
	local ActorAttacker = bgNPC.Actors.Get(attacker)
	TeamParentModule = TeamParentModule or bgNPC.Modules.Get('team_parent')

	if ActorAttacker ~= nil then
		if TeamParentModule:HasParent(target, ActorAttacker) or ActorAttacker:HasTeam('player') then
			return true
		end

		if not ActorAttacker:HasEnemy(target) then
			return true
		end
	end

	local hook_result = hook.Run('BGN_PreReactionTakeDamage', attacker, target, nil, dmginfo)
	if isbool(hook_result) then return hook_result end

	return hook.Run('BGN_PostReactionTakeDamage', attacker, target, nil, dmginfo)
end)
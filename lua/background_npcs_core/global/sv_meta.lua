do
	local bit_band = bit.band
	local util_PointContents = util.PointContents
	local CONTENTS_WATER = CONTENTS_WATER

	function bgNPC:VectorInWater(position)
		return bit_band(util_PointContents(position), CONTENTS_WATER) == CONTENTS_WATER
	end
end

function bgNPC:SetActorWeapon(actor, weapon_class, switching)
	local npc = actor:GetNPC()
	local data = actor:GetData()
	local can_give = false

	local cvar_disable_weapon = GetConVar('bgn_disable_weapon_' .. actor.type)
	if cvar_disable_weapon and cvar_disable_weapon:GetBool() then return end

	if weapon_class then
		local active_weapon = npc:GetActiveWeapon()

		switching = switching or false

		if IsValid(active_weapon) then
			local is_equal_class = active_weapon:GetClass() == weapon_class
			if (switching and is_equal_class) or (not switching and not is_equal_class) then
				return
			end
		end

		local weapon = npc:GetWeapon(weapon_class)
		if not IsValid(weapon) and not hook.Run('BGN_PreGiveWeapon', actor, npc, weapon_class) then
			weapon = npc:Give(weapon_class)
			hook.Run('BGN_PostGiveWeapon', actor, npc, weapon_class)
			can_give = true
		end

		if can_give and IsValid(weapon) and not hook.Run('BGN_PreSelectWeapon', actor, npc, weapon_class) then
			npc:SelectWeapon(weapon_class)
			hook.Run('BGN_PostSelectWeapon', actor, npc, weapon_class)
		end
	else
		local actor_weapon_class = actor.weapon
		if actor_weapon_class and #actor_weapon_class ~= 0 then
			local active_weapon = npc:GetActiveWeapon()
			if not IsValid(active_weapon) then
				local vj_base_npcs_list = list.Get('VJBASE_SPAWNABLE_NPC')
				if vj_base_npcs_list then
					local npc_class = npc:GetClass()
					local vj_base_npc_data = vj_base_npcs_list[npc_class]
					if vj_base_npc_data and vj_base_npc_data.Weapons then
						actor_weapon_class = table.RandomBySeq(vj_base_npc_data.Weapons)
					end
				end

				local weapon = npc:GetWeapon(actor_weapon_class)
				if not IsValid(weapon) and not hook.Run('BGN_PreGiveWeapon', actor, npc, actor_weapon_class) then
					weapon = npc:Give(actor_weapon_class)
					hook.Run('BGN_PostGiveWeapon', actor, npc, actor_weapon_class)
					can_give = true
				end

				if can_give and IsValid(weapon) and not hook.Run('BGN_PreSelectWeapon', actor, npc, actor_weapon_class) then
					npc:SelectWeapon(actor_weapon_class)
					hook.Run('BGN_PostSelectWeapon', actor, npc, actor_weapon_class)
				end
			end
		end
	end

	-- Backward compatibility with the old version of the config
	local weapon_skill = data.weapon_skill or data.weaponSkill
	if weapon_skill and isnumber(weapon_skill) then
		npc:SetCurrentWeaponProficiency(weapon_skill)
	end

	hook.Run('BGN_OnSetActorWeapon', actor)
end

function bgNPC:CheckVehicleAttacker(attacker)
	if IsValid(attacker) and attacker:IsVehicle() then
		attacker = attacker:GetDriver()
		if not IsValid(attacker) then return end
	end
	return attacker
end

function bgNPC:IsEnemyTeam(target_actor, attacker)
	if not IsValid(attacker) or attacker:Health() <= 0 then return false end

	local actors = self:GetAll()
	local AttackerActor = bgNPC:GetActor(attacker)
	if AttackerActor and AttackerActor:HasEnemy(target_actor) then return true end

	local FirstAttackerModule = bgNPC:GetModule('first_attacker')
	if FirstAttackerModule:IsFirstAttacker(attacker, target_actor) then return true end

	for i = #actors, 1, -1 do
		local actor = actors[i]
		if actor and actor:IsAlive() and actor ~= target_actor and actor:HasTeam(target_actor) then
			if AttackerActor and not actor:HasTeam(AttackerActor) and AttackerActor:HasEnemy(actor) then
				return true
			end

			if actor:HasEnemy(attacker) or FirstAttackerModule:IsFirstAttacker(attacker, actor:GetNPC()) then
				return true
			end
		end
	end

	return false
end

local function GetEntityType(ent)
	if not ent or not IsValid(ent) then return nil end
	if ent:IsNextBot() then return 'nextbot' end
	if ent:IsNPC() then return 'npc' end
	if ent:IsPlayer() then return 'player' end
	return nil
end

local function IsValidEntity(ent)
	return GetEntityType(ent) ~= nil
end

function bgNPC:GetEnemyFromActorByTarget(actor, target, attacker)
	if not IsValidEntity(target) then return end
	if not IsValidEntity(attacker) then return end

	local IsAttackerTeam = actor:HasTeam(attacker)
	local IsTargetTeam = actor:HasTeam(target)
	if IsAttackerTeam and IsTargetTeam then return end

	if IsAttackerTeam then return target end
	if IsTargetTeam then return attacker end

	local FirstAttackerModule = bgNPC:GetModule('first_attacker')
	local WantedModule = bgNPC:GetModule('wanted')
	local AttackerType = GetEntityType(attacker)
	local TargetType = GetEntityType(target)
	local ActorAttacker =  bgNPC:GetActor(attacker)
	local ActorTarget =  bgNPC:GetActor(target)
	local AttackerIsFirstAttacker = FirstAttackerModule:IsFirstAttacker(attacker, target)
	local TargetIsFirstAttacker = FirstAttackerModule:IsFirstAttacker(target, attacker)

	-- If a player attacks an NPC who is not an actor
	if not ActorTarget and TargetType == 'npc' and attacker:IsPlayer() then
		if target:Disposition(attacker) == D_HT then
			return target
		end
		return attacker
	end

	-- If the player is attacked by an NPC who is not an actor
	if not ActorAttacker and AttackerType ~= 'player' and target:IsPlayer() then return attacker end

	if WantedModule:HasWanted(attacker) then return attacker end
	if WantedModule:HasWanted(target) then return target end

	-- If at least one of the target's opponents in the actor's team
	if bgNPC:IsEnemyTeam(actor, target) then return target end
	-- If at least one of the actor's team is the opponent of the attacker
	if bgNPC:IsEnemyTeam(actor, attacker) then return attacker end

	-- If the attacker has an enemy target
	if ActorAttacker and not ActorAttacker:HasEnemy(target) then return target end
	-- If the target has an enemy attacker
	if ActorTarget and not ActorTarget:HasEnemy(attacker) then return attacker end

	if target:IsPlayer() or attacker:IsPlayer() then
		-- If the player is attacked by the actor who was the first victim
		if TargetIsFirstAttacker then return target end
		-- If the player is attacked by the actor who first started the fight
		if AttackerIsFirstAttacker then return attacker end
	end
end
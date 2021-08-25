function bgNPC:SetActorWeapon(actor, weapon_class, switching)
	local npc = actor:GetNPC()
	local data = actor:GetData()

	if weapon_class ~= nil then
		local active_weapon = npc:GetActiveWeapon()

		switching = switching or false

		if IsValid(active_weapon) then
			if switching then
				if active_weapon:GetClass() == weapon_class then return end
			else
				if active_weapon:GetClass() ~= weapon_class then return end
			end
		end
		
		local weapon = npc:GetWeapon(weapon_class)
		if not IsValid(weapon) then
			weapon = npc:Give(weapon_class)
		end

		npc:SelectWeapon(weapon_class)
	else
		local weapon_class = actor.weapon
		if weapon_class then
			local active_weapon = npc:GetActiveWeapon()

			if IsValid(active_weapon) and active_weapon:GetClass() == weapon_class then
				return
			end

			local weapon = npc:GetWeapon(weapon_class)
			if not IsValid(weapon) then
				weapon = npc:Give(weapon_class)
			end

			npc:SelectWeapon(weapon_class)
		end
	end

	-- Backward compatibility with the old version of the config
	data.weapon_skill = data.weapon_skill or data.weaponSkill

	if data.weapon_skill ~= nil and isnumber(data.weapon_skill) then
		npc:SetCurrentWeaponProficiency(data.weapon_skill)
	end
end

function bgNPC:IsEnemyTeam(target_actor, attacker)
	if not IsValid(attacker) or attacker:Health() <= 0 then return false end

	local actors = self:GetAll()
	local asset = bgNPC:GetModule('first_attacker')

	for i = #actors, 1, -1 do
		local actor = actors[i]
		if actor and actor:IsAlive() and actor:HasTeam(target_actor) then
			if actor:HasEnemy(attacker) or asset:IsFirstAttacker(attacker, actor:GetNPC()) then
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

	local asset = bgNPC:GetModule('first_attacker')
	local AttackerType = GetEntityType(attacker)
	local TargetType = GetEntityType(target)
	local ActorAttacker =  bgNPC:GetActor(attacker)
	local ActorTarget =  bgNPC:GetActor(target)
	local AttackerIsFirstAttacker = asset:IsFirstAttacker(attacker, target)
	local TargetIsFirstAttacker = asset:IsFirstAttacker(target, attacker)

	-- If a player attacks an NPC who is not an actor
	if not ActorTarget and TargetType == 'npc' and attacker:IsPlayer() then
		if target:Disposition(attacker) == D_HT then
			return target
		end
		return attacker
	end

	-- If the player is attacked by an NPC who is not an actor
	if not ActorAttacker and target:IsPlayer() then return attacker end

	-- If at least one of the target's opponents in the actor's team
	if bgNPC:IsEnemyTeam(actor, target) then return target end
	-- If at least one of the actor's team is the opponent of the attacker
	if bgNPC:IsEnemyTeam(actor, attacker) then return attacker end

	-- If the target has an enemy attacker
	if ActorTarget and not ActorTarget:HasEnemy(attacker) then return attacker end
	-- If the attacker has an enemy target
	if ActorAttacker and not ActorAttacker:HasEnemy(target) then return target end

	if target:IsPlayer() then 
		-- If the player is attacked by the actor who first started the fight
		if AttackerIsFirstAttacker then return attacker end
		-- If the player is attacked by the actor who was the first victim
		if TargetIsFirstAttacker then return target end
	end
	
	-- The last simple check, in case the previous ones did not work
	if attacker:IsPlayer() then
		if TargetIsFirstAttacker then return target end
		if AttackerIsFirstAttacker then return attacker end
	end
end
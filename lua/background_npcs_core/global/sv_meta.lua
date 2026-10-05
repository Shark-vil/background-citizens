local bgNPC = bgNPC
local Assert = bgNPC.Assert
local IsValid = IsValid
local istable = istable
local isnumber = isnumber
local FirstAttackerModule, WantedModule

do
	local bit_band = bit.band
	local util_PointContents = util.PointContents
	local CONTENTS_WATER = CONTENTS_WATER

	function bgNPC:VectorInWater(position)
		return bit_band(util_PointContents(position), CONTENTS_WATER) == CONTENTS_WATER
	end
end

-- VJ Base NPCs define their own weapon list, prefer it over the actor config.
local function GetVJBaseWeapon(npc)
	local vj_npcs = list.GetForEdit('VJBASE_SPAWNABLE_NPC')
	local vj_data = vj_npcs and vj_npcs[npc:GetClass()]
	if vj_data and istable(vj_data.Weapons) and #vj_data.Weapons ~= 0 then
		return table.RandomBySeq(vj_data.Weapons)
	end
end

-- Gives the weapon if the NPC doesn't have it and makes it active.
-- @return boolean true if the weapon is in the NPC's hands
local function EquipWeapon(actor, npc, weapon_class)
	local weapon = npc:GetWeapon(weapon_class)

	if not IsValid(weapon) then
		if hook.Run('BGN_PreGiveWeapon', actor, npc, weapon_class) then return false end
		weapon = npc:Give(weapon_class)
		hook.Run('BGN_PostGiveWeapon', actor, npc, weapon_class)
		if not IsValid(weapon) then return false end
	end

	local active_weapon = npc:GetActiveWeapon()
	if active_weapon == weapon then return true end

	if hook.Run('BGN_PreSelectWeapon', actor, npc, weapon_class) then return false end
	npc:SelectWeapon(weapon_class)
	hook.Run('BGN_PostSelectWeapon', actor, npc, weapon_class)

	return true
end

-- Arms the actor.
-- @param actor table
-- @param weapon_class string|nil weapon to give, nil - the actor's own weapon
-- @param switching boolean|nil with a class: true - replace another active weapon,
--   false - only give the weapon if the NPC holds nothing else
function bgNPC:SetActorWeapon(actor, weapon_class, switching)
	Assert.Arg(1, actor, 'actor', 'bgNPC:SetActorWeapon')
	Assert.Arg(2, weapon_class, 'string|nil', 'bgNPC:SetActorWeapon')
	Assert.Arg(3, switching, 'boolean|nil', 'bgNPC:SetActorWeapon')

	if not actor:IsAlive() or not actor:IsNPC() then return end

	local cvar_disable_weapon = GetConVar('bgn_disable_weapon_' .. actor:GetType())
	if cvar_disable_weapon and cvar_disable_weapon:GetBool() then return end

	local npc = actor:GetNPC()
	local active_weapon = npc:GetActiveWeapon()

	if weapon_class then
		if IsValid(active_weapon) then
			local is_same = active_weapon:GetClass() == weapon_class
			if is_same or not switching then return end
		end
	else
		weapon_class = actor:GetActorWeapon()
		if not weapon_class or #weapon_class == 0 then return end
		if IsValid(active_weapon) then return end
		weapon_class = GetVJBaseWeapon(npc) or weapon_class
	end

	if not EquipWeapon(actor, npc, weapon_class) then return end

	-- Backward compatibility with the old version of the config
	local data = actor:GetData()
	local weapon_skill = data.weapon_skill or data.weaponSkill
	if isnumber(weapon_skill) then
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

	FirstAttackerModule = FirstAttackerModule or bgNPC:GetModule('first_attacker')
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

	FirstAttackerModule = FirstAttackerModule or bgNPC:GetModule('first_attacker')
	WantedModule = WantedModule or bgNPC:GetModule('wanted')
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
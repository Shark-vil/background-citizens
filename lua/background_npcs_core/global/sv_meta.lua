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

	local AttackerActor = bgNPC:GetActor(attacker)

	for _, actor in ipairs(self:GetAll()) do
		if actor:IsAlive() and actor ~= target_actor then
			local npc = actor:GetNPC()

			if target_actor:HasTeam(actor) then
				if actor:HasEnemy(attacker) then
					return true
				elseif AttackerActor and AttackerActor:HasEnemy(npc) then
					return true
				elseif attacker:IsNPC() and attacker:Disposition(npc) == D_HT then
					return true
				end
			end
		end
	end

	return false
end
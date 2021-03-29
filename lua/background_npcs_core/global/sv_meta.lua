function bgNPC:IsFearNPC(npc)
	if IsValid(npc) and npc:IsNPC() then
		local schedule = npc:GetCurrentSchedule()
		if npc:IsCurrentSchedule(SCHED_RUN_FROM_ENEMY) 
			or npc:IsCurrentSchedule(SCHED_WAKE_ANGRY)
			or schedule == 159
		then
			return true
		end
	end
	return false
end

function bgNPC:SetActorWeapon(actor, weapon_class, switching)
	local npc = actor:GetNPC()
	local data = actor:GetData()

	if weapon_class ~= nil then
		local active_weapon = npc:GetActiveWeapon()

		switching = switching or false

		if switching then
			if IsValid(active_weapon) and active_weapon:GetClass() == weapon_class then
				return
			end
		else
			if IsValid(active_weapon) and active_weapon:GetClass() ~= weapon_class then
				return
			end
		end
		
		local weapon = npc:GetWeapon(weapon_class)
		if not IsValid(weapon) then
			weapon = npc:Give(weapon_class)
		end

		npc:SelectWeapon(weapon_class)
	else
		local weapons = data.weapons
		if weapons ~= nil and #weapons ~= 0 then
			local active_weapon = npc:GetActiveWeapon()

			if IsValid(active_weapon) and table.IHasValue(weapons, active_weapon:GetClass()) then
				return
			end

			local select_weapon = table.Random(weapons)

			local weapon = npc:GetWeapon(select_weapon)
			if not IsValid(weapon) then
				weapon = npc:Give(select_weapon)
			end

			npc:SelectWeapon(select_weapon)
		end
	end

	-- Backward compatibility with the old version of the config
	data.weapon_skill = data.weapon_skill or data.weaponSkill

	if data.weapon_skill ~= nil and isnumber(data.weapon_skill) then
		npc:SetCurrentWeaponProficiency(data.weapon_skill)
	end
end

function bgNPC:IsEnemyTeam(target, team_name)
	if not IsValid(target) then
		return false
	end

	local TargetActor = bgNPC:GetActor(target)

	for _, actor in ipairs(self:GetAll()) do
		if not actor:IsAlive() then goto skip end

		local npc = actor:GetNPC()
		if target == npc or not IsValid(npc) then goto skip end
		if not actor:HasTeam(team_name) then goto skip end

		if TargetActor and TargetActor:HasEnemy(npc) then return true end

		if target:IsNPC() then
			if target:Disposition(npc) == D_HT or npc:Disposition(target) == D_HT then
				return true
			end
		elseif target:IsNextBot() then
			if npc:Disposition(target) == D_HT then
				return true
			end
		elseif target:IsPlayer() and actor:HasEnemy(target) then
			return true
		end

		::skip::
	end
	
	return false
end

function bgNPC:IsEnemyTeams(target, team_table)
	for _, actor in ipairs(self:GetAll()) do
		local npc = actor:GetNPC()
		if IsValid(target) and IsValid(npc) then
			if isstring(team_table) then
				team_table = { team_table }
			end

			for _, team_name in ipairs(team_table) do
				if actor:HasTeam(team_name) then
					if target:IsNPC() and (target:Disposition(npc) == D_HT 
						or npc:Disposition(target) == D_HT)
					then
						return true
					elseif target:IsPlayer() and actor:HasEnemy(target) then
						return true
					end
				end
			end
		end
	end
	return false
end

function bgNPC:TemporaryVectorVisibility(ent, time)
	if IsValid(ent) then
		ent.bgNPCVisibilityDelay = CurTime() + (time or 1)
		ent.bgNPCVisibility = true
	end
end

hook.Add('SetupPlayerVisibility', 'BGN_TemporarilyShowVectorToPlayerForSyncEntities', function(ent)
	if ent.bgNPCVisibility then
		AddOriginToPVS(ent:GetPos())
		if ent.bgNPCVisibilityDelay < CurTime() then
			ent.bgNPCVisibility = false
		end
	end
end)
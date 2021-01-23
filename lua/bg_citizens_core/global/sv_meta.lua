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

function bgNPC:SetActorWeapon(actor, weapon_class)
	if weapon_class ~= nil then
		local npc = actor:GetNPC()
		local active_weapon = npc:GetActiveWeapon()

		if IsValid(active_weapon) and active_weapon:GetClass() ~= weapon_class then
			return
		end
		
		local weapon = npc:GetWeapon(weapon_class)
		if not IsValid(weapon) then
			weapon = npc:Give(weapon_class)
		end

		npc:SelectWeapon(weapon_class)
	else
		local weapons = actor:GetData().weapons
		if weapons ~= nil and #weapons ~= 0 then
			local npc = actor:GetNPC()
			local active_weapon = npc:GetActiveWeapon()

			if IsValid(active_weapon) and table.HasValue(weapons, active_weapon:GetClass()) then
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
end

function bgNPC:IsEnemyTeam(target, team_name)
	for _, actor in ipairs(self:GetAll()) do
		local npc = actor:GetNPC()
		if IsValid(target) and IsValid(npc) then
			if actor:HasTeam(team_name) then
				if target:IsNPC() and (target:Disposition(npc) == D_HT 
					or npc:Disposition(target) == D_HT)
				then
					return true
				elseif target:IsPlayer() and actor:HasTarget(target) then
					return true
				end
			end
		end
	end
	return false
end

function bgNPC:IsEnemyTeams(target, team_table)
	for _, actor in ipairs(self:GetAll()) do
		local npc = actor:GetNPC()
		if IsValid(target) and IsValid(npc) then
			for _, team_name in ipairs(team_table) do
				if actor:HasTeam(team_name) then
					if target:IsNPC() and (target:Disposition(npc) == D_HT 
						or npc:Disposition(target) == D_HT)
					then
						return true
					elseif target:IsPlayer() and actor:HasTarget(target) then
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
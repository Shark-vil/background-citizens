hook.Add("BGN_PreSetNPCState", "BGN_PlaySoundForDefenseState", function(actor, state)
	if not actor:HasTeam('police') then return end
	if state ~= 'defense' or not actor:IsAlive() then return end
	if math.random(0, 10) > 1 then return end
	
	local enemy = actor:GetEnemy()
	if not IsValid(enemy) then return end

	local npc = actor:GetNPC()
	if enemy:GetPos():DistToSqr(npc:GetPos()) > 250000 then return end
	
	npc:EmitSound('npc/metropolice/vo/defender.wav', 300, 100, 1, CHAN_AUTO)
end)

local WantedModule = bgNPC:GetModule('wanted')
local MeleeWeapon = { 'weapon_crowbar', 'weapon_stunstick' }

bgNPC:SetStateAction('defense', function(actor)
	local enemy = actor:GetNearEnemy()
	if not IsValid(enemy) then return end
	
	local npc = actor:GetNPC()
	local data = actor:GetStateData()
	
	data.delay = data.delay or 0

	if enemy:IsPlayer() and enemy:InVehicle() then
		enemy = enemy:GetVehicle()
	end

	if data.delay < CurTime() or enemy:IsNPC() or enemy:IsPlayer() then
		local killingSumm = bgNPC:GetKillingStatisticSumm(enemy)

		if not data.disableWeapon then
			data.notGun = data.notGun or true
			data.notGunDelay = data.notGunDelay or CurTime() + 15

			if data.notGun then
				if data.notGunDelay < CurTime() or killingSumm > 0 or enemy:IsNextBot()
					or (enemy:IsNPC() and IsValid(enemy:GetActiveWeapon()))
				then
					data.notGun = false
				end
			end

			if data.notGun and actor:HasTeam('police') and not WantedModule:HasWanted(enemy) then
				if enemy:GetPos():DistToSqr(npc:GetPos()) <= 160000 then
					bgNPC:SetActorWeapon(actor, 'weapon_stunstick', true)
				else
					bgNPC:SetActorWeapon(actor)
				end
			else
				bgNPC:SetActorWeapon(actor)
			end
		end

		local current_distance = npc:GetPos():DistToSqr(enemy:GetPos())

		if current_distance <= 90000 and not bgNPC:IsTargetRay(npc, enemy) then
			local isMeleeWeapon = false
			local npcWeapon = npc:GetActiveWeapon()
			if IsValid(npcWeapon) then
				isMeleeWeapon = table.HasValue(MeleeWeapon, npcWeapon:GetClass())
			end

			if isMeleeWeapon then
				actor:WalkToTarget(enemy, 'run')
			else
            if current_distance <= 22500 then
               local node = actor:GetDistantPointInRadius(1000)
               if node then
                  actor:WalkToPos(node:GetPos(), 'run')
               else
                  actor:WalkToTarget()
                  npc:SetSchedule(SCHED_MOVE_AWAY_FROM_ENEMY)
               end
            end
			end
		else
			actor:WalkToTarget(enemy, 'run')
		end

		data.delay = CurTime() + 3
	end
end)
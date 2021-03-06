hook.Add("BGN_PreSetNPCState", "BGN_PlaySoundForDefenseState", function(actor, state)
	if not actor:HasTeam('police') then return end
	if state ~= 'defense' or not actor:IsAlive() then return end
	if math.random(0, 10) > 1 then return end
	
	local target = actor:GetNearTarget()
	if not IsValid(target) then return end

	local npc = actor:GetNPC()
	if target:GetPos():DistToSqr(npc:GetPos()) > 250000 then return end
	
	npc:EmitSound('npc/metropolice/vo/defender.wav', 300, 100, 1, CHAN_AUTO)
end)

local WantedModule = bgNPC:GetModule('wanted')
local MeleeWeapon = { 'weapon_crowbar', 'weapon_stunstick' }

timer.Create('BGN_Timer_DefenseController', 0.5, 0, function()
	for _, actor in ipairs(bgNPC:GetAllByState('defense')) do
		if not actor:IsAlive() then goto skip end

		local target = actor:GetNearTarget()
		if not IsValid(target) then goto skip end
		
		local npc = actor:GetNPC()
		local data = actor:GetStateData()
		
		data.delay = data.delay or 0
		data.state_timeout = data.state_timeout or CurTime() + 20

		if bgNPC:IsTargetRay(npc, target) then
			data.state_timeout = CurTime() + 20
		end

		if data.state_timeout < CurTime() then
			actor:RemoveTarget(target)
			data.state_timeout = CurTime() + 20
		elseif npc:Disposition(target) ~= D_HT then
			npc:AddEntityRelationship(target, D_HT, 99)
		end

		if target:IsPlayer() and target:InVehicle() then
			target = target:GetVehicle()
		end

		if npc:GetTarget() ~= target then
			npc:SetTarget(target)
		end

		if data.delay < CurTime() then
			local killingSumm = bgNPC:GetKillingStatisticSumm(target)

			data.notGun = data.notGun or true
			data.notGunDelay = data.notGunDelay or CurTime() + 15

			if data.notGun then
				if data.notGunDelay < CurTime() or killingSumm > 0 
					or (target:IsNPC() and IsValid(target:GetActiveWeapon()))
				then
					data.notGun = false
				end
			end

			if data.notGun and actor:HasTeam('police') and not WantedModule:HasWanted(target) then
				if target:GetPos():DistToSqr(npc:GetPos()) <= 160000 then
					bgNPC:SetActorWeapon(actor, 'weapon_stunstick', true)
				else
					bgNPC:SetActorWeapon(actor)
				end
			else
				bgNPC:SetActorWeapon(actor)
			end

			local current_distance = npc:GetPos():DistToSqr(target:GetPos())
			if current_distance <= 500 ^ 2 then

				local notback = true
				if killingSumm > 0 or (target:IsNPC() and IsValid(target:GetActiveWeapon())) then
					notback = false
				end

				local npc_weapon = npc:GetActiveWeapon()
				if IsValid(npc_weapon) then
					local weapon_class = npc_weapon:GetClass()
					if table.HasValue(MeleeWeapon, weapon_class) then notback = true end
				end

				if notback then
					actor:WalkToPos(target:GetPos(), 'run')
				else
					actor:WalkToPos(nil)
					npc:SetSchedule(SCHED_MOVE_AWAY_FROM_ENEMY)
				end
			else
				actor:WalkToPos(target:GetPos(), 'run')
			end

			data.delay = CurTime() + 3
		end
		
		::skip::
	end
end)

hook.Add('BGN_PostReactionTakeDamage', 'BGN_UpdateResetProtectionTimer', function(attacker, target, dmginfo)
	local actor = bgNPC:GetActor(attacker)
	if actor == nil or not actor:HasState('police') then return end

	actor:GetStateData().state_timeout = CurTime() + 20
end)
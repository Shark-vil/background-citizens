local WantedModule = bgNPC:GetModule('wanted')
local ArrestModule = bgNPC:GetModule('player_arrest')

hook.Add('BGN_PreCallForHelp', 'BGN_PlayerArrest', function(actor, enemy)
	if not ArrestModule:HasPlayer(enemy) then return end
	return ArrestModule:GetPlayer(enemy).arrested
end)

local function _SetEnemyDefense(actor, enemy, custom_reaction)
	ArrestModule:NotSubjectToArrest(enemy)

	if actor and actor:IsAlive() then
		local reaction = custom_reaction

		if not reaction then
			reaction = actor:GetReactionForProtect()
			if reaction == 'arrest' then reaction = 'defense' end
		end

		actor:RemoveAllTargets()
		actor:AddEnemy(enemy)
		actor:SetState(reaction)
	end
end

hook.Add('BGN_OnKilledActor', 'BGN_PlayerArrest', function(_, attacker)
	if not ArrestModule:HasPlayer(attacker) then return end
	local ArrestComponent = ArrestModule:GetPlayer(attacker)
	if not ArrestComponent.arrested then return end
	ArrestModule:NotSubjectToArrest(attacker)
	local actors = bgNPC:GetAllByRadius(attacker:GetPos(), 700)

	for _, actor in ipairs(actors) do
		if actor:IsAlive() then
			local npc = actor:GetNPC()

			if bgNPC:IsTargetRay(npc, attacker) then
				_SetEnemyDefense(actor, attacker)
			end
		end
	end
end)

local function ActorOverrideReaction(actor)
	local reaction = actor:GetReactionForProtect()
	if reaction == 'arrest' then reaction = 'defense' end
	actor:SetReaction(reaction)
end

hook.Add('BGN_PreDamageToAnotherActor', 'BGN_PlayerArrest', function(actor, attacker, target, reaction)
	local ArrestComponent = ArrestModule:GetPlayer(attacker)

	if ( ArrestComponent and not ArrestComponent.arrested ) or
		reaction ~= 'arrest' or not GetConVar('bgn_arrest_mode'):GetBool()
	then
		ActorOverrideReaction(actor)
		return
	end

	local _target = target
	local _attacker = attacker

	if bgNPC:GetEnemyFromActorByTarget(actor, target, attacker) == target then
		_attacker = target
		_target = attacker
	end

	if not GetConVar('bgn_arrest_mode'):GetBool() or _target:IsPlayer() or not _attacker:IsPlayer() then
		_SetEnemyDefense(actor, _attacker, 'defense')
	end
end)

hook.Add('BGN_PreReactionTakeDamage', 'BGN_PlayerArrest', function(attacker, target, reaction)
	local TargetActor = bgNPC:GetActor(target)
	if not TargetActor then return end

	if not GetConVar('bgn_arrest_mode'):GetBool() or not attacker:IsPlayer() then
		_SetEnemyDefense(TargetActor, attacker)
		return
	end

	if not ArrestModule:HasPlayer(attacker) and not WantedModule:HasWanted(attacker) then
		local PoliceActor

		if TargetActor:HasTeam('police') then
			PoliceActor = TargetActor
		else
			for _, actor in ipairs(bgNPC:GetAllByRadius(attacker:GetPos(), 700)) do
				if actor:IsAlive() and actor:HasTeam('police') then
					if not PoliceActor then
						PoliceActor = actor
					else
						local AttackerPos = attacker:GetPos()
						local NewActorPos = actor:GetNPC():GetPos()
						local OldActorPos = PoliceActor:GetNPC():GetPos()

						if NewActorPos:DistToSqr(AttackerPos) < OldActorPos:DistToSqr(AttackerPos) then
							PoliceActor = actor
						end
					end
				end
			end

			if not PoliceActor then return end
		end

		ArrestModule:AddPlayer(attacker, PoliceActor)

		if PoliceActor:InVehicle() then
			PoliceActor:ExitVehicle()
		end

		PoliceActor:RemoveAllTargets()
		PoliceActor:AddTarget(attacker)
		PoliceActor:SetState('arrest')

		if TargetActor ~= PoliceActor and not TargetActor:HasState('fear') then
			TargetActor:RemoveAllTargets()
			TargetActor:AddEnemy(attacker)
			TargetActor:SetState('fear')
		end

		return false
	else
		local ArrestComponent = ArrestModule:GetPlayer(attacker)
		if not ArrestComponent then return end

		if ArrestComponent.arrested then
			ArrestComponent.damege_count = ArrestComponent.damege_count + 1

			if target:Health() <= 20 or ArrestComponent.damege_count > 5 then
				_SetEnemyDefense(ArrestComponent.policeActor, attacker)
			else
				if TargetActor:HasTeam('police') then
					TargetActor:AddTarget(attacker)
					TargetActor:SetState('arrest')
					return false
				end
			end
		end
	end
end)

bgNPC:SetStateAction('arrest', 'guarded', {
	update = function(actor)
		local npc = actor:GetNPC()
		local target = actor:GetFirstTarget()
		local ArrestComponent = ArrestModule:GetPlayer(target)

		if not IsValid(target) or actor:TargetsCount() == 0 or not ArrestComponent then
			actor:RandomState()
			return
		end

		if not ArrestComponent.arrested or (not ArrestComponent.detention and
			ArrestComponent.warningTime < CurTime())
		then
			_SetEnemyDefense(actor, target)
			return
		end

		if npc:GetPos():DistToSqr(target:GetPos()) > 22500 then
			actor:WalkToTarget(target, 'run')
			ArrestComponent.detention = false
		else
			local addArrestTime = GetConVar('bgn_arrest_time'):GetFloat()
			local eyeAngles = target:EyeAngles()

			if not ArrestComponent.detention then
				ArrestComponent.arrest_time = CurTime() + addArrestTime
			end

			if eyeAngles.x > 40 then
				if not ArrestComponent.detention then
					npc:EmitSound(bgNPC.cfg.arrest['warning_sound'], 300, 100, 1, CHAN_AUTO)
					target:ChatPrint(bgNPC.cfg.arrest['warning_text'])
				end

				ArrestComponent.detention = true
			else
				ArrestComponent.detention = false
			end

			if not ArrestComponent.detention and ArrestComponent.notify_order_time < CurTime() then
				ArrestComponent.notify_order_time = CurTime() + 3
				target:ChatPrint(bgNPC.cfg.arrest['order_text'])
				npc:EmitSound(bgNPC.cfg.arrest['order_sound'], 300, 100, 1, CHAN_AUTO)
			elseif ArrestComponent.detention then
				local time = ArrestComponent.arrest_time - CurTime()

				if time <= 0 then
					ArrestModule:RemovePlayer(target)

					if not hook.Run('BGN_PlayerArrest', target, actor) then
						target:EmitSound('background_npcs/handcuffs_sound1.mp3')
						target:ScreenFade(SCREENFADE.IN, Color(0, 0, 0, 255), 1, 3)
						target:KillSilent()
					end

					for _, selectActor in ipairs(bgNPC:GetAll()) do
						selectActor:RemoveTarget(target)
						selectActor:RemoveEnemy(target)
					end
				else
					if ArrestComponent.notify_arrest_time < CurTime() then
						target:ChatPrint(string.Replace(bgNPC.cfg.arrest['arrest_notify'], '%time%', math.floor(time)))
						ArrestComponent.notify_arrest_time = CurTime() + 1
					end
				end
			end
		end
	end,
	not_stop = function(actor, state, data)
		local target = actor:GetFirstTarget()
		if IsValid(target) then
			local ArrestComponent = ArrestModule:GetPlayer(target)
			if ArrestComponent and ArrestComponent.arrested then return true end
		end
		return false
	end,
})
local WantedModule = bgNPC:GetModule('wanted')
local ArrestModule = bgNPC:GetModule('player_arrest')

hook.Add('BGN_PreCallForHelp', 'BGN_PlayerArrest', function(actor, enemy)
	if not ArrestModule:HasTarget(enemy) then return end
	return ArrestModule:GetTarget(enemy).arrested
end)

hook.Add('BGN_OnKilledActor', 'BGN_PlayerArrest', function(_, attacker)
	if not ArrestModule:HasTarget(attacker) then return end
	local ArrestComponent = ArrestModule:GetTarget(attacker)
	if not ArrestComponent.arrested then return end
	ArrestModule:NotSubjectToArrest(attacker)
end)

hook.Add('BGN_PreReactionTakeDamage', 'BGN_PlayerArrest', function(attacker, target, reaction)
	if not GetConVar('bgn_arrest_mode'):GetBool() then return end
	if not attacker:IsPlayer() and not attacker:IsNPC() then return end
	if attacker:IsPlayer() and WantedModule:HasWanted(attacker) then return end

	local TargetActor = bgNPC:GetActor(target)
	local AttackerActor = bgNPC:GetActor(attacker)

	if attacker:IsNPC() and not AttackerActor then return end

	if not ArrestModule:HasTarget(attacker) then
		local PoliceActor

		if TargetActor and TargetActor:HasTeam('police') then
			PoliceActor = TargetActor
		else
			PoliceActor = ArrestModule:FoundPoliceInRadius(attacker)
			if not PoliceActor then
				PoliceActor = ArrestModule:FoundPoliceInRadius(target)
				if not PoliceActor then return end
			end
		end

		local enemy = bgNPC:GetEnemyFromActorByTarget(PoliceActor, target, attacker)
		if enemy ~= attacker then
			target = attacker
			attacker = enemy

			TargetActor = bgNPC:GetActor(target)
			AttackerActor = bgNPC:GetActor(attacker)
		end

		ArrestModule:AddTarget(attacker, PoliceActor)

		if PoliceActor:InVehicle() then
			PoliceActor:ExitVehicle()
		end

		PoliceActor:RemoveAllTargets()
		PoliceActor:AddTarget(attacker)
		PoliceActor:SetState('arrest')

		if AttackerActor and not AttackerActor:HasState('arrest_surrender') and slib.chance(50) then
			AttackerActor:AddTarget(PoliceActor:GetNPC())
			AttackerActor:SetState('arrest_surrender', nil, true)
		end

		if TargetActor and TargetActor ~= PoliceActor then
			TargetActor:RemoveAllTargets()
			TargetActor:AddEnemy(attacker)

			if not TargetActor:EqualStateGroup('danger') then
				TargetActor:SetState('fear')
			end
		end

		return false
	else
		local ArrestComponent = ArrestModule:GetTarget(attacker)
		if not ArrestComponent then return end

		if AttackerActor and not AttackerActor:HasState('arrest_surrender')
			and slib.chance(30)
			and AttackerActor:Health() <= 50
		then
			ArrestModule:UpdatePolice(attacker)

			local policeActor = ArrestComponent.policeActor
			if policeActor and policeActor:IsAlive() then
				ArrestModule:UpdateArrest(attacker)

				AttackerActor:AddTarget(policeActor:GetNPC())
				AttackerActor:SetState('arrest_surrender', nil, true)

				policeActor:AddTarget(attacker)
				policeActor:SetState('arrest', nil, true)
				return true
			end
		end

		if ArrestComponent.arrested then
			ArrestComponent.damege_count = ArrestComponent.damege_count + 1

			if TargetActor then
				if TargetActor:HasTeam('police')  then
					if target:Health() > 20 and ArrestComponent.damege_count <= 5 then
						TargetActor:AddTarget(attacker)
						TargetActor:SetState('arrest')
					end
				elseif TargetActor:EqualStateGroup('calm') then
					TargetActor:AddEnemy(attacker)
					TargetActor:SetState(reaction, nil, true)
				end
			end

			return false
		end
	end
end)

local function OnSetDefense(actor)
	local target = actor:GetFirstTarget()
	local ArrestComponent = ArrestModule:GetTarget(target)
	local TargetActor = bgNPC:GetActor(target)

	if not IsValid(target)
		or not ArrestComponent
		or not ArrestComponent.arrested
		or ArrestComponent.damege_count > 5
		or (target:IsPlayer() and not ArrestComponent.detention and ArrestComponent.warningTime < CurTime())
		or (target:IsPlayer() and WantedModule:HasWanted(target))
		or not GetConVar('bgn_arrest_mode'):GetBool()
		or (TargetActor and not TargetActor:HasState('arrest_surrender'))
	then
		actor:RemoveAllTargets()
		if IsValid(target) then actor:AddEnemy(target) end
		return 'defense'
	end
end

bgNPC:SetStateAction('arrest', 'guarded', {
	pre_start = function(actor)
		return OnSetDefense(actor)
	end,
	update = function(actor, state, data)
		local npc = actor:GetNPC()
		local target = actor:GetFirstTarget()
		local TargetActor = bgNPC:GetActor(target)
		local ArrestComponent = ArrestModule:GetTarget(target)

		if not IsValid(target) or actor:TargetsCount() == 0 or not ArrestComponent then
			actor:RandomState()
			return
		end

		local defense = OnSetDefense(actor)
		if defense then
			actor:SetState(defense, nil, true)
			return
		end

		if npc:GetPos():DistToSqr(target:GetPos()) > 10000 then
			actor:WalkToTarget(target, 'run')
			ArrestComponent.detention = false
			if actor:IsAnimationPlayed() then actor:ResetSequence() end
		else
			local addArrestTime = GetConVar('bgn_arrest_time'):GetFloat()
			local eyeAngles = target:EyeAngles()

			if not ArrestComponent.detention then
				ArrestComponent.arrest_time = CurTime() + addArrestTime
			end

			if target:IsNPC() or eyeAngles.x > 40 then
				if not ArrestComponent.detention then
					npc:EmitSound(bgNPC.cfg.arrest['warning_sound'], 300, 100, 1, CHAN_AUTO)

					if target:IsPlayer() then
						target:ChatPrint(bgNPC.cfg.arrest['warning_text'])
					end
				end
				ArrestComponent.detention = true
			else
				ArrestComponent.detention = false
				if actor:IsAnimationPlayed() then actor:ResetSequence() end
			end

			if not ArrestComponent.detention and ArrestComponent.notify_order_time < CurTime() then
				ArrestComponent.notify_order_time = CurTime() + 3
				if target:IsPlayer() then
					target:ChatPrint(bgNPC.cfg.arrest['order_text'])
				end
				npc:EmitSound(bgNPC.cfg.arrest['order_sound'], 300, 100, 1, CHAN_AUTO)
			elseif ArrestComponent.detention then
				local time = ArrestComponent.arrest_time - CurTime()

				if npc:IsNPC() then
					local npc_angle = npc:GetAngles()
					local npc_new_angle = (target:GetPos() - npc:GetPos()):Angle()
					npc:SetAngles(Angle(npc_angle.x, npc_new_angle.y, npc_angle.z))
					actor:PlayStaticSequence('canal5bidle1', true)
				end

				if time <= 0 then
					ArrestModule:RemoveTarget(target)
					data.arrested = true

					if not hook.Run('BGN_PlayerArrest', target, actor) then
						target:EmitSound('background_npcs/handcuffs_sound1.mp3')

						if target:IsNPC() then
							if TargetActor then
								TargetActor:RemoveAllTargets()
								TargetActor:RemoveAllEnemies()
								TargetActor:StateLock(true)
							end

							local weapon = target:GetActiveWeapon()
							if IsValid(weapon) then
								weapon:Remove()
							end

							if TargetActor and TargetActor:IsValidSequence('arrestcurious') then
								TargetActor:PlayStaticSequence('arrestcurious', true, 4, function()
									TargetActor:PlayStaticSequence('arrestidle', true)
									target:slibFadeRemove(.5)
								end)
							elseif TargetActor and TargetActor:IsValidSequence('checkmale') then
								TargetActor:PlayStaticSequence('checkmale', false, nil, function()
									TargetActor:PlayStaticSequence('checkmalepost', true)
									target:slibFadeRemove(.5)
								end)
							else
								target:slibFadeRemove()
							end
						else
							target:ScreenFade(SCREENFADE.IN, Color(0, 0, 0, 255), 1, 3)
							target:KillSilent()
						end
					end

					for _, selectActor in ipairs(bgNPC:GetAll()) do
						selectActor:RemoveTarget(target)
						selectActor:RemoveEnemy(target)
					end
				else
					if target:IsPlayer() and ArrestComponent.notify_arrest_time < CurTime() then
						target:ChatPrint(string.Replace(bgNPC.cfg.arrest['arrest_notify'], '%time%', math.floor(time)))
						ArrestComponent.notify_arrest_time = CurTime() + 1
					end
				end
			end
		end
	end,
	stop = function(actor, state, data)
		if data.arrested then
			hook.Run('BGN_PlayerArrestStop', actor, state, data)
		end
	end,
	not_stop = function(actor, state, data)
		local target = actor:GetFirstTarget()
		if IsValid(target) then
			local ArrestComponent = ArrestModule:GetTarget(target)
			if ArrestComponent and ArrestComponent.arrested then return true end
		end
		return false
	end,
})
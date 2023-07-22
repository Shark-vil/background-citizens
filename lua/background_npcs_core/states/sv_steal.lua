hook.Add('BGN_Module_FirstAttackerValidator', 'BGN_StealTargetSet', function(attacker, target)
	if target:slibGetVar('is_stealer') then return target, attacker end
end)

hook.Add('BGN_StealFinish', 'BGN_StealFinishedCallForHelp', function(actor, target, success)
	if not success or slib.chance(30) then
		local anotherActor = bgNPC:GetActor(target)
		if anotherActor then
			if not anotherActor:HasTeam('police') then
				anotherActor:CallForHelp(actor:GetNPC())
			end
			anotherActor:SetState('defense', nil, true)
		end
	end
end)

bgNPC:SetStateAction('steal', 'wary', {
	pre_start = function(actor, state, data)
		local npc = actor:GetNPC()
		local npc_pos = npc:GetPos()
		local entities = ents.FindInSphere(npc_pos, 500)
		local dist = nil
		local target = NULL

		for _, ent in ipairs(entities) do
			if not IsValid(ent) or (not ent:IsPlayer() and not ent:IsNPC() and not ent:IsNextBot()) then
				continue
			end

			local distToPlayer = npc_pos:DistToSqr(ent:GetPos())
			local anotherActor = bgNPC:GetActor(ent)
			if anotherActor and anotherActor:GetType() == 'thief' then
				continue
			end

			if dist == nil then
				dist = distToPlayer
				target = ent
			elseif distToPlayer < dist then
				dist = distToPlayer
				target = ent
			end
		end

		if not IsValid(target) then
			return 'walk'
		end

		actor:AddTarget(target)

		return state, {
			isSteal = false,
			stealDelay = 0,
			walkUpdate = 0,
			isPlayAnim = false,
			isWanted = false,
		}
	end,
	update = function(actor)
		local polices = bgNPC:GetAllByTeam('police')
		local npc = actor:GetNPC()
		local data = actor:GetStateData()
		local target = actor:GetFirstTarget()

		if not IsValid(target) then
			actor:SetState('walk')
			return
		end

		local npc_pos = npc:GetPos()
		local target_pos = target:GetPos()

		if data.isSteal then
			for _, ActorPolice in ipairs(polices) do
				if ActorPolice:IsAlive() then
					local PoliceNPC = ActorPolice:GetNPC()

					if PoliceNPC:GetPos():DistToSqr(npc_pos) <= 490000 and
						bgNPC:NPCIsViewVector(PoliceNPC, npc_pos) and bgNPC:IsTargetRay(PoliceNPC, npc)
					then
						ActorPolice:AddEnemy(npc)
						ActorPolice:SetState('defense')
					end
				end
			end

			data.SoundDelay = data.SoundDelay or 0

			if data.SoundDelay < CurTime() then
				npc:EmitSound('background_npcs/bed_sheet_movement.mp3', 70, 100, 1, CHAN_AUTO)
				data.SoundDelay = CurTime() + 3
			end
		end

		if target:slibIsViewVector(npc_pos, 80) then
			if data.isSteal then
				if not data.isWanted then
					data.isWanted = true
					actor:PlayStaticSequence('Crouch_To_Stand', false, nil, function()
						hook.Run('BGN_StealFinish', actor, target, false)
						actor:AddEnemy(target)
						actor:SetState('retreat', nil, true)
					end)
				end
			else
				if not data.isPlayAnim then
					data.isPlayAnim = true
					actor:ClearSchedule()
					local id = tostring(math.random(1, 4))
					actor:PlayStaticSequence('LineIdle0' .. id, true)
				end
			end
		else
			if data.isSteal then
				if not data.isPlayAnim and not data.isWanted then
					data.isPlayAnim = true
					npc:slibSetVar('is_stealer', true)
					actor:ClearSchedule()

					actor:PlayStaticSequence('Crouch_IdleD', true, 5, function()
						actor:PlayStaticSequence('Crouch_To_Stand', false, nil, function()
							data.isPlayAnim = false
							data.isWanted = true

							hook.Run('BGN_StealFinish', actor, target, true)
							actor:AddEnemy(target)
							actor:SetState('retreat', nil, true)
						end)
					end)
				end

				if npc_pos:DistToSqr(target_pos) > 10000 and actor:HasSequence('Crouch_IdleD') then
					data.isSteal = false
					actor:PlayStaticSequence('Crouch_To_Stand', false)
				end
			else
				if data.isPlayAnim then
					data.isPlayAnim = false
					actor:ResetSequence()
				end

				if data.walkUpdate < CurTime() then
					actor:WalkToPos(target:GetPos())
					data.walkUpdate = CurTime() + 5
				end

				if npc_pos:DistToSqr(target_pos) <= 10000 then
					data.isSteal = true
				end
			end
		end
	end,
	stop = function(actor)
		actor:RemoveAllTargets()
	end,
	not_stop = function(actor, state, data, new_state, new_data)
		return not data.isWanted and IsValid(actor:GetFirstTarget())
	end
})
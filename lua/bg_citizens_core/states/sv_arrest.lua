hook.Add('BGN_PreReactionTakeDamage', 'BGN_AttackerRegistrationOnArrestTable', function(attacker, target, dmginfo, reaction)
	if reaction == 'defense' then return end
	if not GetConVar('bgn_arrest_mode'):GetBool() then return end
	if #bgNPC:GetAllByType('police') == 0 then return end

	local ActorTarget = bgNPC:GetActor(target)
	if not (attacker:IsPlayer() and ActorTarget ~= nil and ActorTarget:GetType() == 'citizen') then return end

	if bgNPC.arrest_players[attacker] ~= nil then
		bgNPC.arrest_players[attacker].count = bgNPC.arrest_players[attacker].count + 1

		if bgNPC.arrest_players[attacker].delayIgnore > CurTime()
			and bgNPC.arrest_players[attacker].count >= 3
		then
			bgNPC.arrest_players[attacker].delayIgnore = 0
		end

		return
	end

	bgNPC.arrest_players[attacker] = {
		target = target,
		delay = CurTime() + 1.5,
		delayIgnore = CurTime() + GetConVar('bgn_arrest_time_limit'):GetFloat(),
		arrestTime = GetConVar('bgn_arrest_time'):GetFloat(),
		count = 1
	}
end)

hook.Add('BGN_OnKilledActor', 'BGN_ResettingNPCFromTheArrestTableAfterDeath', function(actor, attacker)
	if bgNPC.arrest_players[attacker] ~= nil then
		bgNPC.arrest_players[attacker].delayIgnore = 0
	end
end)

hook.Add('BGN_DamageToAnotherActor', 'BGN_EnableArrestStateForPolice', function(actor, attacker, target, reaction)
	if not GetConVar('bgn_arrest_mode'):GetBool() and reaction == 'arrest' then
		return 'defense'
	end

	if not IsValid(attacker) or not IsValid(target) then
		return
	end

	if bgNPC.arrest_players == nil or bgNPC.arrest_players[attacker] == nil
		or bgNPC.arrest_players[attacker].target == nil
		or not IsValid(bgNPC.arrest_players[attacker].target)
	then
		return
	end

	if bgNPC.arrest_players[attacker].arrest ~= nil
		and not bgNPC.arrest_players[attacker].arrest
	then
		return
	end

	local police = bgNPC:GetNearByType(attacker:GetPos(), 'police')
	if IsValid(police) then
		bgNPC.arrest_players[attacker].notify_delay
			= bgNPC.arrest_players[attacker].notify_delay or 0

		-- attacker:SetPos(police:GetNPC():GetPos())

		police:AddTarget(attacker)
		police:SetState('arrest', {
			targets = target,
			attacker = attacker,
		})

		bgNPC.arrest_players[attacker].arrest = true
		return false
	else
		bgNPC.arrest_players[attacker].arrest = false
	end

	--[[
	if actor:GetType() == 'police' then
		if actor:GetReactionForProtect() ~= 'arrest' then
			bgNPC.arrest_players[attacker].arrest = false
			return
		end
	else
		if bgNPC.arrest_players[attacker].delay > CurTime() then
			return true
		end
	end

	bgNPC.arrest_players[attacker].arrest = true
	
	if bgNPC.arrest_players[attacker].target == target then
		bgNPC.arrest_players[attacker].notify_delay 
			= bgNPC.arrest_players[attacker].notify_delay or 0

		actor:SetState('arrest', {
			targets = target,
			attacker = attacker,
		})
		return true
	end
	]]
end)

timer.Create('BGN_Timer_CheckingTheStateOfArrest', 1, 0, function()
	for _, actor in ipairs(bgNPC:GetAllByType('police')) do
		local npc = actor:GetNPC()
		if not IsValid(npc) then continue end
		local state = actor:GetState()
		local data = actor:GetStateData()

		if state ~= 'arrest' then continue end
		if not IsValid(data.attacker) then
			actor:Idle()
		else
			data.delay = data.delay or 0

			local delayIgnore = bgNPC.arrest_players[data.attacker].delayIgnore
			local arrestTime = bgNPC.arrest_players[data.attacker].arrestTime

			if delayIgnore < CurTime() then
				actor:AddTarget(data.attacker)
				actor:Defense()
				return
			end

			if npc:GetTarget() ~= data.attacker then
				npc:SetTarget(data.attacker)
			end

			if data.delay < CurTime() then
				bgNPC:SetActorWeapon(actor)

				local point = nil
				local current_distance = npc:GetPos():DistToSqr(data.attacker:GetPos())

				if current_distance > 1000 ^ 2 then
					point = actor:GetClosestPointToPosition(data.attacker:GetPos())
				else
					point = data.attacker:GetPos()
				end

				if point ~= nil then
					npc:SetSaveValue('m_vecLastPosition', point)
					npc:SetSchedule(SCHED_FORCED_GO_RUN)
				end

				local eyeAngles = data.attacker:EyeAngles()
				data.arrest_time = data.arrest_time or 0
				data.arrested = data.arrested or false

				if eyeAngles.x > 40 then
					if not data.arrested then
						npc:EmitSound('npc/metropolice/vo/apply.wav', 300, 100, 1, CHAN_AUTO)
						data.attacker:ChatPrint('Stay in this position, don\'t move!')
						data.arrest_time = CurTime() + arrestTime
					end
					data.arrested = true
				elseif data.arrested then
					data.arrested = false
					data.arrest_time = CurTime() + arrestTime
				end

				if not data.arrested
					and bgNPC.arrest_players[data.attacker].notify_delay < CurTime()
				then
					bgNPC.arrest_players[data.attacker].notify_delay = CurTime() + 3
					data.attacker:ChatPrint('Put your head down!')
					npc:EmitSound('npc/metropolice/vo/firstwarningmove.wav',
						300, 100, 1, CHAN_AUTO)
				elseif data.arrested then
					delayIgnore = delayIgnore + 1
					bgNPC.arrest_players[data.attacker].delayIgnore = delayIgnore

					local time = data.arrest_time - CurTime()
					if time <= 0 then
						bgNPC.arrest_players[data.attacker] = nil

						hook.Run('BGN_PlayerArrest', data.attacker, actor)
						for _, v in ipairs(bgNPC:GetAll()) do
							v:RemoveTarget(data.attacker)
						end
						return
					else
						bgNPC.arrest_players[data.attacker].notify_arrest = bgNPC.arrest_players[data.attacker].notify_arrest or 0

						if bgNPC.arrest_players[data.attacker].notify_arrest < CurTime() then
							data.attacker:ChatPrint('Arrest after ' .. math.floor(time) .. ' sec.')
							bgNPC.arrest_players[data.attacker].notify_arrest = CurTime() + 1
						end
					end
				end

				data.delay = CurTime() + 1
			end
		end
	end
end)

hook.Add('BGN_PlayerArrest', 'BGN_DarkRP_DefaultPlayerArrest', function(ply, actor)
	if ply.arrest then
		ply:arrest(nil, actor:GetNPC())
	end
end)
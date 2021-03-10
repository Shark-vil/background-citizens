local WantedModule = bgNPC:GetModule('wanted')

hook.Add('BGN_PreSetNPCState', 'BGN_DisableArrestIfWanted', function(actor, state)
   if state ~= 'arrest' or not actor:IsAlive() then return end
	
	if WantedModule:HasWanted(actor:GetFirstTarget()) then
		return { state = 'defense' }
	end
end)

--[[
	We add the player to the arrest module, and increase the level of violation
	if he continues to inflict damage.
--]]
hook.Add("BGN_PreReactionTakeDamage", "BGN_AttackerRegistrationOnArrestTable", 
function(attacker, target, dmginfo, reaction)
	if reaction == 'defense' then return end
	if not GetConVar('bgn_arrest_mode'):GetBool() then return end
	if #bgNPC:GetAllByType('police') == 0 then return end

	local asset = bgNPC:GetModule('player_arrest')
	local ActorTarget = bgNPC:GetActor(target)

	if attacker:IsPlayer() and ActorTarget ~= nil and ActorTarget:HasTeam('residents') then
		if not asset:HasPlayer(attacker) then
			if not WantedModule:HasWanted(attacker) then
				asset:AddPlayer(attacker)
			end
		else
			local c_Arrest = asset:GetPlayer(attacker)
			c_Arrest.damege_count = c_Arrest.damege_count + 1

			if c_Arrest.damege_count >= 3 then
				c_Arrest.not_arrest = true
			end
		end
	end
end)

--[[
	Reset the timer ignore violations if the player killed the actor during the arrest.
--]]
hook.Add("BGN_OnKilledActor", "BGN_ResettingNPCFromTheArrestTableAfterDeath", function(actor, attacker)
	local asset = bgNPC:GetModule('player_arrest')
	if asset == nil then return end

	if asset:HasPlayer(attacker) then
		local c_Arrest = asset:GetPlayer(attacker)
		if c_Arrest.is_look_police then
			c_Arrest.not_arrest = true
		end
	end
end)

--[[
	An overload of the standard reaction of the actor state.
--]]
local function ReactionOverride(actor, reaction)
	actor:SetReaction(reaction == 'arrest' and 'defense' or reaction)
end

--[[
	Actions performed by other actors if an ally takes damage.
--]]
hook.Add("BGN_PreDamageToAnotherActor", "BGN_EnableArrestStateForPolice", 
function(actor, attacker, target, reaction)
	if not IsValid(attacker) then return end
	if not GetConVar('bgn_arrest_mode'):GetBool() then
		ReactionOverride(actor, reaction)
		return
	end

	local asset = bgNPC:GetModule('player_arrest')
	if asset == nil then return end

	local c_Arrest = asset:GetPlayer(attacker)
	if c_Arrest == nil or c_Arrest.not_arrest then
		ReactionOverride(actor, reaction)
		return
	end

	local success = false
	for _, police in ipairs(bgNPC:GetAllByType('police')) do
		if police:IsAlive() then
			local npc = police:GetNPC()
			local dist = target:GetPos():DistToSqr(npc:GetPos())

			if dist < 1000000 and bgNPC:IsTargetRay(npc, attacker) then
				police:AddTarget(attacker)
				police:SetState('arrest')

				npc:EmitSound('npc/metropolice/vo/movetoarrestpositions.wav', 300, 100, 1, CHAN_AUTO)
				success = true
				c_Arrest.is_look_police = success
			end
		end
	end

	if not success then
		ReactionOverride(actor, reaction)
	end

	return true
end)

--[[
	Arrest state processing timer.
--]]
bgNPC:SetStateAction('arrest', function(actor)
	local addArrestTime = GetConVar('bgn_arrest_time'):GetFloat()

	if actor:TargetsCount() == 0 then
		actor:RandomState()
	else
		local npc = actor:GetNPC()
		local target = actor:GetNearTarget()
		if not IsValid(target) then return end

		local data = actor:GetStateData()
		data.delay = data.delay or 0

		local asset = bgNPC:GetModule('player_arrest')

		if not asset:HasPlayer(target) then
			return
		end

		local c_Arrest = asset:GetPlayer(target)

		if c_Arrest.not_arrest or c_Arrest.delayIgnore < CurTime() then
			actor:SetState('defense')
			return
		end

		if npc:GetTarget() ~= target then
			npc:SetTarget(target)
		end

		if data.delay < CurTime() then
			bgNPC:SetActorWeapon(actor)

			actor:WalkToPos(target:GetPos(), 'run')

			local eyeAngles = target:EyeAngles()
			data.arrest_time = data.arrest_time or 0
			data.arrested = data.arrested or false

			if eyeAngles.x > 40 then
				if not data.arrested then
					npc:EmitSound(bgNPC.cfg.arrest['warning_sound'], 300, 100, 1, CHAN_AUTO)
					target:ChatPrint(bgNPC.cfg.arrest['warning_text'])
					data.arrest_time = CurTime() + addArrestTime
				end
				data.arrested = true
			elseif data.arrested then
				data.arrested = false
				data.arrest_time = CurTime() + addArrestTime
			end

			if not data.arrested and c_Arrest.notify_delay < CurTime() then
				c_Arrest.notify_delay = CurTime() + 3
				target:ChatPrint(bgNPC.cfg.arrest['order_text'])
				npc:EmitSound(bgNPC.cfg.arrest['order_sound'], 300, 100, 1, CHAN_AUTO)
			elseif data.arrested then
				c_Arrest.delayIgnore = c_Arrest.delayIgnore + 1

				local time = data.arrest_time - CurTime()
				if time <= 0 then
					asset:RemovePlayer(target)

					hook.Run('BGN_PlayerArrest', target, actor)
					
					for _, actor in ipairs(bgNPC:GetAll()) do
						actor:RemoveTarget(target)
					end
					return
				else
					c_Arrest.notify_arrest = c_Arrest.notify_arrest or 0

					if c_Arrest.notify_arrest < CurTime() then
						local text = string.Replace(bgNPC.cfg.arrest['arrest_notify'], '%time%', math.floor(time))
						target:ChatPrint(text)
						c_Arrest.notify_arrest = CurTime() + 1
					end
				end
			end

			data.delay = CurTime() + 1
		end
	end
end)
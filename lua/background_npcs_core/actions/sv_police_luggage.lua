local math = math
local table = table
local hook = hook
--
local slapSounds = {
	'physics/body/body_medium_impact_hard1.wav',
	'physics/body/body_medium_impact_hard2.wav',
	'physics/body/body_medium_impact_hard3.wav',
	'physics/body/body_medium_impact_hard5.wav',
	'physics/body/body_medium_impact_hard6.wav',
	'physics/body/body_medium_impact_soft5.wav',
	'physics/body/body_medium_impact_soft6.wav',
	'physics/body/body_medium_impact_soft7.wav',
}

local function TargetPlayerPush(npc, target, velocity)
	local forward = npc:GetForward()
	local angle_punch_pitch = math.Rand(-20, 20)
	local angle_punch_yaw = math.sqrt(20 * 20 - angle_punch_pitch * angle_punch_pitch)
	if math.random(0, 1) == 1 then
		angle_punch_yaw = angle_punch_yaw * -1
	end

	target:ViewPunch(Angle(angle_punch_pitch, angle_punch_yaw, 0))
	target:EmitSound(table.RandomBySeq(slapSounds), 75, 100, 0.3, CHAN_AUTO)
	target:SetVelocity(forward * velocity)
end

hook.Add('BGN_ActorVisibleAtObject', 'BGN_PolicPlayerPushDanger', function(actor, ent, distance)
	if distance > 50 or not ent:IsPlayer() or ent:InVehicle() then return end
	if ent:Health() <= 0 or actor:IsMeleeWeapon() then return end
	if not actor:HasTeam('police') or actor:HasState('arrest') then return end

	local LuggagePush = actor:IsValidSequence('LuggagePush')
	local MeleeGunhit = actor:IsValidSequence('MeleeGunhit')

	if not LuggagePush and MeleeGunhit then return end

	if actor:EqualStateGroup('danger') and actor:IsSequenceFinished() then
		local data = actor:GetStateData()

		data.LuggagePushDelay = data.LuggagePushDelay or 0
		if data.LuggagePushDelay > CurTime() then return end

		if LuggagePush then
			actor:ResetSequence()
			actor:PlayStaticSequence('LuggagePush')
		else
			actor:ResetSequence()
			actor:PlayStaticSequence('MeleeGunhit')
		end

		TargetPlayerPush(actor:GetNPC(), ent, 600)
	end
end)

hook.Add('BGN_ActorVisibleAtObject', 'BGN_PolicPlayerPushCalmly', function(actor, ent, distance)
	if distance > 50 or not ent:IsPlayer() or ent:InVehicle() then return end
	if ent:Health() <= 0 or actor:IsMeleeWeapon() then return end
	if not actor:HasTeam('police') or actor:HasState('arrest') then return end

	local LuggagePush = actor:IsValidSequence('LuggagePush')
	local LuggageWarn = actor:IsValidSequence('LuggageWarn')

	if not LuggagePush and not LuggageWarn then return end

	if actor:EqualStateGroup('calm') and actor:IsSequenceFinished() then
		local data = actor:GetStateData()
		local npc = actor:GetNPC()
		data.LuggageWarn = data.LuggageWarn or 0

		if data.LuggageWarn == 0 then
			npc:EmitSound('npc/metropolice/vo/firstwarningmove.wav')
		elseif data.LuggageWarn == 1 then
			npc:EmitSound('npc/metropolice/vo/secondwarning.wav')
		end

		if data.LuggageWarn < 2 then
			actor:PlayStaticSequence('LuggageWarn')
			data.LuggageWarn = data.LuggageWarn + 1
		else
			actor:PlayStaticSequence('LuggagePush')
			TargetPlayerPush(actor:GetNPC(), ent, 250)
			data.LuggageWarn = 0
		end
	end
end)
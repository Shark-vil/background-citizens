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

	target:EmitSound(table.Random(slapSounds), 75, 100, 0.3, CHAN_AUTO)
	target:SetVelocity(forward * velocity)
end


hook.Add('BGN_NPCLookAtObject', 'BGN_PolicePushPlayerWhileProtectedIfHeIsClose', function(actor, ent)
	if ent:IsPlayer() and actor:GetType() == 'police'
		and actor:GetState() == 'defense'
		and actor:IsSequenceFinished()
	then
		if ent:GetPos():DistToSqr(actor:GetNPC():GetPos()) > 50 ^ 2 then return end

		local data = actor:GetStateData()
		data.LuggagePush = data.LuggagePush or false

		if data.LuggagePush then return end

		actor:PlayStaticSequence('LuggagePush')

		TargetPlayerPush(actor:GetNPC(), ent, 450)

		data.LuggagePush = true
	end
end)

hook.Add('BGN_NPCLookAtObject', 'BGN_PoliceWarnAndPushPlayerIfHeIsClose', function(actor, ent)
	if ent:IsPlayer() and actor:GetType() == 'police'
		and actor:GetState() == 'walk'
		and actor:IsSequenceFinished()
	then
		if ent:GetPos():DistToSqr(actor:GetNPC():GetPos()) > 50 ^ 2 then return end

		local data = actor:GetStateData()
		data.LuggageWarn = data.LuggageWarn or 0

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
--[[
	medic_revive: the medic runs to the body of its call (systems/sv_medics.lua), kneels over it with sounds,
	brings the actor back, then walks back to its ambulance and drives away (or just goes on walking).
	State data: { call = <medic call> }.
--]]

local REACH_DIST_SQR = 70 ^ 2
local CAR_REACH_DIST_SQR = 200 ^ 2
local REVIVE_TIME = 6
local GIVE_UP_TIME = 40 -- can't reach the body or the car
-- first sequence the model has: the HL2 medic heal, kneeling idles as a fallback
local SEQUENCES = { 'heal', 'Crouch_idleD', 'crouchidle', 'Crouch_idle_pistol' }
local WORK_SOUNDS = { 'items/medshot4.wav', 'items/medcharge4.wav', 'items/smallmedkit1.wav' }

local function Voice(actor, line)
	local folder = string.find(actor:GetNPC():GetModel(), 'female', 1, true) and 'female01' or 'male01'
	actor:VoiceSay('vo/npc/' .. folder .. '/' .. line .. '.wav')
end

local function PickSequence(actor)
	for _, name in ipairs(SEQUENCES) do
		if actor:IsValidSequence(name) then return name end
	end
end

-- @return boolean true while walking back to the ambulance
local function ReturnToCar(actor, data)
	local car = actor.medic_ambulance
	if not IsValid(car) or actor:InVehicle() then return false end
	if actor:GetPos():DistToSqr(car:GetPos()) <= CAR_REACH_DIST_SQR then
		actor.medic_ambulance = nil
		actor:EnterVehicle(car)
		return false
	end
	if (data.next_walk or 0) < CurTime() then
		data.next_walk = CurTime() + 2
		actor:WalkToPos(car:GetPos(), 'walk')
	end
	return true
end

bgNPC.States.Register('medic_revive', 'calm', {
	start = function(actor, _, data)
		data.give_up = CurTime() + GIVE_UP_TIME
	end,
	stop = function(actor)
		actor:StopStaticSequence()
	end,
	update = function(actor)
		local data = actor:GetStateData()
		local call = data.call
		local now = CurTime()

		if not call or call.done or call.medic ~= actor or data.give_up < now then
			if data.give_up >= now and ReturnToCar(actor, data) then return end
			actor:RandomState()
			return
		end

		if not data.revive_end then
			if actor:GetPos():DistToSqr(call.pos) > REACH_DIST_SQR then
				if (data.next_walk or 0) < now then
					data.next_walk = now + 2
					actor:WalkToPos(call.pos, 'run')
				end
				return
			end

			actor:StopWalk()
			local npc = actor:GetNPC()
			local dir = call.pos - npc:GetPos()
			npc:SetAngles(Angle(0, dir:Angle().y, 0))
			data.revive_end = now + REVIVE_TIME
			data.next_sound = now
			data.sequence = PickSequence(actor)
			data.give_up = now + GIVE_UP_TIME -- the way back to the car starts after the revive
			Voice(actor, 'health0' .. math.random(1, 5))
		end

		if data.sequence then actor:PlayStaticSequence(data.sequence, true) end
		if data.next_sound <= now then
			data.next_sound = now + 1.5
			actor:GetNPC():EmitSound(bgNPC.Table.Random(WORK_SOUNDS), 70, math.random(95, 105))
		end

		if now >= data.revive_end then
			actor:StopStaticSequence()
			call.done = true
			bgNPC.Medics.Revive(call)
			Voice(actor, math.random(2) == 1 and 'ok01' or 'ok02')
		end
	end,
})

--[[
	medic_revive: the medic runs to the body of its call (systems/sv_medics.lua), kneels over it with sounds,
	brings the actor back, then walks back to its ambulance and drives away (or just goes on walking).
	The partner of the medic (call.partner) goes too and kneels beside it; only the medic brings the actor back.
	State data: { call = <medic call> }.
--]]

local REACH_DIST_SQR = 80 ^ 2
local STRAIGHT_DIST_SQR = 300 ^ 2 -- closer than this the body walks straight (the actor walk stops 150 short)
local MOVE_PERIOD = 1.5
local CAR_REACH_DIST_SQR = 200 ^ 2
local REVIVE_TIME = 6
local PARTNER_OFFSET = Vector(45, 30, 0) -- the partner kneels beside the medic, not in it
local GIVE_UP_TIME = 40 -- can't reach the body or the car
-- first sequence the model has: the HL2 medic heal, kneeling idles as a fallback
local SEQUENCES = { 'heal', 'Crouch_idleD', 'crouchidle', 'Crouch_idle_pistol' }
-- one-shot sounds only: a looping one (items/medcharge4.wav) keeps playing after the revive or the medic's death
local WORK_SOUNDS = { 'items/medshot4.wav', 'items/smallmedkit1.wav' }

local function Voice(actor, line)
	local folder = string.find(actor:GetNPC():GetModel(), 'female', 1, true) and 'female01' or 'male01'
	actor:VoiceSay('vo/npc/' .. folder .. '/' .. line .. '.wav')
end

local function PickSequence(actor)
	for _, name in ipairs(SEQUENCES) do
		if actor:IsValidSequence(name) then return name end
	end
end

-- The actor walk follows nav points and stops 150 units short of the goal; bodies off the points
-- (grass, squares) or that close are reached by the body going straight.
local function MoveTo(actor, data, pos, run)
	local now = CurTime()
	if (data.next_move or 0) > now then return end
	data.next_move = now + MOVE_PERIOD
	if actor:GetPos():DistToSqr(pos) > STRAIGHT_DIST_SQR then
		actor:WalkToPos(pos, run and 'run' or 'walk')
		if #actor.walkPath ~= 0 then return end
	end
	if actor:WalkDestinationExists() then actor:StopWalk() end
	actor:GetBody():MoveTo(pos, run)
end
bgNPC.MoveToPoint = MoveTo -- also the police at a body (sv_police_inspect_body.lua)

-- @return boolean true while walking back to the ambulance
local function ReturnToCar(actor, data)
	local car = actor.medic_ambulance
	if not IsValid(car) or actor:InVehicle() then return false end
	if actor:GetPos():DistToSqr(car:GetPos()) <= CAR_REACH_DIST_SQR then
		actor.medic_ambulance = nil
		actor:GetBody():StopMoving()
		actor:EnterVehicle(car)
		-- the car drives off once someone is at the wheel: the partner close by gets in together
		local partner = actor.medic_partner
		if partner and partner:IsAlive() and not partner:InVehicle() and partner.medic_ambulance == car
			and partner:GetPos():DistToSqr(car:GetPos()) <= bgNPC.Medics.PARTNER_PULL_DIST_SQR
		then
			partner.medic_ambulance = nil
			partner:EnterVehicle(car)
		end
		return false
	end
	MoveTo(actor, data, car:GetPos(), false)
	return true
end

bgNPC.States.Register('medic_revive', 'calm', {
	start = function(actor, _, data)
		data.give_up = CurTime() + GIVE_UP_TIME
	end,
	stop = function(actor)
		actor:StopStaticSequence()
		if not actor:InVehicle() then actor.eternal = false end
	end,
	update = function(actor)
		local data = actor:GetStateData()
		local call = data.call
		local now = CurTime()

		-- closed: revived, expired or the body is gone
		local is_medic = call and call.medic == actor
		if not call or call.done or call.closed or bgNPC.Medics.IsBlocked(call.pos)
			or not (is_medic or call.partner == actor) or data.give_up < now then
			if not data.returning then
				data.returning = true
				data.give_up = now + GIVE_UP_TIME -- the way back gets its own time
				data.next_move = 0
				if data.revive_end then actor:StopStaticSequence() end
			end
			if data.give_up >= now and ReturnToCar(actor, data) then return end
			actor:RandomState()
			return
		end

		local spot = is_medic and call.pos or call.pos + PARTNER_OFFSET
		if not data.revive_end then
			if actor:GetPos():DistToSqr(spot) > REACH_DIST_SQR then
				MoveTo(actor, data, spot, true)
				return
			end

			actor:StopWalk()
			actor:GetBody():StopMoving()
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

		-- the partner kneels on until the medic is done (call.done above)
		if is_medic and now >= data.revive_end then
			actor:StopStaticSequence()
			call.done = true
			bgNPC.Medics.Revive(call)
			Voice(actor, math.random(2) == 1 and 'ok01' or 'ok02')
		end
	end,
})

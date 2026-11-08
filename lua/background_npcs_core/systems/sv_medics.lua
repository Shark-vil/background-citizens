--[[
	Medics: every actor death (not in a vehicle, not killed by the police) is a call. A free medic takes it, otherwise one is spawned
	near the body (bgNPC:FindSpawnPosition) with an ambulance when Decent Vehicle and the medic config have one.
	The ambulance drives to the body with the siren (npc_dvbgn_police, actor.drive_target_pos), the medic gets out,
	revives the actor (state "medic_revive") and drives away. A body can be revived for CORPSE_TIME seconds,
	and only while it exists: a removed server ragdoll or a client report of a removed client ragdoll closes the
	call (call.closed), and the medic goes back to its car.
--]]

local Medics = {}
bgNPC.Medics = Medics

local CORPSE_TIME = 90
local EXIT_DIST_SQR = 700 ^ 2 -- the ambulance stops this close to the body
local VEHICLE_WAIT = 2 -- the medic enters the spawned ambulance after a short delay
local STOPPED_EXIT_TIME = 5 -- an ambulance standing this long gets out even far from the body
local STOPPED_SPEED = 50
local MEDIC_TYPE = 'medic'
local BODY_GONE_DIST_SQR = 200 ^ 2
local REVIVE_OFFSETS = {
	Vector(0, 0, 8), Vector(40, 0, 8), Vector(-40, 0, 8), Vector(0, 40, 8), Vector(0, -40, 8),
	Vector(60, 60, 8), Vector(-60, -60, 8), Vector(60, -60, 8), Vector(-60, 60, 8),
}

local calls = {}
Medics.calls = calls

hook.Add('BGN_OnKilledActor', 'BGN_Medics_Call', function(actor, attacker)
	if not bgNPC.Config.IsTypeActive(MEDIC_TYPE) or actor:InVehicle() then return end
	local killer = IsValid(attacker) and bgNPC.Actors.Get(attacker)
	if killer and killer:HasTeam('police') then return end -- shot by the police: no ambulance
	local npc = actor:GetNPC()
	if not IsValid(npc) then return end
	calls[#calls + 1] = {
		pos = npc:GetPos(),
		npc = npc,
		type = actor:GetType(),
		model = npc:GetModel(),
		skin = npc:GetSkin(),
		time = CurTime(),
	}
end)

-- A medic's enemies are only those who hurt it (not the wanted, not other people's fights).
hook.Add('BGN_PreReactionTakeDamage', 'BGN_Medics_Attacker', function(attacker, target)
	local actor = bgNPC.Actors.Get(target)
	if actor and actor:GetType() == MEDIC_TYPE then
		actor.medic_attackers = actor.medic_attackers or setmetatable({}, { __mode = 'k' })
		actor.medic_attackers[attacker] = true
	end
end)

hook.Add('BGN_AddActorEnemy', 'BGN_Medics_OnlyAttackers', function(actor, ent)
	if actor:GetType() == MEDIC_TYPE and not (actor.medic_attackers and actor.medic_attackers[ent]) then return true end
end)

-- npc_citizen picks its own model by citizentype on spawn; "unique" (4) keeps the medic model given before it.
hook.Add('BGN_PreSpawnActor', 'BGN_Medics_Model', function(npc, npc_type, data)
	if npc_type ~= MEDIC_TYPE or not istable(data.models) or #data.models == 0 then return end
	npc:SetKeyValue('citizentype', 4)
	npc:SetModel(data.models[math.random(#data.models)])
end)

-- A server-side ragdoll (ai_serverragdolls 1) is removed on revive.
hook.Add('CreateEntityRagdoll', 'BGN_Medics_Ragdoll', function(owner, ragdoll)
	for i = #calls, 1, -1 do
		if calls[i].npc == owner then calls[i].ragdoll = ragdoll return end
	end
end)

-- Clients own the usual NPC ragdolls: one tells when it fades or is cleaned up.
-- shortcut: any client may close a call near a position, harmless (the medic just leaves), rate-limited by Net
bgNPC.Net.Receive('bgn.medic_body_gone', function(_, pos)
	if not isvector(pos) then return end
	for _, call in ipairs(calls) do
		if not call.done and call.pos:DistToSqr(pos) < BODY_GONE_DIST_SQR then call.gone = true end
	end
end)

-- Brings the dead actor back: a new actor of the same type with the same look on the body's place,
-- or next to it when the place is taken (a car, another actor). The body stays when nowhere fits.
function Medics.Revive(call)
	if IsValid(call.ragdoll) then call.ragdoll:Remove() end
	local actor
	for _, offset in ipairs(REVIVE_OFFSETS) do
		actor = bgNPC:SpawnActor(call.type, call.pos + offset)
		if actor then break end
	end
	if not actor then return end
	bgNPC.Net.Send('bgn.medic_revived', nil, call.pos) -- removes the client-side ragdoll
	local npc = actor:GetNPC()
	if not IsValid(npc) then return end
	npc:SetModel(call.model)
	npc:SetSkin(call.skin or 0)
	npc:EmitSound('items/smallmedkit1.wav', 75)
	hook.Run('BGN_ActorRevived', actor, call)
end

local function IsFree(medic)
	return medic:IsAlive() and not medic.medic_call and not medic:EqualStateGroup('danger')
end

local function Assign(medic, call)
	call.medic = medic
	medic.medic_call = call
end

-- @return table|nil nearest free medic, or a new one
local function FindMedic(call)
	local best, best_dist
	for _, medic in ipairs(bgNPC.Actors.GetByType(MEDIC_TYPE)) do
		if IsFree(medic) then
			local dist = medic:GetPos():DistToSqr(call.pos)
			if not best or dist < best_dist then best, best_dist = medic, dist end
		end
	end
	if best then return best end

	if #bgNPC.Actors.GetNPCsByType(MEDIC_TYPE) >= bgNPC.Config.GetTypeLimit(MEDIC_TYPE) then return end
	local pos = bgNPC:FindSpawnPosition({ position = call.pos })
	if not pos then return end
	local medic = bgNPC:SpawnActor(MEDIC_TYPE, pos)
	if not medic then return end
	if bgNPC:SpawnVehicleWithActor(medic, true) then medic.medic_vehicle_wait = CurTime() + VEHICLE_WAIT end
	return medic
end

-- Moves the medic towards the body: drives while in the ambulance, walks and revives on foot.
local function Respond(medic, call)
	local now = CurTime()
	if (medic.medic_vehicle_wait or 0) > now then return end

	-- driving ignores the medic's fear: the car keeps going to the body
	if medic:InVehicle() then
		local vehicle = medic:GetVehicle()
		if IsValid(vehicle) and vehicle:GetPos():DistToSqr(call.pos) > EXIT_DIST_SQR then
			medic.drive_target_pos = call.pos
			if vehicle:GetVelocity():Length() > STOPPED_SPEED then
				medic.medic_stopped_since = nil
				return
			end
			-- stuck or the body is off the road: walk the rest
			medic.medic_stopped_since = medic.medic_stopped_since or now
			if now - medic.medic_stopped_since < STOPPED_EXIT_TIME then return end
		end
		medic.drive_target_pos = nil
		medic.medic_stopped_since = nil
		medic.medic_ambulance = vehicle
		medic:ExitVehicle()
	end
	medic.eternal = true -- on foot out of the players' sight the remover would take or teleport it

	if medic:EqualStateGroup('danger') then return end

	-- forced: a medic still walking back from the previous call is in the same state
	local data = medic:HasState('medic_revive') and medic:GetStateData()
	if not data or data.call ~= call then medic:SetState('medic_revive', { call = call }, true) end
end

local function Release(medic)
	medic.medic_call = nil
	medic.drive_target_pos = nil
end

timer.Create('BGN_MedicsDispatch', 1, 0, function()
	local now = CurTime()
	for i = #calls, 1, -1 do
		local call = calls[i]
		local medic = call.medic
		local body_removed = call.ragdoll ~= nil and not IsValid(call.ragdoll)
		if call.done or call.gone or body_removed or call.time + CORPSE_TIME < now then
			call.closed = true
			table.remove(calls, i)
			if medic and medic.medic_call == call then Release(medic) end
		elseif not medic or not medic:IsAlive() then
			medic = FindMedic(call)
			if medic then Assign(medic, call) end
		else
			Respond(medic, call)
		end
	end
end)

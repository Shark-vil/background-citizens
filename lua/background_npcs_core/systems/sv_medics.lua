--[[
	Medics: every actor death (not in a vehicle) is a call. A free medic takes it, otherwise one is spawned
	near the body (bgNPC:FindSpawnPosition) with an ambulance when Decent Vehicle and the medic config have one.
	The ambulance drives to the body with the siren (npc_dvbgn_police, actor.drive_target_pos), the medic gets out,
	revives the actor (state "medic_revive") and drives away. A body can be revived for CORPSE_TIME seconds.
--]]

local Medics = {}
bgNPC.Medics = Medics

local CORPSE_TIME = 90
local EXIT_DIST_SQR = 700 ^ 2 -- the ambulance stops this close to the body
local VEHICLE_WAIT = 2 -- the medic enters the spawned ambulance after a short delay
local MEDIC_TYPE = 'medic'

local calls = {}
Medics.calls = calls

hook.Add('BGN_OnKilledActor', 'BGN_Medics_Call', function(actor)
	if not bgNPC.Config.IsTypeActive(MEDIC_TYPE) or actor:InVehicle() then return end
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

-- A server-side ragdoll (ai_serverragdolls 1) is removed on revive.
hook.Add('CreateEntityRagdoll', 'BGN_Medics_Ragdoll', function(owner, ragdoll)
	for i = #calls, 1, -1 do
		if calls[i].npc == owner then calls[i].ragdoll = ragdoll return end
	end
end)

-- Brings the dead actor back: a new actor of the same type with the same look on the body's place.
function Medics.Revive(call)
	if IsValid(call.ragdoll) then call.ragdoll:Remove() end
	bgNPC.Net.Send('bgn.medic_revived', nil, call.pos) -- removes the client-side ragdoll
	local actor = bgNPC:SpawnActor(call.type, call.pos + Vector(0, 0, 8))
	if not actor then return end
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
	if (medic.medic_vehicle_wait or 0) > CurTime() or medic:EqualStateGroup('danger') then return end

	if medic:InVehicle() then
		local vehicle = medic:GetVehicle()
		if IsValid(vehicle) and vehicle:GetPos():DistToSqr(call.pos) > EXIT_DIST_SQR then
			medic.drive_target_pos = call.pos
			return
		end
		medic.drive_target_pos = nil
		medic.medic_ambulance = vehicle
		medic:ExitVehicle()
	end

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
		if call.done or call.time + CORPSE_TIME < now then
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

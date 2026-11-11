--[[
	Doors: an actor looking at a closed door it may open (bgNPC.Util.CanActorOpenDoor: "bgn_npc_open_doors",
	"bgn_npc_open_locked_doors" for a locked one) opens it and closes it again after 10 s, locking it back if it
	was locked. An already open door is just walked through: the opening animation used to stop actors in the doorway.
	Engine NPCs also open doors themselves (CAP_OPEN_DOORS), only while "bgn_npc_open_doors" is on.
--]]

local DOOR_CAPABILITIES = CAP_AUTO_DOORS + CAP_OPEN_DOORS

local function OpenDoor(actor, door)
	if hook.Run('BGN_PreOpenDoor', actor, door) then return end
	actor:PlayStaticSequence('Open_door_away')

	door.bgNPCOpenDoor = true
	local was_locked = bgNPC.Util.IsDoorLocked(door)
	if was_locked then door:Fire('unlock', '', 0) end
	door:Fire('open', '', 0)

	hook.Run('BGN_PostOpenDoor', actor, door)

	timer.Simple(10, function()
		if IsValid(door) and door.bgNPCOpenDoor and not hook.Run('BGN_PreCloseDoor', door) then
			door:Fire('close', '', 0)
			if was_locked then door:Fire('lock', '', 0) end
			door.bgNPCOpenDoor = false

			hook.Run('BGN_PostCloseDoor', door)
		end
	end)
end

hook.Add('BGN_ActorLookAtObject', 'BGN_NPCDoorOpeningEvent', function(actor, ent, distance)
	if actor:HasState('scenic_npc') then return end
	if distance > 80 then return end
	local entities = ents.FindInSphere(ent:GetPos(), 150)
	for i = 1, #entities do
		local door = entities[i]
		if not door.bgNPCOpenDoor and bgNPC.Util.CanActorOpenDoor(door) and not bgNPC.Util.IsDoorOpen(door) then
			OpenDoor(actor, door)
			break
		end
	end
end)

cvars.AddChangeCallback('bgn_npc_open_doors', function(_, _, value)
	local enable = tonumber(value) == 1
	for _, actor in ipairs(bgNPC.Actors.GetAll()) do
		local npc = actor:GetNPC()
		if IsValid(npc) and npc:IsNPC() then
			local posing = actor:HasState('scenic_npc') and actor:GetStateData().door
			if enable and not posing then npc:CapabilitiesAdd(DOOR_CAPABILITIES) else npc:CapabilitiesRemove(DOOR_CAPABILITIES) end
		end
	end
end, 'BGN_NPCOpenDoors')

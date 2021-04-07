local function OpenDoor(actor, door)
	if not door.bgNPCOpenDoor and not hook.Run('BGN_PreOpenDoor', actor, door) then
		actor:PlayStaticSequence('Open_door_away')

		door.bgNPCOpenDoor = true
		
		door:Fire("unlock", "", 0)
		door:Fire("open", "", 0)
		
		hook.Run('BGN_PostOpenDoor', actor, door)

		timer.Simple(10, function()
			if IsValid(door) and door.bgNPCOpenDoor and not hook.Run('BGN_PreCloseDoor', door) then
				door:Fire("close", "", 0)
				door.bgNPCOpenDoor = false

				hook.Run('BGN_PostCloseDoor', door)
			end
		end)
	end
end

hook.Add("BGN_ActorLookAtObject", "BGN_NPCDoorOpeningEvent", function(actor, ent, distance)
	if distance > 80 then return end
	local entities = ents.FindInSphere(ent:GetPos(), 150)
	for i = 1, #entities do
		local door = entities[i]
		if not door:slibDoorIsLocked() then OpenDoor(actor, door) end
	end
end)
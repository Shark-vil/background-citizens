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

hook.Add("BGN_NPCLookAtObject", "BGN_NPCDoorOpeningEvent", function(actor, ent)
	local pos = ent:GetPos()
	if pos:DistToSqr(actor:GetNPC():GetPos()) > 10000 then return end -- 100 ^ 2

	local door_class = {
		"func_door",
		"func_door_rotating",
		"prop_door_rotating",
		-- "func_movelinear",
		-- "prop_dynamic",
	}

	for _, door in ipairs(ents.FindInSphere(pos, 150)) do
		if table.HasValue(door_class, door:GetClass()) then
			OpenDoor(actor, door)
		end
	end
end)
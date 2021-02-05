hook.Add("BGN_NPCLookAtObject", "BGN_NPCDoorOpeningEvent", function(actor, door)
	if door:GetPos():DistToSqr(actor:GetNPC():GetPos()) > 10000 then return end -- 100 ^ 2

	local door_class = {
		"func_door",
		"func_door_rotating",
		"prop_door_rotating",
		-- "func_movelinear",
		-- "prop_dynamic",
	}

	if not table.HasValue(door_class, door:GetClass()) then return end
	-- if not tobool(string.find(door:GetModel(), '*door*')) then return end

	if not door.bgNPCOpenDoor and hook.Run('BGN_PreOpenDoor', actor, door) == nil then
		actor:PlayStaticSequence('Open_door_away')

		door.bgNPCOpenDoor = true
		
		door:Fire("unlock", "", 0)
		door:Fire("open", "", 0)
		
		hook.Run('BGN_PostOpenDoor', actor, door)

		timer.Simple(10, function()
			if IsValid(door) and door.bgNPCOpenDoor and 
				hook.Run('BGN_PreCloseDoor', door) == nil
			then
				door:Fire("close", "", 0)
				door.bgNPCOpenDoor = false

				hook.Run('BGN_PostCloseDoor', door)
			end
		end)
	end
end)
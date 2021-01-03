hook.Add("bgCitizens_NPCLookAtObject", "bgCitizensOpenDoorAction", function(actor, door)
    if door:GetPos():DistToSqr(actor:GetNPC():GetPos()) > 100 ^ 2 then return end

    local door_class = {
        "func_door",
        "func_door_rotating",
        "prop_door_rotating",
        -- "func_movelinear",
        -- "prop_dynamic",
    }

    if not table.HasValue(door_class, door:GetClass()) then return end
    -- if not tobool(string.find(door:GetModel(), '*door*')) then return end

    local npc = actor:GetNPC()

    if hook.Run('bgCitizens_PreOpenDoor', npc, door) == nil then
        actor:PlayStaticSequence('Open_door_away')

        door.bgCitizenOpenDoor = true
        
        door:Fire("unlock", "", 0)
        door:Fire("open", "", 0)
        
        hook.Run('bgCitizens_PostOpenDoor', npc, door)

        timer.Simple(10, function()
            if IsValid(door) and door.bgCitizenOpenDoor and 
                hook.Run('bgCitizens_PreCloseDoor', door) == nil
            then
                door:Fire("close", "", 0)
                door.bgCitizenOpenDoor = false

                hook.Run('bgCitizens_PostCloseDoor', door)
            end
        end)
    end
end)
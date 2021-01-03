timer.Create('bgCitizensTimerOpenDoorAction', 1, 0, function()
    for _, actor in pairs(bgCitizens:GetAll()) do
        local npc = actor:GetNPC()
        if IsValid(npc) then
            local door_class = {
				"func_door",
				"func_door_rotating",
				"prop_door_rotating",
				"func_movelinear",
				"prop_dynamic",
            }
            
            local tr = util.TraceLine({
                start = npc:EyePos(),
                endpos = npc:EyePos() + npc:EyeAngles():Forward() * 100,
                filter = function(ent) 
                    if table.HasValue(door_class, ent:GetClass()) then
                        return true
                    end
                end
            })

            local door = tr.Entity

            if tr.Hit and IsValid(door) and hook.Run('bgCitizens_PreOpenDoor', npc, door) == nil then
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
                    end
                end)
            end
        end
    end
end)
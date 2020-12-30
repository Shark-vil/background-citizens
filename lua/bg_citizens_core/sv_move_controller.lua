local movement_map = {}
local movement_ignore = {}

hook.Add('PostCleanupMap', 'bgCitizensUpdateMovementTable', function()
    movement_map = {}
    movement_ignore = {}
    bgCitizens.npcs = {}
    bgCitizens.fnpcs = {}
end)

local function getPositionsInRadius(npc)
    local npc_pos = npc:GetPos()
    local radius_positions = {}

    for _, v in pairs(bgCitizens.points) do
        if v.pos:Distance(npc_pos) <= 500 then
            if movement_ignore[npc] ~= nil then
                for _, data in pairs(movement_ignore[npc]) do
                    if data.resetTime > CurTime() and data.pos == v.pos then
                        goto skip
                    end
                end
            end

            table.insert(radius_positions, v)
        end

        ::skip::
    end

    return radius_positions
end

local function updateMovement(npc, positions)
    local v, key = table.Random(positions)

    npc:SetNWVector('bgCitizen_CurrentTargetPos', v.pos)

    movement_map[npc] = {
        pos = v.pos,
        index = key,
        resetTime = CurTime() + 10
    }

    return movement_map[npc]
end

local function nextMovement(npc, positions)
    if movement_map[npc] ~= nil then
        local map = movement_map[npc]
        local parents = bgCitizens.points[map.index].parents

        if #parents ~= 0 then
            local index = table.Random(parents)
            local pos = bgCitizens.points[index].pos
            local dist = movement_map[npc].pos:Distance(pos)

            if dist <= 500 and bgCitizens:NPCIsViewVector(npc, pos) then
                npc:SetNWVector('bgCitizen_CurrentTargetPos', pos)

                movement_map[npc] = {
                    pos = pos,
                    index = index,
                    resetTime = CurTime() + 10
                }

                return movement_map[npc]
            end
        end
    end
    return updateMovement(npc, positions)
end

timer.Create('bgCitizensMoveController', 0.3, 0, function()
    if #bgCitizens.npcs ~= 0 and #bgCitizens.points ~= 0 then
        for _, npc in pairs(bgCitizens.npcs) do
            if IsValid(npc) and npc:GetState() == 'walk' then

                if bgCitizens:IsFearNPC(npc) then
                    npc:bgCitizenTaskClear()

                    npc:bgCitizenStateUpdate('attacked', {
                        target = NULL,
                        delay = 0
                    })

                    goto skip
                end

                for _, enemy in pairs(ents.FindInSphere(npc:GetPos(), 600)) do
                    if IsValid(enemy) and enemy:IsNPC() then
                        if enemy:Disposition(npc) == D_HT then
                            if movement_map[npc] ~= nil then
                                movement_map[npc] = nil
                                npc:bgCitizenTaskClear()
                            end
                            goto skip
                        end
                    end
                end


                local map = movement_map[npc]
                local positions = getPositionsInRadius(npc)
                local data = npc:GetStateData()

                if hook.Run('bgCitizens_PreMovementNPC', npc, map) ~= nil then
                    goto skip
                end

                if #positions ~= 0 then
                    if map == nil then
                        map = updateMovement(npc, positions)

                        npc:SetSaveValue("m_vecLastPosition", map.pos)
                        if hook.Run('bgCitizens_SetScheduleNPC', npc, map) == nil then
                            npc:SetSchedule(data.schedule)
                            data.startWalkTime = CurTime()
                            data.startWalkPos = npc:GetPos()
                        end

                        movement_ignore[npc] = movement_ignore[npc] or {}
                        table.insert(movement_ignore[npc], {
                            pos = map.pos,
                            resetTime = CurTime() + 30
                        })
                    else
                        local getNewPos = false

                        if map.resetTime < CurTime() then
                            getNewPos = true
                        elseif table.HasValue(ents.FindInSphere(map.pos, 10), npc) then
                            getNewPos = true
                        end

                        if data.startWalkTime ~= nil and data.startWalkTime + 3 < CurTime() then
                            if npc:GetPos():Distance(data.startWalkPos) < 10 then
                                getNewPos = true
                            else
                                data.startWalkTime = nil
                            end
                        end

                        if getNewPos then
                            map = nextMovement(npc, positions)

                            npc:SetSaveValue("m_vecLastPosition", map.pos)
                            if hook.Run('bgCitizens_SetScheduleNPC', npc, map) == nil then
                                npc:SetSchedule(data.schedule)
                                data.startWalkTime = CurTime()
                                data.startWalkPos = npc:GetPos()
                            end

                            movement_ignore[npc] = movement_ignore[npc] or {}
                            table.insert(movement_ignore[npc], {
                                pos = map.pos,
                                resetTime = CurTime() + 30
                            })
                        end
                    end

                    hook.Run('bgCitizens_PostMovementNPC', npc, map)
                end

                ::skip::
            end
        end
    end
end)

timer.Create('bgCitizensOtherTask', 1, 0, function()
    for _, npc in pairs(bgCitizens.npcs) do
        if IsValid(npc) and npc:GetState() == 'walk' then
            local data = npc:GetStateData()
            if data.schedule == SCHED_FORCED_GO_RUN then
                if data.runReset < CurTime() then
                    npc.bgCitizenState.data = { 
                        schedule = SCHED_FORCED_GO,
                        runReset = 0
                    }
                end
            elseif math.random(0, 100) == 0 then
                npc.bgCitizenState.data = { 
                    schedule = SCHED_FORCED_GO_RUN,
                    runReset = CurTime() + 20
                }
            end

            local door_class = {
				"func_door",
				"func_door_rotating",
				"prop_door_rotating",
				"func_movelinear",
				"prop_dynamic",
            }
            
            local tr = util.TraceLine({
                start = npc:EyePos(),
                endpos = npc:EyePos() + npc:EyeAngles():Forward() * 150,
                filter = function(ent) 
                    if table.HasValue(door_class, ent:GetClass()) then
                        return true
                    end
                end
            })

            local door = tr.Entity

            if tr.Hit and IsValid(door) and hook.Run('bgCitizens_PreOpenDoorNPC', npc, door) == nil then
                door:Fire("unlock", "", 0)
                door:Fire("open", "", 0)
                
                hook.Run('bgCitizens_PostOpenDoorNPC', npc, door)
            end
        end
    end
end)

timer.Create('bgCitizensMoveResetIgnore', 1, 0, function()
    for npc, tbl in pairs(movement_ignore) do
        for i = #tbl, 1, -1 do
            if tbl[i].resetTime < CurTime() then
                table.remove(tbl, i)
            end
        end
    end
end)
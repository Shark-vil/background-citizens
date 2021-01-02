local movement_map = {}
local movement_ignore = {}

hook.Add('PostCleanupMap', 'bgCitizensCleanupNPCsMovementMaps', function()
    movement_map = {}
    movement_ignore = {}
end)

local function getPositionsInRadius(npc)
    local npc_pos = npc:GetPos()
    local radius_positions = {}

    for _, v in ipairs(bgCitizens.points) do
        if v.pos:DistToSqr(npc_pos) <= 500 ^ 2 then
            if movement_ignore[npc] ~= nil then
                for _, data in ipairs(movement_ignore[npc]) do
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

    movement_map[npc] = {
        pos = v.pos,
        index = key,
        resetTime = CurTime() + 6
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
            local dist = movement_map[npc].pos:DistToSqr(pos)

            if dist <= 500 ^ 2 and bgCitizens:NPCIsViewVector(npc, pos) then
                movement_map[npc] = {
                    pos = pos,
                    index = index,
                    resetTime = CurTime() + 6
                }

                return movement_map[npc]
            end
        end
    end
    return updateMovement(npc, positions)
end

timer.Create('bgCitizensMoveController', 0.3, 0, function()
    if #bgCitizens.points ~= 0 then
        for _, actor in ipairs(bgCitizens:GetAll()) do
            local npc = actor:GetNPC()
            if IsValid(npc) and actor:GetState() == 'walk' then
                local map = movement_map[npc]
                local positions = getPositionsInRadius(npc)
                local data = actor:GetStateData()

                if hook.Run('bgCitizens_PreStollNPC', npc, map) ~= nil then
                    goto skip
                end

                if #positions ~= 0 then
                    if map == nil then
                        map = updateMovement(npc, positions)

                        npc:SetSaveValue("m_vecLastPosition", map.pos)
                        npc:SetSchedule(data.schedule)
                        data.startWalkTime = CurTime()
                        data.startWalkPos = npc:GetPos()

                        movement_ignore[npc] = movement_ignore[npc] or {}
                        table.insert(movement_ignore[npc], {
                            pos = map.pos,
                            resetTime = CurTime() + 60
                        })
                    else
                        local getNewPos = false

                        if map.resetTime < CurTime() then
                            getNewPos = true
                        elseif table.HasValue(ents.FindInSphere(map.pos, 10), npc) then
                            getNewPos = true
                        end

                        if data.startWalkTime ~= nil and data.startWalkTime + 3 < CurTime() then
                            if npc:GetPos():DistToSqr(data.startWalkPos) < 10 ^ 2 then
                                getNewPos = true
                            else
                                data.startWalkTime = nil
                            end
                        end

                        if getNewPos then
                            map = nextMovement(npc, positions)

                            npc:SetSaveValue("m_vecLastPosition", map.pos)
                            npc:SetSchedule(data.schedule)
                            data.startWalkTime = CurTime()
                            data.startWalkPos = npc:GetPos()

                            movement_ignore[npc] = movement_ignore[npc] or {}
                            table.insert(movement_ignore[npc], {
                                pos = map.pos,
                                resetTime = CurTime() + 60
                            })
                        end
                    end

                    hook.Run('bgCitizens_PostStollNPC', npc, map)
                end

                ::skip::
            end
        end
    end
end)

timer.Create('bgCitizensSwitchStollMovementType', 1, 0, function()
    for _, actor in ipairs(bgCitizens:GetAll()) do
        local npc = actor:GetNPC()
        if IsValid(npc) and actor:GetState() == 'walk' then
            local data = actor:GetStateData()
            if data.schedule == SCHED_FORCED_GO_RUN then
                if data.runReset < CurTime() then
                    actor:UpdateStateData({ 
                        schedule = SCHED_FORCED_GO,
                        runReset = 0
                    })
                end
            elseif math.random(0, 100) == 0 then
                actor:UpdateStateData({ 
                    schedule = SCHED_FORCED_GO_RUN,
                    runReset = CurTime() + 20
                })
            end
        end
    end

    for npc, tbl in pairs(movement_ignore) do
        for i = #tbl, 1, -1 do
            if tbl[i].resetTime < CurTime() then
                table.remove(tbl, i)
            end
        end
    end
end)
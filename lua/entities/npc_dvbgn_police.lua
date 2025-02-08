local dvd = DecentVehicleDestination
if not dvd then return end
if SERVER then util.AddNetworkString('BGN_DvPoliceDebugDrawPath') end
AddCSLuaFile()
ENT.Base = 'npc_decentvehicle'
ENT.PrintName = dvd.Texts.npc_dvpolice
ENT.DV_Police = true
ENT.Model = {'models/player/police.mdl', 'models/player/police_fem.mdl',}
ENT.EnemyTarget = NULL
ENT.Preference = {
    DoTrace                             = true, -- Whether or not it does some traces
    GiveWay                             = true, -- Whether or not it gives way for vehicles with ELS
    GiveWayTime                         = 5, -- Time to reset the offset for giving way
    GobackDuration                      = 0.7, -- Duration of going back on stuck
    GobackTime                          = 10, -- Time to start going back on stuck
    LockVehicle                         = true, -- Whether or not it allows other players to get in
    LockVehicleDependsOnCVar            = false, -- Whether or not LockVehicle depends on CVar
    ShouldGoback                        = true, -- Whether or not it should go backward on stuck
    StopAtTL                            = true, -- Whether or not it stops at traffic lights with red sign
    StopEmergency                       = true,  -- Whether or not it stops on crash
    StopEmergencyDuration               = 5,     -- Duration of stopping on crash
    StopEmergencyDurationDependsOnCVar  = true,  -- Same as LockVehicle, but for StopEmergencyDuration
    StopInfrontofPerson                 = true,  -- Whether or not it stops when it sees something in front of it
    StopInfrontofPersonDependsOnCVar    = true,  -- Same as LockVehicle, but for StopInfrontofPerson
    TraceMaxBound                       = 64, -- Maximum hull size of trace: max = Vector(1, 1, 1) * this value, min = -max
    TraceMinLength                      = 200, -- Minimum trace length in hammer units
    WaitUntilNext                       = true, -- Whether or not it waits on WaitUntilNext
}

local _cvar_bgn_debug = GetConVar('bgn_debug')
local _util_TraceLine = util.TraceLine
local _IsValid = IsValid
local _ipairs = ipairs
local _table_insert = table.insert
local _table_remove = table.remove
local _table_Reverse = table.Reverse
local _table_HasValue = table.HasValue
local _ents_FindByClass = ents.FindByClass
local vector_0_0_10 = Vector(0, 0, 10)

-- list.Set('NPC', 'npc_dvbgn_police', {
--     Name = ENT.PrintName,
--     Class = 'npc_dvbgn_police',
--     Category = 'GreatZenkakuMan\'s NPCs',
-- })

if CLIENT then
    net.Receive('BGN_DvPoliceDebugDrawPath', function()
        local ent = net.ReadEntity()
        local waypoints = net.ReadTable()
        if _IsValid(ent) then ent.WaypointList = waypoints end
    end)

    hook.Add('PostDrawTranslucentRenderables', 'BGN_DvPoliceDebugDrawPath', function()
        if not _cvar_bgn_debug:GetBool() then return end
        for _, dv in _ipairs(_ents_FindByClass('npc_dvbgn_police')) do
            -- Отрисовка точек из WaypointList
            if _IsValid(dv) and dv.WaypointList then
                for index, waypoint in _ipairs(dv.WaypointList) do
                    if waypoint and waypoint.Target then
                        -- Отрисовка точки
                        render.SetColorMaterial()
                        if index == 1 then
                            render.DrawSphere(waypoint.Target, 10, 8, 8, Color(60, 255, 0))
                        else
                            render.DrawSphere(waypoint.Target, 10, 8, 8)
                        end
                    end
                end
            end

            -- Отрисовка пути (линии между точками)
            if _IsValid(dv) and dv.WaypointList and #dv.WaypointList > 1 then
                for i = 1, #dv.WaypointList - 1 do
                    local startPos = dv.WaypointList[i].Target
                    local endPos = dv.WaypointList[i + 1].Target
                    if startPos and endPos then
                        -- Отрисовка линии между точками пути
                        render.SetColorMaterial()
                        render.DrawLine(startPos, endPos)
                    end
                end
            end
        end
    end)
    return
end

local function Heuristic(a, b)
    return a:DistToSqr(b)
end

local function GetCustomNode(self, position, speed)
    return {
        Target = position,
        Neighbors = {},
        SpeedLimit = speed or self.MaxSpeed / 2
    }
end

local function IsVisibleTarget(self, pos)
    -- if self:GetPos():DistToSqr(pos) > 1000000 then return false end
    local trace = _util_TraceLine({
        start = self:LocalToWorld(self:OBBCenter()),
        endpos = pos + vector_0_0_10,
        filter = function(ent)
            if _IsValid(ent)
                and ent ~= self
                and ent ~= self.v
                and ent:GetClass() ~= 'prop_vehicle_prisoner_pod'
            then
                return true
            end
        end
    })
    if not trace.Hit then return false end
    if trace.Entity == self.EnemyTarget then return true end
    if trace.Entity:IsVehicle() and trace.Entity:GetDriver() == self.EnemyTarget then return true end
    return false
end

-- local function IsVisibleNode(self, startPos, endPos)
--     local trace = _util_TraceLine({
--         start = startPos,
--         endpos = endPos,
--         filter = function(ent)
--             if _IsValid(ent)
--                 and ent ~= self
--                 and ent ~= self.v
--                 and ent:GetClass() ~= 'prop_vehicle_prisoner_pod'
--             then
--                 return true
--             end
--         end
--     })
--     return not trace.Hit
-- end

local function FindPath(self, targetPos)
    if IsVisibleTarget(self, targetPos) then
        self.Waypoint = GetCustomNode(self, targetPos)
        -- self.WaypointList = {self.Waypoint}
        return
    end

    -- Получаем начальную и конечную точки
    local startWaypoint = dvd.GetNearestWaypoint(self:GetPos())
    local endWaypoint = dvd.GetNearestWaypoint(targetPos)
    -- local startCustomWaypoint = GetCustomNode(self, self:GetPos())
    -- _table_insert(startCustomWaypoint.Neighbors, startWaypoint)
    -- local endCustomWaypoint = GetCustomNode(self, targetPos)
    -- _table_insert(endCustomWaypoint.Neighbors, endWaypoint)
    -- Очередь с приоритетом для поиска
    local max_iteration = 500
    local current_iteration = 0
    local openSet = {}
    -- Множество для посещённых точек
    local closedSet = {}
    -- Стоимость пути до точки
    local gScore = {}
    -- Оценка пути с учётом эвристики
    local fScore = {}
    -- Режим следования по родительским точкам
    local cameFrom = {}
    -- Инициализируем начальную точку
    _table_insert(openSet, startWaypoint)
    gScore[startWaypoint] = 0
    fScore[startWaypoint] = Heuristic(startWaypoint.Target, endWaypoint.Target)
    while #openSet > 0 do
        -- Находим точку с наименьшей fScore в очереди
        local currentNode = nil
        local lowestF = math.huge
        for _, node in _ipairs(openSet) do
            if fScore[node] < lowestF then
                lowestF = fScore[node]
                currentNode = node
            end
        end

        current_iteration = current_iteration + 1

        -- Если мы достигли цели, восстанавливаем путь
        if current_iteration == max_iteration or currentNode == endWaypoint then
            local path = {}
            while cameFrom[currentNode] do
                _table_insert(path, 1, currentNode)
                currentNode = cameFrom[currentNode]
            end

            -- local newPath = {}
            -- local path_count = #path
            -- for index = 1, path_count do
            --     local node = path[index]
            --     local newNode = GetCustomNode(self, node.Target, node.SpeedLimit)
            --     local parentNodeIndex = index + 1
            --     if parentNodeIndex < path_count then
            --         newNode.Neighbors = {parentNodeIndex}
            --     end
            --     _table_insert(newPath, newNode)
            -- end

            local newIndex = 0
            local newPath = {}
            local path_count = #path
            for index = path_count, 1, -1 do
                newIndex = newIndex + 1
                local node = path[index]
                local newNode = GetCustomNode(self, node.Target, node.SpeedLimit)
                local parentNodeIndex = newIndex + 1
                if parentNodeIndex < path_count then
                    newNode.Neighbors = {parentNodeIndex}
                end
                newPath[newIndex] = newNode
            end
            -- local startCustomWaypoint = GetCustomNode(self, self:GetPos())
            -- _table_insert(startCustomWaypoint.Neighbors, #newPath)

            self.Waypoint = newPath[#newPath]
            -- self.Waypoint = startCustomWaypoint
            self.WaypointList = newPath
            return
        end

        -- Убираем текущую точку из openSet
        for i, node in _ipairs(openSet) do
            if node == currentNode then
                _table_remove(openSet, i)
                break
            end
        end

        -- Добавляем текущую точку в closedSet
        closedSet[currentNode] = true
        -- Проходим по соседям текущей точки
        for _, neighborID in _ipairs(currentNode.Neighbors) do
            local neighbor = dvd.Waypoints[neighborID]
            if closedSet[neighbor] then
                -- Пропускаем уже посещённые точки
                continue
            end

            -- Расчёт стоимости пути
            local tentativeGScore = gScore[currentNode] + currentNode.Target:DistToSqr(neighbor.Target)
            if not gScore[neighbor] or tentativeGScore < gScore[neighbor] then
                -- Если путь через текущую точку лучше, обновляем
                cameFrom[neighbor] = currentNode
                gScore[neighbor] = tentativeGScore
                fScore[neighbor] = gScore[neighbor] + Heuristic(neighbor.Target, endWaypoint.Target)
                -- Добавляем соседа в openSet, если его там ещё нет
                if not _table_HasValue(openSet, neighbor) then
                    _table_insert(openSet, neighbor)
                end
            end
        end

        -- Возможность переключения на другие 'полосы' или точки, не связанные через Neighbors
        -- Пробуем 'перескочить' на соседние точки, которые не связаны напрямую
        -- Пример: Если текущая точка и сосед не связаны напрямую, но их расстояние минимально, можно их соединить
        for _, possibleWaypoint in _ipairs(dvd.Waypoints) do
            -- Пропускаем себя и уже посещённые точки
            if possibleWaypoint == currentNode or closedSet[possibleWaypoint] then continue end
            -- Расстояние от текущей точки до возможной точки
            local tentativeGScore = gScore[currentNode] + currentNode.Target:DistToSqr(possibleWaypoint.Target)
            if tentativeGScore <= 360000 and (not gScore[possibleWaypoint] or tentativeGScore < gScore[possibleWaypoint]) then
                -- Если путь через возможную точку лучше, обновляем
                cameFrom[possibleWaypoint] = currentNode
                gScore[possibleWaypoint] = tentativeGScore
                fScore[possibleWaypoint] = gScore[possibleWaypoint] + Heuristic(possibleWaypoint.Target, endWaypoint.Target)
                -- Добавляем возможную точку в openSet
                if not _table_HasValue(openSet, possibleWaypoint) then
                    _table_insert(openSet, possibleWaypoint)
                end
            end
        end
    end

    -- Если пути нет, возвращаем пустой список
    self.WaypointList = {}
    return
end

function ENT:CarCollide(data)
    local hitEnt = data.HitEntity
    if not hitEnt:IsVehicle() then return end
    for _, dv in _ipairs(_ents_FindByClass('npc_dvbgn_police')) do
        if dv.v == hitEnt and dv.DV_Police then return end
    end

    local vehicle_provider = BGN_VEHICLE:GetVehicleProvider(self)
    if vehicle_provider then
        local driver = hitEnt:GetDriver()
        if _IsValid(driver) then
            local actor = vehicle_provider:GetDriver()
            if actor and actor:IsAlive() then
                actor:AddEnemy(driver)
                actor:SetState('defense')
            end
        end
    end
    -- local driver = hitEnt:GetDriver()
    -- if not _IsValid(driver) then return end
    -- local dv = self:GetDriver()
    -- if not _IsValid(dv) or dv:GetClass() ~= 'npc_dvbgn_police' then return end
    -- dv.EnemyTarget = driver
end

function ENT:GetCurrentMaxSpeed()
    if _IsValid(self.EnemyTarget) and self.EnemyTarget:Health() > 0 then
        local limit
        if self.Trace.Entity == self.EnemyTarget
        or self.EnemyTarget:IsVehicle()
        or (
            self.EnemyTarget:IsPlayer()
            and self.EnemyTarget:InVehicle()
            and (
                self.Trace.Entity == self.EnemyTarget:GetVehicle()
                or self.Trace.Entity == self.EnemyTarget:GetVehicle():GetParent()
            )
        )  then
            limit = self.MaxSpeed
        else
            if self.Prependicular >= .9 then
                self.TurnWaitDelay = CurTime() + 5
            end
            if self.TurnWaitDelay and self.TurnWaitDelay > CurTime() then
                limit = math.Clamp(self.MaxSpeed / 2, 500, 800)
            else
                limit = math.Clamp(self.MaxSpeed / 2, 500, 2500)
            end
        end
        if not limit then
            return self.BaseClass.GetCurrentMaxSpeed(self)
        end
        self.Waypoint.SpeedLimit = limit
        return limit
    else
        return self.BaseClass.GetCurrentMaxSpeed(self)
    end
end

function ENT:Think()
    local vehicle_provider = BGN_VEHICLE:GetVehicleProvider(self.v)
    if vehicle_provider then
        local actor = vehicle_provider:GetDriver()
        if actor and actor:IsAlive() then
            self.EnemyTarget = actor:GetNearEnemy()
        end
    end

    self.UpdateWaypointListDelay = self.UpdateWaypointListDelay or 0
    if _IsValid(self.EnemyTarget) and self.EnemyTarget:Health() > 0 then
        if not self.IsTargetExists then
            self.Preference.GiveWay = false
            self.Preference.StopAtTL = false
            self:SetELS(true)
            self:SetELSSound(true)
        end

        self.IsTargetExists = true

        if (not _IsValid(self.Trace.Entity) or not self.Trace.Entity:IsWorld())
        and (#self.WaypointList == 0
        or self.UpdateWaypointListDelay < CurTime()
        or self:GetPos():DistToSqr(self.EnemyTarget:GetPos()) <= 250000)
        then
            FindPath(self, self.EnemyTarget:GetPos())
            if _cvar_bgn_debug:GetBool() then 
                net.Start('BGN_DvPoliceDebugDrawPath')
                net.WriteEntity(self)
                net.WriteTable(self.WaypointList)
                net.Broadcast()
            end
            self.UpdateWaypointListDelay = CurTime() + 15
        end
    elseif self.IsTargetExists then
        self.IsTargetExists = false
        self.WaypointList = {}
        self.EnemyTarget = NULL
        self.Preference.GiveWay = true
        self.Preference.StopAtTL = true
        self:SetELS(false)
        self:SetELSSound(false)
    end
    return self.BaseClass.Think(self)
end
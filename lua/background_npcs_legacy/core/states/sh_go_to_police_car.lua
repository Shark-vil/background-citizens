local _CurTime = CurTime
local _IsValid = IsValid
local _ipairs = ipairs
local _ents_GetAll = ents.GetAll

bgNPC:SetStateAction('go_to_police_car', 'danger', {
    pre_start = function(actor, state, data)
        local near_car
        local last_dist
        local npc = actor:GetNPC()
        local npc_pos = npc:GetPos()
        -- local get_vehicle_provider

        for _, ent in _ipairs(_ents_GetAll()) do
            if _IsValid(ent) and ent:IsVehicle() then
                local vehicle_provider = BGN_VEHICLE:GetVehicleProvider(ent)
                if vehicle_provider and vehicle_provider.type == 'police' and not vehicle_provider:GetDriver() then
                    local dist = npc_pos:DistToSqr(ent:GetPos())
                    if vehicle_provider and (not last_dist or last_dist > dist) then
                        near_car = ent
                        last_dist = dist
                        -- get_vehicle_provider = vehicle_provider
                    end
                end
            end
        end

        if not near_car or not _IsValid(near_car) or last_dist > 1000000 then
            return true
        end

        local enemies = table.Copy(actor.enemies)
        actor:RemoveAllEnemies()
        actor.mechanics.enemies_controller = false
        -- get_vehicle_provider.is_go_to_police_car = true

        local enemy = npc:GetEnemy()
        if _IsValid(enemy) then
            npc:AddEntityRelationship(enemy, D_NU, 99)
        end

        return state, {
            car = near_car,
            enemies = enemies,
            -- vehicle_provider = get_vehicle_provider,
            timeout = _CurTime() + 20
        }
    end,
    update = function(actor, state, data)
        local npc = actor:GetNPC()
        local car = data.car
        if not actor:CheckMoveUpdate('state_go_to_police_cat', 2) then
            return
        end
        if not _IsValid(car) or data.timeout < _CurTime() then
            actor:SetState('defense')
        else
            actor:WalkToTarget(car, 'run')
            local dist = npc:GetPos():DistToSqr(car:GetPos())
            if dist <= 250000 then
                actor:EnterVehicle(car)
                actor:SetState('defense')
            end
        end
    end,
    stop = function(actor, state, data)
        actor.mechanics.enemies_controller = true
        -- if data.vehicle_provider then
        --     data.vehicle_provider.is_go_to_police_car = false
        -- end
        if data.enemies then
            for _, enemy in _ipairs(data.enemies) do
                actor:AddEnemy(enemy)
            end
        end
        actor:WalkToTarget(nil)
    end
})
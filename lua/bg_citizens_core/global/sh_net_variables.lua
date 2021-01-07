local entity_variables = {}
local variables = {}

if SERVER then
    -- Entity
    function bgCitizens:SetEntityVariable(ent, key, data, not_delay)
        not_delay = not_delay or false

        entity_variables[ent] = entity_variables[ent] or {}
        entity_variables[ent][key] = data
        
        ent.bgCitizenVisibility = true

        if not not_delay then
            ent.bgCitizenVisibilityDelay = CurTime() + 3
            timer.Simple(1.5, function()
                if not IsValid(ent) then return end
                net.InvokeAll('bg_citizens_add_entity_variable', ent, key, data)
            end)
        else
            ent.bgCitizenVisibilityDelay = CurTime() + 1.5
            net.InvokeAll('bg_citizens_add_entity_variable', ent, key, data)
        end
    end

    hook.Add('SetupPlayerVisibility', 'SetupPlayerVisiblyOnSetVariable', function(ent)
        if ent.bgCitizenVisibility then
            AddOriginToPVS(ent:GetPos())
            if ent.bgCitizenVisibilityDelay < CurTime() then
                ent.bgCitizenVisibility = false
            end
        end
    end)

    -- Global
    function bgCitizens:SetGlobalVariable(key, data)
        variables[key] = data
        net.InvokeAll('bg_citizens_add_global_variable', key, data)
    end
else
    -- Entity
    net.RegisterCallback('bg_citizens_add_entity_variable', function(ply, ent, key, data)
        if not IsValid(ent) then
            MsgN('[bgCitizens][Network] Error synchronizing entity variables. The data was sent too sooner or later.')
            return
        end

        entity_variables[ent] = entity_variables[ent] or {}
        entity_variables[ent][key] = data
    end)

    net.RegisterCallback('bg_citizens_remove_entity_variable', function(ply, ent, key)
        if not IsValid(ent) then
            MsgN('[bgCitizens][Network] Error synchronizing entity variables. The data was sent too sooner or later.')
            return
        end

        entity_variables[ent] = entity_variables[ent] or {}
        entity_variables[ent][key] = nil
    end)

    -- Global
    net.RegisterCallback('bg_citizens_add_global_variable', function(ply, key, data)
        variables[key] = data
    end)

    net.RegisterCallback('bg_citizens_remove_global_variable', function(ply, key)
        variables[key] = nil
    end)
end

-- Entity
function bgCitizens:RemoveEntityVariable(ent, key)
    entity_variables[ent] = entity_variables[ent] or {}
    entity_variables[ent][key] = nil
    if SERVER then
        net.InvokeAll('bg_citizens_remove_entity_variable', ent, key)
    end
end

function bgCitizens:GetEntityVariable(ent, key, default)
    entity_variables[ent] = entity_variables[ent] or {}
    return entity_variables[ent][key] or default
end

-- Global
function bgCitizens:RemoveGlobalVariable(key)
    variables[key] = nil
    if SERVER then
        net.InvokeAll('bg_citizens_remove_global_variable', key)
    end
end

function bgCitizens:GetGlobalVariable(ent, key, default)
    return variables[key] or default
end
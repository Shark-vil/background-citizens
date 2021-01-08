if net.Invoke ~= nil then return end

local storage = {}

net = net or {}

local function network_callback(len, ply)
    if CLIENT then
        ply = LocalPlayer()
    end

    local name = net.ReadString()

    if storage[name] ~= nil then
        local data = storage[name]

        if data.adminOnly then
            if ply:IsAdmin() or ply:IsSuperAdmin() then
                local vars = net.ReadType()
                data.execute(ply, unpack(vars))
            end
        else
            local vars = net.ReadType()
            data.execute(ply, unpack(vars))
        end

        if data.onRemove then
            net.RemoveCallback(name)
        end
    end
end

if SERVER then
    util.AddNetworkString('sv_qsystem_callback')
    util.AddNetworkString('cl_qsystem_callback')

    net.Receive('sv_qsystem_callback', network_callback)
else
    net.Receive('cl_qsystem_callback', network_callback)
end

net.Invoke = function(name, ply, ...)    
    if SERVER then
        net.Start('cl_qsystem_callback')
        net.WriteString(name)
        net.WriteType({ ... })
        net.Send(ply)
    else
        net.Start('sv_qsystem_callback')
        net.WriteString(name)
        net.WriteType({ ... })
        net.SendToServer()
    end
end

net.InvokeAll = function(name, ...)    
    if SERVER then
        net.Start('cl_qsystem_callback')
        net.WriteString(name)
        net.WriteType({ ... })
        net.Broadcast()
    end
end

net.RegisterCallback = function(name, func, onRemove, adminOnly)
    adminOnly = adminOnly or false
    onRemove = onRemove or false
    storage[name] = {
        adminOnly = adminOnly,
        execute = func,
        onRemove = onRemove
    }
end

net.RemoveCallback = function(name)
    storage[name] = nil
end
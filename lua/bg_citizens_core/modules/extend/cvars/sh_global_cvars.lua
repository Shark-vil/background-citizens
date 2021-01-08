bgNPC.GlobalCvars = bgNPC.GlobalCvars or {}

if SERVER then
    util.AddNetworkString('bgn_gcvars_register_from_client')
    util.AddNetworkString('bgn_gcvars_register_all_from_client')
    util.AddNetworkString('bgn_gcvars_change_from_server')

    net.Receive('bgn_gcvars_change_from_server', function(len, ply)
        if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end

        local cvar_name = net.ReadString()
        local value = net.ReadFloat()

        if bgNPC.GlobalCvars[cvar_name] ~= nil and tobool(GetConVar(cvar_name)) then
            RunConsoleCommand(cvar_name, value)
            bgNPC.GlobalCvars[cvar_name] = value
        end
    end)

    function bgNPC:RegisterGlobalCvar(cvar_name, default_value)
        if tobool(GetConVar(cvar_name)) and bgNPC.GlobalCvars[cvar_name] == nil then
            bgNPC.GlobalCvars[cvar_name] = default_value
        end
    end

    hook.Add("PlayerSpawn", "BGN_SyncPlayerGlobalConvars", function(ply)
        if ply.bgNPCGlobalConvarSync then return end
        
        timer.Simple(3, function()
            if not IsValid(ply) then
                MsgN('Failed to sync global cvars')
                return
            end

            net.Start('bgn_gcvars_register_all_from_client')
            net.WriteTable(bgNPC.GlobalCvars)
            net.Send(ply)
        end)

        ply.bgNPCGlobalConvarSync = true
    end)
else
    net.Receive('bgn_gcvars_register_all_from_client', function()
        bgNPC.GlobalCvars = net.ReadTable()
        for cvar_name, value in pairs(bgNPC.GlobalCvars) do
            if not tobool(GetConVar(cvar_name)) then
                CreateConVar(cvar_name, value, FCVAR_NONE)
    
                cvars.AddChangeCallback(cvar_name, function(convar_name, value_old, value_new)
                    bgNPC.GlobalCvars[cvar_name] = value_new
    
                    net.Start('bgn_gcvars_change_from_server')
                    net.WriteString(cvar_name)
                    net.WriteFloat(value_new)
                    net.SendToServer()
                end)
            end
        end
    end)
end
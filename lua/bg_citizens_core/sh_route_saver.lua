if SERVER then
    util.AddNetworkString('bgCitizensSaveRoute')
    util.AddNetworkString('bgCitizensLoadToolFromServer')
    util.AddNetworkString('bgCitizensUnloadToolFromServer')
    util.AddNetworkString('bgCitizensLoadToolFromClient')
    util.AddNetworkString('bgCitizensAddRouteVectorFromClient')
    util.AddNetworkString('bgCitizensRemoveRouteVectorFromClient')

    net.Receive('bgCitizensSaveRoute', function(len, ply)
        if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end

        local from_json = net.ReadBool()
    
        local wep = ply:GetWeapon('weapon_citizens_points')
    
        if IsValid(wep) and table.Count(wep.Points) ~= 0 then
            file.CreateDir('citizens_points')

            local save_table = {}

            for _, pos in pairs(wep.Points) do
                table.insert(save_table, {
                    pos = pos,
                    parents = {}
                })
            end

            for index, v in pairs(save_table) do
                for id, v2 in pairs(save_table) do
                    local pos = v.pos
                    local otherPos = v2.pos

                    if pos ~= otherPos and otherPos:Distance(pos) <= 500 then
                        if pos ~= otherPos and pos.z >= otherPos.z - 100 and pos.z <= otherPos.z + 100 then
                            local tr = util.TraceLine( {
                                start = pos + Vector(0, 0, 30),
                                endpos = otherPos,
                                filter = function(ent)
                                    if ent:IsWorld() then
                                        return true
                                    end
                                end
                            })
        
                            if not tr.Hit then
                                table.insert(save_table[index].parents, id)
                            end
                        end
                    end
                end
            end

            local json_string = util.TableToJSON(save_table)

            if from_json then
                file.Write('citizens_points/' .. game.GetMap() .. '.json', json_string)
            else
                file.Write('citizens_points/' .. game.GetMap() .. '.dat', util.Compress(json_string))
            end
        end
    end)

    net.Receive('bgCitizensUnloadToolFromServer', function(len, ply)
        if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end

        if ply:HasWeapon('weapon_citizens_points') then
            ply:StripWeapon('weapon_citizens_points')
        end
    end)

    net.Receive('bgCitizensLoadToolFromServer', function(len, ply)
        if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end

        ply:ConCommand('cl_citizens_load_route_from_client')
    
        local wep = ply:GetWeapon('weapon_citizens_points')
    
        if not IsValid(wep) then
            wep = ply:Give('weapon_citizens_points')
        end
    
        ply:SelectWeapon(wep)
    end)
else
    concommand.Add('cl_citizens_save_route', function(ply, cmd, args)
        if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end
        local from_json = false

        if args[1] == 'json' then
            from_json = true
        end

        net.Start('bgCitizensSaveRoute')
        net.WriteBool(from_json)
        net.SendToServer()
    end)
    
    concommand.Add('cl_citizens_load_tool', function(ply)
        if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end

        net.Start('bgCitizensLoadToolFromServer')
        net.SendToServer()
    end)

    concommand.Add('cl_citizens_unload_tool', function(ply)
        if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end

        net.Start('bgCitizensUnloadToolFromServer')
        net.SendToServer()
    end)

    net.Receive('bgCitizensAddRouteVectorFromClient', function()
        local wep = LocalPlayer():GetWeapon('weapon_citizens_points')
        if IsValid(wep) then
            table.insert(wep.Points, net.ReadVector())
            surface.PlaySound('common/wpn_select.wav')
        end
    end)

    net.Receive('bgCitizensRemoveRouteVectorFromClient', function()
        local wep = LocalPlayer():GetWeapon('weapon_citizens_points')
        if IsValid(wep) then
            local id = net.ReadInt(10)
            table.remove(wep.Points, id)
            surface.PlaySound('common/wpn_denyselect.wav')
        end
    end)
end
if SERVER then
    util.AddNetworkString('bgCitizensSaveRoute')
    util.AddNetworkString('bgCitizensLoadToolFromServer')
    util.AddNetworkString('bgCitizensUnloadToolFromServer')
    util.AddNetworkString('bgCitizensLoadToolFromClient')

    net.Receive('bgCitizensSaveRoute', function(len, ply)
        if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end

        local from_json = net.ReadBool()
        local compressed_lenght = net.ReadUInt(24)
        local compressed_data = net.ReadData(compressed_lenght)

        if from_json then
            file.Write('citizens_points/' .. game.GetMap() .. '.json', util.Decompress(compressed_data))
        else
            file.Write('citizens_points/' .. game.GetMap() .. '.dat', compressed_data)
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
    
        timer.Simple(1, function()
            local wep = ply:GetWeapon('weapon_citizens_points')
    
            if not IsValid(wep) then
                wep = ply:Give('weapon_citizens_points')
            end
        
            ply:SelectWeapon(wep)
        end)
    end)
else
    concommand.Add('cl_citizens_save_route', function(ply, cmd, args)
        if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end

        local wep = ply:GetWeapon('weapon_citizens_points')
        if IsValid(wep) then
            local from_json = false

            if args[1] == 'json' then
                from_json = true
            end

            local save_table = {}

            if table.Count(wep.Points) ~= 0 then
                for _, pos in ipairs(wep.Points) do
                    table.insert(save_table, {
                        pos = pos,
                        parents = {}
                    })
                end

                for index, v in ipairs(save_table) do
                    for id, v2 in ipairs(save_table) do
                        local pos = v.pos
                        local otherPos = v2.pos

                        if pos ~= otherPos and otherPos:DistToSqr(pos) <= 500 ^ 2 then
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
            end

            local compressed_data = util.Compress(util.TableToJSON(save_table))
            local compressed_lenght = string.len(compressed_data)

            net.Start('bgCitizensSaveRoute')
            net.WriteBool(from_json)
            net.WriteUInt(compressed_lenght, 24)
            net.WriteData(compressed_data, compressed_lenght)
            net.SendToServer()
        end
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
end
if SERVER then
    util.AddNetworkString('bgCitizensSaveRoute')
    util.AddNetworkString('bgCitizensRemoveRoute')
    util.AddNetworkString('bgCitizensLoadToolFromServer')
    util.AddNetworkString('bgCitizensUnloadToolFromServer')
    util.AddNetworkString('bgCitizensLoadToolFromClient')

    net.Receive('bgCitizensRemoveRoute', function(len, ply)
        if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end
        if not net.ReadBool() then return end

        local map_name = net.ReadString()
        local json_file = 'citizens_points/' .. map_name .. '.json'
        local dat_file = 'citizens_points/' .. map_name .. '.dat'

        if file.Exists(json_file, 'DATA') then
            file.Delete(json_file)
            MsgN('Remove route file - ' .. json_file)
        end

        if file.Exists(dat_file, 'DATA') then
            file.Delete(dat_file)
            MsgN('Remove route file - ' .. dat_file)
        end

        ply:ConCommand('cl_citizens_load_route')
    end)

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
    
        local wep = ply:GetWeapon('weapon_citizens_points')

        if not IsValid(wep) then
            wep = ply:Give('weapon_citizens_points')
        end
    
        ply:SelectWeapon(wep)
    end)
else
    concommand.Add('cl_citizens_remove_route', function (ply, cmd, args)
        if args[1] ~= nil and args[1] == 'yes' then
            local map_name = args[2] or game.GetMap()

            net.Start('bgCitizensRemoveRoute')
            net.WriteBool(true)
            net.WriteString(map_name)
            net.SendToServer()
        else
            MsgN('If you want to delete the mesh file, add as the first command argument - yes')
            MsgN('Example: cl_citizens_remove_route yes')
        end
    end, nil, 'Removes the mesh file from the server. The first argument is confirmation, the second argument is the name of the card. If there is no second argument, then the current map is used.')

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
    end, nil, 'Saves movement points (Only if the player has a tool weapon!)')
    
    local is_load_tool = false
    concommand.Add('cl_citizens_load_tool', function(ply)
        if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end
        is_load_tool = true
        ply:ConCommand('cl_citizens_load_route_from_client')
    end, nil, 'Gives the player a tool for editing movement points. LMB - put a point / delete a point / delete the last point, RMB - switch the editing mode, R - clear all points')

    hook.Add("bgCitizens_LoadingClientRoutes", 'bgCitizensLoadRoutesFromTool', function()
        if not is_load_tool then return end
        net.Start('bgCitizensLoadToolFromServer')
        net.SendToServer()
        is_load_tool = false
    end)

    concommand.Add('cl_citizens_unload_tool', function(ply)
        if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end

        net.Start('bgCitizensUnloadToolFromServer')
        net.SendToServer()
    end, nil, 'Removes the editing tool from the player')
end
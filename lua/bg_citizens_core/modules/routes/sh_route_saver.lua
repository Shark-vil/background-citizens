if SERVER then
    util.AddNetworkString('bgNPCSaveRoute')
    util.AddNetworkString('bgNPCRemoveRoute')
    util.AddNetworkString('bgNPCSyncNavmeshInfoFromPlayer')

    net.Receive('bgNPCRemoveRoute', function(len, ply)
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

    net.Receive('bgNPCSaveRoute', function(len, ply)
        if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end

        local from_json = net.ReadBool()
        local compressed_lenght = net.ReadUInt(24)
        local compressed_data = net.ReadData(compressed_lenght)
        local json_string = util.Decompress(compressed_data)

        if from_json then
            file.Write('citizens_points/' .. game.GetMap() .. '.json', json_string)
        else
            file.Write('citizens_points/' .. game.GetMap() .. '.dat', compressed_data)
        end

        bgNPC.points = util.JSONToTable(json_string)
    end)

    hook.Add("PlayerSpawn", "BGN_SyncPlayerNavmeshInfo", function(ply)
        if ply.bgNPCNavmeshInfoSync then return end
        
        timer.Simple(3, function()
            if not IsValid(ply) then
                MsgN('Failed to sync navmesh info')
                return
            end

            net.Start('bgNPCSyncNavmeshInfoFromPlayer')
            net.WriteBool(navmesh.IsLoaded())
            net.Send(ply)
        end)

        ply.bgNPCNavmeshInfoSync = true
    end)
else
    concommand.Add('cl_citizens_remove_route', function (ply, cmd, args)
        if args[1] ~= nil and args[1] == 'yes' then
            local map_name = args[2] or game.GetMap()

            net.Start('bgNPCRemoveRoute')
            net.WriteBool(true)
            net.WriteString(map_name)
            net.SendToServer()
        else
            MsgN('If you want to delete the mesh file, add as the first command argument - yes')
            MsgN('Example: cl_citizens_remove_route yes')
        end
    end, nil, 'Removes the mesh file from the server. The first argument is confirmation, the second argument is the name of the card. If there is no second argument, then the current map is used.')

    local navmesh_is_loaded = false
    net.Receive('bgNPCSyncNavmeshInfoFromPlayer', function()
        navmesh_is_loaded = net.ReadBool()
    end)

    concommand.Add('cl_citizens_save_route', function(ply, cmd, args)
        if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end

        local tool = LocalPlayer():GetTool()
        if tool == nil or not tool.IsBGNPointEditor then return end

        local from_json = false

        if args[1] == 'json' then
            from_json = true
        end

        local save_table = {}

        if table.Count(tool.Points) ~= 0 then
            for _, pos in ipairs(tool.Points) do
                table.insert(save_table, {
                    pos = pos,
                    parents = {}
                })
            end

            local z_limit = GetConVar('bgn_point_z_limit'):GetInt()
            local dist_limit = 250000
            if navmesh_is_loaded then
                dist_limit = GetConVar('bgn_ptp_distance_limit'):GetFloat() ^ 2
            end

            for index, v in ipairs(save_table) do
                local pos = v.pos
                for id, v2 in ipairs(save_table) do
                    local otherPos = v2.pos

                    if pos ~= otherPos and otherPos:DistToSqr(pos) <= dist_limit then
                        if pos.z >= otherPos.z - z_limit and pos.z <= otherPos.z + z_limit then
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

        net.Start('bgNPCSaveRoute')
        net.WriteBool(from_json)
        net.WriteUInt(compressed_lenght, 24)
        net.WriteData(compressed_data, compressed_lenght)
        net.SendToServer()
    end, nil, 'Saves movement points (Only if the player has a tool weapon!)')
end
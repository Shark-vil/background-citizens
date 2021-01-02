if SERVER then
    util.AddNetworkString('bgCitizensLoadRoute')
    util.AddNetworkString('bgCitizensLoadExistsRoutesFromClient')
    util.AddNetworkString('bgCitizensLoadRouteFromClient')

    bgCitizens.LoadRoutes = function()
        if file.Exists('citizens_points/' .. game.GetMap() .. '.dat', 'DATA') then
            local file_data = file.Read('citizens_points/' .. game.GetMap() .. '.dat', 'DATA')
            local load_table = util.JSONToTable(util.Decompress(file_data))

            bgCitizens.points = load_table
        elseif file.Exists('citizens_points/' .. game.GetMap() .. '.json', 'DATA') then
            bgCitizens.points = util.JSONToTable(file.Read('citizens_points/' .. game.GetMap() .. '.json', 'DATA'))
        else
            bgCitizens.points = {}
        end

        MsgN('Load citizens walk points - ' .. tostring(#bgCitizens.points))

        return bgCitizens.points
    end

    bgCitizens.SendRoutesFromClient = function(ply)
        local compressed_table = util.Compress(util.TableToJSON(bgCitizens.points))
        local compressed_lenght = string.len(compressed_table)

        net.Start('bgCitizensLoadRouteFromClient')
        net.WriteUInt(compressed_lenght, 24)
        net.WriteData(compressed_table, compressed_lenght)
        net.Send(ply)
    end

    net.Receive('bgCitizensLoadRoute', function(len, ply)
        if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end
        bgCitizens.LoadRoutes()
        bgCitizens.SendRoutesFromClient(ply)
    end)

    net.Receive('bgCitizensLoadExistsRoutesFromClient', function(len, ply)
        if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end
        bgCitizens.SendRoutesFromClient(ply)
    end)

    bgCitizens.LoadRoutes()
else
    concommand.Add('cl_citizens_load_route', function(ply)
        if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end

        net.Start('bgCitizensLoadRoute')
        net.SendToServer()
    end, nil, 'loads the displacement points. This is done automatically when the map is loaded, but if you want to update the points without rebooting, use this command.')

    concommand.Add('cl_citizens_load_route_from_client', function(ply)
        if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end

        net.Start('bgCitizensLoadExistsRoutesFromClient')
        net.SendToServer()
    end, nil, 'Technical command. Used to get an array of points from the server.')

    net.Receive('bgCitizensLoadRouteFromClient', function()
        local compressed_lenght = net.ReadUInt(24)
        local compressed_table = net.ReadData(compressed_lenght)
        local data_table = util.JSONToTable(util.Decompress(compressed_table))

        MsgN('Client routes is loading! (' .. table.Count(data_table) .. ')')

        bgCitizens.points = data_table

        hook.Run('bgCitizens_LoadingClientRoutes', bgCitizens.points)
    end)
end
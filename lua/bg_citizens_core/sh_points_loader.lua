if SERVER then
    util.AddNetworkString('bgCitizensLoadRoute')

    local function loadRoutes()
        if file.Exists('citizens_points/' .. game.GetMap() .. '.dat', 'DATA') then
            local file_data = file.Read('citizens_points/' .. game.GetMap() .. '.dat', 'DATA')
            local load_table = util.JSONToTable(util.Decompress(file_data))

            bgCitizens.points = load_table
        elseif file.Exists('citizens_points/' .. game.GetMap() .. '.json', 'DATA') then
            bgCitizens.points = util.JSONToTable(file.Read('citizens_points/' .. game.GetMap() .. '.json', 'DATA'))
        end

        MsgN('Load citizens walk points - ' .. tostring(#bgCitizens.points))
    end

    net.Receive('bgCitizensLoadRoute', function(len, ply)
        if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end
        loadRoutes()
    end)

    loadRoutes()
else
    concommand.Add('cl_citizens_load_route', function(ply)
        if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end

        net.Start('bgCitizensLoadRoute')
        net.SendToServer()
    end)
end
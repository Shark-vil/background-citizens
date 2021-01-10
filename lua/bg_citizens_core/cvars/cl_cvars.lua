concommand.Add('bgn_reset_cvars_to_factory_settings', function(ply, cmd, args)
    if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end

    RunConsoleCommand('bgn_enable', bgNPC.cvar.bgn_enable)
    RunConsoleCommand('bgn_max_npc', bgNPC.cvar.bgn_max_npc)
    RunConsoleCommand('bgn_spawn_radius', bgNPC.cvar.bgn_spawn_radius)
    RunConsoleCommand('bgn_spawn_radius_visibility', bgNPC.cvar.bgn_spawn_radius_visibility)
    RunConsoleCommand('bgn_spawn_radius_raytracing', bgNPC.cvar.bgn_spawn_radius_raytracing)
    RunConsoleCommand('bgn_spawn_block_radius', bgNPC.cvar.bgn_spawn_block_radius)
    RunConsoleCommand('bgn_spawn_period', bgNPC.cvar.bgn_spawn_period)
    RunConsoleCommand('bgn_ptp_distance_limit', bgNPC.cvar.bgn_ptp_distance_limit)
    RunConsoleCommand('bgn_point_z_limit', bgNPC.cvar.bgn_point_z_limit)
    RunConsoleCommand('bgn_enable_wanted_mode', bgNPC.cvar.bgn_enable_wanted_mode)
    RunConsoleCommand('bgn_wanted_time', bgNPC.cvar.bgn_wanted_time)
    RunConsoleCommand('bgn_arrest_mode', bgNPC.cvar.bgn_arrest_mode)
    RunConsoleCommand('bgn_arrest_time', bgNPC.cvar.bgn_arrest_time)
    RunConsoleCommand('bgn_arrest_time_limit', bgNPC.cvar.bgn_arrest_time_limit)
    RunConsoleCommand('bgn_ignore_another_npc', bgNPC.cvar.bgn_ignore_another_npc)

    local exists_types = {}
    for npcType, v in pairs(bgNPC.npc_classes) do
        if not table.HasValue(exists_types, npcType) then
            RunConsoleCommand('bgn_npc_type_' .. npcType, 1)
            table.insert(exists_types, npcType)
        end
    end
end)
local CreateConVar = CreateConVar
local RunConsoleCommand = RunConsoleCommand
local pairs = pairs
local LocalPlayer = LocalPlayer
local cvars = cvars
local tonumber = tonumber
--

CreateConVar('bgn_cl_draw_npc_path', bgNPC.cvar.bgn_cl_draw_npc_path,
{ FCVAR_ARCHIVE }, 'Draw the path of movement of the NPC.')

CreateConVar('bgn_cl_field_view_optimization', bgNPC.cvar.bgn_cl_field_view_optimization,
{ FCVAR_ARCHIVE }, 'Enable field of view optimization.')

CreateConVar('bgn_cl_field_view_optimization_range', bgNPC.cvar.bgn_cl_field_view_optimization_range,
{ FCVAR_ARCHIVE }, 'The minimum distance in which the check is not performed.')

CreateConVar('bgn_cl_ambient_sound', bgNPC.cvar.bgn_cl_ambient_sound,
{ FCVAR_ARCHIVE }, 'Plays a crowd sound based on the number of actors around you. (WARNING! Not recommended for use on weak PC!)')

CreateConVar('bgn_tool_draw_distance', bgNPC.cvar.bgn_tool_draw_distance,
{ FCVAR_ARCHIVE }, 'Distance to draw points in edit mode.')

CreateConVar('bgn_tool_point_editor_autoparent', bgNPC.cvar.bgn_tool_point_editor_autoparent,
{ FCVAR_ARCHIVE }, 'Enable automatic creation of nodes links.')

CreateConVar('bgn_tool_point_editor_autoalignment', bgNPC.cvar.bgn_tool_point_editor_autoalignment,
{ FCVAR_ARCHIVE }, 'Enable automatic height alignment.')

CreateConVar('bgn_tool_point_editor_show_parents', bgNPC.cvar.bgn_tool_point_editor_show_parents,
{ FCVAR_ARCHIVE }, 'Show global connections.')

CreateConVar('bgn_tool_seat_offset_pos_x', bgNPC.cvar.bgn_tool_seat_offset_pos_x,
{ FCVAR_ARCHIVE }, '')

CreateConVar('bgn_tool_seat_offset_pos_y', bgNPC.cvar.bgn_tool_seat_offset_pos_y,
{ FCVAR_ARCHIVE }, '')

CreateConVar('bgn_tool_seat_offset_pos_z', bgNPC.cvar.bgn_tool_seat_offset_pos_z,
{ FCVAR_ARCHIVE }, '')

CreateConVar('bgn_tool_seat_offset_angle_x', bgNPC.cvar.bgn_tool_seat_offset_angle_x,
{ FCVAR_ARCHIVE }, '')

CreateConVar('bgn_tool_seat_offset_angle_y', bgNPC.cvar.bgn_tool_seat_offset_angle_y,
{ FCVAR_ARCHIVE }, '')

CreateConVar('bgn_tool_seat_offset_angle_z', bgNPC.cvar.bgn_tool_seat_offset_angle_z,
{ FCVAR_ARCHIVE }, '')

concommand.Add('bgn_reset_cvars_to_factory_settings', function(ply, cmd, args)
	if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end

	for cvar_name, cvar_value in pairs(bgNPC.cvar) do
		RunConsoleCommand(cvar_name, cvar_value)
	end

	for npcType, v in pairs(bgNPC.cfg.actors) do
		local enabled = 0
		if v.enabled then enabled = 1 end
		RunConsoleCommand('bgn_npc_type_' .. npcType, enabled)
	end

	for npcType, v in pairs(bgNPC.cfg.actors) do
		RunConsoleCommand('bgn_npc_type_max_' .. npcType, bgNPC:GetFullness(npcType))
	end
end)

local is_first_bgn_enable = false
cvars.AddChangeCallback('bgn_enable', function(cvar_name, old_value, new_value)
	if is_first_bgn_enable or tonumber(new_value) ~= 1 then return end
	is_first_bgn_enable = true

	LocalPlayer():slibNotify('The first launch of "Background NPCs" can cause lags. '
	.. 'Please wait until the end of the spawn.', NOTIFY_HINT, 10)
end)
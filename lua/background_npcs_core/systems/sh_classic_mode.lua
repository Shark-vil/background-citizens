--[[
	Admin command that forces the old-version setup: console "bgn_classic" or chat "!bgn_classic" (also "/bgn_classic").
	It sets the same preset as "Classic" in the mode window (ui/menu/cl_menu_welcome.lua reads bgNPC.ClassicPreset):
	NPC body, FSM brain, no ghost crowd, no scenic NPCs. Server part: the admin's server. Client part: only the caller.
	NPCs that are already on the map keep their body; new ones spawn the old way (reload the map for a clean start).
--]]

bgNPC.ClassicPreset = {
	server = { bgn_actor_body = 'npc', bgn_brain = 'fsm', bgn_ghost_crowd = '0', bgn_scenic = '0', bgn_settings_rev = '1' },
	client = { bgn_cl_ghost_crowd = '0', bgn_cl_voices = '2', bgn_cl_settings_rev = '1' },
}

bgNPC.Commands.Register('bgn_classic', {
	admin = true,
	help = 'Admin: sets Background NPCs up like the old versions (NPC body, FSM brain, no ghost crowd)',
	server = function()
		for name, value in pairs(bgNPC.ClassicPreset.server) do RunConsoleCommand(name, value) end
	end,
	client = function()
		RunConsoleCommand('bgn_mode', 'classic')
		RunConsoleCommand('bgn_mode_chosen', '1')
		for name, value in pairs(bgNPC.ClassicPreset.client) do RunConsoleCommand(name, value) end
		chat.AddText(Color(85, 180, 243), 'Background NPCs: ', Color(255, 255, 255), bgNPC.Phrases and bgNPC.Phrases['bgn.classic.applied'] or language.GetPhrase('bgn.classic.applied'))
	end,
})

if SERVER then
	hook.Add('PlayerSay', 'BGN_ClassicChatCommand', function(ply, text)
		local command = string.lower(string.Trim(text))
		if command ~= '!bgn_classic' and command ~= '/bgn_classic' and command ~= '!bgnclassic' then return end
		if ply:IsAdmin() or ply:IsSuperAdmin() then ply:ConCommand('bgn_classic') end
		return ''
	end)
end

local name = slib.language({
	['default'] = 'Assault Helicopter (NOT WANTED MODE)',
	['russian'] = 'Штурмовой вертолет (БЕЗ РЕЖИМА РОЗЫСКА)'
})

bgNPC.cfg:SetActor('police_helicopter_nwm', {
	enabled = false,
	class = 'npc_apache_scp_sb',
	name = name,
	disable_states = true,
	respawn_delay = 15,
	limit = 1,
	team = { 'residents', 'police' },
	money = { 0, 500 },
	at_damage_range = 100, -- Obsolete (not in use)
	at_damage = { ['defense'] = 100 },
	at_protect_range = 100, -- Obsolete (not in use)
	at_protect = { ['defense'] = 100 },
	validator = function(self, npc_type)
		if not list.Get('NPC')[self.class] then
			return false
		end
	end,
})
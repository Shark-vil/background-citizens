local name = slib.language({
	['default'] = 'Assault Helicopter',
	['russian'] = 'Штурмовой вертолет'
})

bgNPC.cfg:SetActor('police_helicopter', {
	enabled = true,
	class = 'npc_apache_scp_sb',
	name = name,
	disable_states = true,
	respawn_delay = 15,
	limit = 1,
	wanted_level = 5,
	team = { 'residents', 'police' },
	money = { 0, 500 },
	at_damage_range = 100,
	at_damage = { ['defense'] = 100 },
	at_protect_range = 100,
	at_protect = { ['defense'] = 100 },
	validator = function(self, npc_type)
		if list.Get('NPC')[self.class] == nil then
			return false
		end
	end,
})
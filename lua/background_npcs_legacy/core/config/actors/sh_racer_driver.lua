local name = slib.language({
	['default'] = 'Racer driver',
	['russian'] = 'Уличный гонщик'
})

bgNPC.cfg:SetActor('racer_driver', {
	enabled = true,
	inherit = 'gangster',
	class = 'npc_citizen',
	name = name,
	weapons = { 'weapon_pistol' },
	getting_weapon_chance = 10,
	limit = 1,
	max_vehicle = 1,
	vehicle_speed = { ['calm'] = 25, ['danger'] = 40 },
	enter_to_exist_vehicle_chance = 100,
	vehicles = { 'sim_fphys_dukes' },
	validator = function(self, npc_type)
		if not GetConVar('bgn_enable_dv_support'):GetBool() or not DecentVehicleDestination then
			return false
		end
	end,
})
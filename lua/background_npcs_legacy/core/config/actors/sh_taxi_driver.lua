local name = slib.language({
	['default'] = 'Taxi driver',
	['russian'] = 'Таксист'
})

bgNPC.cfg:SetActor('taxi_driver', {
	enabled = true,
	inherit = 'citizen',
	class = 'npc_citizen',
	name = name,
	limit = 2,
	max_vehicle = 2,
	enter_to_exist_vehicle_chance = 100,
	vehicle_group = 'taxi',
	vehicles = { 'sim_fphys_dukes' },
	validator = function(self, npc_type)
		if not GetConVar('bgn_enable_dv_support'):GetBool() or not DecentVehicleDestination then
			return false
		end
	end,
})
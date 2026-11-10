-- Not only IsVehicle(): simfphys/LVS/Glide chassis are scripted entities, and a hit on them must reach the occupants too.
hook.Add('EntityTakeDamage', 'BGN_DVCarsDamageReaction', function(target, dmginfo)
	if dmginfo:GetDamage() <= 0 then return end
	local attacker = bgNPC.Combat.ResolveVehicleAttacker(dmginfo:GetAttacker())
	if not bgNPC.Combat.IsAttacker(attacker) then return end
	local cars = bgNPC.DVCars

	for i = 1, #cars do
		local vehicle_provider = cars[i]

		if vehicle_provider and vehicle_provider:GetVehicle() == target then
			-- Exiting removes actors from the provider's list.
			local passengers = {}
			for k, actor in ipairs(vehicle_provider:GetPassengers()) do passengers[k] = actor end

			for k = 1, #passengers do
				local actor = passengers[k]

				if actor and actor:IsAlive() and actor:HasTeam('police') then bgNPC.OffenderFromRamming(attacker) end

				if actor and actor:IsAlive() then
					-- a shot through the car hits the occupant in full; a crash only shakes them
					local damage = dmginfo:GetDamage()
					if dmginfo:IsDamageType(DMG_CRUSH) or dmginfo:IsDamageType(DMG_VEHICLE) then damage = damage / math.random(2, 10) end
					if actor:InVehicle() then
						actor:TakeVehicleDamage(damage, attacker, dmginfo:GetInflictor())
					else
						actor:GetNPC():TakeDamage(damage, attacker, dmginfo:GetInflictor())
					end
					if actor:IsAlive() and actor:HasTeam('police') then
						actor:ExitVehicle()
					elseif actor:IsAlive() and math.random(0, 100) <= 5 then
						actor:ExitVehicle()
					end
				end
			end
		end
	end
end)

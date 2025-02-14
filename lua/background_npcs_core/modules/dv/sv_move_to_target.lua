local _math_random = math.random
local _CurTime = CurTime
local _IsValid = IsValid
local _spread_vector = Vector(5 / 90, 5 / 90, 0)

timer.Create('BGN_DVCars_ExitAnVhicleIfLowerDistance', 0.5, 0, function()
	local cars = bgNPC.DVCars

	for i = 1, #cars do
		local vehicle_provider = cars[i]
		if not vehicle_provider then continue end

		local vehicle = vehicle_provider:GetVehicle()
		if not _IsValid(vehicle) then continue end

		local decentvehicle = vehicle_provider:GetVehicleAI()
		local driver = vehicle_provider:GetDriver()
		local vehiclePosition = vehicle:GetPos()
		local isNotDanger = true
		local passengers = vehicle_provider:GetPassengers()

		for k = 1, #passengers do
			local actor = passengers[k]

			if actor and actor:IsAlive() and actor:EqualStateGroup('danger') and not actor:HasState('fear') then
				local enemy = actor:GetNearEnemy()

				if _IsValid(enemy) then
					if enemy:IsPlayer() and enemy:InVehicle() and vehicle_provider.type == 'police' and _IsValid(decentvehicle) then
						local enemy_vehicle = enemy:GetVehicle()
						local parent_vehicle = enemy_vehicle:GetParent()
						if _IsValid(parent_vehicle) and parent_vehicle:IsVehicle() then
							enemy_vehicle = parent_vehicle
						end
						if _IsValid(enemy_vehicle) and enemy_vehicle:GetClass() ~= 'prop_vehicle_prisoner_pod' then
							decentvehicle.DVPolice_Target = enemy_vehicle
						end
					end

					local dist = enemy:GetPos():DistToSqr(vehiclePosition)

					-- if driver and driver.weapon and enemy:IsPlayer() and enemy:InVehicle() then
					if driver and driver.weapon and enemy:IsPlayer() then
						local isTrueDistance = dist <= 1000000

						if isTrueDistance then
							vehicle_provider.bulletFireDelay = vehicle_provider.bulletFireDelay or 0
							vehicle_provider.bulletIsFire = vehicle_provider.bulletIsFire or false

							if vehicle_provider.bulletFireDelay < _CurTime() then
								vehicle_provider.bulletIsFire = not vehicle_provider.bulletIsFire
							end

							if vehicle_provider.bulletIsFire and _IsValid(decentvehicle) then
								local limit = _math_random(3, 10)
								local delay = _math_random(0.2, 0.4)
								local shoot_vector = enemy:GetPos() - decentvehicle:GetPos()
								shoot_vector:Normalize()

								decentvehicle:slibCreateTimer('dv_fire_enemy', delay, limit, function()
									local bullet = {}
									bullet.Num = 1
									bullet.Src = decentvehicle:GetPos() + decentvehicle:GetForward() * 100 + decentvehicle:GetUp() * 50
									bullet.Damage = _math_random(4, 8)
									bullet.Force = 50
									bullet.Tracer = 1
									bullet.Spread = _spread_vector
									bullet.Dir = shoot_vector
									bullet.IgnoreEntity = vehicle
									decentvehicle:FireBullets(bullet)
									vehicle:EmitSound(
										'weapons/smg1/smg1_fire1.wav',
										75,
										_math_random(90, 110),
										1,
										CHAN_WEAPON
									)
								end)

								vehicle_provider.bulletIsFire = false
								vehicle_provider.bulletFireDelay = _CurTime() + limit + delay + 3
							end
						end
					elseif not actor:HasState({ 'fear', 'dyspnea_danger', 'run_from_danger' }) then
						local isTrueDistance = dist <= 640000
						local delay = vehicle_provider.actorsExitDelay or 0

						if delay < _CurTime() and (isTrueDistance or not driver) then
							actor:ExitVehicle()
							vehicle_provider.actorsExitDelay = _CurTime() + 0.5
						end
					end
				end

				isNotDanger = false
			end
		end

		if _IsValid(decentvehicle) then
			local els = decentvehicle:GetELS()
			if els and (not driver or isNotDanger) then
				decentvehicle:SetELS(false)
			elseif not els and driver and not isNotDanger and driver:HasTeam('police') then
				decentvehicle:SetELS(true)
			end
		end
	end
end)
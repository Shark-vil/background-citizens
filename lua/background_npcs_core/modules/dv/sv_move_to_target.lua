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
		local passengers = vehicle_provider:GetPassengers()

		if not decentvehicle or not driver or not vehiclePosition or not passengers then
			continue
		end

		for k = 1, #passengers do
			local actor = passengers[k]

			if actor and actor:IsAlive() and actor:EqualStateGroup('danger') and not actor:HasState('fear') then
				local enemy = actor:GetNearEnemy()

				if _IsValid(enemy) then
					local in_vehicle = false
					local enemy_vehicle
					if enemy:IsPlayer() then
						in_vehicle = enemy:InVehicle()
						if in_vehicle then
							enemy_vehicle = enemy:GetVehicle()
						end
					else
						local enemy_actor = bgNPC:GetActor(enemy)
						if enemy_actor then
							enemy_vehicle = enemy_actor:GetVehicle()
							in_vehicle = _IsValid(enemy_vehicle)
						end
					end

					local result_enemy

					if _IsValid(enemy_vehicle) and vehicle_provider.type == 'police' and _IsValid(decentvehicle) then
						local parent_vehicle = enemy_vehicle:GetParent()
						if _IsValid(parent_vehicle) and parent_vehicle:IsVehicle() then
							result_enemy = parent_vehicle
						elseif _IsValid(enemy_vehicle) and enemy_vehicle:GetClass() ~= 'prop_vehicle_prisoner_pod' then
							result_enemy = enemy_vehicle
						end
					end

					if not _IsValid(result_enemy) then
						result_enemy = enemy
					end

					enemy = result_enemy
					decentvehicle.DVPolice_Target = enemy

					if not _IsValid(enemy) then break end

					local dist = enemy:GetPos():DistToSqr(vehiclePosition)
					if driver and driver.weapon then
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
									local dv_veh = decentvehicle.v
									local is_static = false
									if _IsValid(dv_veh) then
										is_static = dv_veh:GetVelocity():Length() <= 10
									end

									local bullet = {}
									bullet.Num = 1
									bullet.Src = decentvehicle:GetPos() + decentvehicle:GetForward() * 100 + decentvehicle:GetUp() * (is_static and _math_random(-5, 5) or _math_random(-10, 40))
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
			end
		end

		if _IsValid(decentvehicle) then
			local els = decentvehicle:GetELS()
			local is_police = driver:HasTeam('police')
			if els and not driver or not is_police then
				decentvehicle:SetELS(false)
			elseif not els and driver and is_police and driver:EnemiesCount() > 0 then
				decentvehicle:SetELS(true)
			end
		end
	end
end)
timer.Create('BGN_DVCars_ExitAnVhicleIfLowerDistance', 0.5, 0, function()
	local cars = bgNPC.DVCars

	for i = 1, #cars do
		local vehicle_provider = cars[i]

		if vehicle_provider then
			local vehicle = vehicle_provider:GetVehicle()

			if IsValid(vehicle) then
					local decentvehicle = vehicle_provider:GetVehicleAI()
					local driver = vehicle_provider:GetDriver()
					local vehiclePosition = vehicle:GetPos()
					local isNotDanger = true
					local passengers = vehicle_provider:GetPassengers()

					for k = 1, #passengers do
						local actor = passengers[k]

						if actor and actor:IsAlive() and actor:EqualStateGroup('danger') and not actor:HasState('fear') then
							local enemy = actor:GetNearEnemy()

							if IsValid(enemy) then
								local dist = enemy:GetPos():DistToSqr(vehiclePosition)

								if driver and driver.weapon and enemy:IsPlayer() and enemy:InVehicle() then
									local isTrueDistance = dist <= 1000000

									if isTrueDistance then
										vehicle_provider.bulletFireDelay = vehicle_provider.bulletFireDelay or 0
										vehicle_provider.bulletIsFire = vehicle_provider.bulletIsFire or false

										if vehicle_provider.bulletFireDelay < CurTime() then
											vehicle_provider.bulletIsFire = not vehicle_provider.bulletIsFire
										end

										if vehicle_provider.bulletIsFire then
											local limit = math.random(3, 5)
											local delay = math.random(0.2, 0.4)
											local shoot_vector = enemy:GetPos() - decentvehicle:GetPos()
											shoot_vector:Normalize()

											decentvehicle:slibCreateTimer('dv_fire_enemy', delay, limit, function(decentvehicle)
												local bullet = {}
												bullet.Num = 1
												bullet.Src = decentvehicle:GetPos() + decentvehicle:GetForward() * 100 + decentvehicle:GetUp() * 50
												bullet.Damage = math.random(4, 8)
												bullet.Force = 50
												bullet.Tracer = 1
												bullet.Spread = Vector(5 / 90, 5 / 90, 0)
												bullet.Dir = shoot_vector
												bullet.IgnoreEntity = vehicle
												decentvehicle:FireBullets(bullet)
												vehicle:EmitSound('weapons/smg1/smg1_fire1.wav', 100, 100)
											end)

											vehicle_provider.bulletIsFire = false
											vehicle_provider.bulletFireDelay = CurTime() + limit + delay + 3
										end
									end
								elseif not actor:HasState({ 'fear', 'dyspnea_danger', 'run_from_danger' }) then
									local isTrueDistance = dist <= 640000
									local delay = vehicle_provider.actorsExitDelay or 0

									if delay < CurTime() and (isTrueDistance or not driver) then
										actor:ExitVehicle()
										vehicle_provider.actorsExitDelay = CurTime() + 0.5
									end
								end
							end

							isNotDanger = false
						end
					end

					if IsValid(decentvehicle) then
						local els = decentvehicle:GetELS()
						if els and (not driver or isNotDanger) then
							decentvehicle:SetELS(false)
						elseif not els and driver and not isNotDanger and driver:HasTeam('police') then
							decentvehicle:SetELS(true)
						end
					end
			end
		end
	end
end)
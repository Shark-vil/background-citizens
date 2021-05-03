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
               if actor and actor:IsAlive() and actor:InDangerState() and not actor:HasState('fear') then
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
                                 bullet.Src = decentvehicle:GetPos() + decentvehicle:GetForward() * 100
                                    + decentvehicle:GetUp() * 50
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
                     else
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
               if decentvehicle:GetELS() and (not driver or isNotDanger) then
                  decentvehicle:SetELS(false)
               elseif not decentvehicle:GetELS() and driver and driver:HasTeam('police') then
                  decentvehicle:SetELS(true)
               end
            end
         end
      end
   end
end)

timer.Create('BGN_DVCars_AlarmOtherActorsInRoad', 0.5, 0, function()
   local cars = bgNPC.DVCars 
   for i = 1, #cars do
      local vehicle_provider = cars[i]
      if vehicle_provider then
         local vehicle = vehicle_provider:GetVehicle()
         local decentvehicle = vehicle_provider:GetVehicleAI()
         if IsValid(vehicle) and IsValid(decentvehicle) then
            local on_signal = false
            local forward_pos = vehicle:GetPos() + decentvehicle:GetForward() * 150

            debugoverlay.Sphere(forward_pos, 100, 1, Color(0, 100, 150))

            for _, ent in ipairs(ents.FindInSphere(forward_pos, 100)) do
               if not ent:IsPlayer() and not ent:IsNPC() and not ent:IsNextBot() then goto skip end
   
               local AnotherActor = bgNPC:GetActor(ent)
               if AnotherActor then
                  if not AnotherActor:IsAlive() or AnotherActor:InVehicle() then
                     goto skip
                  end

                  if AnotherActor:InCalmlyState() and not AnotherActor:HasState('walk') then
                     AnotherActor:SetState('walk')
                  end
               end
   
               if not on_signal then on_signal = true end
   
               ::skip::
            end

            if decentvehicle:GetELS() ~= on_signal then
               decentvehicle:SetELS(on_signal)
            end
         end
      end
   end
end)
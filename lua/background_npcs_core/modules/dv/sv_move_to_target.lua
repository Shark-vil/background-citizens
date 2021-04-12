timer.Create('BGN_PoliceMoveToEnemy', 0.5, 0, function()
   local cars = bgNPC.DVCars 
   for i = 1, #cars do
      local vehicle = cars[i]
      if vehicle and IsValid(vehicle) and vehicle.bgn_passengers then
         local vehiclePosition = vehicle:GetPos()
         local isNotDanger = true

         for k = 1, #vehicle.bgn_passengers do
            local actor = vehicle.bgn_passengers[k]
            if actor and actor:IsAlive() and actor:InDangerState() then
               isNotDanger = false

               local decentvehicle = actor:GetVehicleAI()
               local enemy = actor:GetNearEnemy()

               if IsValid(decentvehicle) and IsValid(enemy) then
                  local delay = vehiclePosition.bgnExitDelay or 0
                  if delay < CurTime() and enemy:GetPos():DistToSqr(vehiclePosition) <= 1000000 then
                     actor:ExitVehicle()
                     vehiclePosition.bgnExitDelay = CurTime() + 1
                  else
                     if IsValid(decentvehicle) and not decentvehicle:GetELS() then
                        decentvehicle:SetELS(true)
                     end
                  end
                  actor:WalkToTarget(enemy)
               end
            end
         end

         local decentvehicle = vehicle.bgn_decentvehicle
         if IsValid(decentvehicle) and isNotDanger and decentvehicle:GetELS() then
            decentvehicle:SetELS(false)
         end
      end
   end
end)

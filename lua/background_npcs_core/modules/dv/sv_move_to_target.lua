timer.Create('BGN_PoliceMoveToEnemy', 0.5, 0, function()
   local cars = bgNPC.DVCars 
   for i = 1, #cars do
      local vehicle_provider = cars[i]
      if vehicle_provider then
         local vehicle = vehicle_provider:GetVehicle()
         if IsValid(vehicle) then
            local decentvehicle = vehicle_provider:GetVehicleAI()
            local vehiclePosition = vehicle:GetPos()
            local isNotDanger = true

            local passengers = vehicle_provider:GetPassengers()
            for k = 1, #passengers do
               local actor = passengers[k]
               if actor and actor:IsAlive() and actor:InDangerState() then
                  local enemy = actor:GetNearEnemy()
                  if IsValid(enemy) then
                     local delay = vehicle_provider.actorsExitDelay or 0
                     if delay < CurTime() and enemy:GetPos():DistToSqr(vehiclePosition) <= 640000 then
                        actor:ExitVehicle()
                        vehicle_provider.actorsExitDelay = CurTime() + 1
                     else
                        if IsValid(decentvehicle) and not decentvehicle:GetELS() then
                           decentvehicle:SetELS(true)
                        end
                     end
                     actor:WalkToTarget(enemy)
                  end

                  isNotDanger = false
               end
            end

            if IsValid(decentvehicle) and isNotDanger and decentvehicle:GetELS() then
               decentvehicle:SetELS(false)
            end
         end
      end
   end
end)

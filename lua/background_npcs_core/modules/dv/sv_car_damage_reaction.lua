hook.Add('EntityTakeDamage', 'BGN_DVCarsDamageReaction', function(target, dmginfo)
   if not target:IsVehicle() then return end

   local attacker = dmginfo:GetAttacker()
   if not attacker:IsPlayer() and not attacker:IsNPC() and not attacker:IsNextBot() then
      return
   end

   local cars = bgNPC.DVCars 
   for i = 1, #cars do
      local vehicle_provider = cars[i]
      if vehicle_provider and vehicle_provider:GetVehicle() == target then
         local passengers = vehicle_provider:GetPassengers()
         local vehiclePosition = vehicle_provider:GetVehicle():GetPos()

         for k = 1, #passengers do
            local actor = passengers[k]
            if actor and actor:IsAlive() then
               if math.random(0, 100) <= 5 then
                  actor:ExitVehicle()
               elseif actor:HasTeam('police') and attacker:GetPos():DistToSqr(vehiclePosition) <= 640000 then
                  actor:ExitVehicle()
               end
               
               local npc = actor:GetNPC()
               if IsValid(npc) then
                  npc:TakeDamage(dmginfo:GetDamage() / math.random(2, 10), attacker, dmginfo:GetInflictor())
                  -- hook.Run('BGN_TakeDamageFromNPC', attacker, npc)
               end
            end
         end

         break
      end
   end
end)
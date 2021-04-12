hook.Add('EntityTakeDamage', 'BGN_DVCarsDamageReaction', function(target, dmginfo)
   local attacker = dmginfo:GetAttacker()
   if not attacker:IsPlayer() and not attacker:IsNPC() and not attacker:IsNextBot() then
      return
   end

   local cars = bgNPC.DVCars 
   for i = 1, #cars do
      local vehicle = cars[i]
      if vehicle and vehicle.bgn_passengers and vehicle == target then
         for k = 1, #vehicle.bgn_passengers do
            local actor = vehicle.bgn_passengers[k]
            if actor and actor:IsAlive() then
               if not actor:HasTeam('police') and math.random(0, 100) < 70 then return end
               
               actor:ExitVehicle()
               actor:AddEnemy(attacker)
               actor:SetState(actor:GetReactionForDamage())
               if actor:HasState('fear') then actor:CallForHelp(attacker) end
            end
         end
         break
      end
   end
end)
local RAM_REACTION_CHANCE = 10 -- percent of rams by an actor-driven car that the police in the rammed car react to
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
      local police_inside = false
      for k, actor in ipairs(vehicle_provider:GetPassengers()) do
        passengers[k] = actor
        police_inside = police_inside or actor:HasTeam('police')
      end

      -- another actor's car rams a police car: the officers react only now and then, otherwise the hit is ignored
      local rammer = bgNPC.Actors.Get(attacker)
      if police_inside and rammer and rammer:InVehicle() and not bgNPC.Util.Chance(RAM_REACTION_CHANCE) and (dmginfo:IsDamageType(DMG_CRUSH) or dmginfo:IsDamageType(DMG_VEHICLE)) then return end
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

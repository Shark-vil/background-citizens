hook.Add('BGN_PreSetNPCState', 'BGN_DvVehicle_FindCarOnRadius', function(actor, state)
   if state ~= 'dv_vehicle_drive' or not actor:IsAlive() then return end
   if DecentVehicleDestination == nil or not GetConVar('bgn_enable_dv_support'):GetBool() then
      return true
   end

   local npc = actor:GetNPC() 
   local vehicle = NULL
   local entities = ents.FindInSphere(npc:GetPos(), 500)

   for _, ent in ipairs(entities) do
      if not IsValid(ent) then goto skip end
      if not ent:IsVehicle() then goto skip end

      local veh = ent
      local veh_owner = ent:GetOwner()
      if IsValid(veh_owner) and veh_owner:IsVehicle() then
         veh = veh_owner
      end

      if engine.ActiveGamemode() == 'darkrp' then
         if not veh:isKeysOwnable() then 
            goto skip
         elseif IsValid(veh:getDoorOwner()) then
            if actor:HasTeam('bandits') then
               if veh:isLocked() then goto skip end
            else
               goto skip
            end
         end
      end

      -- if simfphys and not simfphys.IsCar(ent) then goto skip end

      local owner = veh:slibGetVar('bgn_vehicle_owner', NULL)
      if not IsValid(owner) then
         vehicle = veh
         veh:slibSetVar('bgn_vehicle_owner', npc)
         break
      end

      ::skip::
   end

   if not IsValid(vehicle) then return { state = 'walk' } end

   actor:StateLock(true)

   return {
      state = state,
      data = {
         decentvehicle = NULL,
         vehicle = vehicle,
         sitDelay = CurTime() + 10,
         isSit = false,
         delay = 0,
         vehicle_last_pos = vehicle:GetPos(),
         vehicle_last_right = vehicle:GetRight()
      }
   }
end)

local function ExitActor(actor, vehicle, decentvehicle)
   if IsValid(decentvehicle) then
      decentvehicle:Remove()
   end

   if IsValid(vehicle) then
      vehicle:slibSetVar('bgn_vehicle_owner', NULL)
   end

   if actor ~= nil and actor:IsAlive() then
      local npc = actor:GetNPC()
      local data = actor:GetStateData()

      if data.isSit then
         local pos = data.vehicle_last_pos or npc:GetPos()
         local right = data.vehicle_last_right or npc:GetRight()
         
         if IsValid(vehicle) then
            pos = vehicle:GetPos()
            right = vehicle:GetRight()
         end

         npc:SetParent(nil)
         npc:SetPos(pos + (right * 100))
         npc:SetNoDraw(false)
         npc:PhysWake()
      end

      actor:StateLock(false)
      actor.eternal = false
      actor:SetState('walk')
   end
end

bgNPC:SetStateAction('dv_vehicle_drive', {
   update = function(actor)
      local npc = actor:GetNPC()
      local data = actor:GetStateData()
      local vehicle = data.vehicle
      
      if data.isSit then
         if not IsValid(vehicle) then
            ExitActor(actor, vehicle, data.decentvehicle)
         else
            data.vehicle_last_pos = vehicle:GetPos()
            data.vehicle_last_right = vehicle:GetRight()

            if IsValid(data.decentvehicle) and data.beep and data.beepDelay < CurTime() then
               data.decentvehicle:SetELS(false)
               data.beep = false
            end
            
            local forward_pos = data.vehicle_last_pos + vehicle:GetForward() * 40
            for _, AnotherActor in ipairs(bgNPC:GetAllByRadius(forward_pos, 200)) do
               if AnotherActor:HasState('dv_vehicle_drive') or not AnotherActor:IsAlive() then
                  goto skip
               end

               data.beepDelay = data.beepDelay or 0
               data.beep = data.beep or false

               if IsValid(data.decentvehicle) and not data.beep and data.beepDelay < CurTime() then
                  data.decentvehicle:SetELS(true)
                  data.beepDelay = CurTime() + math.random(0.5, 2)
                  data.beep = true
               end

               local data = AnotherActor:GetStateData()
               data.delayVehicleRetreat = data.delayVehicleRetreat or 0
               
               if data.delayVehicleRetreat < CurTime() then
                  AnotherActor:WalkToPos(data.vehicle_last_pos, 'run')
                  data.delayVehicleRetreat = CurTime() + 3
               end

               ::skip::
            end
         end
      else
         local is_valid_vehicle = IsValid(vehicle)

         if not is_valid_vehicle or data.sitDelay < CurTime() then
            ExitActor(actor, vehicle, data.decentvehicle)
            return
         end

         if data.delay < CurTime() then
            local veh_pos = vehicle:GetPos()
            data.sitpos = veh_pos + (vehicle:GetRight() * 100)

            local distance = npc:GetPos():Distance(veh_pos)
            
            if distance <= 150 then
               local decentvehicle = ents.Create('npc_decentvehicle')
               decentvehicle:SetPos(veh_pos)
               decentvehicle:Spawn()
               
               data.decentvehicle = decentvehicle
               data.isSit = true
               actor.eternal = true

               npc:SetPos(vehicle:GetPos())
               npc:SetParent(vehicle)
               npc:SetNoDraw(true)

               timer.Create('BGN_Actor' .. actor.uid .. 'ExitCar', math.random(30, 120), 1, function()
                  ExitActor(actor, vehicle, decentvehicle)
               end)

               return
            end

            actor:WalkToPos(data.sitpos)
            
            data.delay = CurTime() + 3
         end
      end
   end
})
hook.Add('BGN_PreSetNPCState', 'BGN_DvVehicle_FindCarOnRadius', function(actor, state)
   if state ~= 'dv_vehicle_drive' or not actor:IsAlive() then return end

   local npc = actor:GetNPC()

   if actor:GetState() == 'dv_vehicle_drive' then
      local curr_veh = actor:GetStateData().vehicle
      if IsValid(curr_veh) and curr_veh:slibGetVar('bgn_vehicle_owner', NULL) == npc then
         return true
      end
   end
   
   local vehicle = NULL
   local entities = ents.FindInSphere(npc:GetPos(), 500)

   for _, ent in ipairs(entities) do
      if not IsValid(ent) then goto skip end

      if ent:IsVehicle() or (simfphys and simfphys.IsCar(ent)) then
         local owner = ent:slibGetVar('bgn_vehicle_owner', NULL)
         if not IsValid(owner) then
            vehicle = ent
            ent:slibSetVar('bgn_vehicle_owner', npc)
            break
         end
      end

      ::skip::
   end

   if not IsValid(vehicle) then return { state = 'walk' } end

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
      local pos = data.vehicle_last_pos or npc:GetPos()
      local right = data.vehicle_last_right or npc:GetRight()
      
      if IsValid(vehicle) then
         pos = vehicle:GetPos()
         right = vehicle:GetRight()
      end

      npc:SetPos(pos + (right * 100))
      npc:SetParent(nil)
      npc:PhysWake()

      actor:Walk()

      actor.eternal = false
   end
end

timer.Create('BGN_DvVehicle_WalkToCar', 1, 0, function()
   for _, actor in ipairs(bgNPC:GetAllByState('dv_vehicle_drive')) do
		if not actor:IsAlive() then goto skip end

      local npc = actor:GetNPC()
      local data = actor:GetStateData()
      local vehicle = data.vehicle
      
      if data.isSit then
         if not IsValid(vehicle) then
            ExitActor(actor, vehicle, data.decentvehicle)
         else
            data.vehicle_last_pos = vehicle:GetPos()
            data.vehicle_last_right = vehicle:GetRight()
         end
      else
         local is_valid_vehicle = IsValid(vehicle)

         if not is_valid_vehicle or data.sitDelay < CurTime() then
            actor:RandomState()
            if is_valid_vehicle then
               vehicle:slibSetVar('bgn_vehicle_owner', NULL)
            end
            goto skip
         end

         if data.delay < CurTime() then
            local veh_pos = vehicle:GetPos()
            local distance = npc:GetPos():Distance(veh_pos)
            
            if distance <= 200 then
               local decentvehicle = ents.Create('npc_decentvehicle')
               decentvehicle:SetPos(veh_pos)
               decentvehicle:Spawn()
               
               data.decentvehicle = decentvehicle
               data.isSit = true
               actor.eternal = true

               npc:SetParent(vehicle)
               npc:SetPos(vehicle:GetPos())

               timer.Create('BGN_Actor' .. actor.uid .. 'ExitCar', 10, 1, function()
                  ExitActor(actor, vehicle, decentvehicle)
               end)

               goto skip
            end

            local move_pos = veh_pos
            if distance > 500 then
               actor:GetClosestPointToPosition(veh_pos)
            end

            npc:SetSaveValue("m_vecLastPosition", move_pos)
            npc:SetSchedule(SCHED_FORCED_GO)
            
            data.delay = CurTime() + 2
         end
      end

      ::skip::
   end
end)
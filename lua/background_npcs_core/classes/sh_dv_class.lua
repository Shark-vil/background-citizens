BGN_VEHICLE = {}

local uid = 0
function BGN_VEHICLE:Instance(vehicle, type, actor_type)
   if not DecentVehicleDestination then return nil end

   uid = uid + 1

   local obj = {}
   obj.uid = uid
   obj.vehicle = vehicle
   obj.type = type or 'residents'
   obj.actor_type = actor_type
   obj.ai = nil
   obj.passengers = {}
   obj.driver = nil

   if type == 'police' then
      obj.ai_class = 'npc_dvpolice'
      obj.ai_type = 'police'
   elseif type == 'taxi' then
      obj.ai_class = 'npc_dvtaxi'
      obj.ai_type = 'taxi'
   else
      obj.ai_class = 'npc_decentvehicle'
      obj.ai_type = 'default'
   end

   function obj:Initialize()
      if self.ai or IsValid(self.ai) then return end
      
      local decentvehicle = ents.Create(self.ai_class)
      decentvehicle:SetPos(vehicle:GetPos())
      decentvehicle.DontUseSpawnEffect = true
      decentvehicle.bgn_type = self.ai_type
      BGN_VEHICLE:OverridePoliceVehicle(decentvehicle)
      decentvehicle:Spawn()
      decentvehicle:Activate()

      self.ai = decentvehicle
   end

   function obj:GetDriver()
      if not self.driver or not self.driver:IsAlive() then return nil end
      return self.driver
   end

   function obj:SetDriver(actor)
      if actor == nil then
         if self.driver and IsValid(self.ai) then
            self:RemovePassenger(self.driver)
            self.ai:Remove()
         end
      else
         self.driver = actor
         self:AddPassenger(actor)
         if not self.ai then self:Initialize() end
      end
   end

   function obj:AddPassenger(actor)
      if array.HasValue(self.passengers, actor) then return false end

      if self:GetDriver() ~= actor then
         for index, ent in ipairs(vehicle:GetChildren()) do
            if ent:GetClass() == 'prop_vehicle_prisoner_pod' and not IsValid(ent:GetDriver()) then
               local passenger = ents.Create("npc_decentvehicle_passenger")
               passenger.Seat = ent
               passenger.SeatIndex = index
               passenger.v = vehicle
               passenger.actor = actor
               passenger:SetPos(vehicle:GetPos())
               passenger:Spawn()
               passenger:Activate()
               return true
            end
         end
         return false
      end

      table.insert(self.passengers, actor)
      return true
   end

   function obj:RemovePassenger(actor)
      table.RemoveByValue(self.passengers, actor)

      for _, ent in ipairs(ents.FindByClass('npc_decentvehicle_passenger')) do
         if ent.actor == actor then ent:Remove() end
      end
   end

   function obj:GetPassengers()
      self:PassengersRecalculate()
      return self.passengers
   end

   function obj:PassengersRecalculate()
      for i = #self.passengers, 1, -1 do
         local actor = self.passengers[i]
         if not actor or not actor:IsAlive() then
            table.remove(self.passengers, i)
         end
      end
   end

   function obj:GetVehicle()
      return self.vehicle
   end

   function obj:GetVehicleAI()
      return self.ai
   end

   function obj:IsValid()
      return self.vehicle and IsValid(self.vehicle)
   end

   function obj:IsValidAI()
      return self.ai and IsValid(self.ai)
   end

   function obj:IsDestroyed()
      return not self:IsValid()
   end

   function obj:Remove()
      local vehicle = self.vehicle
      local decentvehicle = self.ai

      self:PassengersRecalculate()

      for _, actor in ipairs(self.passengers) do
         actor:ExitVehicle()
      end

      if IsValid(vehicle) then vehicle:Remove() end
      if IsValid(decentvehicle) then decentvehicle:Remove() end
   end

   return obj
end

function BGN_VEHICLE:OverridePoliceVehicle(decentvehicle)
   if not decentvehicle.bgn_type or decentvehicle.bgn_type ~= 'police' then return end
   local dvd = DecentVehicleDestination
   local original_DVPolice_GenerateWaypoint = decentvehicle.DVPolice_GenerateWaypoint

   function decentvehicle:DVPolice_GenerateWaypoint(ent, turn)
      if not self or not IsValid(self) then return end

      if not ent:IsPlayer() then
         original_DVPolice_GenerateWaypoint(self, ent, turn)
         return
      end
      
      turn = turn or false
      assert(IsEntity(ent), string.format("Entity expected, got %s.", tostring(ent)))
      assert(isbool(turn), string.format("Bool expected, got %s.", tostring(turn)))
      
      local is_opposite, foundwp, wpside, back, neighbor = self:GetOppositeLine()
      local tg_nearest =  dvd.GetNearestWaypoint(ent:GetPos())
      if turn then -- if moving towards us
         if tg_nearest == foundwp then
            self.Waypoint = foundwp
         elseif tg_nearest == neighbor then
            self.Waypoint = neighbor
         else
            self.Waypoint = neighbor
         end
         
         debugoverlay.Sphere(self.Waypoint.Target, 50, 1, color_green, true)
      end
      
      if not table.HasValue(self.WaypointList,tg_nearest) then
         table.insert(self.WaypointList, tg_nearest)
         debugoverlay.Sphere(tg_nearest.Target, 30, 1, color_green, true)
      end
   
      timer.Simple(.2, function() -- idk why, but first it need to wait before get route
         if not self or not IsValid(self) then return end
         
         if self.Preference and not self.PreferencesSetUpped then
            self.Preference.StopAtTL = false -- don't stop at traffic light
            self.Preference.GiveWay = false -- don't give way
            self.Preference.StopEmergency = false -- don't stop after crash
            self.Preference.WaitUntilNext = false -- don't stop at specefid waypoints
   
            table.insert(dvd.DVPolice_WantedTable, self.DVPolice_LastTarget)
            self.PreferencesSetUpped = true
         end
         
         if not self:GetELS() then 
            self.DVPolice_Code = 1
            self:SetELS(true) -- set ELS on
   
            if self.v:GetClass() == "prop_vehicle_jeep"
            and VC and isfunction(VC.ELS_Lht_SetCode) then
               VC.ELS_Lht_SetCode(self.v, nil, nil, 1)
            end
         end
         
         if not self:GetELSSound() then
            self.DVPolice_Code = 1
            self:SetELSSound(true) -- and set ELS sound on
            if self.v:GetClass() == "prop_vehicle_jeep"
            and VC and isfunction(VC.ELS_Snd_SetCode) then
               VC.ELS_Snd_SetCode(self.v, nil, nil, 1)
            end
         end
         
         hook.Run("Decent Police: Chasing", self, ent)
      end)
   end

   local ChangeCode = dvd.CVars.Police.ChangeCode
   function decentvehicle:Think()
      if self.DVPolice_Target and self:TargetStopped() and self.Trace.Entity == self.DVPolice_Target then
         self.Waypoint = dvd.GetNearestWaypoint(self.DVPolice_Target:GetPos())
      end
      
      if not self.v.ELSCycleChanged then -- for VCMod
         self.v.ELSCycleChanged = true
         if self.v:GetClass() == "prop_vehicle_jeep" and VC
         and isfunction(self.v.VC_setELSLightsCycle)
         and isfunction(VC.ELS_Lht_SetCode)
         and isfunction(VC.ELS_Snd_SetCode) then
            VC.ELS_Lht_SetCode(self.v, nil, nil, 1)
            VC.ELS_Snd_SetCode(self.v, nil, nil, 1)
            self.DVPolice_Code = 1
            self:SetELS(false)
            self:SetELSSound(false)
          end
      end
      
      if not IsValid(self.DVPolice_Target) then -- if we don't have target
         if not self.Waypoint then
            self.WaypointList = {}
            self.NextWaypoint = nil
            self:FindFirstWaypoint()
         end
         
         if self:GetELS() then -- and ELS enabled
            self.WaypointList = {}
            self.NextWaypoint = nil
            self:FindFirstWaypoint()
            self:SetELS(false) -- then disable it
            self:SetELSSound(false) -- and it
            self.Preference.StopAtTL = true -- again be polite
            self.Preference.GiveWay = true -- very polite
            self.Preference.StopEmergency = true -- so damn polite stop after crash
            self.Preference.WaitUntilNext = true -- you so.fuckin.precios.when you. stop at specefid waypoints
            self.PreferencesSetUpped = false
            if self.v:GetClass() == "prop_vehicle_jeep" and VC
            and isfunction(self.v.VC_setELSLightsCycle)
            and isfunction(VC.ELS_Lht_SetCode)
            and isfunction(VC.ELS_Snd_SetCode) then
               VC.ELS_Lht_SetCode(self.v, nil, nil, 1)
               VC.ELS_Snd_SetCode(self.v, nil, nil, 1)
               self.DVPolice_Code = 1
               self:SetELS(false)
               self:SetELSSound(false)
               self.v.ELSCycleChanged = true
             end
            
            hook.Run("Decent Police: Calmed", self)
         end
      elseif not IsValid(self.DVPolice_Target) then -- "wh9t the g0in on wh3r3 is m9 t9rg3t" (if target not is valid)
         self.DVPolice_Target = nil -- "ak th3n n3v3r mind" (forgot it)
         self:FindFirstWaypoint()
         hook.Run("Decent Police: Reset Target", self)
      elseif self:GetPos():DistToSqr(self.DVPolice_Target:GetPos()) > 36000000 then -- If target too far
         self.DVPolice_LastTarget = self.DVPolice_Target -- don't chase anymore, but remember this guy
         hook.Run("Decent Police: Added wanted list", self, self.DVPolice_Target)
         local route = dvd.GetRouteVector(self.v:GetPos(), self.DVPolice_Target:GetPos(), self.Group)
   
         if route then
            self.WaypointList = route -- go to the last known pos
         else
            self:FindFirstWaypoint()
         end
         
         if self.v:GetClass() == "prop_vehicle_jeep"
         and VC and not self:TargetStopped()
         and isfunction(VC.ELS_Lht_SetCode)
         and isfunction(VC.ELS_Snd_SetCode) then
            VC.ELS_Lht_SetCode(self.v, nil, nil, 1) -- change code
            VC.ELS_Snd_SetCode(self.v, nil, nil, 1) -- change code
            self.DVPolice_Code = 1
         end
         
         self.DVPolice_Target = nil -- and clean up target
      else
         local tg_speed = math.Round(self.DVPolice_Target:GetVelocity():Length() * 0.09144, 0)
         if not self:TargetStopped() then
            self:DVPolice_GenerateWaypoint(self.DVPolice_Target, self:IsTargetInBack(self.DVPolice_Target))
         end
   
         timer.Simple(ChangeCode:GetInt(), function() -- if chasing for 2 mins
            if IsValid(self) and not self:TargetStopped() and
            (self.DVPolice_Target == self.DVPolice_LastTarget
            or not self.DVPolice_LastTarget and self.DVPolice_Target) then
               if self.v:GetClass() == "prop_vehicle_jeep" and VC
               and isfunction(VC.ELS_Lht_SetCode)
               and isfunction(VC.ELS_Snd_SetCode) then
                  VC.ELS_Lht_SetCode(self.v, nil, nil, 2) -- change code
                  VC.ELS_Snd_SetCode(self.v, nil, nil, 2) -- change code
                  self.DVPolice_Code = 2
               end
            end
         end)
      end
      
      return self.BaseClass.Think(self)
   end

   function decentvehicle:GetCurrentMaxSpeed()
      local limit = self.Waypoint.SpeedLimit

      if self.DVPolice_Target and IsValid(self.DVPolice_Target) then
         self.Waypoint.SpeedLimit = limit * 10
      end

      return self.BaseClass.GetCurrentMaxSpeed(self)
   end
end

function BGN_VEHICLE:AddToList(vehicle_provider)
   if not vehicle_provider then return -1 end
   
   for i = 1, #bgNPC.DVCars do
      local other_vehicle_provider = bgNPC.DVCars[i]
      if other_vehicle_provider:GetVehicle() == vehicle_provider:GetVehicle() then return -1 end
   end
   return table.insert(bgNPC.DVCars, vehicle_provider)
end

function BGN_VEHICLE:RemoveFromList(vehicle_provider)
   table.RemoveByValue(bgNPC.DVCars, vehicle_provider)
end

function BGN_VEHICLE:GetVehicleProvider(vehicle)
   for i = 1, #bgNPC.DVCars do
      local vehicle_provider = bgNPC.DVCars[i]
      if vehicle_provider:GetVehicle() == vehicle or vehicle_provider:GetVehicleAI() == vehicle then
         return vehicle_provider
      end
   end
   return nil
end

if SERVER and not BGN_VEHICLE_GARRYSMOD_METATABLE_OVERRIDE_SUCCESS then
   local vehiclemeta = FindMetaTable('Vehicle')
   local GetDriver = vehiclemeta.GetDriver

   function vehiclemeta:GetDriver(...)
      if self.BGN_DecentVehiclePassenger and IsValid(self.BGN_DecentVehiclePassenger) then
         return self.BGN_DecentVehiclePassenger
      end
      return GetDriver(self, ...)
   end

   BGN_VEHICLE_GARRYSMOD_METATABLE_OVERRIDE_SUCCESS = true
end
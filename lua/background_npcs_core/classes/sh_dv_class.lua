BGN_VEHICLE = {}

local uid = 0
function BGN_VEHICLE:Instance(vehicle, type, actor_type)
   if not DecentVehicleDestination then return nil end

   uid = uid + 1

   local obj = {}
   obj.uid = uid
   obj.vehicle = vehicle
   obj.type = type or 'default'
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
      -- BGN_VEHICLE:OverrideVehicleBase(decentvehicle)

      decentvehicle:Spawn()
      decentvehicle:Activate()

      self.ai = decentvehicle
   end

   function obj:GetDriver()
      if not self.driver or (self.driver and not self.driver:IsAlive()) then return nil end
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
      if table.IHasValue(self.passengers, actor) then return end
      table.insert(self.passengers, actor)
   end

   function obj:RemovePassenger(actor)
      table.RemoveByValue(self.passengers, actor)
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
      return self.vehicle and self.ai ~= vehicle
   end

   function obj:IsValidAI()
      return self.ai and self.ai ~= NULL
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

--[[
function BGN_VEHICLE:OverrideVehicleBase(decentvehicle)
   local dvd = DecentVehicleDestination
   local vehicle_base

   if decentvehicle.PrintName == dvd.Texts.npc_decentvehicle then
      vehicle_base = decentvehicle
   elseif decentvehicle.BaseClass and decentvehicle.BaseClass.PrintName == dvd.Texts.npc_decentvehicle then
      vehicle_base = decentvehicle.BaseClass
   end

   local original_Think = vehicle_base.Think
   if not original_Think then return end

   decentvehicle.bgn_tick_delay = 0
   decentvehicle.bgn_tick_sleep = false

   function vehicle_base:Think()
      local is_players_see = self:slibIsPlayersSee()
      if not is_players_see and self.bgn_tick_sleep and self.bgn_tick_delay > CurTime() then
         return
      end
      
      if not self:IsValidVehicle() then SafeRemoveEntity(self) return end

      if self:ShouldStop() then
         self:StopDriving()
         self:FindFirstWaypoint()
      elseif self:DriveToWaypoint() then
         hook.Run("Decent Vehicle: OnReachedWaypoint", self)
         if self.Waypoint.FuelStation then self:Refuel() end
         self:SetupNextWaypoint()
      elseif self:ShouldRefuel() then
         if ShouldGoToRefuel:GetBool() then
            self:FindRoute "FuelStation"
         else
            self:Refuel()
         end
      end

      if not is_players_see and self.bgn_tick_delay < CurTime() then
         self.bgn_tick_delay = CurTime() + 1
         self.bgn_tick_sleep = not self.bgn_tick_sleep
      end
   
      self:DoGiveWay()
      self:DoTrace()
      self:DoLights()
      self:NextThink(CurTime())
      self:SetDriverPosition()
      return true
   end
end
]]

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
         
         if not self.PreferencesSetUpped then
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
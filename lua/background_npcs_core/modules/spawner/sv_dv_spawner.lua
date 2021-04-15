local function GetNearPoints(center, radius)
   radius = radius ^ 2

   local dvd = DecentVehicleDestination
   local points = {}

   for i = 1, #dvd.Waypoints do
      local point = dvd.Waypoints[i]
      if point and point.Target:DistToSqr(center) <= radius then
         table.insert(points, point)
      end
   end

   return points
end

local function FindSpawnLocation(center)
   local spawn_radius = GetConVar('bgn_spawn_radius'):GetFloat()
   local points = GetNearPoints(center, spawn_radius)
   if #points == 0 then return nil end
   points = array.shuffle(points)

   local dvd = DecentVehicleDestination
   local radius_visibility = GetConVar('bgn_spawn_radius_visibility'):GetFloat() ^ 2
   local radius_raytracing = GetConVar('bgn_spawn_radius_raytracing'):GetFloat() ^ 2
   local block_radius = GetConVar('bgn_spawn_block_radius'):GetFloat() ^ 2
   local all_players = player.GetAll()
   local spawn_position = nil
   local spawn_angle = nil

   for i = 1, #points do
      local point = points[i]
      spawn_position = point.Target

      for k = 1, #all_players do
         local ply = all_players[k]
         local distance = spawn_position:DistToSqr(ply:GetPos())
               
         if distance <= block_radius then goto skip end
         if distance < radius_visibility and bgNPC:PlayerIsViewVector(ply, spawn_position) then
            if radius_raytracing == 0 then goto skip end

            local tr = util.TraceLine({
               start = ply:EyePos(),
               endpos = spawn_position,
               filter = function(ent)
                  if IsValid(ent) and ent ~= ply 
                     and not ent:IsVehicle() and ent:IsWorld() 
                     and not string.StartWith(ent:GetClass(), 'prop_')
                  then
                     return true
                  end
               end
            })

            if not tr.Hit then goto skip end
         end
      end

      if spawn_position then
         local entities = ents.FindInSphere(spawn_position, 300)
         for _, ent in ipairs(entities) do
            if IsValid(ent) then
               if ent:IsVehicle() or ent:IsPlayer() or ent:IsNPC() 
                  or ent:IsNextBot() or ent:GetClass():StartWith('prop_')
               then
                  goto skip
               end
            end
         end

         if point.Neighbors and point.Neighbors[1] then
            local direction_point = dvd.Waypoints[point.Neighbors[1]]
            if direction_point then
               local vector_1 = spawn_position
               local vector_2 = direction_point.Target
               local vector_1_normalize = vector_1:GetNormalized()
               local vector_2_normalize = vector_2:GetNormalized()
               local dot = math.deg(math.acos(vector_1_normalize:Dot(vector_2_normalize)))

               if dot <= 1 then
                  spawn_angle = (vector_1 - vector_2):Angle()
               else
                  spawn_angle = (vector_1 + vector_2):Angle()
               end
            end
         end

         break
      end

      ::skip::

      spawn_position = nil
   end

   if not spawn_position then return end

   spawn_position = spawn_position + Vector(0, 50, 0)
   spawn_angle = spawn_angle or Angle(0, 0, 0)

   return { spawn_position, Angle(0, spawn_angle.y, 0) }
end

function bgNPC:CheckVehicleLimitFromActors(actor_type)
   local limit = GetConVar('bgn_npc_vehicle_max_' .. actor_type):GetInt()
   local count = 0
   for i = 1, #bgNPC.DVCars do
      local vehicle_provider = bgNPC.DVCars[i]
      if vehicle_provider.actor_type and vehicle_provider.actor_type == actor_type then
         count = count + 1
      end
   end
   return count < limit
end

function bgNPC:EnterActorInExistVehicle(actor, bypass)
   local actor_data = actor:GetData()
   local chance = actor_data.enter_to_exist_vehicle_chance

   if not bypass and chance and math.random(0, 100) > chance then return false end

   local all_players = player.GetAll()

   for i = 1, #bgNPC.DVCars do
      local vehicle_provider = bgNPC.DVCars[i]
      if vehicle_provider:IsValid() and vehicle_provider:IsValidAI() then

         local vehicle = vehicle_provider:GetVehicle()
         local driver = vehicle_provider:GetDriver()

         if not driver or not driver:HasTeam(vehicle_provider.type) then
            goto skip_vehicle
         end

         -- Поместить в расширение метатаблицы авто библиотеки slib
         local all_seats_are_taken = true
         for _, ent in ipairs(vehicle:GetChildren()) do
            if ent:GetClass() == 'prop_vehicle_prisoner_pod' and not IsValid(ent:GetDriver()) then
               all_seats_are_taken = false
               break
            end
         end

         if all_seats_are_taken then break end
         ---  -----------------------------------------------------

         local vehiclePosition = vehicle:GetPos()
         local isVisible = false

         for k = 1, #all_players do
            local ply = all_players[k]
            if IsValid(ply) and bgNPC:PlayerIsViewVector(ply, vehiclePosition) then
               isVisible = true
               break
            end
         end

         if not isVisible then
            actor:EnterVehicle(vehicle)
            return true
         end
      end

      ::skip_vehicle::
   end

   return false
end

function bgNPC:SpawnVehicleWithActor(actor, bypass)
   if not GetConVar('bgn_enable_dv_support'):GetBool() then return false end

   local dvd = DecentVehicleDestination
   if not dvd or not dvd.Waypoints or #dvd.Waypoints == 0 or player.GetCount() == 0 then return false end

   local actor_data = actor:GetData()

   local car_classes = actor_data.vehicles
   if not car_classes or not istable(car_classes) or #car_classes == 0 then return false end

   local actor_type = actor:GetType()
   if not bypass and not bgNPC:CheckVehicleLimitFromActors(actor_type) then return false end

   local ply = array.Random(player.GetAll())
   local data = FindSpawnLocation(ply:GetPos())

   if not data then return false end

   local npc = actor:GetNPC()
   local car_class = array.Random(car_classes)
   local spawn_pos = data[1] + Vector(0, 0, 50)
   local spawn_ang = data[2]
   local car

   local simfphys_list = list.Get('simfphys_vehicles')
   local vehicles_list = list.Get('Vehicles')

   if simfphys_list[car_class] then
      car = simfphys.SpawnVehicleSimple(car_class, spawn_pos, spawn_ang)
   elseif vehicles_list[car_class] then
      local vehicle_data = vehicles_list[car_class]
      local vehicle = ents.Create(vehicle_data.Class)
      vehicle:SetModel(vehicle_data.Model)
      if vehicle_data.KeyValues then
			for k, v in pairs(vehicle_data.KeyValues) do
				vehicle:SetKeyValue(k, v)
			end
		end
      vehicle.VehicleTable = vehicle_data
      vehicle:SetPos(spawn_pos)
      vehicle:SetAngles(spawn_ang)
      vehicle:Spawn()
      vehicle:Activate()
      car = vehicle
   else
      return false
   end

   local vehicle_provider = BGN_VEHICLE:Instance(car, actor_data.vehicle_group, actor_type)

   local index = BGN_VEHICLE:AddToList(vehicle_provider)
   if index == -1 then
      car:Remove()
      return false
   end
   
   car:slibCreateTimer('spawn_dv_ai', 1, 1, function(ent)
      if not IsValid(npc) then
         ent:Remove()
         return
      end

      npc:SetPos(ent:GetPos())
      actor:EnterVehicle(ent)
   end)

   return true
end
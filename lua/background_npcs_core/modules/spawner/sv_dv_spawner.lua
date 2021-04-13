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
   points = table.shuffle(points)

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
               spawn_angle = (spawn_position + direction_point.Target):Angle()
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

function bgNPC:SpawnVehicleWithActor(actor)
   if not GetConVar('bgn_enable_dv_support'):GetBool() then return false end

   local dvd = DecentVehicleDestination
   if not dvd or not dvd.Waypoints or #dvd.Waypoints == 0 or player.GetCount() == 0 then return false end

   local car_classes = actor:GetData().vehicles
   if not car_classes or not istable(car_classes) or #car_classes == 0 then return false end

   local actor_type = actor:GetType()
   if not bgNPC:CheckVehicleLimitFromActors(actor_type) then return false end

   local ply = table.Random(player.GetAll())
   local data = FindSpawnLocation(ply:GetPos())

   if not data then return false end

   local npc = actor:GetNPC()
   local car_class = table.Random(car_classes)
   local spawn_pos = data[1]
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

   local vehicle_provider
   if actor:HasTeam('police') then
      vehicle_provider = BGN_VEHICLE:Instance(car, 'police', actor_type)
   else
      vehicle_provider = BGN_VEHICLE:Instance(car, nil, actor_type)
   end

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
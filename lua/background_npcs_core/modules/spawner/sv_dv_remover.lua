hook.Add('PostCleanupMap', 'BGN_CleanDvCarsCache', function()
	table.Empty(bgNPC.DVCars)
end)

hook.Add('BGN_DvCarRemoved', 'BGN_DVCars_OnRemoved', function(ent)
   if ent.bgn_passengers and #ent.bgn_passengers ~= 0 then
      for _, actor in ipairs(ent.bgn_passengers) do
         if actor:IsAlive() then
            actor:GetNPC():Remove()
         end
      end
   end
end)

timer.Create('BGN_Timer_DVCars_Remover', 1, 0, function()
   local count = #bgNPC.DVCars

   if count == 0 then return end

   local bgn_spawn_radius = GetConVar('bgn_spawn_radius'):GetFloat() ^ 2
	local bgn_enable = GetConVar('bgn_enable'):GetBool()
   local dv_support_enable = GetConVar('bgn_enable_dv_support'):GetBool()

   for i = count, 1, -1 do
      local car = bgNPC.DVCars[i]

		if not IsValid(car) or not bgn_enable or not dv_support_enable or player.GetCount() == 0 then
         if car ~= NULL then
            hook.Run('BGN_DvCarRemoved', car)
            car:Remove()
         end

         table.remove(bgNPC.DVCars, i)
      else
         local isRemove = true
         local car_pos = car:GetPos()

         for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) then
               local ply_pos = ply:GetPos()
               local dist = car_pos:DistToSqr(ply_pos)
               if dist < bgn_spawn_radius or bgNPC:PlayerIsViewVector(ply, car_pos) then
                  isRemove = false
                  break
               end
            end
         end

         if isRemove then
            hook.Run('BGN_DvCarRemoved', car)
            car:Remove()

            table.remove(bgNPC.DVCars, i)
         end
      end
   end
end)
local is_active = GetConVar('bgn_cl_field_view_optimization'):GetBool()
local min_range = GetConVar('bgn_cl_field_view_optimization_range'):GetFloat() ^ 2

cvars.AddChangeCallback('bgn_cl_field_view_optimization', function(convar_name, value_old, value_new)
   local new_value = tobool(value_new)
   if is_active == new_value then return end

   is_active = new_value

   if not is_active then
      local entities = bgNPC:GetAllNPCs()
      for i = 1, #entities do
         local npc = entities[i]
         if IsValid(npc) and npc:Health() > 0 then
            npc:SetNoDraw(false)
         end
      end
   end
end)

cvars.AddChangeCallback('bgn_cl_field_view_optimization_range', function(convar_name, value_old, value_new)
   local new_value = tonumber(value_new) ^ 2
   if min_range == new_value then return end
   min_range = new_value
end)

local max_pass = 5
async.Add('bgn_client_render_optimization', function(yield)
   if not is_active then return end

   local ply = LocalPlayer()
   local actors = bgNPC:GetAll()
   local pass = 0

   yield()

   for i = 1, #actors do
      local actor = actors[i]
      if actor then
         local npc = actor:GetNPC()
         if IsValid(npc) then
            local pos = npc:GetPos()
            local weapon = npc:GetActiveWeapon()
            local in_vehicle = actor:InVehicle()

            if in_vehicle or (ply:GetPos():DistToSqr(pos) > min_range and not ply:slibIsViewVector(pos)) then
               npc:SetNoDraw(true)
               if IsValid(weapon) then weapon:SetNoDraw(true) end
               pass = pass + 1
            else
               npc:SetNoDraw(false)
               if IsValid(weapon) then weapon:SetNoDraw(false) end
               pass = pass + 1
            end

            if pass == max_pass then pass = 0; yield() end
         end
      end
   end

   return yield(true)
end)
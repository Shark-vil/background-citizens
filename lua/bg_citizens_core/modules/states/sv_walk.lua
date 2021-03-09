local ASSET = {}

local movement_map = {}
local movement_ignore = {}

local ignore_delay = 15
local movement_delay = 8

function ASSET:CreateMovementMap(npc, radius, ignore_checkers)
   radius = radius or 500

   local is_created = false
	local points = bgNPC:GetAllPointsInRadius(npc:GetPos(), radius)

   if not ignore_checkers then
      for _, v in ipairs(points) do
         if not self:HasIgnorePos(npc, v.pos) and bgNPC:NPCIsViewVector(npc, v.pos) then
            movement_map[npc] = {
               point = v,
               delay = CurTime() + movement_delay
            }

            self:AddIgnorePos(npc, v.pos)

            is_created = true
            return true
         end
      end
   end

   if not is_created then
      local v = table.Random(points)

      movement_map[npc] = {
         point = v,
         delay = CurTime() + movement_delay
      }

      self:AddIgnorePos(npc, v.pos)
      
      return true
   end

   return false
end

function ASSET:UpdateMovementMap(npc)
   local map = self:NextMovementPoint(npc)
   if map == nil then return false end

   self:AddIgnorePos(npc, map.point.pos)

   movement_map[npc] = map
   return true
end

function ASSET:NextMovementPoint(npc)
   local map = movement_map[npc]

   if map ~= nil then
      local parents = map.point.parents
      local count = #parents

      if count ~= 0 then
         local npc_pos = npc:GetPos()
         local point, dist

         for _, index in ipairs(parents) do
            local new_point = bgNPC.points[index]

            if bgNPC:NPCIsViewVector(npc, new_point.pos, 130) then
               local ents_count = 0

               for _, ent in ipairs(ents.FindInSphere(new_point.pos, 100)) do
                  local class = ent:GetClass()
                  if not ent:IsWorld() and (ent:IsNPC() or ent:IsPlayer() or class:StartWith('prop_')) then
                     ents_count = ents_count + 1
                  end

                  if ents_count >= 3 then return end
               end

               if point and npc_pos:DistToSqr(new_point.pos) > dist then
                  goto skip
               end

               point = new_point
               dist = npc_pos:DistToSqr(new_point.pos)

               if math.random(0, 10) <= 3 then
                  break
               end
            end

            ::skip::
         end

         if point then
            return {
               point = point,
               delay = CurTime() + movement_delay
            }
         end
      end
   end

   local points = bgNPC:GetAllPointsInRadius(npc:GetPos(), 500)
   if #points ~= 0 then
      return {
         point = table.Random(points),
         delay = CurTime() + movement_delay
      }
   end

   return nil
end

function ASSET:GetMovementMap(npc)
   return movement_map[npc]
end

function ASSET:MapIsExist(npc)
   return movement_map[npc] ~= nil
end

function ASSET:RemoveMovementMap(npc)
   movement_map[npc] = nil
end

function ASSET:AddIgnorePos(npc, pos)
   for _, v in ipairs(movement_ignore) do
      if v.npc == npc and v.pos == pos then return end
   end

   table.insert(movement_ignore, {
      npc = npc,
      pos = pos,
      delay = CurTime() + ignore_delay
   })
end

function ASSET:HasIgnorePos(npc, pos)
   for _, v in ipairs(movement_ignore) do
      if v.npc == npc and v.pos == pos then return true end
   end
   return false
end

function ASSET:ResetDelayedIgnorePoints()
   for i = #movement_ignore, 1, -1 do
      local v = movement_ignore[i]
      if v.delay < CurTime() then
         table.remove(movement_ignore, i)
      end
   end
end

timer.Create('BGN_Module_Timer_ResetDelayedIgnorePoints', 1, 0, function()
   ASSET:ResetDelayedIgnorePoints()
end)

list.Set('BGN_Modules', 'movement_service', ASSET)
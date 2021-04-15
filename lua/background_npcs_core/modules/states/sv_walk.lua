local ASSET = {}

local movement_map = {}
local movement_ignore = {}

local ignore_delay = 10
local movement_delay = 10

function ASSET:CreateMovementMap(npc, radius, ignore_checkers)
   radius = radius or 500

   local is_created = false
	local nodes = bgNPC:GetAllPointsInRadius(npc:GetPos(), radius)
   
   if #nodes == 0 then
      return false
   end

   if not ignore_checkers then
      for _, node in ipairs(nodes) do
         local pos = node.position
         if not self:HasIgnorePos(npc, pos) and bgNPC:NPCIsViewVector(npc, pos, 130) then
            movement_map[npc] = {
               node = node,
               delay = CurTime() + movement_delay
            }

            self:AddIgnorePos(npc, pos)

            is_created = true
            return true
         end
      end
   end

   if not is_created then
      local node = array.Random(nodes)

      movement_map[npc] = {
         point = node,
         delay = CurTime() + movement_delay
      }

      self:AddIgnorePos(npc, node.position)
      
      return true
   end

   return false
end

function ASSET:UpdateMovementMap(npc)
   local map = self:NextMovementPoint(npc)
   if map == nil then return false end

   self:AddIgnorePos(npc, map.node.position)

   movement_map[npc] = map
   return true
end

function ASSET:NextMovementPoint(npc)
   local map = movement_map[npc]

   if map ~= nil then
      local npc_pos = npc:GetPos()
      local node, dist

      for _, parentNode in ipairs(map.node.parents) do
         if bgNPC:NPCIsViewVector(npc, parentNode.position, 130) then
            local ents_count = 0

            for _, ent in ipairs(ents.FindInSphere(parentNode.position, 100)) do
               local class = ent:GetClass()
               if ent ~= npc and (ent:IsNPC() or ent:IsPlayer() or class:StartWith('prop_')) then
                  ents_count = ents_count + 1
               end

               if ents_count >= 3 then
                  return
               end
            end

            if node and npc_pos:DistToSqr(parentNode.position) > dist then
               goto skip
            end

            node = parentNode
            dist = npc_pos:DistToSqr(parentNode.position)

            if math.random(0, 10) <= 3 then
               break
            end
         end

         ::skip::
      end

      if node then
         return {
            node = node,
            delay = CurTime() + movement_delay
         }
      end
   end

   local nodes = bgNPC:GetAllPointsInRadius(npc:GetPos(), 500)
   if #nodes ~= 0 then
      return {
         node = array.Random(nodes),
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

function ASSET:ClearIgnorePoints(npc)
   for i = #movement_ignore, 1, -1 do
      local v = movement_ignore[i]
      if v.npc == npc then
         table.remove(movement_ignore, i)
      end
   end
end

function ASSET:RemoveLastIgnorePoints(npc, max)
   max = max or 1

   local current = 0
   for i = #movement_ignore, 1, -1 do
      local v = movement_ignore[i]
      if v.npc == npc then
         table.remove(movement_ignore, i)
         current = current + 1
         if current == max then
            return
         end
      end
   end
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
-- new walk state

local asset = bgNPC:GetModule('movement_service')

timer.Create('BGN_Timer_WalkController', 0.5, 0, function()
   if not bgNPC.PointsExist then return end
   
   for _, actor in ipairs(bgNPC:GetAllByState('walk')) do
      if not actor:IsAlive() then goto skip end

      local npc = actor:GetNPC()

      if not asset:MapIsExist(npc) then
         if not asset:CreateMovementMap(npc, 500) then
            bgNPC:Log('Critical error! Failed to create a movement map!', 'Walking')
         end
      else
         local map = asset:GetMovementMap(npc)

         if map.delay < CurTime() then
            if not asset:CreateMovementMap(npc, 500, true) then
               bgNPC:Log('Critical error! Failed to create a movement map!', 'Walking')
            end
            bgNPC:Log('NPC was unable to move in the right direction! Reset tables...', 'Walking')
         else
            actor:WalkToPos(map.point.pos)
         end
      end

      ::skip::
   end
end)

hook.Add('BGN_ActorFinishedWalk', 'BGN_WalkStateUpdatePoint', function(actor)
   if not bgNPC.PointsExist then return end
   if actor:GetState() ~= 'walk' then return end

   local npc = actor:GetNPC()

   bgNPC:Log('NPC has reached the desired point', 'Walking')

   if asset:MapIsExist(npc) then
      if not asset:UpdateMovementMap(npc) then
         if not asset:CreateMovementMap(npc, 500, true) then
            bgNPC:Log('Critical error! Failed to create a movement map!', 'Walking')
         end
         
         bgNPC:Log('Creating a new movement map', 'Walking')
         bgNPC:Log('Can\'t find the next move point! Reset tables...', 'Walking')
      end

      local map = asset:GetMovementMap(npc)
      actor:WalkToPos(map.point.pos)

      return true
   end
end)
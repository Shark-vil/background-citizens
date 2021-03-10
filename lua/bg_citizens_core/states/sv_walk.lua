-- new walk state

local asset = bgNPC:GetModule('movement_service')

bgNPC:SetStateAction('walk', function(actor)
   if not bgNPC.PointsExist then return end

   local npc = actor:GetNPC()
   local data = actor:GetStateData()
   data.schedule = data.schedule or 'walk'
   data.runReset = data.runReset or 0

   if data.schedule == 'run' then
      if data.runReset < CurTime() then
         actor:UpdateStateData({ 
            schedule = 'walk',
            runReset = 0
         })
      end
   elseif math.random(0, 100) == 0 then
      actor:UpdateStateData({ 
         schedule = 'run',
         runReset = CurTime() + 20
      })
   end

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
         actor:WalkToPos(map.point.pos, data.schedule)
      end
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
      if actor.walkPos ~= map.point.pos then
         local data = actor:GetStateData()
         data.schedule = data.schedule or 'walk'

         actor:WalkToPos(map.point.pos, data.schedule)
         actor:UpdateMovement()
      end

      return true
   end
end)
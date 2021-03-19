-- new walk state

local asset = bgNPC:GetModule('movement_service')

local function GetNextNode(actor)
   return table.Random(bgNPC:GetAllPointsInRadius(actor:GetNPC():GetPos(), 1500, 'walk'))
   -- return table.Random(BGN_NODE:GetMap())
end

hook.Add('BGN_PreOpenDoor', 'BGN_ChangePathIfDoorMaxActors', function(actor)
	if actor:GetState() ~= 'walk' then return end

	local entities = ents.FindInSphere(actor:GetNPC():GetPos(), 200)
   local max_entities = 2
   local current_index = 0
   for _, v in ipairs(entities) do
      if v:IsNPC() or v:IsPlayer() then
         current_index = current_index + 1
         if current_index > max_entities then
            actor:GetStateData().updatePoint = 0
            return
         end
      end
   end
end)

bgNPC:SetStateAction('walk', function(actor)
   if not bgNPC.PointsExist then return end

   local data = actor:GetStateData()
   data.schedule = data.schedule or 'walk'
   data.runReset = data.runReset or 0
   data.updatePoint = data.updatePoint or 0

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

   if data.updatePoint < CurTime() then
      local node = GetNextNode(actor)
      actor:WalkToPos(node.position, data.schedule, 'walk')
      data.updatePoint = CurTime() + math.random(10, 20)
   end
end)

hook.Add('BGN_ActorFinishedWalk', 'BGN_WalkStateUpdatePoint', function(actor)
   if not bgNPC.PointsExist then return end
   if actor:GetState() ~= 'walk' then return end

   bgNPC:Log('NPC has reached the desired point', 'Walking')

   local data = actor:GetStateData()
   local node = GetNextNode(actor)
   actor:WalkToPos(node.position, data.schedule, 'walk')
   data.updatePoint = CurTime() + math.random(10, 20)
end)
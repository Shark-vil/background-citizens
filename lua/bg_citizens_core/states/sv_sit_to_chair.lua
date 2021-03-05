local cahirs = {
   {
      models = {
         'models/props_c17/chair02a.mdl',
         'models/nseven/chair02a.mdl',
      },
      offsetPosition = function(npc, chair, default_offset)
         return default_offset + (chair:GetRight() * -5) + (chair:GetForward() * 2) - (chair:GetUp() * 8)
      end,
      offsetAngle = function(npc, chair, default_offset)
         return default_offset
      end,
   },
   {
      models = { 'models/props_c17/FurnitureChair001a.mdl' },
      offsetPosition = function(npc, chair, default_offset)
         return default_offset + (chair:GetForward() * -15) - (chair:GetUp() * 20)
      end,
      offsetAngle = function(npc, chair, default_offset)
         return default_offset
      end,
   },
   {
      models = {
         'models/props_trainstation/bench_indoor001a.mdl',
         'models/nseven/bench_indoor001a.mdl'
      },
      offsetPosition = function(npc, chair, default_offset)
         return default_offset + (chair:GetForward() * -17) - (chair:GetUp() * 20)
      end,
   },
   {
      models = {
         'models/props_trainstation/BenchOutdoor01a.mdl',
         'models/nseven/benchoutdoor01a.mdl'
      },
      offsetPosition = function(npc, chair, default_offset)
         return default_offset + (chair:GetForward() * -17) - (chair:GetUp() * 13)
      end,
   },
   {
      models = { 'models/props_wasteland/cafeteria_bench001a.mdl' },
      offsetPosition = function(npc, chair, default_offset)
         return default_offset + (chair:GetForward() * -17) - (chair:GetUp() * 5)
      end,
   },
   {
      models = {
         'models/props_wasteland/controlroom_chair001a.mdl',
         'models/nseven/controlroom_chair001a.mdl'
      },
      offsetPosition = function(npc, chair, default_offset)
         return default_offset + (chair:GetForward() * -10) - (chair:GetUp() * 18)
      end,
   },
   {
      models = {
         'models/props_interiors/Furniture_chair03a.mdl',
         'models/nseven/furniture_chair03a.mdl',
      },
      offsetPosition = function(npc, chair, default_offset)
         return default_offset + (chair:GetForward() * -13) - (chair:GetUp() * 15)
      end,
   },
   {
      models = { 'models/props_interiors/Furniture_chair01a.mdl' },
      offsetPosition = function(npc, chair, default_offset)
         return default_offset + (chair:GetForward() * -16) - (chair:GetUp() * 15)
      end,
   },
   {
      models = { 
         'models/props_interiors/Furniture_Couch01a.mdl',
         'models/props_interiors/Furniture_Couch02a.mdl',
      },
      offsetPosition = function(npc, chair, default_offset)
         return default_offset + (chair:GetForward() * -10) - (chair:GetUp() * 21)
      end,
   },
   {
      models = { 
         'models/props_c17/FurnitureCouch001a.mdl',
         'models/nseven/furniturecouch001a.mdl'
      },
      offsetPosition = function(npc, chair, default_offset)
         return default_offset + (chair:GetForward() * -10) - (chair:GetUp() * 15)
      end,
   },
   {
      models = { 
         'models/props_c17/FurnitureCouch002a.mdl',
         'models/nseven/furniturecouch002a.mdl'
      },
      offsetPosition = function(npc, chair, default_offset)
         return default_offset + (chair:GetForward() * -10) - (chair:GetUp() * 20)
      end,
   },
   {
      models = { 'models/props_c17/bench01a.mdl' },
      offsetPosition = function(npc, chair, default_offset)
         return default_offset + (chair:GetForward() * -12) - (chair:GetUp() * 17)
      end,
   },
   {
      models = { 'models/props_trainstation/traincar_seats001.mdl' },
      offsetPosition = function(npc, chair, default_offset)
         return default_offset + (chair:GetForward() * -12) + (chair:GetUp() * 2)
      end,
   },
   {
      models = { 
         'models/props_combine/breenchair.mdl',
         'models/nseven/breenchair.mdl' 
      },
      offsetPosition = function(npc, chair, default_offset)
         return default_offset + (chair:GetForward() * -12)
      end,
   },
}

hook.Add("BGN_PreSetNPCState", "BGN_SitToChairState", function(actor, state, data)
   if actor:HasState('sit_to_chair') and state ~= 'defense' and state ~= 'fear' then
      if actor:GetStateData().isStand then return end
      return true
   end

   if state ~= 'sit_to_chair' then return end
   
   local npc = actor:GetNPC()
   if not IsValid(npc) then return end

   local entities = ents.FindInSphere(npc:GetPos(), 500)
   local chair = NULL
   local cahirId = -1

   for _, ent in ipairs(entities) do
      if not IsValid(ent) then goto skip end
      if not ent:GetClass():StartWith('prop_') then goto skip end
      
      local ent_model = ent:GetModel()
      if ent_model == nil then goto skip end
      ent_model = ent_model:lower()

      for id, chair_data in ipairs(cahirs) do
         for _, model in ipairs(chair_data.models) do
            if model:lower() == ent_model and not ent.occupied then
               if ent.sitDelay == nil or ent.sitDelay < CurTime() then
                  local ang = ent:GetAngles()
                  if math.abs(ang.x) < 10 and math.abs(ang.z) < 10 then
                     chair = ent
                     cahirId = id
                     break
                  end
               end
            end
         end
      end

      ::skip::
   end
   
   if IsValid(chair) then
      chair.occupied = true
      return {
         state = state,
         data = {
            chair = chair,
            chairDataId = cahirId,
            delay = CurTime() + math.random(10, 30),
            isSit = false,
            isMove = false,
            isStand = false,
         }
      }
   else
      return { state = 'walk' }
   end
end)

timer.Create('BGN_Timer_SitToChairState', 0.5, 0, function()
   for _, actor in ipairs(bgNPC:GetAllByState('sit_to_chair')) do
      if actor:IsAlive() then
         local npc = actor:GetNPC()
         local data = actor:GetStateData()
         local chair = data.chair
         local chairData = cahirs[data.chairDataId]

         if not IsValid(chair) then
            actor:ResetSequence()

            npc:SetAngles(Angle(0, 0, 0))
            npc:SetCollisionGroup(COLLISION_GROUP_NONE)
            npc:PhysWake()

            data.isStand = true
            actor:SetState('walk')
         elseif not data.isSit and data.delay < CurTime() then
            data.isStand = true
            actor:SetState('walk')
            chair.occupied = false
         else
            local phys = chair:GetPhysicsObject()
            
            if not data.isMove then
               actor:WalkToPos(chair:GetPos() + (chair:GetForward() * 35))
               data.isMove = true
            end
            
            if not data.isSit and npc:GetPos():DistToSqr(chair:GetPos()) <= 3600 then  -- 60 ^ 2 
               data.isSit = true

               local sitTime = 5
               local new_pos = chair:GetPos() + (chair:GetForward() * 35)
               local new_angle = chair:GetAngles()

               if chairData.offsetPosition ~= nil then
                  new_pos = chairData.offsetPosition(npc, chair, new_pos)
               end

               if chairData.offsetAngle ~= nil then
                  new_angle = chairData.offsetAngle(npc, chair, new_angle)
               end

               npc:SetPos(new_pos)
               npc:SetAngles(new_angle)
               npc:SetParent(chair)
               -- npc:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
               if IsValid(phys) then
                  phys:EnableMotion(false)
               end
               
               actor:PlayStaticSequence('Idle_To_Sit_Chair', false, nil, function()
                  actor:PlayStaticSequence('Sit_Chair', true, sitTime, function()
                     actor:PlayStaticSequence('Sit_Chair_To_Idle', false, nil, function()
                        if not IsValid(npc) then return end
                        if data.isStandAnimation then return end
                        data.isStandAnimation = true
                        
                        if IsValid(chair) then
                           npc:SetAngles(Angle(0, chair:GetAngles().y, 0))
                        else
                           npc:SetAngles(Angle(0, 0, 0))
                        end

                        npc:SetParent(nil)
                        npc:SetPos(npc:GetPos() + npc:GetForward() * 10)
                        -- npc:SetCollisionGroup(COLLISION_GROUP_NONE)
                        npc:PhysWake()

                        data.isStand = true
                        actor:SetState('walk')
                        chair.sitDelay = CurTime() + 15
                        chair.occupied = false
                     end)
                  end)
               end)
            end
         end
      end
   end
end)
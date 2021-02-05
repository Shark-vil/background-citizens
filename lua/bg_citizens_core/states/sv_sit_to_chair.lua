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
}

hook.Add("BGN_PreSetNPCState", "BGN_SitToChairState", function(actor, state, data)
   if actor:HasState('sit_to_chair') and state ~= 'defense' and state ~= 'fear' then
      if actor:GetStateData().isStand then return end
      return false
   end

   if state ~= 'sit_to_chair' then return end
   
   local npc = actor:GetNPC()
   local entities = ents.FindInSphere(npc:GetPos(), 500)
   local chair = NULL
   local cahirId = -1

   for _, ent in ipairs(entities) do
      if IsValid(ent) then
         if ent:GetClass():StartWith('prop_') then
            local ent_model = ent:GetModel()
            for id, chair_data in ipairs(cahirs) do
               for _, model in ipairs(chair_data.models) do
                  if model:lower() == ent_model:lower() and not ent.occupied then
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
      end
   end
   
   if IsValid(chair) then
      chair.occupied = true
      return {
         state = state,
         data = {
            chair = chair,
            chairDataId = cahirId,
            delay = CurTime() + 10,
            isSit = false,
            isMove = false,
            isStand = false,
         }
      }
   else
      return false
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
            actor:Walk()
         elseif not data.isSit and data.delay < CurTime() then
            data.isStand = true
            actor:Walk()
            chair.occupied = false
         else
            local phys = chair:GetPhysicsObject()
            
            if not data.isMove then
               npc:SetSaveValue("m_vecLastPosition", chair:GetPos() + (chair:GetForward() * 35))
               npc:SetSchedule(SCHED_FORCED_GO)
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
               npc:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
               if IsValid(phys) then
                  phys:EnableMotion(false)
               end
               
               actor:PlayStaticSequence('Idle_To_Sit_Chair', false, nil, function()
                  actor:PlayStaticSequence('Sit_Chair', true, sitTime, function()
                     actor:PlayStaticSequence('Sit_Chair_To_Idle', false, nil, function()
                        if not IsValid(npc) then return end
                        
                        if IsValid(chair) then
                           npc:SetAngles(Angle(0, chair:GetAngles().y, 0))
                        else
                           npc:SetAngles(Angle(0, 0, 0))
                        end

                        npc:SetCollisionGroup(COLLISION_GROUP_NONE)
                        npc:PhysWake()
   
                        data.isStand = true
                        actor:Walk()
                        chair.occupied = false
                     end)
                  end)
               end)
            end
         end
      end
   end
end)
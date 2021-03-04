hook.Add('BGN_PreSetNPCState', 'BGN_ActorStealPlayerItems', function(actor, state)
   if state ~= 'steal' or not actor:IsAlive() then return end

   local npc = actor:GetNPC() 
   local npc_pos = npc:GetPos()
   local entities = ents.FindInSphere(npc_pos, 500)

   local dist = nil
   local target = NULL
   for _, ent in ipairs(entities) do
      if not IsValid(ent) or not ent:IsPlayer() then goto skip end

      local distToPlayer = npc_pos:DistToSqr(ent:GetPos())

      if dist == nil then
         dist = distToPlayer
         target = ent
      elseif distToPlayer < dist then
         dist = distToPlayer
         target = ent
      end

      ::skip::
   end

   if not IsValid(target) then return { state = 'walk' } end

   actor:AddTarget(target)

   return {
      data = {
         isSteal = false,
         stealDelay = 0,
         walkUpdate = 0,
         isPlayAnim = false,
         isWanted = false,
      }
   }
end)

timer.Create('BGN_ActorStealPlayerItems', 0.5, 0, function()
   for _, actor in ipairs(bgNPC:GetAllByState('steal')) do
		if not actor:IsAlive() then goto skip end

      local npc = actor:GetNPC()
      local data = actor:GetStateData()
      local target = actor:GetFirstTarget()
      
      if not IsValid(target) then
         actor:SetState('walk')
         goto skip
      end
      
      local npc_pos = npc:GetPos()
      local target_pos = target:GetPos()

      if bgNPC:PlayerIsViewVector(target, npc_pos, 80) then
         if data.isSteal then
            if not data.isWanted then
               data.isWanted = true

               actor:PlayStaticSequence('Crouch_To_Stand', false, nil, function()
                  actor:SetState('retreat')
                  MsgN('ПАЛЕВО АТМОСФЕРА НАКАЛЕНА')
               end)
            end
         else
            if not data.isPlayAnim then
               data.isPlayAnim = true
               actor:ClearSchedule()

               local id = tostring(math.random(1, 4))
               actor:PlayStaticSequence('LineIdle0'..id, true)
               MsgN('anim')
            end
         end
      else
         if data.isSteal then
            if not data.isPlayAnim and not data.isWanted then
               data.isPlayAnim = true

               actor:ClearSchedule()
               actor:PlayStaticSequence('Crouch_IdleD', true, 5, function()
                  actor:PlayStaticSequence('Crouch_To_Stand', false, nil, function()
                     data.isPlayAnim = false
                     actor:SetState('retreat')
                     MsgN('Художественный фильм - спиздили')
                  end)
               end)
            end
         else
            if data.isPlayAnim then
               data.isPlayAnim = false
               actor:ResetSequence()
               MsgN('stop anim')
            end

            if data.walkUpdate < CurTime() then
               actor:WalkToPos(target:GetPos())
               data.walkUpdate = CurTime() + 2
            end

            if npc_pos:Distance(target_pos) <= 100 then
               data.isSteal = true
            end
         end
      end

      ::skip::
   end
end)
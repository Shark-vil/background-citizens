hook.Add('BGN_Module_FirstAttackerValidator', 'BGN_StealTargetSet', function(attacker, target)
   if target:slibGetVar('is_stealer') then
      return target, attacker
   end
end)

hook.Add('BGN_StealFinish', 'BGN_DarkRp_StealMoney', function(actor, target, success)
   if not success then return end
   if engine.ActiveGamemode() ~= 'darkrp' then return end

   local moneyCount = target:getDarkRPVar("money")
   local moneySteal = math.random(10, 100)
   if moneyCount < moneySteal then moneySteal = moneyCount end

   target:addMoney(-moneySteal)

   local npc = actor:GetNPC()
   npc:slibSetVar('moneySteal', npc:slibGetVar('moneySteal', 0) + moneySteal)
end)

hook.Add('BGN_PreReactionTakeDamage', 'BGN_DarkRp_DropStealMoney', function(attacker, target)
   if engine.ActiveGamemode() ~= 'darkrp' then return end
   if not target:slibGetVar('is_stealer') then return end
   
   if attacker:IsNPC() then
      local actor = bgNPC:GetActor(attacker)
      if actor == nil or not actor:HasTeam('police') then return end
   elseif not attacker:IsPlayer() then return end

   local moneySteal = target:slibGetVar('moneySteal', 0)
   if moneySteal ~= 0 then
      DarkRP.createMoneyBag(target:GetPos() + target:GetUp() * 10 + target:GetForward() * 20, moneySteal)
      target:slibSetVar('moneySteal', 0)
   end
end)

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

bgNPC:SetStateAction('steal', function(actor)
   local polices = bgNPC:GetAllByTeam('police')

   local npc = actor:GetNPC()
   local data = actor:GetStateData()
   local target = actor:GetFirstTarget()
   
   if not IsValid(target) then
      actor:SetState('walk')
      return
   end
   
   local npc_pos = npc:GetPos()
   local target_pos = target:GetPos()

   if data.isSteal then
      for _, ActorPolice in ipairs(polices) do
         if ActorPolice:IsAlive() then
            local PoliceNPC = ActorPolice:GetNPC()
            if PoliceNPC:GetPos():DistToSqr(npc_pos) <= 490000 and bgNPC:NPCIsViewVector(PoliceNPC, npc_pos) 
               and bgNPC:IsTargetRay(PoliceNPC, npc) 
            then
               ActorPolice:AddEnemy(npc)
               ActorPolice:SetState('defense')
            end
         end
      end
      
      data.SoundDelay = data.SoundDelay or 0
      if data.SoundDelay < CurTime() then
         npc:EmitSound('background_npcs/bed_sheet_movement.mp3', 70, 100, 1, CHAN_AUTO)
         data.SoundDelay = CurTime() + 3
      end
   end

   if bgNPC:PlayerIsViewVector(target, npc_pos, 80) then
      if data.isSteal then
         if not data.isWanted then
            data.isWanted = true

            actor:PlayStaticSequence('Crouch_To_Stand', false, nil, function()
               hook.Run('BGN_StealFinish', actor, target, false)
               actor:SetState('retreat')
               actor:AddEnemy(target)
            end)
         end
      else
         if not data.isPlayAnim then
            data.isPlayAnim = true
            actor:ClearSchedule()

            local id = tostring(math.random(1, 4))
            actor:PlayStaticSequence('LineIdle0'..id, true)
         end
      end
   else
      if data.isSteal then
         if not data.isPlayAnim and not data.isWanted then
            data.isPlayAnim = true
            npc:slibSetVar('is_stealer', true)

            actor:ClearSchedule()
            actor:PlayStaticSequence('Crouch_IdleD', true, 5, function()
               actor:PlayStaticSequence('Crouch_To_Stand', false, nil, function()
                  data.isPlayAnim = false
                  hook.Run('BGN_StealFinish', actor, target, true)
                  actor:SetState('retreat')
               end)
            end)
         end
      else
         if data.isPlayAnim then
            data.isPlayAnim = false
            actor:ResetSequence()
         end

         if data.walkUpdate < CurTime() then
            actor:WalkToPos(target:GetPos())
            data.walkUpdate = CurTime() + 3
         end

         if npc_pos:Distance(target_pos) <= 100 then
            data.isSteal = true
         end
      end
   end
end)
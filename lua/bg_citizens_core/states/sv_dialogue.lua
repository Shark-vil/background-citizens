local asset = bgNPC:GetModule('actors_dialogue')

hook.Add("BGN_PreSetNPCState", "BGN_SetDialogueState", function(actor, state, data)
   if actor:HasState('dialogue') then
      if state ~= 'fear' and state ~= 'defense' then
         if asset:GetDialogue(actor) ~= nil then return true end
      else
         asset:RemoveBadValues()
         return
      end
   end

   if data ~= nil and data.isIgnore then return end
   if state ~= 'dialogue' then return end

   if GetConVar('bgn_disable_dialogues'):GetBool() then return { state = 'walk' } end
   
   local npc = actor:GetNPC()
   local actors = bgNPC:GetAllByRadius(npc:GetPos(), 500)
   local ActorTarget = table.Random(actors)
   
   if ActorTarget ~= actor and ActorTarget:IsAlive() then
      if not bgNPC:IsTargetRay(npc, ActorTarget:GetNPC()) then return true end
      if not asset:SetDialogue(actor, ActorTarget) then return true end
      ActorTarget:SetState('dialogue', { isIgnore = true })
   else
      return true
   end
end)

timer.Create('BGN_Timer_DialogueState', 0.5, 0, function()
   for _, actor in ipairs(bgNPC:GetAllByState('dialogue')) do
      local dialogue = asset:GetDialogue(actor)
      if dialogue ~= nil then
         asset:SwitchDialogue(actor)
         
         local actor1 = dialogue.interlocutors[1]
         local actor2 = dialogue.interlocutors[2]

         local npc1 = actor1:GetNPC()
         local npc2 = actor2:GetNPC()

         if IsValid(npc1) and IsValid(npc2) then
            if not dialogue.isIdle then
               actor1:WalkToPos(npc2:GetPos())
               actor2:WalkToPos(npc1:GetPos())
            else
               local npc1Angle = npc1:GetAngles()
               local npc2Angle = npc2:GetAngles()

               local npc1NewAngle = (npc2:GetPos() - npc1:GetPos()):Angle()
               local npc2NewAngle = (npc1:GetPos() - npc2:GetPos()):Angle()

               npc1:SetAngles(Angle(npc1Angle.x, npc1NewAngle.y, npc1Angle.z))
               npc2:SetAngles(Angle(npc2Angle.x, npc2NewAngle.y, npc2Angle.z))

               if actor1:IsSequenceFinished() then
                  npc1:SetNPCState(NPC_STATE_SCRIPT)
                  npc1:SetSchedule(SCHED_SLEEP)
               end

               if actor2:IsSequenceFinished() then
                  npc2:SetNPCState(NPC_STATE_SCRIPT)
                  npc2:SetSchedule(SCHED_SLEEP)
               end

               npc1:PhysWake()
               npc2:PhysWake()
            end
         end
      end
   end
end)
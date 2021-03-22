local WantedModule = bgNPC:GetModule('wanted')
local ArrestModule = bgNPC:GetModule('player_arrest')

hook.Add('BGN_PreCallForHelp', 'BGN_PlayerArrest', function(actor, enemy)
   if not ArrestModule:HasPlayer(enemy) then return end
   return ArrestModule:GetPlayer(enemy).arrested
end)

hook.Add('BGN_OnKilledActor', 'BGN_PlayerArrest', function(_, attacker)
   if not ArrestModule:HasPlayer(attacker) then return end
   local ArrestComponent = ArrestModule:GetPlayer(attacker)
   if not ArrestComponent.arrested then return end
   ArrestModule:NotSubjectToArrest(attacker)

   local actors = bgNPC:GetAllByRadius(attacker:GetPos(), 700)
   for _, actor in ipairs(actors) do
      if actor:IsAlive() then
         local npc = actor:GetNPC()
         if bgNPC:IsTargetRay(npc, attacker) then
            actor:SetEnemy(attacker)
            actor:SetState('fear')
         end
      end
   end
end)

hook.Add('BGN_PreDamageToAnotherActor', 'BGN_PlayerArrest', function(actor, attacker, target, reaction)
   if reaction ~= 'arrest' then return end
   if not GetConVar('bgn_arrest_mode'):GetBool() or target:IsPlayer() then
      actor:SetReaction('defense')
   end
end)

hook.Add('BGN_PreReactionTakeDamage', 'BGN_PlayerArrest', function(attacker, target, dmginfo)
	if not GetConVar('bgn_arrest_mode'):GetBool() then return end
   if not attacker:IsPlayer() then return end
   
	local TargetActor = bgNPC:GetActor(target)
   if TargetActor == nil or not TargetActor:HasTeam('residents') then return end

   if not ArrestModule:HasPlayer(attacker) then
      if not WantedModule:HasWanted(attacker) then
         
         local PoliceActor

         if TargetActor:HasTeam('police') then
            PoliceActor = TargetActor
         else
            for _, actor in ipairs(bgNPC:GetAllByRadius(attacker:GetPos(), 700)) do
               if actor:IsAlive() and actor:HasTeam('police') then
                  if not PoliceActor then
                     PoliceActor = actor
                  else
                     local AttackerPos = attacker:GetPos()
                     local NewActorPos = actor:GetNPC():GetPos()
                     local OldActorPos = PoliceActor:GetNPC():GetPos()
         
                     if NewActorPos:DistToSqr(AttackerPos) < OldActorPos:DistToSqr(AttackerPos) then
                        PoliceActor = actor
                     end
                  end
               end
            end
         
            if not PoliceActor then return end
         end

         ArrestModule:AddPlayer(attacker, PoliceActor)
         PoliceActor:RemoveAllTargets()
         PoliceActor:SetState('arrest')
         PoliceActor:AddTarget(attacker)

         if PoliceActor ~= TargetActor and not TargetActor:HasState('fear') then
            TargetActor:RemoveAllTargets()
            TargetActor:AddEnemy(attacker)
            TargetActor:SetState('fear')
         end
      end
   else
      local ArrestComponent = ArrestModule:GetPlayer(attacker)
      if ArrestComponent.arrested then
         ArrestComponent.damege_count = ArrestComponent.damege_count + 1
         if ArrestComponent.damege_count >= 3 then
            ArrestModule:NotSubjectToArrest(attacker)
         end
      end
   end

   return false
end)

bgNPC:SetStateAction('arrest', function(actor)
   local npc = actor:GetNPC()
   local target = actor:GetFirstTarget()
   local ArrestComponent = ArrestModule:GetPlayer(target)

   if not IsValid(target) or actor:TargetsCount() == 0 or not ArrestComponent then
		actor:RandomState()
      return
	end

   if not ArrestComponent.arrested or 
      (not ArrestComponent.detention and ArrestComponent.warningTime < CurTime())
   then
      ArrestModule:NotSubjectToArrest(target)
      actor:RemoveAllTargets()
      actor:AddEnemy(target)
      actor:SetState('defense')
      return
   end

   if npc:GetPos():DistToSqr(target:GetPos()) > 22500 then
      actor:WalkToTarget(target, 'run')
      ArrestComponent.detention = false
   else
      local addArrestTime = GetConVar('bgn_arrest_time'):GetFloat()
      local eyeAngles = target:EyeAngles()

      if not ArrestComponent.detention then
         ArrestComponent.arrest_time = CurTime() + addArrestTime
      end

      if eyeAngles.x > 40 then
         if not ArrestComponent.detention then
            npc:EmitSound(bgNPC.cfg.arrest['warning_sound'], 300, 100, 1, CHAN_AUTO)
            target:ChatPrint(bgNPC.cfg.arrest['warning_text'])
         end
         ArrestComponent.detention = true
      else
         ArrestComponent.detention = false
      end

      if not ArrestComponent.detention and ArrestComponent.notify_order_time < CurTime() then
         ArrestComponent.notify_order_time = CurTime() + 3
         target:ChatPrint(bgNPC.cfg.arrest['order_text'])
         npc:EmitSound(bgNPC.cfg.arrest['order_sound'], 300, 100, 1, CHAN_AUTO)
      elseif ArrestComponent.detention then
         local time = ArrestComponent.arrest_time - CurTime()
         if time <= 0 then
            ArrestModule:RemovePlayer(target)

            hook.Run('BGN_PlayerArrest', target, actor)
            
            for _, actor in ipairs(bgNPC:GetAll()) do
               actor:RemoveTarget(target)
               actor:RemoveEnemy(target)
            end
         else
            if ArrestComponent.notify_arrest_time < CurTime() then
               target:ChatPrint(string.Replace(bgNPC.cfg.arrest['arrest_notify'], '%time%', math.floor(time)))
               ArrestComponent.notify_arrest_time = CurTime() + 1
            end
         end
      end
   end
end)
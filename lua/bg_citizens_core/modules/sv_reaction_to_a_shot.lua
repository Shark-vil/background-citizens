local function IsFound(sound_name, text)
   return tobool(string.find(sound_name, text))
end

hook.Add("EntityEmitSound", "BGN_WeaponShotSoundReaction", function(t)
   local sound_name = t.SoundName
   local attacker = t.Entity

   if not attacker:IsPlayer() then return end
   
   if IsFound(sound_name, 'weapon') or IsFound(sound_name, 'shot') or IsFound(sound_name, 'bullet') then
      for _, actor in ipairs(bgNPC:GetAllByRadius(attacker:GetPos(), 2500)) do
         local reaction = actor:GetReactionForProtect()
         actor:SetReaction(reaction)
   
         local npc = actor:GetNPC()
         if npc == attacker then
            goto skip
         end
   
         if not bgNPC:IsTargetRay(npc, attacker) then
            goto skip
         end
   
         local hook_result = hook.Run('BGN_PreDamageToAnotherActor', actor, attacker, npc, reaction) 
         if hook_result ~= nil then
            if isbool(hook_result) and not hook_result then
               goto skip
            end
   
            if isstring(hook_result) then
               reaction = hook_result
            end
         end
   
         local state = actor:GetState()
         if state == 'idle' or state == 'walk' or state == 'arrest' then
            actor:SetState(actor:GetLastReaction())
         end
   
         hook.Run('BGN_PostDamageToAnotherActor', actor, attacker, npc, reaction)
   
         ::skip::
      end
   end
end)
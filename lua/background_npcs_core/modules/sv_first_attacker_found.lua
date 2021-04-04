local ASSET = {}
local first_attackers = {}

hook.Add("EntityTakeDamage", "BGN_FoundFirstAttacker", function(target, dmginfo)
   local attacker = dmginfo:GetAttacker()

   if not attacker:IsNPC() and not attacker:IsPlayer() then return end
   if not target:IsNPC() and not target:IsPlayer() then return end

   for i = 1, #first_attackers do
      local data = first_attackers[i]
      if data.victim == attacker then
         return
      end

      if data.attacker == attacker and data.victim == target then
         return
      end
   end

   local a, t = hook.Run('BGN_Module_FirstAttackerValidator', attacker, target)

   if a ~= nil then attacker = a end
   if t ~= nil then target = t end

   table.insert(first_attackers, {
      attacker = attacker,
      victim = target,
   })
end)

function ASSET:IsFirstAttacker(attacker, victim)
   for i = 1, #first_attackers do
      local data = first_attackers[i]
      if data.victim == attacker then
         return false
      end

      if data.attacker == attacker and data.victim == victim then
         return true
      end
   end
   return false
end

function ASSET:ClearDeath()
   for i = #first_attackers, 1, -1 do
      local data = first_attackers[i]

      if not IsValid(data.attacker) or data.attacker:Health() <= 0 then
         table.remove(first_attackers, i)
      elseif not IsValid(data.victim) or data.victim:Health() <= 0 then
         table.remove(first_attackers, i)
      end
   end
end

function ASSET:RemoveAttacker(attacker)
   for index = 1, #first_attackers do
      local data = first_attackers[i]
      if data.attacker == attacker then
         table.remove(first_attackers, index)
         break
      end
   end
end

function ASSET:GetData()
   return first_attackers
end

hook.Add('PostCleanupMap', 'BGN_FirstAttackerModule_ClearAttackersList', function()
   table.Empty(first_attackers)
end)

hook.Add('PlayerDeath', 'BGN_FirstAttackerModule_ClearAttackersList', function(ply)
   ASSET:RemoveAttacker(ply)
end)

hook.Add("BGN_PlayerArrest", "BGN_FirstAttackerModule_DeletePlayerItemIfExists", function(ply)
   ASSET:RemoveAttacker(ply)
end)

timer.Create('BGN_ModuleTimer_FirstAttacker', 1, 0, function()
   ASSET:ClearDeath()
end)

list.Set('BGN_Modules', 'first_attacker', ASSET)
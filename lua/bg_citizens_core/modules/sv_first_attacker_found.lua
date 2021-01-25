local ASSET = {}
local first_attackers = {}

hook.Add("EntityTakeDamage", "BGN_FoundFirstAttacker", function(target, dmginfo)
   local attacker = dmginfo:GetAttacker()

   if not attacker:IsNPC() and not attacker:IsPlayer() then return end
   if not target:IsNPC() and not target:IsPlayer() then return end

   for i = #first_attackers, 1, -1 do
      local value = first_attackers[i]
      if not IsValid(value.victim) or not IsValid(value.attacker) then
         table.remove(first_attackers, i)
      end
   end

   for _, data in ipairs(first_attackers) do
      if data.victim == attacker then
         return
      end

      if data.attacker == attacker and data.victim == target then
         return
      end
   end

   table.insert(first_attackers, {
      attacker = attacker,
      victim = target,
   })
end)

function ASSET:IsFirstAttacker(attacker, victim)
   for _, data in ipairs(first_attackers) do
      if data.victim == attacker then
         return
      end

      if data.attacker == attacker and data.victim == victim then
         return true
      end
   end
   return false
end

function ASSET:GetData()
   return first_attackers
end

hook.Add('PostCleanupMap', 'BGN_FirstAttackerModule_ClearAttackersList', function()
   table.Empty(first_attackers)
end)

hook.Add('PlayerDeath', 'BGN_FirstAttackerModule_ClearAttackersList', function()
   table.Empty(first_attackers)
end)

hook.Add("BGN_PlayerArrest", "BGN_FirstAttackerModule_DeletePlayerItemIfExists", function(ply)
   for i = #first_attackers, 1, -1 do
      local value = first_attackers[i]
      if value.attacker == ply then
         table.remove(first_attackers, i)
      end
   end
end)

list.Set('BGN_Modules', 'first_attacker', ASSET)
hook.Add("BGN_PostSpawnNPC", "BGN_NPCSetCustomHealthByConfigSettings", function(npc, type, data)
   if data.health == nil then return end
   local new_health = nil
   
   if isnumber(data.health) then
      new_health = data.health
      npc:SetHealth(new_health)
   elseif istable(data.health) then
      new_health = math.random(data.health[1], data.health[2])
      npc:SetHealth(new_health)
   end

   if new_health ~= nil then
      npc:SetMaxHealth(new_health)
   end
end)
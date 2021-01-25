hook.Add("BGN_PostSpawnNPC", "BGN_NPCSetCustomHealthByConfigSettings", function(npc, type, data)
   if data.health == nil then return end
   if isnumber(data.health) then
      npc:SetHealth(data.health)
   elseif istable(data.health) then
      npc:SetHealth(math.random(data.health[1], data.health[2]))
   end
end)
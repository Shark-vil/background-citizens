hook.Add('BGN_PreSpawnNPC', 'BGN_SetCustomCitizenTypeFromDefaultModels', function(npc, type, data)
   if type ~= 'citizen' then return end
   if math.random(0, 10) > 5 then
      npc:SetKeyValue('citizentype', 2)
   end
end)
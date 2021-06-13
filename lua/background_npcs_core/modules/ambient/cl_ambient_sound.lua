local oldLevel
local currentLevel
local currentSound

local function SetAmbient(level)
   if level == currentLevel then return end
   oldLevel = currentLevel
   currentLevel = level

   if currentLevel == 0 then      
      if currentSound ~= nil and currentSound:IsPlaying() then
         timer.Remove('BGN_SetNewAmbientSoundAfterFade')
         currentSound:Stop()
         bgNPC:Log('Stop ambient - ' .. 'background_npcs/ambient/bgn_ambient_'.. oldLevel .. '.wav')
         currentSound = nil
      end
      return
   end

   local sound_name = 'background_npcs/ambient/bgn_ambient_'.. level .. '.wav'
   local fade_time = 2
   if currentSound ~= nil and currentSound:IsPlaying() then
      currentSound:FadeOut(fade_time)
   else
      fade_time = 0
   end

   timer.Create('BGN_SetNewAmbientSoundAfterFade', fade_time + 0.1, 1, function()
      if currentSound ~= nil then
         currentSound:Stop()
         bgNPC:Log('Stop ambient - ' .. 'background_npcs/ambient/bgn_ambient_'.. oldLevel .. '.wav')
      end

      local volume = 1
      if level == 1 then volume = 0.4 end

      currentSound = CreateSound(game.GetWorld(), sound_name)
      currentSound:SetSoundLevel(0)
      currentSound:PlayEx(volume, 100)

      bgNPC:Log('Play ambient - ' .. sound_name)
   end)
end

local min_ambient_1 = 6
local min_ambient_2 = 3
-- 3 automatically

timer.Create('BGN_SetAmbientSound', 2, 0, function()
   if not GetConVar('bgn_cl_ambient_sound'):GetBool() then
      SetAmbient(0)
      return
   end
   if not LocalPlayer().snet_ready then return end

   local ply = LocalPlayer()
   local entities = ents.FindInSphere(ply:GetPos(), 1000)
   
   local count = 0
   for i = 1, #entities do
      local npc = entities[i]
      if bgNPC:GetActor(npc) ~= nil and bgNPC:IsTargetRay(ply, npc) then
         count = count + 1
      end
   end

   if count == 0 then
      SetAmbient(0)
      return
   end

   if count >= min_ambient_1 then
      SetAmbient(1)
   elseif count >= min_ambient_2 then
      SetAmbient(2)
   else
      SetAmbient(3)
   end
end)
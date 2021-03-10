local state_actions = {}

function bgNPC:SetStateAction(state_name, func)
   state_actions[state_name] = func
end

function bgNPC:CallStateAction(actor)
   local state_name = actor:GetState()
   local func = state_actions[state_name]
   if func == nil then return end
   pcall(function()
      func(actor, state_name)
   end)
end

timer.Create('BGN_StateMachine', 1, 0, function()
   for _, actor in ipairs(bgNPC:GetAll()) do
      if actor:IsAlive() then
         bgNPC:CallStateAction(actor)
      end
   end
end)
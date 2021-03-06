local is_active = GetConVar('bgn_cl_field_view_optimization'):GetBool()
local min_range = GetConVar('bgn_cl_field_view_optimization_range'):GetFloat() ^ 2

cvars.AddChangeCallback('bgn_cl_field_view_optimization', function(convar_name, value_old, value_new)
   local new_value = tobool(value_new)
   if is_active == new_value then return end

   is_active = new_value
   if is_active then return end

   for _, npc in ipairs(bgNPC:GetAllNPCs()) do
      if IsValid(npc) and npc:Health() > 0 then
         npc:SetNoDraw(false)
      end
   end
end)

cvars.AddChangeCallback('bgn_cl_field_view_optimization_range', function(convar_name, value_old, value_new)
   local new_value = value_new ^ 2
   if min_range == new_value then return end
   min_range = new_value
end)

local function func()
   local ply = LocalPlayer()
   local pass = 0
   local max_pass = 5
   
   for _, npc in ipairs(bgNPC:GetAllNPCs()) do
      if IsValid(npc) and npc:Health() > 0 then
         local pos = npc:GetPos()

         if ply:GetPos():DistToSqr(pos) > min_range and not bgNPC:PlayerIsViewVector(ply, pos) then
            npc:SetNoDraw(true)
            pass = pass + 1
         else
            npc:SetNoDraw(false)
            pass = pass + 1
         end

         if pass == max_pass then
            pass = 0
            coroutine.yield()
         end
      end
   end

   return coroutine.yield()
end

local thread
hook.Add("Think", "BGN_RenderOptimization", function()
   if not is_active then
      if thread then thread = nil end
      return
   end

   if not thread or not coroutine.resume(thread) then
		thread = coroutine.create(func)
		coroutine.resume(thread)
	end
end)
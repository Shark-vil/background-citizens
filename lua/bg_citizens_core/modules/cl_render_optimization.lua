local is_active = GetConVar('bgn_cl_field_view_optimization'):GetBool()
local min_range = GetConVar('bgn_cl_field_view_optimization_range'):GetFloat() ^ 2

cvars.AddChangeCallback('bgn_cl_field_view_optimization', function(convar_name, value_old, value_new)
   is_active = tobool(value_new)
end)

cvars.AddChangeCallback('bgn_cl_field_view_optimization_range', function(convar_name, value_old, value_new)
   min_range = value_new ^ 2
end)

local function func()
   local ply = LocalPlayer()
   local pass = 0
   local max_pass = 3
   
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
   if not is_active then return end

   if not thread or not coroutine.resume(thread) then
		thread = coroutine.create(func)
		coroutine.resume(thread)
	end
end)
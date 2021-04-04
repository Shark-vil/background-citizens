hook.Add("BGN_PlayerArrest", "BGN_DarkRP_PlayerArrest", function(ply, actor)
   if engine.ActiveGamemode() ~= 'darkrp' then return end
   ply:arrest(nil, actor:GetNPC())
end)
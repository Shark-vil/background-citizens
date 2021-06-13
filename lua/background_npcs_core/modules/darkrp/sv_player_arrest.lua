hook.Add("BGN_PlayerArrest", "BGN_DarkRP_PlayerArrest", function(ply, actor)
   if engine.ActiveGamemode() ~= 'darkrp' then return end
   ply:arrest(nil, actor:GetNPC())
   ply:EmitSound('background_npcs/handcuffs_sound1.mp3')
   ply:ScreenFade(SCREENFADE.IN, Color(0, 0, 0, 255), 1, 3)
end)
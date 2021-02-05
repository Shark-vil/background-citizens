hook.Add("BGN_PlayerArrest", "BGN_SandBox_PlayerArrest", function(ply)
   if engine.ActiveGamemode() ~= 'sandbox' then return end
   
   ply:EmitSound('background_npcs/handcuffs_sound1.mp3')
   ply:ScreenFade(SCREENFADE.IN, Color(0, 0, 0, 255), 1, 3)
   ply:KillSilent()
end)
scommand.Create('cmd_bgn_spawnmenu_default_spawner').OnServer(function(ply, cmd, args)
	if not IsValid(ply) or not bgNPC.SpawnMenu.Creator['Default'] then return end
	print(ply, cmd, table.ToString(args))
	bgNPC.SpawnMenu.Creator['Default'][ply] = args[1]
end).Register()
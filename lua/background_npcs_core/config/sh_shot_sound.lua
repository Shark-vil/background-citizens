bgNPC.cfg.shotsound = {}

--[[
   In this config you can configure a module that makes the actors react to the sounds of gunshots, or any other hostile sounds.
--]]

-- A list of weapons to ignore when playing sound effects.
bgNPC.cfg.shotsound.whitelist_weapons = {
	'weapon_physcannon',
	'gmod_tool',
	'gmod_cinematic_camera',
	'weapon_medkit',
	'remotecontroller',
}

-- Keywords in the name of the sound files being played
bgNPC.cfg.shotsound.sound_name_found = {
	'gun',
	'weapon',
	'shot',
	'shoot',
	'bullet',
	'arccw',
	'tfa',
}
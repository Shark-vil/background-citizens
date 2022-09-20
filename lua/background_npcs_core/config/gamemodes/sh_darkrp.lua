bgNPC.cfg.darkrp = {}

-- TEXT --
local text = slib.language({
	['default'] = {
		['notify'] = 'You cannot change your job while you are wanted!',
	},
	['russian'] = {
		['notify'] = 'Вы не можете сменить работу, пока вас разыскивают!'
	}
})

-- Prevents the player from changing job while he is wanted
bgNPC.cfg.darkrp.disableChangeTeamByWanted = true
-- Error text for limitation above
bgNPC.cfg.darkrp.disableChangeTeamByWantedText = text['notify']
bgNPC.cfg.arrest = {}

-- TEXT --
local text = slib.language({
	['default'] = {
		['order_text'] = 'Put your head down!',
		['warning_text'] = 'Stay in this position, don\'t move!',
		['arrest_notify'] = 'Arrest after %time% sec.'
	},
	['russian'] = {
		['order_text'] = 'Опусти свою голову!',
		['warning_text'] = 'Оставайтесь в этом положении, и не двигайтесь!',
		['arrest_notify'] = 'Задержание через %time% сек.'
	}
})

bgNPC.cfg.arrest['order_text'] = text['order_text']
bgNPC.cfg.arrest['warning_text'] = text['warning_text']
bgNPC.cfg.arrest['arrest_notify'] = text['arrest_notify']

-- SOUND --
bgNPC.cfg.arrest['order_sound'] = 'npc/metropolice/vo/getdown.wav'
bgNPC.cfg.arrest['warning_sound'] = 'npc/metropolice/vo/dontmove.wav'
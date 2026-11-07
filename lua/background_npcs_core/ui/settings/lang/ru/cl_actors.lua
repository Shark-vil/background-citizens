--[[-----------------------------------------
	 Active npc group settings menu
--]]
local lang = {
	['bgn.settings.actor.active_npcs.help'] = 'Вы можете отключить некоторых NPC, если не хотите чтобы они спавнились.',
	['bgn.settings.actor.total_max_npc'] = 'Максимальное количество NPC на карте',
	['bgn.settings.actor.total_max_npc.help'] = 'Максимальное количество фоновых NPC на карте.'
}

for actor_type, actor_data in pairs(bgNPC.cfg.actors) do
	local actor_name = actor_data.name or actor_type

	do
		local key = 'bgn.settings.actor.disable_weapon_' .. actor_type
		local help = key .. '.help'
		lang[key] = 'Отключить оружие'
		lang[help] = 'Запрещает "' .. actor_name .. '" иметь оружие'
	end

	do
		local key = 'bgn.settings.actor.max_npc_' .. actor_type
		local help = key .. '.help'
		lang[key] = 'Лимит для "' .. actor_name .. '"'
		lang[help] = 'Устанавливает лимит на максимальное кол-во актёров типа "' .. actor_name .. '" на карте'
	end

	do
		local key = 'bgn.settings.actor.max_npc_vehicle_' .. actor_type
		local help = key .. '.help'
		lang[key] = 'Лимит для "' .. actor_name .. '"'
		lang[help] = 'Устанавливает лимит на максимальное кол-во транспорта, который могут использовать актёры типа "' .. actor_name .. '" на карте.'
	end
end

return lang
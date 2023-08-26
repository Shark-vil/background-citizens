--[[-----------------------------------------
	 Active npc group settings menu
--]]
local lang = {
	['bgn.settings.actor.active_npcs.help'] = 'You can disable some NPCs if you don\'t want to spawn them anymore.',
	['bgn.settings.actor.total_max_npc'] = 'Maximum number of NPCs on the map',
	['bgn.settings.actor.total_max_npc.help'] = 'The maximum number of background NPCs on the map.'
}

for actor_type, actor_data in pairs(bgNPC.cfg.actors) do
	local actor_name = actor_data.name or actor_type

	do
		local key = 'bgn.settings.actor.disable_weapon_' .. actor_type
		local help = key .. '.help'
		lang[key] = 'Disable weapons'
		lang[help] = 'Prevents "' .. actor_name .. '" from owning weapons'
	end

	do
		local key = 'bgn.settings.actor.max_npc_' .. actor_type
		local help = key .. '.help'
		lang[key] = 'Limit for "' .. actor_name .. '"'
		lang[help] = 'Sets a limit on the maximum number of "' .. actor_name .. '" type actors on the map.'
	end

	do
		local key = 'bgn.settings.actor.max_npc_vehicle_' .. actor_type
		local help = key .. '.help'
		lang[key] = 'Limit for "' .. actor_name .. '"'
		lang[help] = 'Sets a limit on the maximum number of vehicles that "' .. actor_name .. '" type actors can use on the map.'
	end
end

return lang
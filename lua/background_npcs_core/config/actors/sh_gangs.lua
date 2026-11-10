--[[
	Two street gangs, both built on the "gangster" actor: they help only their own gang (systems/sv_fight_roster.lua),
	and each has a light member (a pistol, citizen clothes) and a heavy one (an SMG or a rifle, rebel gear),
	see systems/npcs/sv_gang_models.lua. Both keep the team "bandits" (police, carjacking), plus their own gang team.
--]]

local crows = bgNPC.Util.Lang({
	['default'] = 'Black Raven',
	['russian'] = 'Чёрный Ворон'
})
local wolves = bgNPC.Util.Lang({
	['default'] = 'Red Wolf',
	['russian'] = 'Красный Волк'
})

local function Gang(actor_type, name, gang)
	bgNPC.cfg:SetActor(actor_type, {
		enabled = true,
		inherit = 'gangster',
		class = 'npc_citizen',
		name = name,
		gang = gang,
		fullness = 5, -- percent of bgn_max_npc per gang; Config.GetFullness does not read the inherited one
		team = { 'bandits', 'gang_' .. gang },
		heavy_chance = 35, -- percent of the gang that are heavy members
		heavy_weapons = { 'weapon_smg1', 'weapon_ar2' },
		light_weapons = { 'weapon_pistol' },
	})
end

Gang('gangster_crows', crows, 'crows')
Gang('gangster_wolves', wolves, 'wolves')

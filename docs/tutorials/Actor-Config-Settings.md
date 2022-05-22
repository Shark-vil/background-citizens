# Actor Configuration Options

## enabled
- *boolean*
- Whether the actor is enabled by default in the options menu or not.
```lua
-- Yes
enabled = true
-- No
enabled = false
```

## class
- *string | table*
- NPC entity class. May be in the form of a string or a list of strings.
```lua
-- string
class = 'npc_citizen'
-- table
class = {
	'npc_citizen',
	'npc_metropolice'
}
```

## name
- *string*
- The name of the actor, which is displayed in the options menu.
```lua
-- string
name = 'Amogus'
```

## fullness
- *number*
- Percentage filling from **0** to **100**. Used when changing the slider for the total number of NPCs on the map.
```lua
-- number
-- If the npc limit is 30, then it will be 50% of the number 30.
fullness = 50
```

## limit
- *number*
- Sets a fixed number of NPCs to spawn by default. **Attention**: this parameter is not compatible with "*fullness*". But you can still change this slider individually.
```lua
-- number
-- When changing the slider for the total number of NPCs, the limit will always be at a value of - 5.
limit = 5
```

## team
- *table*
- Team to which the actor belongs. Default teams: **residents, police, bandits, zombies**.
```lua
-- table
-- is in the team of citizens
team = { 'residents' }
-- is a member of the citizen and police team
team = { 'residents', 'police' }
```

## weapons
- *table*
- A weapon that an actor can spawn with. The weapon is not in the hands, it is "in the pocket". NPC takes (spawns) weapons if necessary.
```lua
-- table
weapons = { 'weapon_pistol' }
weapons = { 'weapon_pistol', 'weapon_shotgun' }
```

## getting_weapon_chance
- *boolean* | *number*
- The chance at which an NPC can get a weapon. If set to "false", the NPC will always take weapons.
```lua
-- number
-- 20% chance to pick up a weapon
getting_weapon_chance = 20
-- boolean
-- always take a weapon
getting_weapon_chance = false
```

## money
- *table* | *number*
- How much money can an NPC throw away after death. Works if there are handlers and mods for money. You can specify a fixed or random amount.
```lua
-- number
-- Always throw away "30" money upon death.
money = 30
-- table
-- Throw away a random amount of money from "1" to "20". If 0 falls out, then nothing will come of it.
money = { 0, 20 }
```

## health
- *table* | *number*
- How much health the npc can spawn with. You can specify a fixed or random number.
```lua
-- number
-- The NPC spawns with "50" health each time.
health = 50
-- table
-- The NPC spawns with a random amount of health from "30" to "100".
health = { 30, 100 }
```

## weapon_skill
- *number* | *enum*
- Sets weapon proficiency ([Read More](https://wiki.facepunch.com/gmod/Enums/WEAPON_PROFICIENCY)).
```lua
-- number / enum
weapon_skill = WEAPON_PROFICIENCY_POOR
```

## replics
- *table*
- Sets the lines to be spoken by NPCs in different states.
```lua
-- No description yet
```

## max_vehicle
- *number*
- Sets the maximum number of vehicles to spawn.
```lua
-- number
-- Spawn a maximum of 2 cars for a given actor type.
max_vehicle = 2
```

## vehicle_multiply_speed
- *table*
- Sets the states in which the movement speed will be multiplied.
```lua
-- No description yet
```

## enter_to_exist_vehicle_chance
- *number*
- Chance for an existing or new actor to get into a transport on the map, instead of being removed or teleported.
```lua
-- number
-- 10% chance to board an existing vehicle on the map.
enter_to_exist_vehicle_chance = 10
```

## vehicles_strict_color_chance
- *number*
- Works if random colors (*vehicles_random_color*) are enabled. Sets limits on bright colors, making them less toxic.
```lua
-- number
-- 25% chance of setting a strict color.
vehicles_strict_color_chance = 25
```

## vehicles_random_color
- *boolean*
- Enable color randomization for vehicles.
```lua
-- boolean
-- Turn on random colors.
vehicles_random_color = true
-- boolean
-- Turn off random colors.
vehicles_random_color = false
```

## vehicles_random_skin
- *boolean*
- Switch of random skins for vehicles.
```lua
-- boolean
-- Enable random skins.
vehicles_random_skin = true
-- boolean
-- Disable random skins.
vehicles_random_skin = false
```

## vehicles_random_bodygroups
- *boolean*
- Random bodygroup switcher for vehicles.
```lua
-- boolean
-- Enable random bodygroups.
vehicles_random_bodygroups = true
-- boolean
-- Disable random bodygroups.
vehicles_random_bodygroups = false
```

## vehicle_group
- *string*
- Sets the primary group for this actor's car.
```lua
-- string
-- Allows only actors from the police group to get into the car
vehicle_group = 'police'
```

## vehicles
- *table*
- A list of cars that can be created for this actor. All major vehicle bases must be supported. If there are problems with any base - let me know.
```lua
-- table
-- Sets the actor's vehicles list
vehicles = {
	'sim_fphys_pwavia',
	'sim_fphys_pwgaz52',
	'sim_fphys_pwhatchback',
}
```

## at_random_range
- *number*
- Changes the ranking limits for choosing a random state value. It is recommended to use it to increase the spread if the calculations from 0 to 100 are not enough for you..
```lua
-- number
-- Changes randomization settings from "0 -## 100" to "0 -## 120".
at_random_range = 120
at_random = {
	['walk'] = 75,
	['idle'] = 10,
	['dialogue'] = 15,
	['sit_to_chair'] = 10,
	['random_gesture'] = 10,
}
```

## at_damage_range
- *number*
- Similar actions as "*at_random_range*", but only for the field "*at_damage*".

## at_protect_range
- *number*
- Similar actions as "*at_random_range*", but only for the field "*at_protect*".

## at_random
- *table*
- Actions that the actor will perform after a random period of time.
```lua
-- 50% chance to walk, 50% chance to rest
at_random = {
	['walk'] = 50,
	['idle'] = 50,
}
```

## at_damage
- *table*
- Actions that the actor will take if he is attacked.

## at_protect
- *table*
- Actions an actor will take if his ally is attacked.

## respawn_delay
- *number*
- Set the spawn delay in seconds from the moment the actor dies.
```lua
-- The actor will spawn 5 seconds after death if the global spawn delay is less than this limit.
respawn_delay = 5
```

## wanted_level
- *number*
- Relevant only in the case of an active module on the "Wanted System". Set the level at which NPCs can spawn (*1 to 5*)
```lua
-- Compare actors only if wanted level - 3
wanted_level = 3
```

## disable_states
- *boolean*
- Possibility to turn off Background NPCs state logic. This allows you to spawn NPCs on the map, but not change their original behavior.
```lua
-- NPCs will not use the state system of their Background NPCs
disable_states = false
```

## validator
- *function*
- Checks the validity of the data before creating the actor. Can cancel the creation of the actor if it returns "false".
```lua
-- @self - config data
-- @npc_type - actor type/id
validator = function(self, npc_type)
	-- Cancels the creation of an actor if its class is not in the list of NPCs.
	if list.Get('NPC')[self.class] == nil then
		return false
	end
end,
```

## inherit
- *string*
- Inherits data from another actor. Useful if you don't want to overwrite the same parameters all the time.
```lua
-- For example, this is our main actor.
bgNPC.cfg:SetActor('actor_1', {
	enabled = true,
	name = 'Actor 1',
	class = 'npc_citizen',
	fullness = 64,
	team = { 'residents' },
	health = 1000,
	at_random = {
		['walk'] = 50,
		['idle'] = 50,
	},
	at_damage = { ['defense'] = 100 },
	at_protect = { ['defense'] = 100 }
})

-- This actor uses the "inherit" parameter to borrow the missing parameters it takes from "actor_1"
bgNPC.cfg:SetActor('actor_2', {
	enabled = true,
	name = 'Actor 2',
	inherit = 'actor_1',
	team = { 'bandits' },
	at_protect = { ['fear'] = 100 },
})

-- This actor uses the "inherit" parameter to borrow missing parameters, which it takes from "actor_2", which previously borrowed data from "actor_1".
-- But there is also a team parameter where we explicitly specify from which actor we want to borrow data.
-- The "@" sign is used to indicate the actor from which we want to borrow a similar field.
bgNPC.cfg:SetActor('actor_3', {
	enabled = true,
	name = 'Actor 3',
	inherit = 'actor_2',
	team = '@actor_1',
	at_damage = { ['fear'] = 100 },
	at_protect = { ['fear'] = 100 }
})
```

## random_skin
- *boolean*
- Enables an option for NPCs to spawn with random skins.
```lua
-- Enable random skins
random_skin = true
-- Disable random skins
random_skin = false
```

## random_bodygroups
- *boolean*
- Enables an option for NPCs to spawn with random bodygroups.
```lua
-- Enable random bodygroups
random_bodygroups = true
-- Disable random bodygroups
random_bodygroups = false
```

## default_models
- *boolean*
- Enables or disables the use of standard NPC models. Useful if you use custom models.
```lua
-- Enable default models
default_models = true
-- Disable default models
default_models = false
```

## models
- *table*
- Sets a list of custom npc models.
```lua
models = {
	'models/smalls_civilians/pack1/hoodie_male_01_f_npc.mdl',
	'models/smalls_civilians/pack1/hoodie_male_02_f_npc.mdl',
	'models/smalls_civilians/pack1/zipper_female_01_f_npc.mdl',
	'models/smalls_civilians/pack1/zipper_female_02_f_npc.mdl',
}
```

## relationship
- *table*
- Set values for relations that will be applied to the actor after spawning ([Read More](https://wiki.facepunch.com/gmod/Enums/D)). 
```lua
relationship = {
	['@player'] = D_HT,	-- Hate the players
	['@actor'] = D_HT,	-- Hate other actors
	['@team'] = D_LI,	-- Befriend team members
	['@npc'] = D_NU,	-- Be neutral towards other NPCs
}
```

## bsmod_damage_animation_disable
- *boolean*
- Compatibility with BSmod addon. Prevents the addon from using animations on actors.
```lua
-- Disable animations
bsmod_damage_animation_disable = true
-- Enable animations
bsmod_damage_animation_disable = false
```

---

**Not all options are presented in this article. Expect updates...**
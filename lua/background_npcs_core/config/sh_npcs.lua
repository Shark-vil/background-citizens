--[[
	------------------------------------------------------------
	Actor - the so-called NPCs that are part of this system.
	------------------------------------------------------------
	The name of the table key does not matter. The main thing is the team in which the actor is.
	Teams:
		1. residents - main team for citizens and police. The police will always protect residents.
		2. police - the police are trying to protect everyone. But if the entity is not part of the residents team, they will attack.
		3. player - ignores any player, depending on the config settings may not allow him to inflict damage.
		4. bandits - arbitrary team for troublemakers. At the moment it has no special settings.

	The actions of the actors depend on the settings of the parameters with the prefix at_:
		at_{name}_range - the maximum number parameter for randomizing events (Default - 100)
		at_random - events that are executed randomly if the actor does not have taregts.
		at_damage - events that are performed if the actor takes damage.
		at_protect - events that are performed for other actors, if they see the actor taking damage.

	AT default params:
		ignore - ignores the state change, and leaves the active state.
		idle - the state in which the actor is idle, performing a random animation.
		walk - the state in which the actor moves through the points on the map.
		fear - a state in which the actor tries to escape from the attacker.
		calling_police - a state in which the actor tries to call the police to declare the attacker wanted. After the call, the state will change to "fear"
		defense - a state in which the actor will attack and pursue the attacker.
		impingement - a state in which an actor will try to attack the nearest actor who has no team in common.

	Explanation of other parameters:
		class - NPC class. The class directly affects the playback of animations and the operation of models, use it carefully.
		name - Any NPC name. Displayed in the options menu.
		fullness - the parameter of the world occupancy for each actor (1 to 100)
		limit - alternative for the "fullness" parameter, sets a fixed number of NPCs
		team - the actor's team is used for interaction logic. Explanation above ↑
		weapons - a weapon that an actor can have. If you don't want the actor to have a weapon, leave the list empty or delete the parameter.
		money - the amount of money dropped from the actor after death. The first parameter is the minimum, the second parameter is the maximum (Default used in DarkRP)
		default_models - if true, then the actors will spawn with the standard model mixed with the custom ones. If you want to use only custom models, set the parameter to false
		models - custom actor model. Please note that the model is directly dependent on the class used. If the model is incompatible with the selected class, it can - show an error, not be displayed, the actor can be idle.
		at_ - explanation above ↑
		health - the health that the actor spawns with.
			Can be a number: health = 100
			Can be a table with the possibility of randomness: health = { 100, 200 }
		wanted_level - actors who will spawn only if any entity has the required wanted level. After all the actors have lost their targets, they are removed (1 to 5)
		weapon_skill - The level of circulation of NPCs with weapons. (https://wiki.facepunch.com/gmod/Enums/WEAPON_PROFICIENCY)
		random_skin - enable the creation of random skins for NPCs
		random_bodygroups - enable the creation of random bodygroups for NPCs
		disable_states - disable NPC states switching. Suitable if you need to keep the default logic of the NPC.
		respawn_delay - sets a delay for the appearance of new NPCs after the death of any of the existing
		validator - a function that checks the spawn before the entity is created. Suitable for system checks. For broader checks, use the "BGN_OnValidSpawnActor" or "BGN_PreSpawnActor" hook
--]]

-- NPC classes that fill the streets
bgNPC.cfg.npcs_template = {
	['citizen'] = {},
	['taxi_driver'] = {},
	['racer_driver'] = {},
	['thief'] = {},
	['gangster'] = {},
	['police'] = {},
	['civil_defense'] = {},
	['special_forces'] = {},
	['special_forces_2'] = {},
	['police_helicopter'] = {},
	['zombie'] = {},
}
--[[-----------------------------------------
	 State settings menu
--]]
return {
	['bgn.settings.states.bgn_enable_wanted_mode'] = 'Enable wanted mode',
	['bgn.settings.states.bgn_enable_wanted_mode.help'] = 'Enables or disables wanted mode.',

	['bgn.settings.states.bgn_wanted_time'] = 'Wanted time',
	['bgn.settings.states.bgn_wanted_time.help'] = 'The time you need to go through to remove the wanted level.',

	['bgn.settings.states.bgn_wanted_level'] = 'Wanted level',
	['bgn.settings.states.bgn_wanted_level.help'] = 'Enable the function of increasing the wanted level depending on the number of murders.',

	['bgn.settings.states.bgn_wanted_hud_text'] = 'Wanted time text',
	['bgn.settings.states.bgn_wanted_hud_text.help'] = 'Display text about the remaining wanted time.',

	['bgn.settings.states.bgn_wanted_hud_stars'] = 'Wanted stars',
	['bgn.settings.states.bgn_wanted_hud_stars.help'] = 'Display the wanted level as a star.',

	['bgn.settings.states.bgn_wanted_calling_police_text_color'] = 'Color of police call text',
	['bgn.settings.states.bgn_wanted_calling_police_text_color.help'] = 'Sets the color of the text above the actor who calls the police.',

	['bgn.settings.states.bgn_wanted_calling_police_halo_color'] = 'The color of the outline of the caller to the police',
	['bgn.settings.states.bgn_wanted_calling_police_halo_color.help'] = 'Sets the color of the outline (halo) of the actor calling the police.',

	['bgn.settings.states.bgn_wanted_wanted_halo_color'] = 'The color of the outline of the wanted person',
	['bgn.settings.states.bgn_wanted_wanted_halo_color.help'] = 'Sets the color of the outline (halo) of a wanted entity.',

	['bgn.settings.states.bgn_wanted_impunity_limit'] = 'Impunity limit',
	['bgn.settings.states.bgn_wanted_impunity_limit.help'] = 'Sets the number of kills, on reaching which you are guaranteed to get a wanted level. The value "0" disables the option.',

	['bgn.settings.states.bgn_wanted_impunity_reduction_period'] = 'Impunity penalty reduction period',
	['bgn.settings.states.bgn_wanted_impunity_reduction_period.help'] = 'Sets the period of time in seconds, after which the limit of extreme player kills is reduced by 1 number. The value "0" disables the option.',

	['bgn.settings.states.bgn_wanted_police_instantly'] = 'Instant wanted for killing the police',
	['bgn.settings.states.bgn_wanted_police_instantly.help'] = 'If enabled, you instantly get a wanted level when killing actors from the "police" team.',

	['bgn.settings.states.bgn_arrest_mode'] = 'Enable arrest mode',
	['bgn.settings.states.bgn_arrest_mode.help'] = 'Includes a player arrest module.',

	['bgn.settings.states.bgn_arrest_time'] = 'Arrest time',
	['bgn.settings.states.bgn_arrest_time.help'] = 'Sets the time allotted for your detention.',

	['bgn.settings.states.bgn_arrest_time_limit'] = 'Arrest time limit',
	['bgn.settings.states.bgn_arrest_time_limit.help'] = 'Sets how long the police will ignore you during your arrest. If you refuse to obey after the lapse of time, they will start shooting at you.',

	['bgn.settings.states.bgn_shot_sound_mode'] = 'Enable reaction to shot sounds',
	['bgn.settings.states.bgn_shot_sound_mode.help'] = 'NPCs will react to the sound of a shot as if someone was shooting at an ally. (Warning: this function is experimental and not recommended for use)',

	['bgn.settings.states.bgn_disable_halo'] = 'Disable NPC highlighting stroke.',
	['bgn.settings.states.bgn_disable_halo.help'] = 'Disables the effect of the outline of the NPC during the call and during the wanted.',

	['bgn.settings.states.bgn_cl_disable_self_halo_wanted'] = 'Disable local model halo effect',
	['bgn.settings.states.bgn_cl_disable_self_halo_wanted.help'] = 'Disables the wanted halo effect only for your player model.',

	['bgn.settings.states.bgn_cl_disable_halo'] = 'Disable all halos locally',
	['bgn.settings.states.bgn_cl_disable_halo.help'] = 'Disables all wanted halo effects locally. Useful if you are experiencing performance or rendering problems.',

	['bgn.settings.states.bgn_disable_halo_calling'] = 'Disable police call halo effect',
	['bgn.settings.states.bgn_disable_halo_calling.help'] = 'Disables the halo effect for actors during a call to the police.',

	['bgn.settings.states.bgn_disable_halo_wanted'] = 'Disable wanted halo effect',
	['bgn.settings.states.bgn_disable_halo_wanted.help'] = 'Disables the halo effect of wanted entities.',

	['bgn.settings.states.bgn_cl_disable_hud_local'] = 'Disable wanted HUD locally',
	['bgn.settings.states.bgn_cl_disable_hud_local.help'] = 'Disables the all wanted HUD for the local player.',

	['bgn.settings.states.bgn_enable_dv_support'] = 'Enable "DV" addon support',
	['bgn.settings.states.bgn_enable_dv_support.help'] = 'Includes compatibility with the "DV" addon and forces NPCs to use vehicles. Requires DV to have automatic loading of travel paths enabled!',

	['bgn.settings.states.bgn_enable_police_system_support'] = 'Enable support for the addon "Police System"',
	['bgn.settings.states.bgn_enable_police_system_support.help'] = 'Enables compatibility with the "Police System" addon and overrides the default arrest method.',

	['bgn.settings.states.bgn_disable_dialogues'] = 'Disable dialogues between NPCs',
	['bgn.settings.states.bgn_disable_dialogues.help'] = 'Disables NPCs from communicating with each other.',

	['bgn.settings.states.bgn_module_replics_enable'] = 'Enable text replics',
	['bgn.settings.states.bgn_module_replics_enable.help'] = 'Enable text cues over the heads of NPCs.',

	['bgn.settings.states.bgn_module_bio_annihilation_two_replacement'] = 'Enable support Bio-Annihilation II',
	['bgn.settings.states.bgn_module_bio_annihilation_two_replacement.help'] = 'Enabled automatic replacement of zombies with NPCs from Bio-Annihilation II.',

	['bgn.settings.states.bgn_module_arccw_weapon_replacement'] = 'Enable ArcCW support',
	['bgn.settings.states.bgn_module_arccw_weapon_replacement.help'] = 'Enables automatic swapping for weapons from the ArcCW addon. Requires NPC weapon swapping to be enabled in ArcCW too!',

	['bgn.settings.states.bgn_module_arc9_weapon_replacement'] = 'Enable Arc9 support',
	['bgn.settings.states.bgn_module_arc9_weapon_replacement.help'] = 'Enables automatic swapping for weapons from the Arc9 addon. Requires NPC weapon swapping to be enabled in Arc9 too!',

	['bgn.settings.states.bgn_module_tfa_weapon_replacement'] = 'Enable TFA support',
	['bgn.settings.states.bgn_module_tfa_weapon_replacement.help'] = 'Enables automatic swapping for weapons from the TFA addon.',

	['bgn.settings.states.bgn_all_models_random'] = 'Enable random models',
	['bgn.settings.states.bgn_all_models_random.help'] = 'All NPCs will spawn with random models, which will be taken from the general game list!',

	['bgn.settings.states.bgn_module_stormfox2'] = 'Enable support StormFox2',
	['bgn.settings.states.bgn_module_stormfox2.help'] = 'If it\'s night or it\'s raining outside, then there will be half as many NPCs on the map.',

	['bgn.settings.states.bgn_module_custom_gestures'] = 'Advanced Animations (EXPERIMENTAL)',
	['bgn.settings.states.bgn_module_custom_gestures.help'] = 'Enables support for advanced animations. NPCs will dance and do more different activities. Disable it if it causes problems',

	['bgn.settings.states.bgn_module_tactical_groups'] = 'Tactical groups (EXPERIMENTAL)',
	['bgn.settings.states.bgn_module_tactical_groups.help'] = 'Includes tactical groups. Currently only works with actors who are members of the "police" and "bandits" groups. In firefights, NPCs will try to form tactical groups to try to minimize team damage.',

	['bgn.settings.states.bgn_module_followers_mod_addon'] = 'Enable support Followers Mod',
	['bgn.settings.states.bgn_module_followers_mod_addon.help'] = 'Enables support for the "Followers Mod" addon, and makes it possible to make actors follow you.',
}
# Gangs and combat pacing

Server sources: `config/actors/sh_gangs.lua`, `systems/sv_fight_roster.lua`, `systems/sv_enemy_sharing.lua`, `systems/sv_fight_cooldown.lua`, `systems/npcs/sv_gang_pack.lua`, `sv_gang_models.lua`.

## Gang identity

`gangster_crows` (Black Raven) and `gangster_wolves` (Red Wolf) inherit `gangster`. Each has `gang = 'crows'|'wolves'` and teams `bandits` plus `gang_<id>`. Both are enabled, each with `fullness = 5` (5% of `bgn_max_npc`). Light members use pistols and citizen clothing; 35% heavy members use rebel equipment and SMG/AR2. Gang model selection also applies to NextBot bodies. Models/materials are shipped in the addon.

Gangsters of every gang type (`gangster` and both gangs; `respawn_delay = 30` is inherited from `gangster`) come back no sooner than 30 seconds after a death of their type, one per 30 seconds. `racer_driver` also inherits `gangster` but sets `respawn_delay = 0`. Both spawners read the resolved (inherited) config.

Gang alliance uses gang identity, not the common bandits tag: rivals do not join one another's protection calls. Police/car access still uses team rules.

## Fight roster

The capped roster has been replaced by visible-ally support (`systems/sv_enemy_sharing.lua`). Every living same-gang member that sees an ally outside the `fear` state with a living enemy receives that enemy. Calm members enter `defense` (wanted members use `retreat`) without a chance roll, roster cap or protection cooldown. Walking packs and distance do not limit support: an unobstructed line of sight to the ally is required (a trace, without a facing-direction check). Threats can spread through visible allies. Late arrivals also join; seeing the enemy itself is unnecessary. Seated members also receive enemies. Busy members receive the enemy without changing their current state; arrest protection and state locks remain in effect.

Checks run every `bgn_enemy_share_period` seconds (default **2**, `0` disables sharing), outside peaceful mode. `bgn_gang_help_chance` remains for compatibility but no longer affects support. The random 2–6-member roster has been removed.

A calm member can start a rival-gang fight within 700 units with direct line of sight, checked every 10 seconds with `bgn_gang_war_chance` (default **0.5%**, `0` disables).

## Pack walking

Living members of the same gang, regardless of their current state, form packs of **up to three**, in entity-index order. Each member joins the first pack with a free slot and a leader within 1500 units, or leads a new pack. The leader chooses its route normally. Its two followers stay 80–180 units around its current position, match its pace (walk or run), and recheck the pack every 2 seconds. Singles/pairs remain when there are not enough eligible members. Combat can unite multiple walking packs. Following runs in the `walk` state; a member in another state can still lead, so followers may gather around a stationary ally.

## Protection cooldown

`bgn_fight_cooldown` defaults to **60 seconds**, `0` disables. The first protection `defense` reaction opens a window within 2500 units. During it, protection against another actor attacker in that area is ignored, without adding that enemy. Joining against the same attacker is allowed. Player attacks and foreign NPC/NextBot attackers are never delayed; direct self-defense is unaffected. Police are never delayed, including an officer driving past in a car. A blocked witness gets no enemy whether it was calm or already busy. This is event pacing, not a global pause of ongoing combat. Enemy sharing between visible gang allies bypasses this cooldown.

These cvars are server settings; definitions: `cvars/sh_cvars.lua`. For baseline civilian/police reactions see [brains](brains.md).

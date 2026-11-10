# Gangs and combat pacing

Server sources: `config/actors/sh_gangs.lua`, `systems/sv_fight_roster.lua`, `systems/sv_fight_cooldown.lua`, `systems/npcs/sv_gang_pack.lua`, `sv_gang_models.lua`.

## Gang identity

`gangster_crows` (Black Raven) and `gangster_wolves` (Red Wolf) inherit `gangster`. Each has `gang = 'crows'|'wolves'` and teams `bandits` plus `gang_<id>`. Both are enabled, each with `fullness = 5` (5% of `bgn_max_npc`). Light members use pistols and citizen clothing; 35% heavy members use rebel equipment and SMG/AR2. Gang model selection also applies to NextBot bodies. Models/materials are shipped in the addon.

Gangsters of every gang type (`gangster` and both gangs; `respawn_delay = 30` is inherited from `gangster`) come back no sooner than 30 seconds after a death of their type, one per 30 seconds. `racer_driver` also inherits `gangster` but sets `respawn_delay = 0`. Both spawners read the resolved (inherited) config.

Gang alliance uses gang identity, not the common bandits tag: rivals do not join one another's protection calls. Police/car access still uses team rules.

## Fight roster

The first enemy opens a roster for that gang against that enemy: initiator plus nearby living members on foot within 1000 units, nearest first. A random cap of 2–6 includes the initiator; each helper rolls `bgn_gang_help_chance` (default **1%**), so the actual roster may be smaller. Other members ignore that enemy and protection calls. A member directly hit by the enemy joins and fights back even beyond the original cap.

A calm member can start a rival-gang fight within 700 units, checked every 10 seconds with `bgn_gang_war_chance` (default **0.5%**, `0` disables). Police/player intervention is handled through each gang's own roster.

## Pack walking

Walking members look for a same-gang walking leader within 1500 units: lowest entity index among eligible members. Followers aim 100–250 units around its destination and recheck after 8 seconds. Other actor types keep normal walking.

## Protection cooldown

`bgn_fight_cooldown` defaults to **60 seconds**, `0` disables. The first protection `defense` reaction opens a window within 2500 units. During it, protection against another actor attacker in that area is ignored, without adding that enemy. Joining against the same attacker is allowed. Player attacks and foreign NPC/NextBot attackers are never delayed; direct self-defense is unaffected. Police are never delayed, including an officer driving past in a car. A blocked witness gets no enemy whether it was calm or already busy. This is event pacing, not a global pause of ongoing combat.

These cvars are server settings; definitions: `cvars/sh_cvars.lua`. For baseline civilian/police reactions see [brains](brains.md).

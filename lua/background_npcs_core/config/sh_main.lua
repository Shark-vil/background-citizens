-- Actors (NPC) data table
bgNPC.cfg.actors = bgNPC.cfg.actors or {}

-- Actors (NPC) data table (Outdated)
bgNPC.cfg.npcs_template = bgNPC.cfg.npcs_template or {}

-- Optional parameter to synchronize animation timing with clients.
-- Requires a lot of network bandwidth.
-- Use this only when necessary.
bgNPC.cfg.SyncUpdateAnimationForClient = false

-- Provides the most basic synchronization of states.
-- The client will not receive information about the date, only state name.
-- Disable this if you want to transfer all data (may affect network bandwidth)
bgNPC.cfg.EnableEasySyncStateDataForClient = true

-- The update rate of the random state change.
-- The default is 5 seconds
bgNPC.cfg.RandomStateAssignmentPeriod = 5

-- Allow killing friendly NPCs
-- If enabled, the player can kill allies
bgNPC.cfg.EnablePlayerKilledTeamActors = true

-- A weapon that belongs to the "melee" category.
-- Necessary for some states to work correctly.
bgNPC.cfg.melee_weapons = {'weapon_crowbar', 'weapon_stunstick', 'none'}
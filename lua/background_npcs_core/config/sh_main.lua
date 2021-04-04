-- Optional parameter to synchronize animation timing with clients.
-- Requires a lot of network bandwidth.
-- Use this only when necessary.
bgNPC.cfg.SyncUpdateAnimationForClient = false

-- Provides the most basic synchronization of states.
-- The client will not receive information about the date, only state name.
-- Disable this if you want to transfer all data (may affect network bandwidth)
bgNPC.cfg.EnableEasySyncStateDataForClient = true

-- The update rate of the random state change.
-- The default is 3 seconds
bgNPC.cfg.RandomStateAssignmentPeriod = 3

-- Allow killing friendly NPCs
-- If enabled, the player can kill allies
bgNPC.cfg.EnablePlayerKilledTeamActors = true
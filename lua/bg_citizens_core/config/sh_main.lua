-- Developer mode.
-- In developer mode, a lot of technical information is output to the console.
bgNPC.cfg.debugMode = false

-- Creates files with preset points for maps:
-- gm_bigcity_improved
-- rp_southside
bgNPC.cfg.loadPresets = true

-- Optional parameter to synchronize animation timing with clients.
-- Requires a lot of network bandwidth.
-- Use this only when necessary.
bgNPC.cfg.syncUpdateAnimationForClient = false

-- The update rate of the random state change.
-- The default is 3 seconds
bgNPC.cfg.RandomStateAssignmentPeriod = 3

-- Allow killing friendly NPCs
-- If enabled, the player can kill allies
bgNPC.cfg.EnablePlayerKilledTeamActors = true
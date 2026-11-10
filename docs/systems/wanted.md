# Wanted levels and offenders

Sources: `systems/wanted/`, `systems/sv_offender.lua`, `config/states/sh_wanted.lua`. The server owns wanted state and reactions; clients receive records and render the HUD/halos.

| Server cvar | Default | Purpose |
|---|---|---|
| `bgn_enable_wanted_mode` | `1` | Enables wanted behavior; changing it clears existing wanted entries. |
| `bgn_wanted_time` | `30` | Base wanted duration in seconds. |
| `bgn_wanted_level` | `1` | Allows level escalation (up to level 5). |
| `bgn_wanted_police_instantly` | `1` | Enables immediate police response handling. |
| `bgn_wanted_impunity_limit` | `5` | Impunity threshold used by wanted actions. |
| `bgn_wanted_impunity_reduction_period` | `10` | Seconds between impunity reductions. |

Kills, witnesses, police calls and arrest refusal feed wanted handling. Ignored/arrested players and medic actors are excluded from new wanted entries. Actor wanted identity survives DV body replacement. Non-player wanted actors unseen by players for 15 seconds are dropped; this is separate from player wanted expiry and population removal.

A resident who kills a resident or damages a police car by ramming becomes an offender (the officers react to a ram by an actor-driven car only with 10% per hit; otherwise it is ignored and does no damage to them, `modules/dv/sv_car_damage_reaction.lua`): it loses residents and gains offenders in its own configuration copy. The team is not automatically restored when wanted expires. Witnessed crimes can also create wanted state when enabled. See [brains](brains.md) for reactions and [arrest](arrest.md) for surrender/refusal.

## Integration

Obtain `local wanted = bgNPC.Modules.Get('wanted')` after systems load; it may be nil before then or in a different realm. Query `wanted:HasWanted(entity)`, `GetWanted(entity)` and `GetAllWanted()`. Change state on SERVER with `AddWanted(entity, time)` and `RemoveWanted(entity)`; adding an existing target does not reset or extend its timer. The returned wanted record supports `UpdateWanted(time)`, `SetLevel(level)`, `LevelUp()` and `LevelDown()`; nonpositive SetLevel removes wanted, levels above 5 are capped.

Hooks include `BGN_AddWantedTarget`, `BGN_RemoveWantedTarget`, `BGN_WantedLevelUp`, `BGN_WantedLevelDown`. The server sends existing records to a player on `BGN_PlayerReady`. Client UI options do not disable the authoritative server system.

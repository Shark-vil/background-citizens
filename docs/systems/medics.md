# Medics and bodies

Server owners: `systems/sv_medics.lua`, `systems/sv_corpses.lua`, states `sv_medic_revive.lua`, `sv_police_inspect_body.lua`; client fading: `systems/cl_corpses.lua`.

Eligible actor deaths create calls. A free medic responds, otherwise the system can spawn one; an ambulance is optional and requires DV, configured installed vehicles and road waypoints. A call is not a guarantee of revival: availability, danger and body lifetime still apply. Medics release completed/closed calls rather than remaining assigned forever.

| Server cvar | Default | Meaning |
|---|---|---|
| `bgn_medic_hopeless_chance` | `25` | Percent of ordinary deaths considered hopeless. |
| `bgn_medic_danger_time` | `60` | Avoid the area of a murdered colleague for this many seconds or until the killer dies; `0` disables. |
| `bgn_corpse_cleanup` | `0` | Optional BGN corpse fading; disabled by default. |
| `bgn_corpse_cleanup_time` | `60` | Seconds after death before cleanup may begin. |

A call is created only when a living ally of the victim (same team) sees the body at the moment of death. Only the innocent are saved: no call for an actor at war with the residents (it counted one of them as an enemy, or one of them counted it), nor for one whose teammate is fighting the residents at that moment; residents themselves always qualify. Explosions and bullet/buckshot hits within 150 units are always hopeless. Vehicle impacts use the normal chance and can be saved. A medic gives a verdict; police can run to inspect the body. A medic en route or an officer inspecting it postpones cleanup until the activity finishes. Reviving retires the matching body record. Server ragdolls fade server-side; client ragdolls receive removal events. When BGN cleanup is disabled, it does not block `npc_battle_cleanup`.

Medics/ambulances are protected from police enemy/wanted/offender handling and ambulance confiscation. These are targeted service-role rules, not general invulnerability.

For seated character death and physics limits see [vehicles](vehicles.md); for verification tools see [testing](testing.md).

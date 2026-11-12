# GetActiveWeapon

Realm: **SHARED** (supported usage).

```lua
actor:GetActiveWeapon()
```

Returns a weapon entity or NULL; a seated visual may have no active weapon.
Carried parcels, suitcases/briefcases and newspapers are excluded from this combat-facing API in both realms. The native entity
can still return its carry weapon; see [carried items](../../../tutorials/Modification-of-Existing-NPCs.md#carried-items).

Source: `lua/background_npcs_core/actor/components/sh_combat.lua`.

[Realm reference](../../../reference/shared.md).

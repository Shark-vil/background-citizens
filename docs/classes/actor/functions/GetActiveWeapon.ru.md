# GetActiveWeapon

Область: **SHARED** (поддерживаемое использование).

```lua
actor:GetActiveWeapon()
```

Возвращает сущность оружия либо NULL; у визуальной модели пассажира активного оружия может не быть.
Паёк и чемодан исключены из этого боевого API в обеих областях. Сама движковая сущность может возвращать
своё оружие-предмет; см. [предметы в руках](../../../tutorials/Modification-of-Existing-NPCs.md).

Исходник: `lua/background_npcs_core/actor/components/sh_combat.lua`.

[Справочник областей](../../../reference/shared.md).

# HasEnemy

Окружение: **SHARED**.

```lua
actor:HasEnemy(ent)
```

Проверяет наличие ent в списке врагов. SERVER возвращает false для текущего союзника даже при устаревшей записи; CLIENT читает полученный снимок списка.

Исходник: `lua/background_npcs_core/actor/components/sh_enemies.lua`.

[Справочник окружений](../../../reference/shared.md).

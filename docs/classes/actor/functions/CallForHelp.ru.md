# CallForHelp

Realm: **SERVER**.

```lua
actor:CallForHelp(enemy)
```

Просит живых союзников в радиусе 1000 единиц с LOS к зовущему отреагировать на врага. Видеть врага необязательно; FOV не проверяется. Нужны механика `call_for_help`, допустимый враг и живой зовущий. `BGN_PreCallForHelp` отменяет вызов; защита ареста, запреты назначения врагов и пауза защиты сохраняются.

Исходник: `lua/background_npcs_core/actor/components/sh_combat.lua`.

[Серверный справочник](../../../reference/server.md).

--[[-----------------------------------------
   Spawn settings menu
--]]
return {
  ['bgn.settings.spawn.bgn_dynamic_nodes'] = 'Динамическая сетка передвижения',
  ['bgn.settings.spawn.bgn_dynamic_nodes.description'] = 'Описание: позволяет генерировать сетку передвижения автоматически вокруг игроков. Это полезно, когда у карты нету файла сетки передвижения. Обратите внимание, что это ресурсозатратный процесс. Рекомендуется создать сетку передвижения самому, или сгенерировать, если на карте есть AI NavMesh.',
  ['bgn.settings.spawn.bgn_dynamic_nodes_restict'] = 'Ограничение динамической сетки передвижения',
  ['bgn.settings.spawn.bgn_dynamic_nodes_restict.description'] = 'Описание: если включено, то сетка будет генерироваться только тогда, когда на карте нету файла сетки передвижения. В противном случае всегда будет использоваться автоматическая генерация.',
  ['bgn.settings.spawn.bgn_dynamic_nodes_type'] = 'Тим динамической сетки',
  ['bgn.settings.spawn.bgn_dynamic_nodes_type.description'] = 'Описание:\n' .. 'random - сетка будет генерироваться рандомно. Повышает разнообразие, но точность значительно ниже. В узких коридорах может вообще не работать.\n' .. 'grid - сетка генерируется в шахматном равномерном порядке по всей площади вокруг игрока. Меньше рандома, но больше шансов заполнить область точками перемещения. (Рекомендуется)',
  ['bgn.settings.spawn.bgn_spawn_radius'] = 'Радиус спавна НПС',
  ['bgn.settings.spawn.bgn_spawn_radius.description'] = 'Описание: радиус появления NPC относительно игрока.',
  ['bgn.settings.spawn.bgn_spawn_radius_visibility'] = 'Радиус активации проверки видимости точки',
  ['bgn.settings.spawn.bgn_spawn_radius_visibility.description'] = 'Описание: запускает проверку видимости NPC в этом радиусе, чтобы избежать появления сущностей перед игроком.',
  ['bgn.settings.spawn.bgn_spawn_radius_raytracing'] = 'Радиус активации проверки видимости точки с использованием трассировки лучей',
  ['bgn.settings.spawn.bgn_spawn_radius_raytracing.description'] = 'Описание: проверяет точки появления NPC с помощью трассировки лучей в заданном радиусе. Этот параметр не должен быть больше - bgn_spawn_radius_visibility. 0 - отключить проверку',
  ['bgn.settings.spawn.bgn_spawn_block_radius'] = 'Радиус блокировки появления NPC относительно каждого игрока',
  ['bgn.settings.spawn.bgn_spawn_block_radius.description'] = 'Описание: запрещает спавн NPC в заданном радиусе. Не может быть больше параметра - bgn_spawn_radius_ray_tracing. 0 - отключить проверку',
  ['bgn.settings.spawn.bgn_spawn_period'] = 'Период между появлением NPC (изменение требует перезапуска)',
  ['bgn.settings.spawn.bgn_spawn_period.description'] = 'Описание: устанавливает задержку между спавном каждого NPC.',
  ['bgn.settings.spawn.bgn_actors_teleporter'] = 'Телепортация NPC',
  ['bgn.settings.spawn.bgn_actors_teleporter.description'] = 'Описание: вместо удаления NPC после потери его из поля зрения игроков, он будет телепортироваться в ближайшую точку. Это создаст эффект более населённого города. Отключите эту опцию, если замечайте потерю кадров.',
  ['bgn.settings.spawn.bgn_actors_max_teleports'] = 'Максимум NPC для телепортации',
  ['bgn.settings.spawn.bgn_actors_max_teleports.description'] = 'Описание: сколько NPC можно телепортировать за одну секунду. Чем больше число - тем больше вычислений будет производится. Телепорт вычисляется для каждого актёра индивидуально, не дожидаясь телепорта другого актёра из своеё группы.'
}
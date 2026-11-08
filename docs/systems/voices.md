# Voices

NPC phrases are voiced (XTTS-v2, generated): citizens (calm, fear, the 911 call after the operator answers; a
male and a female take), the police (combat shouts, arrest orders, detention, squad formation calls, wounded
falling back, officer down, luggage warnings, reporting and writing down a body) and every conversation line. English and Russian; the police speak through a radio filter.

## Who plays what

The setting is per player (client only). The server never plays a voice clip: it only tells every client
who says which line, and each client plays it in its own language, or not at all.

| Cvar (client) | Default | Meaning |
|---|---|---|
| `bgn_cl_voices` | `1` | `1` voiced (the old Half-Life 2 sound where a line has no clip), `2` only the old Half-Life 2 sounds, `0` silent |
| `bgn_cl_ui_language` | `auto` | language of the menu, hints, phrases and voices: `auto` (the game language), `english`, `russian` |

Settings window: **My settings**. The server's `bgn_module_replics_language` still forces one phrase language
for everyone when it is not `auto`.

## Lines

Phrases live in `lua/background_npcs_core/config/replics/language/sh_<language>.lua`
(`bgNPC.cfg.replics[id]`). A clip is

```
sound/background_npcs/vo/<language>/<id>/<index>[_f].ogg
```

`index` is the phrase's place in its table, `_f` the female take (picked by the model's file name: female /
woman / women first, then male / man / men). So the voice-only tables (`police_*`, `gangster_*`, `stare_*`,
`brawl_*`, `call_911`) and conversation tables (`conv_*`) must have the same number of lines, in the same order, in every
language.

```lua
-- text over the head + voice (the index must exist in the English table, the server's)
actor:SayReplic('fear', 3)
-- voice only: each client picks a random line of the table; fallback: the sound for "Half-Life 2" mode
actor:Voice('police_arrest_order', 'npc/metropolice/vo/getdown.wav')
-- only the fallback (for players without voices)
actor:Voice(nil, 'npc/metropolice/vo/defender.wav')
```

## Generating clips

`tools/make_voices.py` (not shipped) reads the language files and `config/states/sh_conversations.lua`
and voices only new or changed lines (`tools/voices_state.json`); clips of removed lines are deleted.
In a conversation every participant keeps one voice. It uses the XTTS worker and dxRevive of the mlp-g5
pipeline (`D:/mlp-g5-work/pipeline/scripts/voice_tts.py`, read-only: nothing there is changed).

```
D:/mlp-g5-work/tools/tts_venv/Scripts/python tools/make_voices.py [--force] [--only <line id>]
```

Mono Ogg Vorbis, 44.1 kHz, about 20 KB a clip.

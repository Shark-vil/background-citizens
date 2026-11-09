# Voices

NPC phrases are voiced (XTTS-v2, generated): citizens (calm, fear, the 911 call after the operator answers; a
male and a female take), the police (combat shouts, arrest orders, detention, squad formation calls, wounded
falling back, officer down, luggage warnings, reporting and writing down a body, confiscating a car), gangsters (carjacking) and every conversation line. English and Russian; the police speak through a radio filter.

## Who plays what

The setting is per player (client only). The server never plays a voice clip: it only tells every client
who says which line, and each client plays it in its own language, or not at all.

| Cvar (client) | Default | Meaning |
|---|---|---|
| `bgn_cl_voices` | `1` | `1` voiced, `0` silent; the same conversation clips in both actor modes |
| `bgn_cl_voice_language` | `auto` | language of the NPC phrases and voices: `auto` (the game language), `english`, `russian` |

Settings window: **My settings**. The server's `bgn_module_replics_language` still forces one phrase language
for everyone when it is not `auto`.

The police combat shouts (`police_combat`, `police_contact`) fire on every hit and every entry into combat, so
`Actor:Voice` lets one of them through per officer every 20 s (`COMBAT_VOICE_COOLDOWN` in
`actor/components/sh_speech.lua`). Other lines (arrest, officer down, body report) have no cooldown.

Text over the head (`actor/cl_actor_text_say.lua`): a dark plate with the speaker's name in the team color
(police blue, medics green, bandits orange, zombies yellow-green, others grey), an accent bar and the line
wrapped by words. It rises and fades in, fades out at the end and from 600 to 800 units away.

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
-- voice only: each client picks a line; the event sound is a fallback if the clip is missing
actor:Voice('police_arrest_order', 'npc/metropolice/vo/getdown.wav')
-- event sound only (also muted by bgn_cl_voices 0)
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

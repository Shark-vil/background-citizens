# Conversations, fights and staring

Code: `lua/background_npcs_core/systems/dialogue/sv_conversation.lua`. Off with `bgn_disable_dialogues 1`.

## Conversations

An actor in a calm state may enter the `dialogue` state (its `at_random` weight). It looks for free calm
actors within 400 units in sight and picks a script all of them fit (weighted by `chance`). They walk to
places around a point (8 s at most), face each other and say the lines one after another with gestures.
Text appears over the speaker's head, the voice plays on clients that have it on ([Voices](./voices.md)).
Anything that changes one participant's state (danger, damage) ends the conversation for all.

SERVER suppresses random state phrases and ambient coughs for all participants while gathering, talking
or reacting to a player's interruption. These resume after the actor leaves the conversation;
scripted lines and the conversation's player reactions still play normally on CLIENT.

Scripts: `config/states/sh_conversations.lua`, phrases: `bgNPC.cfg.replics['conv_<id>']` in each language file.

```lua
table.insert(bgNPC.cfg.conversations, {
	id = 'my_talk',                        -- bgNPC.cfg.replics['conv_my_talk'] = { ... 3 phrases ... }
	roles = { 'police', { 'citizen', 'taxi_driver' } }, -- actor types, 2 or 3 participants
	lines = { { 1 }, { 2, 'scared' }, { 1, 'angry' } }, -- { speaker role, mood }: talk wave angry laugh scared
	final = 'flee',                        -- optional, see below
	chance = 10,                           -- relative weight, default 10
})
```

| final | What happens |
|---|---|
| *(none)* | they go back to their business; a player may interrupt |
| `fight` | roles 1 and 2 start a fist fight |
| `attack` | role 2 opens fire on role 1 (and role 1 fights back) |
| `flee` | role 2 runs from role 1. Police as role 1: half the time the suspect gives up and is arrested, otherwise the police open fire |
| `run_off` | role 1 runs off somewhere |

The self-test `conversations.scripts` checks that every script has as many phrases as lines.

## Interrupting

A player within 250 units who looks at an ordinary conversation (no `final`) for 2 s interrupts it with a 50%
chance, once per conversation: they turn to the player and one of them tells them off
(`conv_interrupt`, `police_interrupt`, `gangster_interrupt`).

## Staring

A player within 350 units staring at someone standing still (`idle`, `random_gesture`):

| Staring | Reaction |
|---|---|
| 3 s | turns to the player and says something (`stare_1`) |
| 7 s | warns (`stare_2`) |
| 11 s | gangsters and thieves start a fist fight, civilians half the time (otherwise walk away); police only warn |

The police and gangster variants are `police_stare_*` and `gangster_stare_*`.

## Fist fights

The `brawl` state (group `assault`): no weapons, the hits change health directly, so they are not damage
events: nobody calls it a murder, nobody gets wanted, the police don't shoot. An NPC that drops to 35% health
gives up and runs; a player is beaten down to 15 HP, never killed (a player's own fist hits on the fighter land,
without the usual reaction). A police officer who sees a fight (arrest mode on) arrests both fighters one after
another; NPC fighters give up and wait (`arrest_surrender`). The fight ends after 45 s or at 800 units apart.

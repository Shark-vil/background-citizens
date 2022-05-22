# Editing Actor Configuration

Sometimes it may be necessary to slightly change the parameters of the actors, rather than create new ones.

To get started, check out this article to understand the steps:
[Creating Custom NPCs](./Creating-Custom-NPCs.md)

## 1. Follow the steps to create a workspace.

These actions are described in the article on creating your own actors.

## 2. Code preparation.

Paste the following code into the configuration file:

```lua
bgNPC.cfg:EditActor('citizen', {
	team = { 'player' },
	at_damage = { ['defense'] = 100 },
	at_protect = { ['defense'] = 100 }
})
```

The "*EditActor*" function is very similar to the "*SetActor*", but there is one difference. It does not replace all the data, only the ones you have passed.

In this example, we changed the following parameters:

- team
- at_damage
- at_protect


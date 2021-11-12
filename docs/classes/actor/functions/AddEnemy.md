# AddEnemy

## SERVER
```lua
	ACTOR:AddEnemy(Entity enemy, string reaction:nil, boolean always_visible:false)
```

## Description
Sets the reaction of the actor to the event. Used in system computing.

## Arguments
1. **enemy** Entity - Any entity target.
1. **reaction** string - Actor reaction when adding an enemy. If it is fear, then "[AddEntityRelationship](https://wiki.facepunch.com/gmod/NPC:AddEntityRelationship)" will be called internally with the [D_FR](https://wiki.facepunch.com/gmod/Enums/D#D_FR) parameter. Any other value will set the - [D_HT](https://wiki.facepunch.com/gmod/Enums/D#D_HT) parameter.
1. **always_visible** boolean - If "true", then the enemy will not be automatically removed from the list after the expiration of time if lost from sight.
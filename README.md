# Background NPCs

[![gLua](https://img.shields.io/badge/Language-gLua-blue.svg)](https://wiki.facepunch.com/gmod)
[![Workshop Subscribers](https://img.shields.io/badge/Workshop-Over_50000_sub.-green.svg)](https://steamcommunity.com/sharedfiles/filedetails/?id=2341497926)
[![Favorite](https://img.shields.io/badge/Favorite-Over_5000_fav.-1abc9c.svg)](https://steamcommunity.com/sharedfiles/filedetails/?id=2341497926)
![Open source](https://img.shields.io/badge/Open_source-yes-brightgreen.svg)
[![Documentation](https://img.shields.io/badge/Documentation-EN%20%7C%20RU-blue.svg)](https://shark-vil.github.io/background-citizens/)

## Requirements
No other addons are required: since version 2.0 the addon no longer depends on SLibrary.

Optional: [Decent Vehicle](https://steamcommunity.com/sharedfiles/filedetails/?id=1587455087) for actors driving cars
(police, taxi, ambulances).

## General
***
### **Short information**
This is an addon that will automatically spawn NPCs on the map at predetermined movement points. NPCs can walk around the map, perform random actions, attack or defend.

### **Performance**
Background work uses a shared scheduler with a per-tick budget. Spawning, visibility checks and unseen-actor recycling limit active population; actual performance depends on actor counts, the map and other addons.

### **Assignment**
This addon can rather be considered a base for development. There is basic functionality here, but if you are a developer, you can fairly easily extend the system to suit your conditions and for any gamemode.

## Current code: 2.3.1

The repository includes changes after tag 2.3.0: stable vehicle occupants, traffic recovery, gang rosters and pack walking, medic verdicts and corpse handling, policing and spawn fixes. See the [version history](docs/history.md) for release boundaries and the [architecture](docs/architecture.md) for files, loading and subsystem relationships. The current defaults are engine NPC bodies and FSM; NextBot bodies and GOAP are optional. SLibrary is no longer required.

For developers: [server API](docs/reference/server.md), [client API](docs/reference/client.md), [shared API](docs/reference/shared.md). AI contributors start with [AGENTS.md](AGENTS.md) and [documentation rules](docs/ai.md).

## Documentation
***
[English documentation](https://shark-vil.github.io/background-citizens/) · [Документация на русском](https://shark-vil.github.io/background-citizens/ru/)

Installation, settings, map navigation, practical Lua examples and API reference. To preview or validate the site locally, see [Building the docs](docs/contributing.md).

## Community
<a href="https://www.patreon.com/shark_vil">
	<img src="https://i.imgur.com/gy40FXn.png" width="532" height="169">
</a>
<a href="https://discord.gg/wZwtQTU">
	<img src="https://i.imgur.com/H7T9J3N.png" width="532" height="169">
</a>

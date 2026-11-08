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
The addon is quite optimized and almost does not generate lags. NPCs are removed when they disappear from the player's field of view, and appear with a certain delay. The spawn process is performed between server frames, which does not create unnecessary lags.

### **Assignment**
This addon can rather be considered a base for development. There is basic functionality here, but if you are a developer, you can fairly easily extend the system to suit your conditions and for any gamemode.

## What's new in 2.0
The core was rewritten from scratch:
* **No SLibrary** - everything the addon needs is built in.
* **NextBot actors** - on maps with a NavMesh actors are NextBots with HL2 models; on other maps they are HL2 NPCs
  walking the map's nodegraph or the addon's own movement points.
* **Two brains** - a light state machine for calm civilians and a GOAP planner for fights: taking cover, calling
  backup, surrendering.
* **Wanted levels** - police, civil defense and special forces get harder level by level; with the wanted mode off
  they spawn like regular actors.
* **Performance** - one scheduler with a per-tick time budget for all background work, simplified updates for far
  actors.
* **New settings window** with search.

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

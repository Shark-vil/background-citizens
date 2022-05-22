# Creating Custom NPCs

## 1. Preparing the workspace

If you want to create your own NPCs (Actors), you need to create a module using LUA scripts. *You can't do it through the game*, at least not now.


### **1.1.** Go to the game's addons folder.

*Example:*

> C:\SteamLibrary\steamapps\common\GarrysMod\garrysmod\addons

### **1.2.** Create a folder where your future module will be. It is recommended to name the folder in small letters, no spaces!

*Example:*

> my_first_module

In the end, you should end up with something like this:

> C:\SteamLibrary\steamapps\common\GarrysMod\garrysmod\addons\my_first_module

### **1.3.** Now you need to create a basic folder structure for the addon. Consider the simplest structure.

*Example:*

```
📦my_first_module
 ┗ 📂lua
 ┃ ┗ 📂background_npcs_core
 ┃ ┃ ┗ 📂custom_modules
 ┃ ┃ ┃ ┣ 📂config
 ┃ ┃ ┃ ┃ ┗ 📜sh_my_first_module_cfg.lua
 ┃ ┃ ┃ ┣ 📂postload
 ┃ ┃ ┃ ┃ ┗ 📜sh_my_first_module_postload.lua
 ┃ ┃ ┃ ┗ 📂preload
 ┃ ┃ ┃ ┃ ┗ 📜sh_my_first_module_preload.lua
```

*Explanation:*

> The names of the ".lua" files are given as an example. It is recommended to give unique filenames and create additional directories to avoid possible mod conflicts.

Let's get familiar with the folder structure. There are three main folders for modules:

- **config** - is loaded after the standard addon configuration files have been initialized. This is the right place to make changes to the configs.
- **preload** - loaded after "config", before loaded all main addon scripts. You can use this place to edit the cvars of the addon, or other things that need to be done before the starts main scripts.
- **postload** - loaded last, after all the main files have been loaded. You can use this space to add new hooks and states for actors.

The file prefix is also important (*files will not be loaded without prefix!*):

- **cl_** - loads the script only on the client side.
- **sv_** - loads the script only on the server side.
- **sh_** - loads the script for both sides. (*Recommended to always use when setting up configs*)

*Explanation:*

> You don't have to create all the folders if you don't intend to use them.

## 2. Creating an actor

### **2.1.** Let's create a new actor in the file, which is located in the "config" section.

*Example:*

```
📦my_first_module
 ┗ 📂lua
 ┃ ┗ 📂background_npcs_core
 ┃ ┃ ┗ 📂custom_modules
 ┃ ┃ ┃ ┣ 📂config
 ┃ ┃ ┃ ┃ ┗ 📜sh_yay_new_actor.lua
```

Put the following content inside the file:

```lua
bgNPC.cfg:SetActor('gigachad', {
	enabled = true,
	class = 'npc_citizen',
	name = 'This Real Gigachad',
	fullness = 64,
	team = { 'residents' },
	health = 1000,
	at_random = {
		['walk'] = 50,
		['idle'] = 50,
	},
	at_damage = {
		['defense'] = 100
	},
	at_protect = {
		['defense'] = 100
	}
})
```

The "bgNPC.cfg:SetActor" function consists of 2 arguments:
1. **ID** - in this example, our ID will be: "gigachad"
2. **Actor data** - lua table

Consider the options:

- **enabled** - whether the actor is enabled by default in the options menu or not (*true / false*)
- **class** - NPC entity class. May be in the form of a string or a list of strings (*string / table*)
- **name** - the name of the actor, which is displayed in the options menu (*string*)
- **fullness** - percentage filling from **0** to **100**. Used when changing the slider for the total number of NPCs on the map (*number*)
- **team** - team to which the actor belongs (*table*)
- **health** - actor's starting health (*number*)
- **at_random** - actions that the actor will perform after a random period of time (*table*)
- **at_damage** - actions that the actor will take if he is attacked (*table*)
- **at_protect** - actions an actor will take if his ally is attacked (*table*)

Now if you save the file and start the game, you will have a new actor. If you were in the game when the file was created, the game must be restarted!

If you have already created an addon directory, then you do not need to restart the game. It will be enough for you to save the file again or re-enter the map if you have made changes to the config.

### **2.2.** Let's consider in detail all the parameters that can be added to the actor:

[Actor Configuration Options](./Actor-Config-Settings.md)
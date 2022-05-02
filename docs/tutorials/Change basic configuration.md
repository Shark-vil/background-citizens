## How to add or change NPC parameters?

### 1. Download one of the ready-made examples:

- [NPC model changing module](https://github.com/Shark-vil/background-npcs-example-module)
- [Module adding more vehicles](https://github.com/Shark-vil/background-npcs-gta-sa-cars)

### 2. Place the example in the game folder:

- ..\GarrysMod\garrysmod\addons

### 3. Change the name of the files and folders to your own. Example:

- **bgn_my_custom_models**\lua\background_npcs_core\custom_modules\config\\**mynick_folder\sh_my_custom_module.lua**

You can just put the file in the "config" folder, but then it is recommended to come up with a more unique file name:

- **bgn_my_custom_models**\lua\background_npcs_core\custom_modules\config\\**sh_mynick_my_custom_module.lua**

### 4. See the standard config for orientation:

[sh_npcs.lua](https://github.com/Shark-vil/background-citizens/blob/master/lua/background_npcs_core/config/sh_npcs.lua)

### 5. Add your parameters to your lua script. Example:

```lua
	-- Gets the config of the actor with the ID Key "citizen"
	local citizen = bgNPC.cfg.actors['citizen']
	-- Change or add parameters:
	citizen.random_skin = true
	citizen.random_bodygroups = true
	citizen.models = {
		'boba.mdl',
	}
```

### 6. If you're done and want to upload the configuration to the workshop, use any of these tutorials:

- [Workshop Addon Creation](https://wiki.facepunch.com/gmod/Workshop_Addon_Creation)
- [How to upload to Workshop [EASY]](https://steamcommunity.com/sharedfiles/filedetails/?id=160789919)
- [How to publish an addon to the Steam workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=2157426798)
- [GMod-Easy-Addon-Uploader](https://github.com/EstevanTH/GMod-Easy-Addon-Uploader)
- [Создание GMA и публикация в WorkShop](https://steamcommunity.com/sharedfiles/filedetails/?id=846444270)
- [Загрузка аддона в мастерскую без использования сторонних программ](https://steamcommunity.com/sharedfiles/filedetails/?id=1199456895)
- [Создание и загрузка аддона в WorkShop](https://steamcommunity.com/sharedfiles/filedetails/?id=684046980)
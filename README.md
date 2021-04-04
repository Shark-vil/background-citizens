# Background NPCs

[![gLua](https://img.shields.io/badge/Language-gLua-blue.svg)](https://wiki.facepunch.com/gmod)
[![Workshop Subscribers](https://img.shields.io/badge/Workshop-Over_50000_sub.-green.svg)](https://steamcommunity.com/sharedfiles/filedetails/?id=2341497926)
[![Favorite](https://img.shields.io/badge/Favorite-Over_5000_fav.-1abc9c.svg)](https://steamcommunity.com/sharedfiles/filedetails/?id=2341497926)
![Open source](https://img.shields.io/badge/Open_source-yes-brightgreen.svg)
[![Documentation](https://img.shields.io/badge/Documentation-In_developing-yellow.svg)](https://background-npcs.itpony.ru/wiki)

## WARNING
**BE SURE TO SUBSCRIBE TO THE LIBRARY SLibrary:**
* **[SLibrary in workshop](https://steamcommunity.com/workshop/filedetails/?id=2404080563)**
* **[SLibrary in GitHub](https://github.com/Shark-vil/slib-garrysmod)**

## General
***
### **Short information**
This is an addon that will automatically spawn NPCs on the map at predetermined movement points. NPCs can walk around the map, perform random actions, attack or defend.

### **Performance**
The system is quite optimized and almost does not load the system. NPCs are removed when they disappear from the player's field of view, and appear with a certain delay. The spawn process is performed between server frames, which does not create unnecessary lags.

### **Assignment**
This addon can rather be considered a base for development. There is basic functionality here, but if you are a developer, you can fairly easily extend the system to suit your conditions and for any gamemode.

## F.A.Q.
***
* **[How do I use a wiki?](https://background-npcs.itpony.ru/wiki/How%20do%20I%20use%20a%20wiki?)**
* **[How to change config?](https://background-npcs.itpony.ru/wiki/How%20to%20change%20config)**
* **[Nothing works for me!](https://background-npcs.itpony.ru/wiki/Nothing%20works%20for%20me!)**

## Documentation
***
### **Warning**
The wiki is currently under development and some methods may not be described. When the wiki is complete, this warning will be removed.

[WIKI SITE](https://background-npcs.itpony.ru/wiki)
---

### **Simple code example:**
```LUA
-- The hook is called when the NPC is looking at an object.
-- In this example, the police give the player 2 warnings with animation, and then push him away.
hook.Add("BGN_ActorLookAtObject", "BGN_PoliceWarnAndPushPlayerIfHeIsClose", function(actor, ent)
    if ent:IsPlayer() and actor:GetType() == 'police'
        and actor:GetState() == 'walk'
        and actor:IsSequenceFinished()
    then
        if ent:GetPos():DistToSqr(actor:GetNPC():GetPos()) > 50 ^ 2 then return end

        -- Get temporary table of state data
        local data = actor:GetStateData()
        -- Add a variable to the temporary state table, if it does not exist
        data.LuggageWarn = data.LuggageWarn or 0

        if data.LuggageWarn < 2 then
            -- Play warn animation
            actor:PlayStaticSequence('LuggageWarn')
            data.LuggageWarn = data.LuggageWarn + 1
        else
            -- Play push animation
            actor:PlayStaticSequence('LuggagePush')

            -- A local function that pushes the player away from the entity
            TargetPlayerPush(actor:GetNPC(), ent, 250)

            data.LuggageWarn = 0
        end
    end
end)
```

NPCs do not have extra code and overloaded tables. For each background NPC an "**Actor**" class is created, through which most actions are carried out. This makes the code cleaner.

## Performance testing
During testing, we used the factory settings of cvars.

### Local Server
#### **Disable Background NPCs**
![Disable Background NPCs](https://i.imgur.com/Gf6ZKPM.jpg)

#### **Enable Background NPCs**
![Enable Background NPCs](https://i.imgur.com/xDAcsvn.png)
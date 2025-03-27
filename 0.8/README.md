# PurPur - By Mrakavin

(See prior history on 1.18)


SEE Also: For the definitive history, URLS and active settings for plugins

- https://docs.google.com/spreadsheets/d/1k-CjHgdkYe0VpXqdL3o6171wFg4ZbaG6HXGlnmwNCy8/edit#gid=0 for de
 

Running with Spigot MINIMAL. Especially avoid HUGE mods like SlimeFun which seems
to be a challenge to update (at least to 1.18) and tends to levels of plugin distraction.

System:
  - Spigot (prefer more optimized systems)
  - PaperMC (has always been a good choice)
  - OK - Purpurmc  (based on papermc, more optimizations, but has some really useful settings like Silk-touch mining spawners)
    - Mostly to get silk touch spawner support

Goals:
  - PVE (no grief protection)
  - Keep plugins limited and focus on long life, well maintained plugins
  - Try not tweak configurations
  - Economy based is NOT needed for our users
    - BUT it might be useful as a way to convert useless ivnetory to money (like fom mcMMO)
  - Shops and trade are not usually needed. While used in past it was mostly to deal with tuning
  or provide items that was command based.



## 0.7 @ 2023-12-01

- Spawned from 0.6 in PurPur-1.20.1
- PurPur 1.20.2
  - PurPur 1.20.1 is NOT even listed anymore, weird that. And the latest 1.20.1 does NOT work with Denizen
- EssentialsS Disabled
  - EssentailsX is rather large and slow to update. As far as I know I only use it for Economy for BetterFarms.
    - If EssentialX ends up really being needed for Vault repalce it (if possible) or DROP BetterFarms. Nova might be more balanced forbid
  this anyway. And with Denizen (introduced in this release) the MraKavin created SCANNER is probably a good substitute for Ore Farming
 - See sheet for other updates, many mods did not get any updates
 - Added Denizen and Scanner (Mrakavin) script
 - TODO: THe following are aging, many back to 1.19, should new versions be found?
  - 
- TODO:
  - Add Denizen Teleporter (Custom MraKavin)
  

## 0.6 @ 2023-10-01

Addresses startup warnings to get the server up properly

- Essentials to 17
- Chest Sort 13.6.4
- Better Farming 5.7.4
- Switched to Xeondevs resource delivery as it works (got 500 2023-10-01 and resource pack did nto build properly, the later is unexplained)
- Enabled all machines even chunk loaders. The Server will still shut down on AFK reagrdless of chunk loaders
  - Upgrading from prior tuned recipes
    - configs/Nova/recipes/minecraft/shaped
    - remove the OFF suffix
  - Mob Duplicator : change Nether Star to Ender Eye
- Upgradable Hoppers : These seems a bit OP but is needed to make BetterFarms auto pull from the farmer.
- SimplePortals
  - Works well enough BUT cannot be controlled or limited by players
    - Cannot prevent players from changing some porter target locations while allowing others to be changed (no ownership)
- TeleCraft (Telepoter)
  - NO: It is not quite what I am looking. it is not, functionally, not much different than SimplePortals 
    - or Sign Teleporters
  - Crafting portals - YES, but they are TIED to a target at time of build
  - Is not chainable, it's a teleport not a portal
  - There is a cost for using based on Exp, Exp-Lvl, Money (vault) or Hunger (cool) or Free
  - Pickung up Teleporter (Strange Rune) is possible SNEAK and break Obsidian, get back the Rune and Obsidian
  - BUG? Cannot get chest teleport working, no big deal just a note 
-Portal Gun : seems a bit unreliable, but still useful for reusable portal
   - Recipe based (or not)
   - 4 types each type has its own ends (2 ends max per portal)
   - A flag to allow ONE portal gun per player, One of EACH type OR INFINITE (Using One Per allowing 4 destinations minimum)
   - Adjusted recipe to use ENDER EYE vs that Wither item (too expensive)
   - Adjusted whitelist to include more colors that roughly match the Portal Guns, except potato
   - Resource Pack is can be use dwith Nova BUT it looks like IDs change occasionally on MineCraft restart.
     - The PortalGun Spigot Page mentions this but how. So NOT installing it so portal guns look like hoes with different heads
   - Change recipes to avoid Nether Star with Ender Eye. Nether Star is too expensive
- Build Portals
  - Works nice for players
    - SimplePorts is better for World Design / ADMINs
  - TIP: Add a wall to one side and player will face the open side on teleport.
    - There is no DELAY setting
    - There is no way to chain teleporters
  - Change Recipe to try and balance things a bit
    - KEEP current recipe
    
    ```yaml
    PortalMaterial: EMERALD_BLOCK
    PortalActivators:
    - REDSTONE_BLOCK
    - GOLD_BLOCK
    - DIAMOND_BLOCK
    Debug: false
    ```
    
    - FAIL: Iron_Block / END_CRYSTAL : end-crystals are not placable
    - FAIL:    Iron_Block / END_ER_CHEST : ender chests are NOT removed so I suspect they might not be reliable
- DISABLE : Fast Chunk Pregenerator - 2.0.8-SNAPSHOT.jar
  - Issued warnings and not currently in use after 4 core update. If needed just re-enable
  
   

## 0.5 @ 2023-09-10

Minecraft 1.20.1 Update

- UPDATE client to 4 GB (defualt is 2) vi `-Xmx4G` in Launcher otherwise the client will LOCK hard downloading resource pack
- Log into target server (GCE)
  - `robb> su -l game`
- Shut down server: `bash stop.sh`
- Copy minecraft to minecraft to minecraft.1.19.2
- Update PurPur to 1.20.1 : Server, ~game/minecradft/server.sh
- Update mods per https://docs.google.com/spreadsheets/d/1k-CjHgdkYe0VpXqdL3o6171wFg4ZbaG6HXGlnmwNCy8/edit#gid=0
  - Tip: To avoid have to figure out which duplicates to delete
    - It seems better to just ALWAYS download the mod (updated or not)
    - Then remove EXISTING modes on server (BUT NOT directories, leave those for recover even if mod is removed)
    - Update all mods
 - Nova Addons
   - See Mova/Addons and uplaod to plugins/Nova/addons after clearing that area
 - Mod changes 
  - DecentHoligrans: Added to replace HoligraphicDisplay (per HoligraphicDisplay suggestion)
  - Essentials Chat added : Experimental
  - Essentials Spawn added : Experimental
  - HoligraphicDisplay : DROPEPD and repalced by DecentHoligrans
  - Vault : Disabled, I don't think ANY economy plugins are active
  - WorldKit : Dropped (it looks like it was dropped previusly but not documented)
- Pulled most recent configs from server to local in case edits are needed
  - Tip: Try to edit on server to avoid things being out of sync on server side
- Resource Packs
  - Tweeking Resource Pack OK : same as 0.4 (no changes where needed so nothing changed)
- Restarted server and reviewed for obvious broken things
  - `bash start.sh`
  - Ignore any on 'screen' already exists types of failure
  - Log into server screen
    - `tmux attach -s game-server`
  - See if server is running. If 
    - `list`
      - Expect to see X out of a maximum of 20 players online. If you geta  file-not-found then
      - `bash server.sh`
  - Update resource pack, as of 2023-09-10 the pack is managed by Nova and uploaded to RC Nova storage provided as part of his Patreon subscription to NOVA
    - `noav reload configs`
    - `nova resourcePack create`
    - `nova resourcePack reupload`
  - Restart server
    - `stop`
      - This stops Minecraft and exits the Minecraft terminal screen
    - `bash server.sh`
      - Will retsrat minecraft and enter the Minecraft terminal screen
    
- POST Processing
    - Fix warnings seen on load
      - BeterFarming: `[Farms] crop: Fuel time not configured: fuel.max` and for `tree` and `ore`
          - Changed farms.yaml `fuel:` to add a max of 7 days (7d), except ores
      -  Dynmap: `playermove trigger enabled - this trigger can cause excessive tile updating: use w
ith caution`
        - configuration.txt / render-triggers / comment out playermove
        - This may lead to uglier maps
      - FastChunkPregenerator:  `is creating timing 'Commands' - this is deprecated behavior, please report it to the authors: Gestankbratwurst`
        - Considering this benign as it only operates under commands from OP
      - Tweakin no needs tweaks enabled/disabled via command line NOT config.yaml
        - `tw toggle [tweak-name]`
      - CustomCrafting:  `Print Errors | false (Required for Support! Enable `data.print_stacktrace` in config.yml!`
        - config.yaml : Change data.print_stacktrace false ==> true
      - AdvancedPortals : ` Proxy features disabled for Advanced Portals as bungee isn't enabled on t
he server (spigot.yml) or if you are using Paper settings.velocity-support.enabled may not be enabled (paper
.yml)`
        - Benign but warning can be disabled via config.yml `DisableProxyWarning:true` (default is false)    
      - External light: ` You are running a development build.`
        - Benign, yes we are, necessary for 1.20 so far
      - LucKperms:  WARN]: `[Essentials] Permissions lag notice with (LuckPermsHandler). Response took 147.058529ms. Summary: Getting group for mrakavin`
        - Benign, I thought this was the issue since things failed after this BUT it was Novus (wild guess on my part)
        - NO: (cuased by Novas) Total lock up on client , it looks like ticks just die on server. Server is still running after user disconnects
        - NO: Rename DBs in config area to .bak and see if that works
        - NO: Delete userdata in Essentials configuration directory, chat history, mails, nicknames, etc. will be lost (in any case no used by playersat this time)
        - DISABLED: Novas and it WORKS, so NOVUs is breakling it ... OK, that's new
    - Fix Novas which is silently breaking things
      - Not Acceptable: (YES) Disable Nova - not ideal but is starting to narrow things down
      - NO: Reset Novux configs to defaults
      - NO: Disable Tweaks which has a resource pack
      - TODO: Send message to Discord -- something is wrong with Nova
        - or disable almost everything and verify
        

  
## v0.41

**WARNING** When uploading plugins do the base directory with full sync/delete and NO directories. Then do the entirewith Sync, sub-directoriesbut NO delete. This should retain in game changes. 


- Uploaded local 0.4 configs from server
  - NEXT time ZIP and download, SCP is WAY WAY too slow
- Duplicated directory to 0.41 configuration
- Eternal Light ADDED : https://www.spigotmc.org/resources/eternal-light.50961/
  - /ll to see light levels
- Tweakin : Update the Resource pack
  - ARCHIVE config to *.4 
    - Note: There are no changes made to config from Defaults
  - https://github.com/sachingorkar102/Tweakin-Resource-Pack
  - Click CODE button, download Zip unpack into hosts ./plugins/Mrakavin
  - Copy the file to plugins/Mrakavin (no changes required to the zip - the ones documented in 0.4 were not actually needed)
- Nova update pack
  - NOTE: Nova now supports CUSTOM S3 storage but I am not using that yet
  - ModifyNova config.yml packer setting with:
    - plugins/MraKavin/Tweakin-Resource-Pack-main.zip
    - REMOVE DSP (this mod is not used anymore and was marked removed from sheet but was not)
- Vein Bucket
  - Major updtae, archive old CONFIG (no customizations)
- Server changes summary
  - Shut down MC server
  - Archive current
  - Verify purpur 1.19.2 is being used in startup file
    - Adjusted ~game/minecraft/server.sh from 1.19 to 1.19.2
    - `export getLatest=1.19.2`
  - per startup comment add the following to the java startup anytime before the `-jar` option. This is one of the few
  Java options that start with a double dash (--).
    - `--add-modules=jdk.incubator.vector`
  - Upload only specific changes to avoid any issues with old.new
    - UPLOAD plugins/Nova/configs/config.yml
    - plugins/tweakin ==> plugins/tweakin_0.4
    - plugins/VeinMiner  ==> plugins/VeinMiner_0.4
    - UPLOAD all changes to plugins WITHOUT dub-directories
  - Start server
  - nova resourcePack create
  - nova resourcePack reupload

 New permissions (see also full permission configation at end of file)
 
 ```
lp group default permission set eternallight.use true
lp group default permission set eternallight.mode true
lp group default permission set eternallight.target true
```


### Nova Configuration file : plugins/Nova/configs/config.yml

```
# Configuration options for the resource pack
# READ SETUP GUIDE: https://xenondevs.xyz/docs/nova/admin/setup/#step-2-resourcepack-hosting
resource_pack:
  # The auto uploader automatically uploads the resource pack after generation.
  # READ SETUP GUIDE: https://xenondevs.xyz/docs/nova/admin/setup/#automatic-resource-pack-hosting
  auto_upload:
    enabled: true
    service: xenondevs
    # RC: key delivered via Patreon (two granted: MiSXU1BAb6VqMPQQ AND rE9Pz44dSkABxtbG)
    key: MiSXU1BAb6VqMPQQ
  base_packs:
  - plugins/MraKavin/Tweakin-Resource-Pack-main.zip
```    


## v0.4 @ 2022-07-17

- Tweakin : https://www.spigotmc.org/resources/tweakin-1-17-1-19.93444/
  - Does many of the things VanillaTweaks does but is a bit more confirgurable
  - Install normally, start server, stop server, edit config file
    - Enable desired elements, and generally disable permission check for those (unless you want to manage permissions indivudally)
  - Resource pack download:
    - Go to https://github.com/sachingorkar102/Tweakin-Resource-Pack
    - Download CODE and choose ZIP
    - Unpack it and browse to the directory  with 'assets', this is one level deeper than the base
    - Zip these files into a NEW ZIP file, named the sames as the base file with '-repacked' appended to the named
    - Copy the file to plugins/Mrakavin
    - ModifyNova config.yml packer setting with: `plugins/MraKavin/Tweakin-Resource-Pack-main-repacked.zip`
    - Start server
    - `nova reload configs`
    - `nova resourcePack create`
    - `nova resourcePack reupload`


```
# Configuration options for the resource pack
# READ SETUP GUIDE: https://xenondevs.xyz/docs/nova/admin/setup/#step-2-resourcepack-hosting
resource_pack:
  # The auto uploader automatically uploads the resource pack after generation.
  # READ SETUP GUIDE: https://xenondevs.xyz/docs/nova/admin/setup/#automatic-resource-pack-hosting
  auto_upload:
    enabled: true
    service: xenondevs
    # RC: key delivered via Patreon  (two granted: MiSXU1BAb6VqMPQQ AND rE9Pz44dSkABxtbG)
    key: MiSXU1BAb6VqMPQQ
  base_packs:
  # Deep Storage, finding this name was done by searchin source code on GitHub
  - plugins/MraKavin/DSP1.3.zip
  - plugins/MraKavin/Tweakin-Resource-Pack-main-repacked.zip

```    

## v0.4 @ 2022-07-10


Dir: C:\DATA\Games\Minecraft\CUSTOM-Mrakavin\SPIGOT\PaperMC-1.19\0.4


Based on a copy of 0.3 which was synced and then updated to latest. A backup of the 0.3 version
can be found in ~/minecraft.bak on the SERVER.



## v0.3 @ 2022-05-07 

Dir: C:\DATA\Games\Minecraft\CUSTOM-Mrakavin\SPIGOT\PaperMC-1.18\0.3 Update - WIP

Based on a copy of 0.2 which was synced (plugins only) with server onf 2022-05-07


NO CHANGES YET. Just a place holder for updates

- Nova 0.8.12 : https://www.spigotmc.org/resources/nova-%E2%9C%A8-custom-blocks-%E2%9C%85-items-%E2%9C%85-guis-%E2%9C%85-modpack-like-fully-configurable.93648/
- DISABLED custom resource pack - it's a PITA to maintain and
  - Nova is just easier to deal with
  - DeepStorage is DEPRECATED due to piro bugs and the risk of loosing ALL items on updates or if mod is discontinued
  - Transport Pipes is VERY cool and I like the auto crafting pipe but it lags behind Minecraft updates and is a little buggy
  


# Install Notes

Recovery old bases

- IF possible run the following on existing world: `java(all java options) server|paper|purpur (normal options) --forceUpgrade
  - See https://www.spigotmc.org/threads/bukkit-craftbukkit-spigot-bungeecord-1-14-4-development-builds.369724/
  - PaperMc says htis is optional but will not hurt, hopefully it makes things smoother
- After updating server then repeat the ABOVE
- This will take some time as every chunk is reprocessed, so its best to do BEFORE world generation.


- ./old-pterodactyl-world
  - Tar and download World, Nether, End to this directory
- Installed NBT to find last player location too help find base - installed with defaults
  - https://github.com/jaquadro/NBTExplorer/releases
    - 2017 - quite old and WebRoot HATED it but it looks good to set to Monitor.
      - Player names are NOT in the file, but I know the bases OR could cross reference to player UID
    - world/player-data/
      - Robb: 0d1b9c23-2aca-410f-b187-598979e800e0.dat (Mrakvin or wings of time) :
        - 62 62 -102
      - Volod: 4dafaae0-6574-47aa-b708-5684c71940bf.dat
        -400.6 64 -264.75
      - Robb Alt?: 9bc82942-395b-464b-989d-f36384029a67.dat
      - Isaac : dee4411f-261e-4dd7-8c02-f28b73c2861f.dat
        - -345.5 41 44.6
        
        
        -1280 100 256 : test for OTD

- MCASelector (MCA Selector)
  - https://github.com/Querz/mcaselector/releases        
  - This IS be asier than World Editor and Amulet
  
 
- Amulet : World Editor (NEW)
  - SEE MCASelector which is a easier and a LOT faster for clearing areas
  
  - https://www.amuletmc.com/
    - Downlaod Beta for 1.18 editing (2022-01-17)
    - Downloaded and unpacked then ran in world directory (short also creataed)
  - Located bases and selected them (only the three main bases) plus some chunks around them
    - Deleted ALL unselected chunks (do NOT save undo as that will take 4+ hours, just have a normal backup)
    - Save (that still took 2 hours)
    - Upload to server as a TAR + GZ (2 steps in 7Zip) and keep a backup
    

- Cleanup
  - Server
  - MV virgin world 1.18 (well with my modest experiments) to safe area
  - Download Vaniall 1.18 and sname server.jar
  - Unpack world and start server using VANILLA modifying start-server to change jar file name
    - This works better than Paper or purpur in fixing up world
    - shut down
    - Start as purpur by modifying the start-server.sh script
  - Make sure WorldEdit is present as it is used to do some cleanup
    - make sure SlimeFun is NOT, that caused massive issues wven using just the base Version with no add-ons
  - Remove spigot heads
    - //pos1 x,255,z and //pos2 x,0,z
      - I went cretive and flew to the corners of the bases
        - type `//pos1` to get cordinates  then `//pos1 x,255,z`
        - When to diagonal corner and `//pos2` then `//pos2 x,0,z`
    - `//replace player_wall_head air` - Slimefun cargo blocks
    - `//replace player_wall air` - Slimefun power blocks
      - Find find name of object :
        - Hold a stick (or any item that is not a block)
        - `/tool info`
        - Right clock on target block
        - `/tool unbind` (to unbind tool)
    - TIP: You may need to reset cordinates between commands but 
  - Remove invisibl text, which also removes ALL armor stands
    - TIP: Some commands override core (such as EssentialsX - so use `minecraft:kill` to avoid play not found kindf of errors
    - `/minecraft:kill @e[type=minecraft:armor_stand,nbt={bInvisible:1b}]` - and that wipes out ALL such messages EVERYWHERE
      - ALTERnATIVE but be VERY close to armor stand `/minecraft:kill @e[type=armor_stand,distance=3]` (or r or c if nothing it wipes out ALL)
      - See also: sort=nearest or radius commands
      - OH NICE; it also got rid of that floating grey wool in my base item, all spit messages and wildloader messages but
      my normal armor stands are fine.
  - BACKUP world


TEST

  - AdvancedPortals
    - https://www.spigotmc.org/resources/advanced-portals.14356/
    - Can go between worlds/dimensions easily, just set destination in the target world `dest set <NAME>`
    - Executing commands is done as the CURRENT player so 'home' works (Eseentials) assuming you have permission which you
      probably don't because the player can always teleport home and that's cheating
      - `/portal create name:testbed command:"home" triggerblock:water`
    - Works GREAT
  - NO: Minecraft command: /execute in world_nether run tp mrakavin x y z 
    - Kind of works but needs hardcoded to user's base cordinates OR to a central spawn
  - TODO: Waystones - NOT 1.18 ready but looks pretty cool
    - https://www.spigotmc.org/resources/waystones.93917/

  - NO: Ultimate Homes
    - Did not solve my problem for creating a command block
    - https://www.spigotmc.org/resources/%E3%80%90ultimatehomes%E3%80%91-highly-configurable-player-sethome-system-1-8-1-18-x.64210/
  - NO : Command Hook 2.0.0
    - Did NOT solve my problem with command blocks for '/home' 
    - https://www.spigotmc.org/resources/commandhook.61415/
    - Allows use of vanilla selectors in non-vanilla commands
    ```
    This plugin adds the possibility to use vanilla selectors in non-vanilla commands written in CommandBlock.
    Since it hooks into vanilla functions, all of the selector arguments are parsed (@p[distance=..5])

    Keep in mind
    Selecting entities other than player isn't probably of any use, because after the result is obtained, it parses the command with entity name (Player or mob name), however all of the selectors should work.

    @p - targets nearest player
    @a - targets all players
    @r - targets random player
    @e - targets all entities
    @s - targets the executor (that is command block, not Player!)
    ```

  - Nova
    - Resources:
      - Spigot: https://www.spigotmc.org/resources/nova-%E2%9C%A8-custom-blocks-%E2%9C%85-items-%E2%9C%85-guis-%E2%9C%85-modpack-like-fully-configurable.93648/
      - Config Doc: https://xenondevs.xyz/docs/nova/configs/main/      
      - See settings in config section
      - Game doc : NONE, see update history on spigot
      - Resource pac; On Github (need to find again)
        - Works packaged into Transport Pipes and DeepStorage although those two are a bit supplanted by Nova
    - Feelings
      - HUGE Mod with tons of stuff, similar to SlimeFun but vastly more modern
      - NOT well documented game play wise
      - So far seems pretty reliable, no crashes or warnings but I only played with pipes
    - Posibilities
      - JUST enable basic items such as pipes and filers, trash, vacuum chest, and other basic items - call it done
      - Just enable Press to get a ton of basic items but NO other machines
      - DISABLE OP stuff or stuff out of scope
        - Tree Farm : WAY overpowered for performance, every few seconds a log is created
        - Infinite storage - reduces hording and word destruction
        - Quary - avoid destruction of the world. WHile a new world could be created that always seems a bit of a cheat
        - Jet pack - possible but favor elytra
        - Tree Farm? Is it more balanced than just a farm with fuel? If power based then it is infinite with no maintenance and that
         takes autoamtion a bit too far in my experience. Plus it can be automated which seems too OP
    - TESTED
      - These machines are NOT redstone controlled, so no way to disable or control
      - YES: Furnance generator
        - 80 j / tick
      - YES: Lava Generator
        - 20 j / tick
      - NO: Windmill - NO : no free power!
      - NO: Solar - NO : no free power!
      - NO: Tree Farm: NO - too OP
      - Generalist Farm
        - Harvestor: Yes - does not support cocoa (it breaks logs). It requires an axe?
          - Will harvest but saplings are not pikced up
          - If shears are added then leaves are harvested
          - Items take DAMAGE so that helps, athough it can probably be automated
        - Planter : OK - it may be wise to use 3x3 sections to control what is planted
        - Fertizlier : OK - consumes bone meal QUICKLY
      - NO: Breeder : not overly useful especially since it lacks a limit 
        - Requires power AND the breeding food
        - (if this is fixed then it can be enabled) The config has a limit of 5 but I am not sure what that means since it is still breeder with 9 sheep
      - Vacuum chest (needs power)
        - YES
        - Range is in X, Z AND Y
      - YES: Chunk Loader
        - It might be useful -- we will see if it is abused
      - Auto Fisher - sure, anything beats fishing :(
      - NO: Jet pack - NO not really needed (and I cannot make it work, possible conflict with other mods)
        - Charger is there not needed either
      - NO: Quarry
        - A LOT of power 490 is needed (but trivial to build)
          - = 6 generators OR a BIG battery
        - 10x10 is pretty big at initial size
        - Default is to leave the level the machine is on and dig one block below it
        - No fuel or tools is needed leading to just a big giant harvestor. Not something I think suites this pack.
        We have the Ore farm (Better farming) which is more balaanced as it needs LAVA
      - YES: Lava Generator - uses laval to make power
      - Pump REPALCES water/lava with dirt, it is NOT infinite! Seems reasonable. Does make lava a little to easy but OK
        - This may make it too easy to fill Lava Generator
      - NO: Storage uniits - infinite storage is being avoid in exchange to more relaisitc chests
      - NO: Flued Storage Unit - infinite storage is being avoid in exchange to more relaisitc chests
      - YES: Fluid storage seems OK, basic is 10 buckets, advanced is 50 buckets, elite is 250!
      - Fluid is kept when item is broken - YES
      - YES: Fluid Infuser - OK, mostly for buckets and sponges
      - YES: Cobblestone - just give it a bucket of water and lava
        - Cobblestone : uses NO resources (infinite)
        - Stone: uses 1 bucket of water per block
        - Obsidian : uses 1 bucket of laval per block
      - NO: Freezer : this is normally OK since water is not infinite (unless found) - but its easy to fly around
        - Ice : 1 bucket
        - Packed Ice: 5 buckets?
        - Blue Ice: A LOT more
      - NO: Mob Duplicator - NO : use spawner, except for
        - OP 
      - NO: Mob Killer : NO : use spawner
        - WAY WAY OP
      - NO: Mob Capture
       

      

Custom Resource Packs

  - Resource Pack
    - Made a server resource pack using: https://github.com/xMGZx/zdpack
      - see : D:\Games\PaperMC-1.18\0.1 Initial\Resource-Pack/zdpack-gui.exe
      - Used Version 6 otherwise the resource pack is NOT available to local (so I suispect it fails remote as well)
        - See also : https://mc-packs.net
          - Note once upldoaed there is no provision to remove or edit a pack (no login either)
        - server.properties changes  (note the ':' is quoted with a back-slash in the properties file
        ```
        resource-pack=https\://download.mc-packs.net/pack/01cb852618705bfe3243655962826a9537f9b8da.zip
        resource-pack-sha1=01cb852618705bfe3243655962826a9537f9b8da
        ```
    - NOTE: Vanilla Tweaks is not needed on CLIENT
    - NOVA
      - https://github.com/xenondevs/NovaRP/releases/download/0.8/NovaRP.zip
    - DeepStorage
      - https://download.mc-packs.net/pack/65ada59a809af41a24c2036663a291c30d8cb70b.zip
      - https://drive.google.com/uc?export=download&id=13ZZzmERLZUb_NVG76BctAWnzVkUr6WLb
        - See also: https://github.com/christopherwalkerml/DeepStoragePlus/pull/10
    - YES: Transport Pipes
      - https://github.com/BlackBeltPanda/Transport-Pipes/blob/master/src/main/resources/wiki/resourcepack.zip?raw=true
        - See also: https://github.com/BlackBeltPanda/Transport-Pipes/issues/16
        - Keeping WITH NOVA as its crafting process can do Nova (or any recipe).
  - SERVER SIDE
    - World/Datapack - the invidual ZIP files from valialla  it looks like
      - Valilla Tweaks : Uplaod all indiviual zips (one for each feature to the Datapack directory)
        - https://vanillatweaks.net/share#cXv0mN
          - Survival
            - Coordinates hud
              - Client: `/trigger ch_trigger`
            - Caldron Concrete : Drop concrete Power into Cauldren full of water
            - Fast Leaf Decay  - ONLY in Survival, inc reative the leaves are the same
            - Custom Nether Portals
            - Durability Ping
            - Unlock all recipe
            - Nether Portal Coords
          - Items
            - Redstone Rotation Wrench
                - A seperte WRENCH that goes into client resource pack
                - USE: It is the 'wrench' in the crafting bench. It is grey with gold tip (plain) 1 iron + 3 Gold, the Transport Pipe wrench is red/violet (glowing) (4 redstone+1 stick).
                - If texture pack is not loaded the wrench is NOT in crafting and if you have one it is a carrot on a stick (and will still function)         
                - Two files are downloaded the vanilla tweaks.UNPACK  which goes into server:worlds/datapacl with the above
            - Terracotta Rotation Wrench
            - Armored Elytra
          - Mobs
            - Anti-Enderman Gried (EnderMen will not use structured blocks in survival world)


ADMIN
  - PluginManager
    - https://www.spigotmc.org/resources/pluginmanager.69061/
  - Essential X
    - So OFTEN recomended it seems almost a requirement
    - https://essentialsx.net/downloads.html
    - CORE, and recomended (Chat / Spawn)
  - Vault
    - Still marked 1.17 but it seems to work on 1.18
    - https://www.spigotmc.org/resources/vault.34315/
  - LuckPerms
    - https://www.spigotmc.org/resources/luckperms.28140/
  - Recipie Adjustment
    - Custom Crafting
      - https://www.spigotmc.org/resources/customcrafting-advanced-custom-recipe-plugin-1-16-1-18-free.55883/
      - REQUIRES: WolfyUtilities
        - https://www.spigotmc.org/resources/wolfyutilities-core-plugin-api-1-15-1-17.64124/
      - Note Craft API also has a GUI but it is not nearly as advanced as Custom Crafting
      - Currently used to make
        - Elantra to make up for lack of portals
      - Making items is FANSTACTIC - allows for creating enchanted items that can be CRAFTED
      - went away? !!! BUG: Every target item is set to the last item saved!!!!! kinda a big bug
        - no mention of it -- but tis makes mod unusable for more than one recipe
        - Um, everthing is fine now ... 
      - Recipies do NOT appear in MC recipie book
    - CRAPI - needed by other libraries
      - Note it has a very simplistic recipe creator but NO editor and the resulting YML file is kind of painful to edit
        - Prefer Custom Crafting
    - NO : Executable Items - Custom Item Creator
      - Allows for CUSTOM items but not recipies and I need both so prefer `Custom Crafting` assumign it is reliable
      - (is this the same) https://polymart.org/resource/custom-items.1
      - FREE: https://www.spigotmc.org/resources/custom-items-free-executable-items-1-12-1-18.77578/
      - (Free less features) https://www.spigotmc.org/resources/custom-items-free-executable-items-1-12-1-18.77578/
        - Note: Delivered as a Zip with 2 Jars - unzip into plugins
          - ExecutableItems-*.jar
          - Score-*.jar
      - https://www.spigotmc.org/resources/%E2%9A%94%EF%B8%8F-executable-items-%E2%AD%90-create-custom-items-easily-%E2%AD%90-1-12-1-18.83070/
    - WorldEdit
      - Used for Admin Repair
      - https://dev.bukkit.org/projects/worldedit/files/3559523
    - WorldEditSUI (aka WorldEditCUI repalcement)
      - https://www.spigotmc.org/resources/worldeditsui-visualize-your-selection.60726/
      - Visualize World Edit selection
        - `/wesui`
        - `/wesui toggle`
        - `/wesui showregion`
        - `/wesui reload`
    - NO : Dimensions Custom Portals - for test worlds (or future expansion)
      - Requires using a web site to create portals and that site is NASTY for adds and downloads
      - https://www.spigotmc.org/resources/dimensions-custom-portals.57542/
    - Phantom Worlds - to create new worlds easily
      - https://www.spigotmc.org/resources/phantomworlds.84099/
      - `/pw`
      - Resource world (kind of hard) : /pw create world_resource NORMAL generatestructures:false structures:false type:AMPLIFIED
        - Documentation omn wiki is essential zero for `/pw`
          - 2022-02-01 : https://github.com/lokka30/PhantomWorlds/wiki/Commands-and-Permissions
        - 'CUSTOM' world type crashes (maybe because custom needs options I do not know?)
      
    - NO - Farm Control - Used to limit loads
      - Decided not to use as there seems to be a lot of lag control in purpur
      - https://www.spigotmc.org/resources/farmcontrol-1-15-1-18.86923/
    - Fast Chunk Pregenerator (FastChunk)
      - https://www.spigotmc.org/resources/fast-chunk-pregenerator.74429/
      - status of render can be see on Minecraft server screen (tmux) or logs
      - Pregenerate 5,000 blocks around player. Suggest placing player at 0,150,0 then run:
      - `/fcp start 5000`
      - The CPU usage is 175 during this process -- (I have 8 cores in this dynamic VM - so not sure 8 cores are worth it)
      - Restarted with 4 cors and have a CPU load of 162
        - Rendering survied restarted and just continued
        - 2 cores was almost always at 1.8+
        - All RAM is 8 GB but that is probably overkill as with 3 players it tends to hover near 4 GB (with dynmap)
      - Oh The Dungeons (OTD) seems to be generating structures as locations are rendered, averaging one every 6 minutes of
      fast Chunk render. (see plugins/Oh.../log.txt)
    - NOY YET: spark
      - https://www.spigotmc.org/resources/spark.57242/
      - Deeper monitoring of Java and the CPU - not needed currently. If pauses occur check ghe GC Monitoring commands on the Spigot page
      
      

QOL - if possible add
  - FarmingUpgrade : Better farming harvesting, simple effectve immerssive
    - https://dev.bukkit.org/projects/farmingupgrade
  - Harbor - Vote sleep
    - https://www.spigotmc.org/resources/harbor-a-sleep-enhancement-plugin.60088/
  - DynMap
    - https://www.spigotmc.org/resources/dynmap%C2%AE.274/
  - Better Farming? (13 EU)
    - Purchased - instantly appeared on Downlaod resources
    - https://www.spigotmc.org/resources/better-farming-auto-farm-plugin-crops-and-trees-automated-grow-plant-harvest-gui-1-18-support.67627/
    - see [Better Farming](better_farming)
  - SEE ALso Farms Advanced
    - https://www.spigotmc.org/resources/farms-advanced-farming-minions-free.98747/
    - A new mod so waiting to stabalize but worth a review when it does

      
  - Vein Miner - WORKS
    - https://www.spigotmc.org/resources/veinminer.12038/
  - NO: Machines - no real history (but very cool looking)
    - BAD BAD BAD -- Comemrcie via MCMarket  $9.99
      - Too many shady reviews of this market
    - https://www.mc-market.org/resources/22299/history
  - Graves!!!!
    - Graves
      https://www.spigotmc.org/resources/graves.74208/
    - NO- Angle Death (PAID $12 wich is expensive)
      - https://www.spigotmc.org/resources/%E2%AD%90-angelchest-plus-%E2%AD%90-death-chests-graveyards.88214/
    - PERMS: None
  - Some kind of inventory control besdies 100's of hoppers
    - SlimeFun -- COOL but get scomplex and has proven hard to port
    - YES: Transport Pipes - recently resurected but not sure it is stable or long life
      - https://github.com/BlackBeltPanda/Transport-Pipes
      - Replaced with Nova for MAIN pipe runs: Loosing too many items - Nova does everything (differently) except crafting
      - Keeping in addition TO NOVA as Transport-Pipes crafting process can do Nova (or any recipe) - Use for SHORT well defined pipes and verify
      the items do not go missing. At least until bugs are fixed.
      - SERIOUS bug with item loss if chests are removed, see below
        - Now random pipes loosing items. There is a pending fix but no build is available yet.
      - Like buildcraft, has a few bugs but seems to be updated (kind of)
        - This is VERY cool, and likley my favorite transport / sorting pack BUT it is not as actively maintained as I would like.
        The risk for using this seems significant.
        - Bugs (CRITICAL item loss)
          - Wildchest - just VANISHES (Deep Stoage) and can even extarct PLACEHODLER blocks. Just use a HOPPER on any NON vanilla item
            - MITIGATION: Use a hooper between pipe and Storage Chest
          - IF a target chest is removed the system will still try to PUSH an item into it (and it goes away)
            - rebuilding the pipe does not help unless the pip is on a new course
            - but then it goes away .... server restart?
          - Works with DSU IF a HOPPER is used (else item is lost)
          - If a pipe breaks sometimes the item will fly off to the distance - although oddly enough when I break the pipes
            I get that item back.
            - Sometimes an item just vanishes into the pipes, I only found this true when breaking pipes during items moving.
            In all cases, so far, breaking the pipes nearby got the item back.
        - Pipes can be walked through (kind of cool)
        - Weird graphics for pipes (wooden pickaxes) woe graphics are 75% in the block below
          - Need service pack but there can only be ONE server servic pack and currently Deep Storage is doing that
          - https://github.com/BlackBeltPanda/Transport-Pipes/issues/16
          - https://github.com/BlackBeltPanda/Transport-Pipes/blob/master/src/main/resources/wiki/resourcepack.zip
          - The EASY way is to load the transport one locally (or maybe all) OR make a single server side reosurce pack by combining them
          - If this still does not work the DELETE plugins/TransportPipes/playersettings
            - The `*.yml` probably has the setting `render_system: VANILLA` instead of `render_system: MODELLED` as it is cached from the time
            the user first logged in PER the defaults. It's easy for this to get screwed up when experimenting.
        - Items traverse down pipes  visually (cool)  and if they hit the end of a pipe with no where to go reverse back
          - Items cannot enter pipe if something else occuipies it so not overflow
          - If entire pipe is full it just keeps cycling (ok)
          - It appears the pipe can get stuck in an infinite reetry loop and never send out to another pipe
            - Solution change that pipes extarct mode to OFF
            - OR Break the pipe
        - Ice pipes need SNOW (not ice) so that is useful. 
        - Void pipes work just fine, note you need an extract or the ite to otherwise be in a pipe
        - Gold pipes
          - Colors on selector (click with tool) is show AFTER pipe is connected to the gold outputs
          - Everything is round-robin so there is no DEFAULT pipe, you need to add an INVERT (PITA)
        - Colord pipes only connect to the same color (white, gold, extract and void are NOT colored pipes and connect everywhere)
        - Extraction modes apply to the item when it was extracted (NOT the pipe)
          - DIRECT Mode
            - At every possible intersection (regardless of inbound direction) the priority preference
              - E, W, S, N, Up, Down
              - IF a path HAS bene traversed it is SKIPPED
              - If all paths are traversed then it tends to bounce between the two highest priority
                - So if a 6 pipesa re setip and the item has traversed through them all then the item bounces
                between E/W. If W did not exist it would bounce between E/S (not well tested)
          - ROUND ROBIN Mode (more like RANDOM mode)
            - Picks a random direction at every intersetion that it is NOT yet traversed through
            - If it cannot exit it will usually cycle between last two routes
          - GOLD pipes follow this SAME logic as above BUT ehn a direction is chosen THEN the filter is checked
            - If running filters be sure to block other paths with an INVERT of all the other filters
          - Iron pipes only have one direction they can output to so these rulesa re not applicable
          - TIP: Use DIRECT mode, gold pipes and iron pipes to handle overflow. In this diagram it is important that
          the overflow pipe is a LOWER priority than the extarct direction. Down is often good as it is the lowest priority but
          anything other than the direction of motion will work. When the extract outputs it will go through the IRON, to each gold and if
          it cannot route anywhere (targets full or no gold filter matches) it will reverse. But once it hits that IRON pipe it will
          be FORCED down. NOTE: Due to priorities the iron pipe is NOT strictly needed, but it does make it more clear.
          - SHIFT RIGHT clickn on a pipe with the wrench (Transport Pipe version) will BLOCK that side of the pipe
            - break pipe, SHIFT ROGHT click side of adjacent pipe, and when adding a pipe you will see that side is NO LONGER
            connected.

          
            ```
              Extract => Iron Pipe => Gold => Gold ....
                                    |
                                    Overflow
            ```
                                    
            
          

        - The recipies for sorting are a tad high since without sorting the network is a tad weak, although
        Chests++ filters could be used but that seems wasteful
          - Would be good to change this recpie
        - Crafting pipe is cool, it has a buffer of 9 stacks of items (accesible via wrench) and will craft items at about 1 a second.
      - https://github.com/BlackBeltPanda/Transport-Pipes/pull/20
      - REQUIRES: protocollib
        - https://www.spigotmc.org/resources/protocollib.1997/
    - DISBALED - Deep Storage Plus - a bit limited but still useful
      - NOTE: This mod proved a bit dangerous in that it sometimes broke (yes litterally turned back to a chest) and
      stores item in a way that makes it iompossible to recover if anything goes wrong.
      - Latest udate is pretty cool bt NOT immersive at all. Still better than 100s of hoppers
        - Prior install noticed HEAVY LAG - did not notice it yet
        - Very limited filtering but that could be done via other mods
          - the sorting unit does not pay attention to filters
        - wireless is connected to only ONE storage chest so a max of 35 unique items
      - https://www.spigotmc.org/resources/deepstorageplus-1-13-1-18.74145/
      - CONFIG CHANGES
        - # RC: disable resource pack (true => false)
        - loadresourcepack: false
      - Permissions
        - ALL deepstorageplus.create
      - Resource Pack: Both files are the same contents
        - See also: https://github.com/christopherwalkerml/DeepStoragePlus/pull/10
        - https://download.mc-packs.net/pack/65ada59a809af41a24c2036663a291c30d8cb70b.zip
      - REQUIRES: CustomRecipeAPI
        - https://www.spigotmc.org/resources/customrecipeapi-1-13.74134/
    - NO - Unlimited Storage System -- (PAID) WAY too magical (6 EU)
      - https://www.spigotmc.org/resources/%E2%9C%A8extrastorage%E2%9C%A8unlimited-storage-sorting-system-customizable-mysql-and-sqlite-support.90379/
    - Wild Chests 2.2.3 b43 : WAS on spigot but seems to have gone private -- 
      - https://bg-software.com/wildchests/
      - REQUIRED: Sell Items, vacuum chests (see also Nova)
        - See also : PAID mod
      - Pretty cool but magical and storage is basically DEEP STORAGE one type
      - config.yml
        ```
        # RC: ShopGUiPlus ==> Essentials (otherwise nothing will sell)
        prices-provider: 'Essentials'
        ```
    - NO Advanced Chests (PAID, $7.50)
      - A NEW chest : Sell, sort, etc. and I am concerned the items would be lost if plugin fails or on backup/restore emergencies
      - https://www.spigotmc.org/resources/%E2%AD%90advancedchests%E2%AD%90-unlimited-sizes-holograms-%E2%9C%A8upgrades-%E2%9C%85sells-%E2%9A%A1sorter-%E2%98%84%EF%B8%8F-compressor.79061/
    - NO: WildLoaders (see wild chests ofr download)
      - - https://bg-software.com/wildloaders/
      - Replaced with Nova
      - Perms: None
    - Chests++ - a bit magical but not crazy so (aka ChestPlusPlus)
      - This was not working in the World
      - https://dev.bukkit.org/projects/chests-plus-plus
  - Silk touch Mine spawners (a config on PurpurMC)
  - Some form of enchant that is NOT random
    - NO: Enchantment Solution
      - Replaced with ExpandedEnchants 
      - Changes exp to combine books to be more reasonable (1 or 2)
      - https://www.spigotmc.org/resources/enchantment-solution.59556/
      - seems more visible and has an RPG component I do not understand
      - Needs: https://www.spigotmc.org/resources/crashapi.82229/
    - NO - OR ability to remove enchants might be useful
      - https://www.spigotmc.org/resources/extractable-enchantments-remove-enchantments-1-14-1-18.73954/
    - Perms: None
    - YES: ExpandedEnchantments (Expanded Enchantments) - allows enchantments to be crafted but rather expensive!
      - The charge seems to be 5 levels to increase levels
      combining items.
      - https://www.spigotmc.org/resources/expandedenchants.98780/
      - Has a disenchant (anvil: item / book = magic book)
      - `/ee recipes`
    - NO : ExpBottle : Cannot get this to work via commands
      - Save experience into bottles. This can help with enchanting since enchanting is lvl based NOT point based (which is silly). So it is
      vastly better to save experience do encahnting / anvile.
      - https://www.spigotmc.org/resources/expbottle-withdraw-your-xp-into-bottles.98763/
  - YES: Waypoints
    - https://www.spigotmc.org/resources/waypoints.66647/
  - Some immersive skill based system (mcMMO?)
    - https://polymart.org/resource/mcmmo.727#!
    - Bought it for review purposes - took about 10 minutes to be available for download
    - EXPENSIVE at $20
    - No special permissions for players
  - OTD : Oh' The Dungeons
    - https://www.spigotmc.org/resources/oh-the-dungeons-youll-go.76437/
    - Perms: None
    - Enable as OP via GUI: `/otd` 
    - Turn on all dungeions for world (ONLY)
    - Change rate from 62 to 48 average chunks (62 is almost 1000 between dungeons, that's so rare I did not see on for ages)
    - See PDF: https://github.com/OhTheDungeon/OhTheDungeon/blob/main/OTD.pdf
  - WhatisThis : https://www.spigotmc.org/resources/whatisthis-identify-the-block-you-are-looking-at-1-13-1-18-multi-language-support.65050/
      - More sophistcated than Wailat
      - Click block with stick OR /wc
  - HolographicDiplays
    - Be suee to download VER 3+ for 1.18
    - https://dev.bukkit.org/projects/holographic-displays
    - Provides nice output for plugins
    - Better Farming uses this
  - NO (no compelling use in this pack) Upgrdable Hoppers
    - PAID - https://www.spigotmc.org/resources/upgradeable-hoppers-fast-hopper-plugin-link-containers-item-transfer-suction-chunk-1-18-support.69201/
    - Does NOT speed up normal hoppers
    - Can sort but it is rather magical (all managed by hopper and gets REALLY expensive)
    - I think I prefer Ender Chests
  - BROKEN : Eternal-Light (FORK) for 1.18
    - `/ll` Crashes plugin and it auto disables
    - https://github.com/jordankothe9/Eternal-Light/releases/tag/1.8
  - YES : ChestSort (+ API)
    - https://www.spigotmc.org/resources/chestsort-api.59773/
    - Easy way to sort inventories
    - While it seems to conflict with other mods (especially those with special placeholders like DeepStorage) it is super useful and DeepStorage is NOT in use anymore
  - YES : Automated Crafting
    - https://www.spigotmc.org/resources/automated-crafting.70432/
    - Seems reasonable and straight forward, a sign on a dropper
    - Handles Vanilla  and Crapi (and some versions of cc) BUT not NOVA (resource data pack?)
    - Use a chest facing front, do not use pipes to extract from droper as that will extra items before they can
    be used for crafting 
      - Will NOT craft nova items
  - OFF (RESEARCH) : Spawner Control
    - https://www.spigotmc.org/resources/spawnercontrol.98872/
    - Allows spawners to be changed in behavior and type, such as adding slime / creeper.
    - OFF until it can be tested as the configuration is a tad confusing. For example can 'creeper' spawners be limited
    to a certain percentage.


Potential

- SpigpotAutoSort
  - https://github.com/CurtisDH/SpigotAutoSort/
  - Seems to work by auto sorting into chests that contain that item
- NPC living towns (Unlikley, nothing like availble on Forge where towns are very immersive)
- Citizen (NO)
  - An NPC building too but not immersive
- mcMMO : A skill based level system
  - Seems immersive and have a nice reward system
- Jobs 2 (NO)
  - Does not seem to be useful except for economy based games and lacks immersion
- Player Warps (NO)
  - Instant warping based on numerous settings, but not immersive

# Essentials Configs

This assumes EssentialsSpawn module is set

## essentials/config.yml

```
# RC: See also: https://github.com/EssentialsX/Essentials/issues/3836
newbies:

  #RC: spawnpoint: newbies => none
  spawnpoint: none

# When users die, should they respawn at their first home or bed, instead of the spawnpoint?
# RC: respawn at HOME to enable respawn-at-home-bed
respawn-at-home: true
```


/execute in minecraft:world_resource run tp @p[distance=2] -672 78 272  

# NOVA Config


WARNING: 0.9 is a MAJOR change and all existing Nova machines and ITEMS will break. This makes anythign with pipes a total and complete mess.

https://xenondevs.xyz/docs/nova/admin/setup/


## Resource pack if it is needed to be manually installed

Tool: https://nerawoowty.github.io/packcombiner.html


## Remove OLD items

/minecraft:kill @e[type=armor_stand,distance,c=256]
/minecraft:kill @e[type=blocker,c=256]


## Disable mchines

Simply append `.off` (any anythign other than yml) to the file name

- Nova/recipes/shaped
  - breeder.json.OFF  : Lacks a limit on maximum enties eben through the config seems to have it
  - charger.json.OFF  : no items that are enabled need a charger
  - freezer.json.OFF  : Seems OP
  - jetpack.json.OFF : OP compared to Elytra
  - mob_catcher.json.OFF : OP
  - mob_duplicator.json.OFF : VERY OP
  - mob_killer.json.OFF : VERY VERY OP
  - tree_factory.json.OFF : Seems a bit OP as it allows easy infiniite fuel - although for more effort than Better Farms
  - Quary : ONLY IF Quarry is disabled - currently it is enabled ONLY for resource world, see other NOVA settings
    - quarry
    - netherite_drill
    - scaffolding
  - wind_turbine.OFF : NO leads to easy Infinite power
  - wireless_charger.json.OFF : No enabled items need wireless charging
  
## Disable Inifnite water source loot
 
 Backup  Nova/config/loot.json then remove the `nova:infinite_water_source`

## Add alternate recipes for star shards (OPTONAL)

For worlds that are pre-generated it can be silly to go to unexplored areas to locate a dungeons
to find a chest with star shards. The following recipe (via `/cc`) is used:

```
Blaze Powder    Ender Pearl     Blaze Powder
Diamond                         Diamond
Blaze Powder    Ender Pearl     Blaze Powder
```


## Nova/config.json

Enable Quarry ONLY in resource world and forbid generators forcing
playing to bring batteries. Only those generators that were not already
disabled are needed here. This configuration helps balance the quary
OP nature:

- Player must hand transport items since spawn port is not loaded.
- Player must be present as chunk loaders are forbidden.
- Player MUST have batteries to support the Quarry operation


```
  "tile_entity_world_blacklist": [],
  "tile_entity_type_world_blacklist": {
    "QUARRY": [
      "world",
      "world_nether",
      "world_the_end",
      "otd_dungeon_shadow_world"
    ],
    "FURNANCE_GENEERATOR": [
      "world_resource"
    ],
    "LAVA_GENEERATOR": [
      "world_resource"
    ],
    "CHUNK_LOADER": [
      "world_resource"
    ] 
  },
  "tile_entity_limit": {
    "QUARRY": 1
  }
```

# Better Farming Configs

## config.yml

```
  # World names are CASE-SENSITIVE
  # - RC: ADD test world
  worlds_list:
    - world
    - world_test

  farm
    creation
      farm-land
        filter
            blocks_list:
              - 'AIR'
              - 'GRASS_BLOCK'
              - 'DIRT'
              # RC: Added couarse dirt as looks like dirt and is frustrating to debug when not repalaced
              - 'COARSE_DIRT'
```

## farms.yml

For fuel be careful to avoid creating a near infiite farm run. There ar 18 fuel slots so I tend to make it so
that the player needs to log in at occasionally to keep farm running. And since the server runs ONLY
when a player (any player_ is doing something. 

A player can choose a few startegies with these fuel laod outs

- Use an Iron Hoe for an easy 30 minutes (max 9 hours)
- Use DIAMOND Iron Hole for the same as 64 bone blocks
- Use a 64 Bone blocks for a bit 8 days
  - This probably represents 24 or so days at average load of 1/3 seever on real-time
  - This can be auto crafted using a farm dedictaed to it (composter => bine meal => bne block) but is a lot of work
  - This is the BEST fuel since it can be auto crafted but takes a lot of work and may not be useful for anything but
  hording :)

```

types
  crop
    fuel
      items:
        # NEW - same as 64 bone blocks
        - DIAMOND_HOE: 23040
        # 900 => 1800
        - IRON_HOE:1800
        # 25 => 180 :  STACK so 64*18 units
        - BONE_MEAL:60
        # 225 => 600 :  STACK so 64*18 units (max 8 days)
        - BONE_BLOCK:600
        # 50 => 60
        - BREAD:60
        
        
    blocks
      # RC: Added cocoa beans (works - just make sure cocoa bena is inside the base boundry, log does not need to be)
      cocoa_beans:
        harvest:
          - COCOA_BEANS:3:3
            
 
  farm
    fuel
      items:
         # NEW- same as 64 bone blocks
        - DIAMOND_AXE: 23040
        # NEW (1 more iron than shears so 50% more)
        - IRON_AXE: 2700
        # 900 => 1800
        - SHEARS: 1800
        # 25 => 60 :  STACK so 64*18 units
        - BONE_MEAL:60
        # 225 => 600   :  STACK so 64*18 units (max 8 days)
        - BONE_BLOCK:600
        # 50 => 60
        - BREAD:60

```

  
# Essetnails/config.yml

I think this also requires one (or both of the following). If Essentials is not loaded
the PurPur.config and server.properties can be set to enabe a kick-on-afk. Thjose settings
are OVERIDDEN by EssentialsX so a default can be set and if EssentialsX is installed it willoverride that.

See also the LuckPerms settings

- essentials.afk.auto (enable auto AFK)
- essentials.afk  (allow manual AFK such as admins)


```
# Auto-AFK
# After this timeout in seconds, the user will be set as AFK.
# This feature requires the player to have essentials.afk.auto node.
# Set to -1 for no timeout.
auto-afk: 300

# Auto-AFK Kick
# After this timeout in seconds, the user will be kicked from the server.
# essentials.afk.kickexempt node overrides this feature.
# Set to -1 for no timeout.
# RC: -1 to 420 (it's important to shut down on-demand server)
auto-afk-kick: 420
```


# Graves


```
token:
    basic: # Token name, you can define multiple tokens.
      material: SUNFLOWER # https://hub.spigotmc.org/javadocs/bukkit/org/bukkit/Material.html
      name: "Grave Token" # Grave token name.
      craft: false # Can players craft this grave token. (RC: Was true)
  
    entity:
    # Here we override the options for entities, remember you can copy options from the default section.
    PLAYER: # Override default options for players.
      grave:
        enabled: true
        # RC: 10800 +> -1 (never timeout)
        time: 10800

      world:
        - world
        - world_nether
        - world_the_end
        # RC was commented out, allow ALL worlds
        - ALL

     ############
      # Teleport #
      ############
      # Teleportation options.
      teleport:
        enabled: false # Can the entity teleport to their grave from the Graves GUI. (RC: true => false)


  ###################
  # Entity Override #
  ###################
  # Override default config options for entities that match these types, entity type names must be uppercase.
  # https://hub.spigotmc.org/javadocs/bukkit/org/bukkit/entity/EntityType.html
  entity:        
    # Here we override the options for entities, remember you can copy options from the default section.
    PLAYER: # Override default options for players.
      grave:
        enabled: true
        # RC: 10800 +> -1 (never timeout)
        time: -1
        
      ##############
      # Experience #
      ##############
      # If store is false it will store what Minecraft would normally drop, if you want to fully disable it, set store to true and store-percent to 0.
      experience:
        store: true # Should all the entities EXP be stored in the grave. If false only the vanilla drop amount will be stored.
        # RC: Store MOST of a users expereince: 0.8 => 0.95
        store-percent: 0.95 # How much of the EXP should be stored, 0.8 = 80%, 1 = 100%, 0 = 0%.

```

# PurPurMC.yml

Enable default AFK (wich EssentialsX is ikley going to override) and sign editing. Sign
editing si doen by holding a sign and RIGHT-Click on the sign. ALL editing codes are allowed.

```
# If player is AFK treat as sleeping (mostly to allow for skipping night)
count-as-sleeping: true
# Allow silk touch items to pick up spawners - works IF perms are set.  See [luckperms](luckperms)
silk-touch:
  enabled: true
# Kick idle players (requires player-idle-timeout in server.properties)
player:
  idle-timeout:
    kick-if-idle: true
 
# See also https://minecraft.fandom.com/wiki/Formatting_codes
sign:
  right-click-edit: true
  allow-colors: true

 
 ```
 
 # server.properties
 
 ```
 # Allows for kick-if-dile purpur config to reduce server loads
 # - This works but for some reason 300 == 7 minutes????
 player-idle-timeout=300
 
 # RC: Enable command blocks to allow custom teleporting for OP
enable-command-block=true

# RC: Disable PVP
pvp=false

# RC: Special server port to reduce bots
server-port=24199

# RC: Resource pack : URL changes with each upload see above
resource-pack=https\://download.mc-packs.net/pack/48172bf3d1a616fd360ba80d8553adcae9f2419c.zip
resource-pack-sha1=48172bf3d1a616fd360ba80d8553adcae9f2419c

# RC: Enforce whitelist YES
whitelist=true
# RC: White list - if user is removed from whitelist they are kicked
enforce-whitelist=true

 ```


# dynmap/configurations.txt

Move tiles to a seperta earea to make it easier to backup configurations and such.
Since this is a dedicated server the system duses local web server for improved
performance (it uses PHP 7 so make sure that is installed).

To migrate default to this location:

- cd ~/minecraft
- mkdir dynmap-data
- mv plugins/dynmap/web/tiles dynmap-data
- Update plugins/dynmap/configuration.txt per below


```
# The path where the tile-files are placed. REALTIVE to dynmap home (web/tiles)
tilespath: ../../dynmap-data/tiles

# The path where the web-files are located.
webpath: web

# The path were the /dynmapexp command exports OBJ ZIP files
exportpath: ../../dynmap-data/tilesexport


# The network-interface the webserver will bind to (0.0.0.0 for all interfaces, 127.0.0.1 for only local access).
# If not set, uses same setting as server in server.properties (or 0.0.0.0 if not specified)
#webserver-bindaddress: 0.0.0.0

# The TCP-port the webserver will listen on.
webserver-port: 24198

...


# Parallel fullrender: if defined, number of concurrent threads used for fullrender or radiusrender
#   Note: setting this will result in much more intensive CPU use, some additional memory use.  Caution should be used when
#  setting this to equal or exceed the number of physical cores on the system.
# RC: 4 => 1 to reduce server loads => 4 (after hundreds of hoopers were removed by Isaac server loads are no longer an issue)
parallelrendercnt: 4


# NOTE: render-triggers 
# RC: one reason dynmap might not be rendering is that a pre-generated world, followed by
# a PURGE (to add fog of war) means the only time dynmap will render is if the chunk changes.
# Which effectively disbales exploration. And playermove is NOT recomended as it can impact server
# performacne as every time a playe rmoves between chunks they are rendered.


``` 
 
# Custom Recipies - available in CC only

Note that the CC Recipe book is not working (Book + Crafting-Bench). When created it looks like
a glowing wrench but when added to inventory becomes a normal wrench (vanilla tweaks). Possible collision
with vanilla tweaks. Also the "Add to Vanilla Recipe Book" is nto yet working and their is a ticket that
addresses the concept but it has no changes. Note the GIVE command also does not grant the proper item.

Can be made in normal crafting bench but will NOT appear in recipe book

## Elytra

```
Feather          Sugar-cane  feather
glowstone-dust   quartze     glow-stone-dust
feather          sugar-cane  feather
```

## Gold-Pipe (transport pipes - ALT)

```
        Glass
Glass  Comparator    Glass
        Glass
```

## Silk Touch Axe
```
feather  feather     feather
feather  Diamond-Axe feather
feather  feather     feather
```
 
 
 ## Chunk Collector Chest
 
 ```
  --        Ender Eye   --
  --        HOPPER      --
  --        Chest       --
```
 
 
 ## Auto Crafting chest
 
 ```
  --        Book              --
  --        Crafting Bench    --
  --        Chest             --
```
 
 ## Auto Crafting chest
 
 ```
  --        Book              --
  --        Crafting Bench    --
  --        Chest             --
```
 
 
 ## Sell Chest
 
 ```
  --        Gold Ingot        --
  --        Hopper            --
  --        Chest             --
```

 ## Storage Chest
 
 ```
  Chest     Hopper            Chest
  Chest     Chest             Chest
  Chest     Hopper            Chest
```
  
# WorldEdit

Prevent teleporting wiuth the compass (which is really annoying when playing / testing as op)
to something far less likely to be held in hand (yet makes odd sense) WorldEdit/config.yaml

```
navigation-wand:
    # RC: compass => elytra
    item: minecraft:elytra
    max-distance: 100
```
 
# Advanced Portals

``` 
# RC: by using WorldBuild we avoid a conflict with AXE for OP. If iron axe is a selector it cannot be used normally by users with
# permission to make portals.
WorldEditIntegration: true
```

 
 
# Luckperms and other commands
 
 Note that purpur permissions are alwasy FALSE (unless others specified) even for OP. OP is a tool not
 a ROLE.

 
 The following script will apply permissions to a runing minecraft server. Just run this script as 'game' or anyone with
 access to the tmux. Be sure to review for any errors via 'tmux a' and scroll (`CTRL-B [`) through the results, use
`ESC` key to exit scroll. If consistent issues occur increase sleep by 0.05 until relaible. Or code up a MUCH bettersystem, via expect 
or tweaks to the Perl script / tmux.
 
 
 ```
#!/usr/bin/perl

#
# FILE: ~game/luck-perms.script.yml luck-perms.script.pl
# USAGE: perl ~game/luck-perms.script.yml luck-perms.script.pl
#

use Time::HiRes qw/sleep/;

print "Apply lucky perms, minecraft MUST be running in tmux: ";
while(my $l = <DATA>) {
  system("tmux send -t game-server '$l' ENTER");
  # Sleep a little bit otherwise LucKperms does not have time to apply changes.
  sleep 0.1;
  print STDERR '.';
}
print "\n -- Done:  'tmux a' for results of commands\n";


__DATA__
 
say Allow playes to see TPS Bar
lp group default permission set bukkit.command.tpsbar true
 
say Enabling Kick on AFK (EssentialX)
lp group default permission set essentials.afk.auto true
 
say Enabling drop/place spawners with silk touch tools
lp group default permission set purpur.drop.spawners true
lp group default permission set purpur.place.spawners true
 
say Granting access to Better Farming Crop 2 (was 4)
lp group default permission set betterfarming.crop.1 true
lp group default permission set betterfarming.crop.2 true
lp group default permission set betterfarming.crop.3 true
lp group default permission set betterfarming.crop.4 true

say Better Farming Tree (see also Nova)
lp group default permission set betterfarming.tree.1 true
lp group default permission set betterfarming.tree.2 true
lp group default permission set betterfarming.tree.3 true
lp group default permission set betterfarming.tree.4 true

say Granting access to Better Farming Ore, removing for then setting to 1 (was 2)
lp group default permission set betterfarming.ore.1 true
lp group default permission set betterfarming.ore.2 true

say Alow plater to request farm via Interface
lp group default permission set betterfarming.command.get true


say Granting Edit Sign ability and add colors
lp group default permission set purpur.sign.edit true
lp group default permission set purpur.sign.color true
lp group default permission set purpur.sign.style true
lp group default permission set purpur.sign.magic true

say Granting Chest Sorting
lp group default permission set chestsort.use true
lp group default permission set chestsort.use.inventory true

say Enable FarmerUpgrade tools 
lp group default permission set farmer true

Say Grant Cusotm Crafting System Recipe Book
lp group default permission set customcrafting.item.recipe_book true
lp group default permission set customcrafting.inv.recipe_book.* true
lp group default permission set customcrafting.cmd.recipes true

Say Grant Balance
lp group default permission set essentials.balance true

# NON of this works -- growing disapointed with Deep Storage (not sure what is wrong)
Say Crafting API Recipe Book (need 'command' to use any commands)
lp group default permission set crapi.command true
lp group default permission set crapi.book true
lp group default permission set crapi.craft true
lp group default permission set crapi.craftall true

lp group default permission set crapi.craft.sorterloader true

Say lagassist view
lp group default permission set lagassist.use true
lp group default permission set lagassist.chunkanalyser true

Say Chest Sorting
lp group default permission set chestsort.use true
lp group default permission set chestsort.use.inventory true
lp group default permission set chestsort.hotkey.middleclick true
lp group default permission set chestsort.hotkey.shiftclick true
lp group default permission set chestsort.hotkey.doubleclick true
lp group default permission set chestsort.hotkey.shiftrightclick true

Say Eternal Light
lp group default permission set eternallight.use true
lp group default permission set eternallight.mode true
lp group default permission set eternallight.target true

Say Upgradable Hoppers
lp group default permission set uhoppers.hoppers.5 true
lp group default permission set uhoppers.command.get true
lp group default permission set uhoppers.command.list true


Say Nova Permissions - defaults are fine, no changes needed

Say Simple Portals
lp group default permission set simpleportals.portal.* true
 
 ```
 
 
### Luck perms Deep Storage (removed) 
 
Note that deep storage was removed in 0.4 as being too dangerous (possibly massive loss of inventory if mod brakes) and NOVA
being a better Minecrafty solution. Permissions for it were

```
Say Deep Storage Access
lp group default permission set deepstorageplus.create true
lp group default permission set deepstorageplus.wireless true
```




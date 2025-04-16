# Simple Inventory

A Denizen script for managing inventory handling without custom items or commands.  There are numerous
limitations that are triggered by the desire to keep lag low. The goal of this is to replace the huge
network of Hoppers and redstone that cause signifciant loads.

# Author

- Robb Canfield <robb@canfield.com>
- Copyright 2025
- License: Proprietory during development

# TODO:

- Add images and find a way to publish this in a maintainable way.
- Fix bugs
- Deal with performance issues
- Tune max ranges and speed of movement

## Installation

- Install Denizen per web site instructions
- Place `simple-inventory.dsc` file and `pl_commands.dsc` in Denizen Script directory (./plugins/Denizen/scripts/)

NOTE: During Alpha the mod is DISABLED by default. See [Commands](#commands) for how to enable/disable. And while scrolling
down to that section please consider reading this document.


## GUI

To make it easier to access inventory (chests) when there is a sign or frame attached the Right-Click button
now passes through to the attached chest.
    - Crouch (SHIFT) and right click to interact with the sign/frame normally
        - Right clock rotates item in frame (which crouching)
        - Left click pops the item out of the frame (which crouching)
    - To Edit a sign (limitation caused by Minecraft)
        - OR use stand up and using a STICK, SIGN, or FRAME Left click
        - Crouch (SHIFT) and left click with your hand (Microsft)

- Editing a sign will update the inventory system if aplicable tokens are found
- Editing a frame will update the inventory system if aplicable tokens are found
- Breaking either will remove the applicable inventory element
- If a Feeder is right clicked (which probably pops up the edit window, close it)
    - In the user chat will be a summary of the Feeder
    - Including any JAM message


## Therory of operation

The Inventory system orks by using frames (sticks surroudning leather) and signs.  The following inventories are know
to work:

- chest
- Double Chest
- Trapped Chest
- Schuker Box
- Barral
- Hopper
- Possible others

**TIP**: Use hoppers to add more targets or control inventory. For example on a furnace add a hopper on the back and add a FRAME with Coal (or any fuel),
on the top add a hopper and attach ad frame an IRON ORE in it. FInally add a hopper on the bottom and add asign with an ARROR rotated
to point up to SEND this item, see below.


## Frames

- Add a frame to a chest, any side. And place an item in it. That item is what will be sent to the chest. This is
an easy and athestic way to define inventory.
- A frame with an Arror rotated to point up (CROUCH Right Click on frame to rotate) to make it a FEEDER (sender), see below
- Multiple frames can be placed on an inventory
- You have have mutliple frames with the same item, this is actually quite normal. For example 4 chests for Cobblestone.

## Signs

Signs are the most flexible, if least attractive option. Signs are attached to the applicable inventory. Like Frames, different signs
can specify the same items.


### Targets (INV)

The sign should have the first line containing ONLY (case insensitive):
    - [inv]

The next lines can mix-n-match of tokens which are either item names or wildcards using multiple per lines. Spaces
are used to seperate items. You cannot wrap tokens across a sign line. You can have as many signs (and frames) on an
inventory as will fit. For a double chest that is 6.

- Iten names: Case insensitive, spaces replaced with underscores. The names are 'minecraft' names without any prefix. All
the following are valid and you can put as many as you want on the sign
    - wheat
    - Wheat_Seeds
    - Carrot
    - Cobblestone
- Wildcards. You can use '*' to match any number of characters (anywhere) and '!' as the first character of the token to prevent an item from being stored. 
    - Do NTO store cobblestone BUT store any other item name ending with 'stone'
        - !cobblestone *stone
    - Find anything with raw anywhere in the name
        - *raw*
    - NOTES:
        - Order on the sign matters, first match wins. So for '!cobblestone' if cobblestone is seen then that inevntory is SKIPPED for that item
        no what follows.
        - Wildcards are little slower than pure Items. So try to limit yourself to 20 or so. The upper limit is not known at this time and it
        depends on other players.

### Overflow (OVERFLOW)

Overflow accept items ONLY if that item found targets but they were all full. This will not get used if the item was not found
in any normal (INV) target.
    - [OVERFLOW]
    - same tokens as for INV

### Overflow (OVERFLOW) Fallback

If overflow cannot accept any item then these chests are used. It is the same as (OVERFLOW) but cannot have any tokens
    - [OVERFLOW]

### Uknown (UNKNOWN)

If no matching targets were found then all chects with typss type are use. It has no filters.


### Feeders (FEEDER)

Feeders send their inventory to any other matching inventory. These are defined with the first line (case insensitive)
    - [feeder]

The sign next lines are parsed as tokens on a SPACE. The following tokens are accepted and processed in order.
    
- nearest
    - Sets sort order (nearest is the defualt). Searches for matching targets for each item in order of range (ecludian)
    to the Feeder.
- random
    - Sets sort order to random target inventory for roughly equal distribution
- quiet
    - If a Feeder jams because it cannot send items a particle effect is applied. If that bothers
    you use this token to disable it per feeder
- a number (4, 6, 32)    
    - Limits the range of this feeder to this number of blocks up to max range. Range is a cube around the feeder.
- Compass directions: N S E W U P  (north, south, east, west, up, down)
    - This is a odd one. It helps limit the directions the FEEDER will lookf or targets. For example
    if you specify 'U' (yes just U), then only inventory above the chest will be considered. You
    can have multiple facing names.

Tip: Item names signs (or items in frames) are the lowest lag option available and are encouraged.

Feeders always use the first (top-right to bottom-left) item when sending. If that item cannot be placed anywhere (no targets, everythign full, etc.).
If a feeder cannot send that item, the Feeder is considered JAMED. In this case a particle effect is applied (unless 'quiet' was used) and a JAM
message is logged. You can see this right clicking  n the Feeder and reviewing the message sent to your chat window.


## Target determinination

This can geta  little tricky. There are 5 lists and they are processed in this way.

- Process the lists in this order
    - Direct:
        - 1. Items (frames/signs)
        - 2. Wildcards (signs)
    - If an item match was found in the Direct group but there was no room:
        - a. Overflow Items
        - b. Overflow Wildcard
    - If NO item was found in the direct group:
        - a. Unknown

For each list:

- Collect all targets within range each feeder settings
- Sort these by nearest/random per each feeder settings
- Verify target is within facing of the feeder (default is all directions)
- Within this group the FIRST chest in the list that matches (exact, then wildcard) WINS.
    - Control order by distance and feeder range settings, as well as facings.


## Redstone

Any inventory that is receiving redstone will ignore that Feeder or Target. FOr example applying redstone to a Feeder
stops it from sending. And a target with a redstone applied is not considered, as if it never existed. That means this
might impact oveflow/unknown processng


## Commands

- /simple_inventory <plater-name>
    - list : Shows a list of all inventory chests. The lists are presented in the order they are looked up.
    - enable : Enables the inventory movement
    - disbale : disabled the inventory movement
    - clear : Removes all inventory 
    - repair : Rebuilds the inventory using all sings/frames within a radius of 5 chunks around the player.
    This CAN cause lag. If you cannot perform the command contact and OP with your world cordinates
    of the center for the area to repari.


## Specifications

- Max range of a Feeder is 170 blocks radius
    - Radius is CHUNKSquare radius not spherical. So this is roughly an 11x11 chunk area centered around the feeder. It is NOT chunk aligned.
- Minimum radius is 1.5. This prevents infinite loops and prevents some issues with double chests.
- Speed is approc 1 stack every 1/4 tick (subject to change) per feeder.
- All moves are done in the same tick so nothing should be lost or duplicated but please be on the lookout for bugs


## Limitations:

- Hanging sounds will not work when above a chest
- This script assumes kind players. Abuse may well crash the system ot lag it. If you find a lag issue please notify the author with
a reproducable description or your world cordinates so it can be investigated.
- A lot probably


The system works on a pre-programmed order.

## Theory of Operation

The basic logic for managing moves is
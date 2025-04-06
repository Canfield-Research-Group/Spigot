    # ***
# A VERY simple invrneoty system propsoal
# Place a Frame  with the desired item in it on an object
#   * chests (any side)
#   * hoppers (any side)
#   * use hoppers to feed other elements this avoids very complicated
#   side detection logic
#
# Optimizations
#  * adding a frame with an item in it, data this in player flags/ This is a filter
#  * Any chest that has a frame with chest in is a PUSH
#    * You can stills ort chests by placing frame on the Hopper
#  * If the hopper is redstone powered  then it no longer accepts data
#  * Storing items works by closest (ties are non determinsitic) then further as full


# ------------------------------------------------------------------------------
# SIMPLE INVENTORY MAPPING STRUCTURE (Version 1)
#
# Each player stores inventory trigger mappings in:
#   player.flag[inventory_simple.<world>.<trigger_location>] = <entry_map>
#
# The inventory_simple is the prefix to avoid collisions between plugins
#
# <trigger_location> is the `.simple` string form of the location (x,y,z)
# The world name is used as a namespace, e.g. inventory_simple.overworld.1777,112,-1271
#
# The <entry_map> contains the following short keys to reduce memory usage:
#
#   t: trigger location (the location of the sign or item frame)
#   c: chest location (the block with inventory, like chest, barrel, hopper)
#   i: item name string (optional; usually the item displayed in frame)
#   g: group matching using wildcard (optional)
#
# Example entry (in real life this is on ONE line to avoid spaces)
#   flag.player.inventory_simple.overworld.1777,112,-1271 = map[
#       t:1777,112,-1271;
#       c:1777,112,-1270;
#       i:apple;
#       g:food
#   ]
#
# All locations are stored in `.simple` form for compactness and easy lookup.
# These mappings are fast to query per trigger or group, and cross-world access
# is enabled by using world-scoped namespaces.
#
#
# ------------------------------------------------------------------------------



# TODO: Structure of code to avoid horrible lag
    # - move full stacks (easier code) - one per tick, per push?
    # - Can multiple scripts run, one for each player so one player does not hog?
        # - Or we code this ourself?
    # - detect target full and skip it
    # - detect target has redstone ON to it and skip (ie stopped hoppers)
    # - range limit, closest
    # - LONG distance transport: water streams, tricky but works. Easier with bubble elevators (souls and), trains work as well but can be more/less  complex depdnign on route
    #  - Do NOT support interworld inventory or LONG range chaining. Do that the minecraft way. Kepe it simple and clean


# TODO Command to clear player flags for inventory

# TODO command to rebuild inventory matrix based on x chunks around player (default is bed-spawn chunks if that flag exists), elase 5 chunks

# TODO intercept sign being attached to hopper of chest (or anything with a simple inventory), AS: name is the name (* = wildcard, ends with)
    # - Does Denizen have a '*' wildcard for suffix, prefix, etc. OR some way to match: *copper*
    # - We should be able to support groups: ORE, INGOTS, etc.
# TODO intercept frame being attached to hopper of chest (or anything with a simple inventory), use item in frame as ITEM


# TODO Detect if sign is a PUSH type sign:  AS: PUSH and set flag appropiatley


# ***
# *** Signs/Frames can make clicking on chests very challenging. Adjust the right-click to
# *** pass through the right-click to the chest unless crouching
# ***
sign_or_frame_events:
  type: world
  debug: false
  events:


    # ==== TEST CODE just need an easy place to add this
    #on event SOMETHING
    #- define item_name "cobblestone"
    #- if <[item_name].advanced_matches[!*cobblestone|*stone]>:
    #    - debug log "<green><[item_name]> MATCHED!"
    #- else:
    #    - debug log "<red><[item_name]> NO MATCH!"


    # - EVENT: after player opens sign : WORKS BUT not needed

    # - EVENT: on/after player cha nges sign : WORKS
    after player changes sign:
        - define loc <context.location||null>
        - if <[loc]> != null :
            - define details <proc[inventory_simple_sign_details].context[<player>|<[loc]>]>


    # === Right click on item frame
    # Surprising this works for frams
    on player right clicks entity:
        # TIP: Do NOT use context.location here, it will error out
        - if <player.is_sneaking>:
            - stop

        # De-bouncer, to avoid triggering on item frame and item in frame
        - if <player.has_flag[inventory_simple.clicked_recently]>:
            - stop
        - flag player inventory_simple.clicked_recently duration:1t

        - define details <proc[inventory_simple_frame_details].context[<player>|<context.entity>]>
        - define trigger <[details].get[trigger]>
        - if <[trigger]> == na:
            - stop

        # an auto repair, in case something went wrong, this should not impact performance in any meaningful way
        - run inventory_simple_add_mapping def:<player>|<[details]>
        - define chest <[details].get[chest]>
        - inventory open destination:<[chest]>
        - determine cancelled


    # === Right click on sign
    on player right clicks block:
        # make sure location is defined, if not then exit now (sucha s right clicking in air and SPigot/purpur routed it to 'clocks blokc' event' event anyway)
        # Exit as quick as possible if this event is not applicable (crouching bypasses the override)
        - define loc <context.location||null>

        # Sneaking and right click lets you edit a sign SOMETIMES but it is NOT reliable, it was a few hour ago. Not sure what's up with that
        # in any case we need a bypass so stick allows edit
        - if <player.is_sneaking> || <player.item_in_hand.material.name> == stick:
            - if <[loc]> != null:
                # Remember to check this sign being edited in some player action
                - flag <player> inventory_simple.pending_sign:<[loc]>
            - stop


        - if <[loc]> == null:
            - stop

        - if <player.has_flag[inventory_simple.clicked_recently]>:
            - stop
        - flag player inventory_simple.clicked_recently duration:1t

        - define details <proc[inventory_simple_sign_details].context[<player>|<[loc]>]>
        - define trigger <[details].get[trigger]>
        - if <[trigger]> == na:
            - stop

        # an auto repair, in case something went wrong, this should not impact performance in any meaningful way
        - run inventory_simple_add_mapping def:<player>|<[details]>
        - define chest <[details].get[chest]>
        - inventory open destination:<location[<[chest]>]>
        - determine cancelled


    # === ENTITY (Frame) EDITED ===
    # use 'item' to amtach any, otherwise specific item name.
    # context
    #   * frame : frame object, eg frame.location
    #   * item : item element, eg; item.material.name
    #   * action : PLACE, REMOVE, ROTATE
    #
    after player changes framed item:
        # Location is used in this case, and refers to the location the frame is placed
        - define frame <context.frame>
        - define item <context.item>
        - define action <context.action>

        # No wait is needed as this is an AFTER event
        - define details <proc[inventory_simple_frame_change].context[<player>|<[frame]>|<[item]>]>
        - define trigger <[details].get[trigger]>
        - if <[trigger]> == na:
            - stop

        # an auto repair, in case something went wrong, this should not impact performance in any meaningful way
        - run inventory_simple_add_mapping def:<player>|<[details]>
        - determine cancelled

    # === (Sign) placed ===
    after player places *_sign:
        - define details <proc[inventory_simple_sign_details].context[<player>|<context.location>]>
        - define trigger <[details].get[trigger]>
        - if <[trigger]> == na:
            - stop
        - define chest <[details].get[chest]>
        - run inventory_simple_add_mapping def:<player>|<[trigger]>|<[chest]>


    # === Sign block broken ===
    after player breaks *_sign:
        - define block <context.location>
        - define block_name <[block].material.name>
        - if !<[block_name].ends_with[_sign]>:
            - stop
        - run inventory_simple_remove_mapping def:<player>|<[block]>


    # === Frame entity broken (REMOVED) ===
    # This is NOT reliable as the 'on entioty dies' is not reliable called when a block holder a frame is broken. 
    # Favor code that dynamically removes missing items during auto sorting procesing.



# ***
# ***
# *** BENCHMAKR: 49 chests take 2ms (usually 0-1) to scan and remove duplciates and add an item. That should be OK
#  TODO:  BECNHMARKING OK but item scanning will be the true test and that may take a LOT longer
# ***
inventory_simple_add_mapping:
  type: task
  definitions: player|data
  debug: false
  script:
    # ==== Tempory OP this for developer
    - if !<player.has_permission[minecraft.command.op]>:
        - stop

    - define trigger_loc <[data].get[trigger]>
    - define chest_loc <[data].get[chest]>
    - define item_filter <[data].get[filter]||na>
    - define group_filter <[data].get[group]||na>
    - define is_feeder <[data].get[feeder]||f>

    - if <[trigger_loc]> == null || <[chest_loc]> == null:
        - determine false

    # TIP: originally the idea was to shoten locations by dropping world. But that complicates the lookup code
    # and only aves aroun 7.5 KB for even 500 entries per player. Until proved necessary let's favor simplistiy and reduced
    # bugs and keep the location fully qualified

    # The parser cannot handle the colon delimiter and ',' inside the entity_text being built. So use '='
    # OR build the map structure directly using ';' but that involves aleays storing item/group. In this
    # case I decided to always define item/group ("" it not set/passed) for consitency. So we just built
    # the map directly using ONE LINE to avoid parsing issues
    #  * !!! Always use '=' in maps even through doc shows ':' as being more common. The ':' is often mis-parsed
    #  * Denzien just gets weirder and weirder

    # Remove the existing flag (if any) and replace with the new one to form an auto-repair
    - define start_time <util.current_time_millis>

    - run inventory_simple_remove_mapping def:<[player]>|<[trigger_loc]>
    - define flag_path <proc[inventory_simple_flag_path].context[<[trigger_loc]>]>
    - define entry <map[t=<[trigger_loc].block>;c=<[chest_loc].block>;i=<[item_filter]>;w=<[group_filter]>;f=<[is_feeder]>]>
    - flag <[player]> <[flag_path]>:->:<[entry]>

    # == DEBUG
    - define end_time <util.current_time_millis>
    - define duration <[end_time].sub[<[start_time]>]>
    - debug log "<green>ADD took <[duration]> ms"
    - determine true


inventory_simple_remove_mapping:
  type: procedure
  definitions: player|trigger_loc
  debug: false
  script:
    # ==== Tempory OP this for developer
    - if !<player.has_permission[minecraft.command.op]>:
        - stop

    - define flag_path <proc[inventory_simple_flag_path].context[<[trigger_loc]>]>
    - define trigger_key <[trigger_loc].block>
    - foreach <[player].flag[<[flag_path]>].filter_tag[<[filter_value].get[t].equals[<[trigger_key]>]>]> as:entry:
        - flag <[player]> <[flag_path]>:<-:<[entry]>



inventory_simple_flag_path:
  type: procedure
  definitions: trigger_loc
  debug: false
  script:
    - define world_name <[trigger_loc].world.name>
    - define flag_path inventory_simple.<[world_name]>
    - determine <[flag_path]>


# ****
# **** Return an array of the frame_loc and chect_loc if both are valid. Else return nulls.
# **** Effort is made to exit as quickly as possible
# **** NOTE: Frame valdiation is really tedious as item frames are quite annoying to deal with comapred to signs
# ****
# **** While this returns location data it should NOT be added to the simple inventory.
# ****
inventory_simple_frame_details:
  type: procedure
  definitions: player|entity
  debug: false
  script:
     # There is no Entity
    - define no_match <list[null|null]>

    # Exit as quick as possible if this event is not applicable (wrong type)
    - if <[entity].entity_type> != item_frame:
        - determine <[no_match]>


    - define data <proc[inventory_simple_frame_change].context[<[player]>|<[entity]>]>

    # Return both frame and attached block (normal locations, not simplified)
    - determine <[data]>
    - stop


# ****
# **** Return an array of the sign_loc and chect_loc if both are valid. Else return nulls.
# **** Effort is made to exit as quickly as possible
# ****
# **** Called when a frame change occurs, such as item in frame added, removed, rotated
# ****
# *** NOTE: Be sure to `wait 1t` before calling this function so rortate is processed, otherwise things get otu of sync
# *** Unless user 'after' events instead of 'on'
inventory_simple_frame_change:
  type: procedure
  definitions: player|frame|item
  debug: false
  script:
    # Id no match is found return nulls for each element
    - define no_match <map[trigger=na;chest=na]>

    # Frames are peculary, so they need to be trated a bit different
    - define frame_loc <[frame].location>
    - define rotation_vector <[frame].rotation_vector>
    - define attached <[frame_loc].add[<[rotation_vector].mul[-1]>]>
    - define is_allowed <proc[is_chest_like].context[<[attached]>]>
    - if <[is_allowed].not>:
        - determine <[no_match]>

    # If itemw as not passed then fetch from passed frame data
    - define item <[item]||<[frame].framed_item>>

    # get item filter, this is easy, it is the item name
    - define item_filter <[item].material.name>


    - if <[item_filter]> == air:
        # Empty frame - use 'not applciable' (common in this script, and saves space in large maps)
        - define inv_type na
        - define item_filter na
    - else:
        # If an arrow we are interested in rotation, an UP pointing arrow is treated as an AUTO SORTER
        # he challenge is we want the rotation AFTER it is rotated not before ....
        - define item_rotation <[frame].framed_item_rotation>

        # These go through a sequence starting with initial. Sometimes it takes 2 rotations to trigger
        #   * NOTE: Be sure to `wait 1t` before calling this function so rortate is processed, otherwise things get otu of sync
        # 
        # Most items visually appear pointing up when added to a frame(rotaetion NONE)
        # But ARROWS appear pointing upper-right at rotation NONE, the following table shows how arrows
        # visually move. This is because the image map for arrows was made with the upper-right visual.
        #   * none (Arror pointing upper right)
        #   * clockwise_45 (arrow pointing right) 
        #   * clockwise (pointing down-right)
        #   * clockwise_135 (pointing down)
        #   * rotation_flipped (pointing down-left)
        #   * flipped_45 (pointing left)
        #   * counter_clockwise (pointing upper-left)
        #   * counter_clockwise_45 (poinitng up)
        - if <[item_rotation]> == counter_clockwise_45:
            # feeder
            - define inv_type feeder
        - else:
            # target
            - define inv_type target

    # Return both trigger and chest-like inventory location. use a map to self-document. This is all internal
    # data so size is not relevent.
    - determine <map[trigger=<[frame_loc]>;chest=<[attached]>;filter=<[item_filter]>;type=<[inv_type]>]>


# ****
# **** Return an array of the sign_loc and chect_loc if both are valid. Else return nulls.
# **** Effort is made to exit as quickly as possible
# ****
# TODO: See https://meta.denizenscript.com/Docs/Search/match
# TODO: parse sign using simple parsing for now:
# TODO: FIRST LINE: [feed], [inv]
# TODO: SECOND LINE: https://meta.denizenscript.com/Docs/Search/match, all spaces/newlines removed
# TODO: with newlines automatically getting a '|'
inventory_simple_sign_details:
  type: procedure
  definitions: player|location
  debug: false
  script:
    # Id no match is found return nulls for each element
    - define no_match <map[trigger=na;chest=na]>

    - define block <[location]||null>
    - if !<[block]>:
        - determine <[no_match]>

    - define block_name <[block].material.name>
    - if !<[block_name].ends_with[_sign]>:
        - determine <[no_match]>

    # Signs re SO much simpler than frames, so optimize for signs (bug backward/forward still seem weird, and not reliable)
    - define facing <[block].block_facing||null>
    # This is NOT just attached blocks but also blocks behind the sign. Filter for only attached  proved annoying so allow a sign to be in FRONT of chest
    - if !<[facing]>:
        - determine <[no_match]>

    - define attached <[location].relative[<[facing].mul[-1]>]>
    - define is_allowed <proc[is_chest_like].context[<[attached]>]>
    - if !<[is_allowed]>:
        - determine <[no_match]>

    # Calling proc with a list often causes the list to be broken into paramaters so the first list item
    # is assigned to argument one of the proc. Using named argument should have worked but did not. And using
    # a assigned variable to hold sign lines did not reoslve the issue. You cannot even use a listp[ wrapper 
    # as that passes a double list thing. oer Denizen us a string, an origina sign object or a map.
    # * See also https://guide.denizenscript.com/guides/basics/procedures.html
 
    # Seperated_by should be usable but is NOT, we will just use a comma since the parser uses that
    #
    # OK, I am so fucking tired of this Denizen parsing crap; I am sending the sign object to avoid lists passing to procedures.
    # and I need to reconsider Denizen. Maybe pure Java is not as fucking horrible parser is. While I liek some things in
    # Denizen refacrtoring code is a bloody waste of time for any complex. If we need another parser for text just
    # recode it and break out tiny procedures. Seems the way it is.
    - debug log "<red>CONTENTS: <[block].sign_contents>"
    - define sign_details <proc[process_sign_text].context[<[block]>]>

    - debug log "<red> Returned sign details: <[sign_details]>"

    # Return both trigger and chest-like inventory location
    # TODO: fill in filter and type wehen sign parsing is done
    - determine <map[trigger=<[location]>;chest=<[attached]>;filter=na;type=na]>



inventory_simple_list:
  type: command
  name: inventory_simple
  description: List or reset simple inventory triggers
  usage: /inventory_simple [list/reset]
  permission: inventory.simple
  debug: false
  script:
    - if <context.args.get[1]> == list:
        # Using '||' fallback is not reliable in Denizen due to parser limitations
        - if !<player.has_flag[inventory_simple]>:
            - narrate "<gray>No inventory data stored." targets:<player>
            - stop

        - define inv_map <player.flag[inventory_simple]>
        - foreach <[inv_map].keys.alphanumeric> as:world:
            - narrate "<yellow>• World: <[world]>" targets:<player>
            - define counter 0
            - foreach <[inv_map].get[<[world]>]> as:entry:
                - define trigger <proc[location_noworld].context[<[entry].get[t]>]>
                - define chest <proc[location_noworld].context[<[entry].get[c]>]>
                - define item <[entry].get[i]||"">
                - define group <[entry].get[g]||"">
                - narrate "<green>- Trigger: <[trigger]> | Chest: <[chest]> | Item: <[item]> | Group: <[group]>"
                - define counter <[counter].add[1]>
            - narrate "<yellow> Inventory storage size: <[counter]>"
        - stop

    - if <context.args.get[1]> == reset:
        - flag <player> inventory_simple:!
        - narrate "<red>All Inventory Simple triggers have been reset." targets:<player>
        - stop

    - narrate "<yellow>Usage: /inventory_simple [list|reset]" targets:<player>


# ==========================================
# == Move to these to the common library when done

# ***
# *** See if block is a chest like object. Not a furance. This is a whitelist
# *** so is NOT ideal. It was designed for use by inventory_simple which should
# *** only work for simple inventories. Otherwise use hoppers to feed.
# ***
is_chest_like:
  type: procedure
  definitions: loc
  debug: false
  script:
    - if !<[loc].inventory.exists>:
        - determine false
    - define inv <[loc].inventory>
    - define inv_type <[loc].inventory.inventory_type||NONE>
    - if <[inv_type]> in <list[CHEST|BARREL|HOPPER|SHULKER_BOX]>:
        - determine true
    - determine false

# ***
# *** Turns a location into a simple one (rounds) and  removes world. Often used
# *** to shoten location for large user flag lists
# ****
location_noworld:
  type: procedure
  definitions: loc
  script:
    # TODO: Combine the defines into a single line as possible -- or not. Denizen can screw that up in parsing   
    # There does not appear to be an .is[location]
    - define loc_obj <[loc].as[location]>
    - if <[loc_obj].world.exists.not>:
        - debug log "<red>Invalid location input: <[loc]>"
        - determine null

    # Now process normally
    - define loc_simple <[loc_obj].block.simple>
    - define parts <[loc_simple].split[,]>

    # TIp: the get end of [-2] means 2nd to last item. If we used `get[1].to[-1]` the entire list woudl be returned. The get is INCLUSIVE
    # Also note Denizen arrays start with [1] not 0.
    - define return <[parts].get[1].to[-2].comma_separated>
    - determine <[return]>


process_sign_text:
  type: procedure
  definitions: sign_obj
  debug: false
  script:
    # Return data set
    - define sign_type na
    - define filter na
    - define message na

    - define result <map[type={;match=na;error=na]>

    - define sign_obj <[sign_obj].block>

    # Instead o geting fancy I am going to do a DEAD SIMPLE code.
    - define sign_lines <list[]>
    - foreach <[sign_obj].sign_contents> as:line :
        # Clean lines of special cpracters
        - define line <[line].unescaped.strip_color.trim.to_lowercase>
        # Split these into more lines based on special characters
        - foreach <[line].split[regex:[,;| ]]> as:part :
            - define part <[part].trim>
            - if <[part].length> > 0:
                # Appen item to list
                - define sign_lines:->:<[part]>

    - if <[sign_lines].size> > 0:
        # Get the type if the first line is like "[something]"
        - define type <[sign_lines].get[1]>
        # Tip: Using after/before here is messy as '[]', but useing variable subsition worked!
        # NOTE: REGEX DID NOT for any of these
        #   * FAILS: no match  <[type].regex[\[(.+?)\]].group[1]>
        #   * FAILS: no match  <[type].regex[\[(.+?)\]].group[1]>
        #   * Fails: no match  <[type].regex[<[open]>(.+?)<[close]>].group[1]>
        #   * Fails: no match  <[type].regex[\<[open]>(.+?)\<[close]>].group[1]>
        #   * Maybe there is some quopting mechanism that qorks but I am really bored of these annoyances
        - define open '['
        - define close ']'
        # We cannot just use after["["] ... as that parse fails as does nto using quotes. using substituon works altough I am not sure
        # why given Denzien's literal parser. But then again, the parser is, from my experience, in desperate need of a refactor
        - define sign_type <[type].after[<[open]>].before[<[close]>]>
        - if <[sign_type].advanced_matches[inv|inventory]>:
            - define sign_type inventory
            # Containue parsing spec
            - define sign_lines <[sign_lines].remove[1]>
            - define filter <[sign_lines].separated_by[|]>
            # More denizien oddness, we cannat match regex: assumes  regex and escaping (regex\:) made not
            # difference and a a regex it alwasys matched. Denizen is fuzzy, you just have to deal with it.
            - if <[filter].contains[regex]>:
                - define message "regex: is not supported at this time. Wildcards (*?) are supported"
                - define filter na
        - else if <[type].advanced_matches[feed|feeder]>:
            - define sign_type feeder
            # The rest of the sign can be anything you want

    - determine <map[filter=<[filter]>;type=<[sign_type]>;message=<[message]>]>

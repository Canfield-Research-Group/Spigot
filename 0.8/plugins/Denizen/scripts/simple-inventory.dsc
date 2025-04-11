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
# Each player stores inventory feeder mappings in:
#   * player.flag[si.<world>.
#   * item. -- indexe dby EXACT item_name
#       * <item-name> = [t=tirgger-location,c=chest-location],i=item-name]
#   * wildcard = [t=tirgger-location,c=chest-location],w=item-name]
#   * feeder =  [t=tirgger-location,c=chest-location],t=item-name]
#
# 
#
# ------------------------------------------------------------------------------

# TODO: CHANGE the inventory storage
#
#       - Hoopers run at 2.5 items second so we have a lot of flexibility to be at least this fast
#           - sorter runs every tick and operates for 1ms max per, then saves state and waits for 1t
#           - consider running 1 cycle for all feeders and move a STACK (or whatever fits)
#           - process nearest chests with same item first, but a partial move due to room is still an event
#           - if no exact items match/have room process against the SIGN chests
#           - if none have room process the special '[inv] overflow' chest(s) in nearest order
#           - Based on total time to move items we may run more than one loop but even at that we will be
#           - running up to 64 a tick!
#           - main process will need to tracl state:
#               - current player name
#               - current feeder offset (we will assume a per move across multiple chests is in out 2ms range)


# TODO: Structure of code to avoid horrible lag
    # - move full stacks (easier code) - one per tick, per push?
    # - Can multiple scripts run, one for each player so one player does not hog?
        # - Or we code this ourself?
    # - detect target full and skip it
    # - detect target has redstone ON to it and skip (ie stopped hoppers)
    # - range limit, closest
    # - LONG distance transport: water streams, tricky but works. Easier with bubble elevators (souls and), trains work as well but can be more/less  complex depdnign on route
    #  - Do NOT support interworld inventory or LONG range chaining. Do that the minecraft way. Kepe it simple and clean


# TODO command to rebuild inventory matrix based on x chunks around player (default is bed-spawn chunks if that flag exists), elase 5 chunks


# ***
# *** Signs/Frames can make clicking on chests very challenging. Adjust the right-click to
# *** pass through the right-click to the chest unless crouching
# ***
si__sign_or_frame_events:
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


    # == Changes Sign
    after player changes sign:
        - define loc <context.location||null>
        - if <[loc]> != null :
            - define details <proc[si__parse_sign].context[<player>|<[loc]>]>
            - if <[details].get[message]>:
                - narrate <[details].get[message]>
            - run si__add_mapping def:<player>|<[details]>


    # === Right click on item frame
    # This just allows the open chest mechanism for frames. The actual inventory managment handling
    # is handled via 'changes framed item'. WE do do a repair here just in case
    on player right clicks entity:
        # TIP: Do NOT use context.location here, it will error out
        - if <player.is_sneaking>:
            - stop

        - define details <proc[si__frame_details].context[<player>|<context.entity>]>
        - if <[details].get[message]||"">:
            - narrate <[details].get[message]>

        # an auto repair, in case something went wrong, this should not impact performance in any meaningful way
        - define chest <[details].get[chest]>
        - if <[chest]>:
            - run si__add_mapping def:<player>|<[details]>
            - debug log "<green>Clicked: <[details]>"
            - run open_chest_gui def:<player>|<[chest]>
            - determine cancelled
        - else:
            # AUTO REPAIR: If there is no chest something broke, fix it
            - run si__remove_mapping def:<player>|<[details]>


    # === ENTITY (Frame) changes ===
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
        - define details <proc[si__parse_frame].context[<player>|<[frame]>|<[item]>]>
        - if <[details].get[message]>:
            - narrate <[details].get[message]>

        # an auto repair, in case something went wrong, this should not impact performance in any meaningful way
        - if <[action]> == BROKEN:
            - run si__remove_mapping def:<player>|<[details]>
        - else:
            - run si__add_mapping def:<player>|<[details]>


    # === Right click on sign
    on player right clicks block:
        # make sure location is defined, if not then exit now (sucha s right clicking in air and SPigot/purpur routed it to 'clocks blokc' event' event anyway)
        # Exit as quick as possible if this event is not applicable (crouching bypasses the override)
        - define loc <context.location||null>

        # Sneaking and right click lets you edit a sign SOMETIMES but it is NOT reliable, it was a few hour ago. Not sure what's up with that
        # in any case we need a bypass so stick allows edit
        - if <player.is_sneaking> || <player.item_in_hand.material.name> == stick:
            - stop

        - if <[loc]> == null:
            - stop

        - define details <proc[si__parse_sign].context[<player>|<[loc]>]>
        - if <[details].get[message]>:
            - narrate <[details].get[message]>

        - define feeder <[details].get[trigger]>
        - if !<[feeder]>:
            - stop

        # an auto repair, in case something went wrong, this should not impact performance in any meaningful way
        - run si__add_mapping def:<player>|<[details].escaped>
        - define chest <[details].get[chest]>
        - if <[chest]>:
            - run open_chest_gui def:<player>|<[chest]>

        - determine cancelled


    # === (Sign) placed ===
    after player places *_sign:
        - define details <proc[si__parse_sign].context[<player>|<context.location>]>
        - if <[details].get[message]>:
            - narrate <[details].get[message]>

        - define trigger <[details].get[trigger]>
        - if !<[trigger]>:
            - stop
        - run si__add_mapping def:<player>|<[details]>


    # === Sign broken ===
    after player breaks *_sign:
        - define trigger <context.location>
        - define block_name <[trigger].material.name>
        - if !<[block_name].ends_with[_sign]>:
            - stop
        - run si__remove_mapping def:<player>|<[trigger]>


    # === Frame entity broken (REMOVED) ===
    # This is NOT reliable as the 'on entioty dies' is not reliable called when a frame is broken.
    # Favor code that dynamically removes missing items during auto sorting procesing.


# ***
# *** Add the data element to the applicable indexes. This also removes any other locations in any index that exists.
# *** This tends to help auto reapir things a bit.
# ***
# *** 30 Item chests being scanned for duplciates and repairs: 3ms
# ***
si__add_mapping:
  type: task
  definitions: player|data
  debug: false
  script:
    # ==== Tempory OP this for developer
    - if !<[player].has_permission[minecraft.command.op]>:
        - stop

    - define start_ticks <util.current_time_millis>

    # unescape restores the data type, since in Denzien I think EVERYTHING is a string there is no 'data-type' in the normal
    # sense. If the string starts with 'map@' it is a map, if 'l@' it is a location and so on. All data types are faked.
    # Which might make code REALLY REALLY slow.
    - define data <[data].unescaped>

    # Expect to get full data element, we will optimize these in the when updating flags
    - define trigger_loc <[data].get[trigger]||false>
    - define chest_loc <[data].get[chest]||false>
    - define item <[data].get[item]||false>
    - define wildcard <[data].get[wildcard]||false>
    - define is_feeder <[data].get[is_feeder]||false>
    # Entity check is used during repairs/item-moves to make sure the object is still present for so auto repair
    # can be triggered during item move.
    - define is_entity <[data].get[is_entity]||false>

    - if !<[trigger_loc]>  || !<[chest_loc]>:
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

    # Remove any existing before adding
    - run si__remove_mapping def:<[player]>|<[trigger_loc]>

    # Build flag path
    - define flag_root <proc[si__flag_path].context[<[trigger_loc]>]>

    - if <[data].get[is_feeder]>:
        - debug log "<red>Adding FEEDER SI: <[data]>"

    # if a Feeder then by indexed by LOCATION
    - if <[is_feeder]>:
        # Optimize for feeder, all we need are feeder/chest location
        # = TODO: look for glowing tag or other speed indicator
        - define entry <map[t=<[trigger_loc]>;c=<[chest_loc]>;e=<[is_entity]>]>
        - define flag_feeders <[flag_root]>.feeder
        - flag <[player]> <[flag_feeders]>:->:<[entry]>
    - else:
        - if <[item]>:
            # ** ITEMS indexed by item name. Minimmal item settings
            - define entry <map[t=<[trigger_loc]>;c=<[chest_loc]>;i=<[item]>;e=<[is_entity]>]>
            - define flag_loc <[flag_root]>.item.<[item]>
            - flag <[player]> <[flag_loc]>:->:<[entry]>
        - if <[wildcard]>:
            # ** wildcards ar ejust a list, again just minimal attributes
            - define entry <map[t=<[trigger_loc]>;c=<[chest_loc]>;w=<[wildcard]>;e=<[is_entity]>]>
            - define flag_loc <[flag_root]>.wildcard
            - flag <[player]> <[flag_loc]>:->:<[entry]>

    - define end_ticks <util.current_time_millis>
    - define duration_millis <[end_ticks].sub[<[start_ticks]>]>
    #- debug log "<red>Scan time: <[duration_millis]>"
    - determine true


# ***
# *** Remove a location key from all indexes
# ***
si__remove_mapping:
  type: task
  definitions: player|trigger_loc
  debug: false
  script:
    # Use FULL search data since later the indexes will need ato be sorted by nearest so full notation is easier overall
    - define search_loc <[trigger_loc]>

    - define flag_root <proc[si__flag_path].context[<[trigger_loc]>]>

    # Remove items, these are indexed by NAME, then a list of maps with t=target location (full)
    - define flag_path <[flag_root]>.item
    - if <[player].has_flag[<[flag_path]>]>:
        # Each item as it's on list scan. A bit slow but it is safe. This is only
        # done on changes to frames/signs or whatever feeders
        - define item_names <[player].flag[<[flag_path]>].keys>
        - foreach <[item_names]> as:item_name :
            - define flag_loc <[flag_path]>.<[item_name]>
            - run si__remove_locations def:<[player]>|<[flag_loc]>|<[search_loc]>

    # Remove Wildcard / groups which are not indexed, just a list of maps
    - define flag_loc <[flag_root]>.wildcard
    - run si__remove_locations def:<[player]>|<[flag_loc]>|<[search_loc]>

    # Remove Feeders which ar eno indexed, just a list of maps. Usually under 20 or so
    - define flag_loc <[flag_root]>.feeder
    - run si__remove_locations def:<[player]>|<[flag_loc]>|<[search_loc]>


# ***
# *** Remove all entries that match the target key (t) from the list specified by the flag path
si__remove_locations:
  type: task
  definitions: player|flag_path|trigger_loc
  debug: false
  script:

    # THis method is likley faster for cases needing multiple deletes, RARE.
    - if <[player].has_flag[<[flag_path]>]>:
        # = This works but is 3ms for 40 chests and one or zero duplicates. Which is the norm
        #- define keep_entries <[player].flag[<[flag_path]>].filter_tag[<[filter_value].get[t].equals[<[trigger_loc]>].not>]>
        #- flag <[player]> <[flag_path]>:!
        #- flag <[player]> <[flag_path]>:<[keep_entries]>

        # THis method is likley faster for cases needing one or zero deletes, COMMON
        # = Loop is faster, about 1ms for 40 chests
        - define found_entries <[player].flag[<[flag_path]>].filter_tag[<[filter_value].get[t].equals[<[trigger_loc]>]>]>
        - foreach <[found_entries]> as:entry :
            - flag <[player]> <[flag_path]>:<-:<[entry]>
            # THis is pretty easy to do here but ignore it since the keep_entries method makes the counter much more costly



# ***
# *** Build base flag path to root of invenotory based ona location string
# ***   - Each type of ivnetory key follows this text (dot (.) delimited)
si__flag_path:
  type: procedure
  definitions: loc
  debug: false
  script:
    - define world_name <[loc].world.name>
    - define flag_path si.<[world_name]>
    - determine <[flag_path]>


# ****
# **** Checks if entity is a valid frame inventory marker and returns the frame loc, and it is attached to a chest
# **** Effort is made to exit as quickly as possible
# **l**
# **** While this returns location data it should NOT be added to the simple inventory.
# ****
si__frame_details:
  type: procedure
  definitions: player|entity
  debug: false
  script:
     # There is no Entity
    - define no_match <map[trigger=false;chest=false;message=false]>

    # Exit as quick as possible if this event is not applicable (wrong type)
    - if <[entity].entity_type> != item_frame:
        - determine <[no_match]>

    # Re-use the complex frame parser
    - define data <proc[si__parse_frame].context[<[player]>|<[entity]>]>

    # Returns standard Invetory trigger data element
    - determine <[data]>


# ****
# **** Return an array of the sign_loc and chect_loc if both are valid. Else return nulls.
# **** Effort is made to exit as quickly as possible
# ****
# **** Called when a frame change occurs, such as item in frame added, removed, rotated
# ****
#
# The item within the frame is used as an exact item match (without NBT). This is the fastest
# inventory filter and using frames (or multuiple frames per chest).
#
# TIP: An arrow pointing up (use shift right click to rotate) is a FEEDER.
#
si__parse_frame:
  type: procedure
  definitions: player|frame|item
  debug: false
  script:
    # Id no match is found return nulls for each element
    - define no_match <map[trigger=false;chest=false;message=false;is_entity=true]>

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
        - determine <[no_match]>
    - else:
        - define is_feeder false
        - if <[item_filter]> == arrow:
            # If an arrow we are interested in rotation, an UP pointing arrow is treated as an AUTO SORTER
            # he challenge is we want the rotation AFTER it is rotated not before ....
            - define item_rotation <[frame].framed_item_rotation>

            # These go through a sequence starting with initial. Sometimes it takes 2 rotations to feeder
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
                - define is_feeder true

    # Return both feeder and chest-like inventory location. use a map to self-document. This is all internal
    # data so size is not relevent.
    - determine <map[trigger=<[frame_loc]>;chest=<[attached]>;item=<[item_filter]>;wildcard=false;is_feeder=<[is_feeder]>;message=false;entity=true]>


# ****
# **** Return an array of the sign_loc and chect_loc if both are valid. Else return nulls.
# **** Effort is made to exit as quickly as possible
# ****
# Sign usage:
# Line 1: [inv|inventory|feed|feeder]
# Line 2+: Item filter where first one that match wins. Multiple filters can be comma or space seperated. Word dwrap is NOT supported
# The matches are case insensitibe and can be:
#  * an exact name: cobblestone, arrow, apple
#  * wild cards using '*', '?' anywhere:  *_ore, *stone*, *_seed?
#  * SPECIAL item name, shown in upper case but are case insensitive. Multiple can be specified exactly as an item name.
#       * OVERFLOW (any item that matched but has no room)
#       * UNDEFINED (any item that did not match any chest)
#
# Tip: Multiple signs can be placed on an inventory to increase filters or add hoppers feeding an inverntory with even more signs
#
#
si__parse_sign:
  type: procedure
  definitions: player|location
  debug: false
  script:
    # Id no match is found return nulls for each element
    - define no_match <map[trigger=false;chest=false;item=false;wildcard=false;is_feeder=false;message=false;is_entity=false]>

    - define trigger <[location]||null>
    - if !<[trigger]>:
        #- debug log "<red>NO Location"
        - determine <[no_match]>

    - define block_name <[trigger].material.name>
    - if !<[block_name].ends_with[_sign]>:
        - determine <[no_match]>

    # Signs re SO much simpler than frames, so optimize for signs (bug backward/forward still seem weird, and not reliable)
    - define facing <[trigger].block_facing||null>
    # This is NOT just attached blocks but also blocks behind the sign. Filter for only attached  proved annoying so allow a sign to be in FRONT of chest
    - if !<[facing]>:
        #- debug log "<red>NO Facing"
        - determine <[no_match]>

    - define chest <[location].relative[<[facing].mul[-1]>]>
    - define is_allowed <proc[is_chest_like].context[<[chest]>]>
    - if !<[is_allowed]>:
        #- debug log "<red>NOT allowed"
        - determine <[no_match]>

    # Get sign data and assign internal postional
    - define data <proc[si__process_sign_text].context[<[trigger]>]>
    - define data <[data].with[trigger].as[<[trigger]>].with[chest].as[<[chest]>]>
    - determine <[data]>


# ***
# *** Given a location to a sign, generate a map for the sign data. This happens at sign edit via a player.
# ***
si__process_sign_text:
  type: procedure
  definitions: sign_obj
  debug: false
  script:
    # Return data set
    - define is_feeder false
    - define wildcard false
    - define message false

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
        #- debug log "<red>Sign type: <[sign_type]>"
        - if <[sign_type].advanced_matches[inv|inventory]>:
            - define is_feeder false
            # Containue parsing spec
            - define sign_lines <[sign_lines].remove[1]>
            #- debug log "<red>Sign lines: <[sign_lines]>"
            - define wildcard <[sign_lines].separated_by[|]>
            #- debug log "<red>wildcard: <[wildcard]>"
            # More denizien oddness, we cannat match regex: assumes  regex and escaping (regex\:) made not
            # difference and a a regex it alwasys matched. Denizen is fuzzy, you just have to deal with it.
            - if <[wildcard].contains[regex]>:
                - define message "regex: is not supported at this time. Wildcards (*?) are supported"
                - define wildcard false

        - if <[type].advanced_matches[feed|feeder]>:
            - define is_feeder true
            # The rest of the sign can be anything you want

    - define result <map[item=false;wildcard=<[wildcard]>;is_feeder=<[is_feeder]>;message=<[message]>;entity=false]>
    #- debug log "<red>Sign RESULT: <[result]>"
    - determine <[result]>


# ***
# Scan all feeders
# ***
si__process_feeders:
  type: task
  debug: false
  definitions: tick_group
  script:
    - define chunk_cache <map[]>
    - foreach <proc[get_all_players]> as:owner:
        - if <[owner].has_flag[si].not>:
            - foreach next

        - define world_keys <[owner].flag[si].keys>
        - foreach <[world_keys]> as:world_name:
            - define feeders <[owner].flag[si.<[world_name]>.feeder]>
            - debug log "<red>World Name: <[world_name]> -- <[feeders]>"
            - stop

            - foreach <[feeders]> as:feeder:
                # Check feeder location
                - define trigger_loc <[feeder].get[t]>
                - define t_chunk <[trigger_loc].chunk.simple>
                - define t_loaded <[chunk_cache.get[<[t_chunk]>]]||null>
                - if <[t_loaded]> == null:
                    - define t_loaded <chunk[<[t_chunk]>].is_loaded>
                    - define chunk_cache <[chunk_cache].with[<[t_chunk]>].as[<[t_loaded]>]>
                - if !<[t_loaded]>:
                    - foreach next

                # Check chest location
                - define chest_loc <[feeder].get[c]>
                - define c_chunk <[chest_loc].chunk.simple>

                # Only check second chunk if it's different
                - if <[t_chunk]> != <[c_chunk]>:
                    - define c_loaded <[chunk_cache.get[<[c_chunk]>]]||null>
                    - if <[c_loaded]> == null:
                        - define c_loaded <chunk[<[c_chunk]>].is_loaded>
                        - define chunk_cache <[chunk_cache].with[<[c_chunk]>].as[<[c_loaded]>]>
                    - if !<[c_loaded]>:
                        - foreach next

                # Sign/chest chunks are both loaded.
                #    remember to verify the objects actuall exist

                - debug log "<red>FEEDER FOUND: <[owner].name> --- <[feeder]>"




# ***
# *** HELP TEXT
# ***
# TODO: Prototype - clean this up when code structure is done
si__help:
  type: command
  name: simple_inventory
  description: List or reset simple inventory feeders
  usage: /simple_inventory [player] [list/clear/rebuild] [rebuild-radius-chunks]
  permission: simple_inventory.list
  debug: false
  script:
      # Definitions
    - define owner <context.args.get[1]>
    - define command <context.args.get[2]||help>
    - define radius <context.args.get[3]||5>

    # Help block (called when command is missing or unknown)
    - define show_help false
    - if <[command]> == help:
        - define show_help true
    - if <context.args.size> < 2:
        - define show_help true
    - if <list[list|clear|repair].contains_text[<[command].to_lowercase>].not>:
        - define show_help true

    - if <[show_help]>:
        - narrate "<gold>Simple Inventory Help:"
        - narrate "<yellow>/simple_inventory [player] list"
        - narrate "<gray>  View all active inventory feeders for that player"
        - narrate "<yellow>/simple_inventory [player] clear"
        - narrate "<gray>  Remove all inventory feeder data"
        - narrate "<yellow>/simple_inventory [player] repair [radius]"
        - narrate "<gray>  Scan signs/frames around player to rebuild flags"
        - narrate "<yellow>Default radius is <white>5<yellow> chunks."
        - stop

    # Match_offline_ wills earch for online/offline by a case insensitive flexible matching.
    # The online_players and offline_players are specific to these states.
    - define all_players <proc[get_all_players]>
    - define found <[all_players].filter_tag[<[filter_value].name.to_lowercase.contains[<[owner].to_lowercase>]>]>
    - if <[found].is_empty> :
        - narrate "<red>Player '<[owner]>' match not found."
        - stop
    - define owner <[found].get[1]>

    # All commands hae a player component
    - if <[command]> == list:
        # Using '||' fallback is not reliable in Denizen due to parser limitations
        - if !<[owner].has_flag[si]>:
            - narrate "<gray>No inventory data stored." targets:<player>
            - stop

        - define inv_map <player.flag[si]>
        - narrate "<green>Inventory map: <[inv_map]>"
        - stop

    - if <[command]> == clear:
        - flag <player> si:!
        - narrate "<red>Inventory locations cleared for <[owner]>"
        - narrate "<yellow>Click each sign/frame OR use /simple_inventory <player> repair"
        - stop

    - if <[command]> == repair:
        - define radius <context.args.get[3]||5>
        - narrate "<green>Repairing <[radius]> radius chunks around player"
        - run si_scan_signs_nearby def:<[owner]>|<[radius]>
        - narrate "<yellow>Move to next location and run again"
        - stop


# ***
# *** Reapir by finding all signs within range of the character
si_scan_signs_nearby:
  type: task
  debug: false
  definitions: player|radius
  script:
    # change this to control the scan range. 10 is the normal spawn range
    - define counter 0

    # keep radius relatively small for safety 
    - define radius <[radius]||5>
    - define loc <[player].location.chunk>
    # Get a chunk count for status, note that Denzien lacks a pow() function
    - define span <[radius].mul[2].add[1]>
    - define area_size <[span].mul[<[span]>]>
    - narrate "<gold>Chunks in radius <[radius]>: <[area_size]>"

    - repeat <[radius].mul[2].add[1]> as:x:
        - define start_ticks_raw <util.current_time_millis>
        - repeat <[radius].mul[2].add[1]> as:z:
            - define offset_x <[x].sub[<[radius].add[1]>]>
            - define offset_z <[z].sub[<[radius].add[1]>]>
            - define cx <[loc].x.add[<[offset_x]>]>
            - define cz <[loc].z.add[<[offset_z]>]>
            # TODO: I cannot find out quite how to get as[chunk] to work here.
            - define chunk ch@<[cx]>,<[cz]>,<[loc].world.name>
            - define chunk <[chunk].as[chunk]>
            - define log "CHUNK: <[chunk]>"
            - define area <[chunk].cuboid>

            # Scan for all signs (blocks)
            - define found_list <[area].blocks[*_sign]>
            - if <[found_list].is_empty.not>:
                # A chunk scan is pretty slow so give up time for others
                - foreach <[found_list]> as:sign :
                    - define details <proc[si__parse_sign].context[<[player]>|<[sign]>]>
                    - run si__add_mapping def:<[player]>|<[details].escaped>
                - narrate "<green>Fixed <[found_list].size> signs at <[chunk]>"


            # Scan for FRAMES with ITEMS
            - define found_list <[area].entities[*_frame]>
            - if <[found_list].is_empty.not>:
                - foreach <[found_list]> as:frame :
                    - define item  <[frame].framed_item>
                    - if <[item]>:
                        - define details <proc[si__parse_frame].context[<[player]>|<[frame]>|<[item]>]>
                        - define trigger <[details].get[trigger]>
                        - run si__add_mapping def:<[player]>|<[details].escaped>
                - narrate "<green>Fixed <[found_list].size> frames at <[chunk]>"


            # Update status and add waits
            - define counter <[counter].add[1]>
            - wait 1t

        - define elapsed <util.current_time_millis.sub[<[start_ticks_raw]>]>
        - narrate "<yellow>Working (chunks: <[counter]>/<[area_size]>) in <[elapsed]> ms ..."
    - narrate "<gold>Finished"



# == BENCHMARK CODE
# Run this once to set up the test list
test_flag_setup:
    type: task
    debug: false
    script:
        - flag player test_list:!
        # 100 item names with 10 chests per entry
        - repeat 100:
            - define flag_path "test_list.item_name_<[value]>"
            - debug log "<green>Path: <[flag_path]>"
            - repeat 20:
                - define entry <map[trigger='-9999,61,9999@nether';chest='-9999,<[value]>,9999@nether';item=false;wildcard=false;is_feeder=false;message=<[value]>]>
                - flag player <[flag_path]>:->:<[entry]>
        - narrate "Test list created with x entries."

benchmark_raw_list:
    type: task
    debug: false
    script:
        - define start_ticks <util.current_tick>
        - repeat 1000:
            - define v <player.flag[test_list].get[500]>
        - define end_ticks <util.current_tick>
        - define duration_millis <[end_ticks].sub[<[start_ticks]>].mul[50]>
        - narrate "Raw List Access Time: <[duration_millis]> ms"


benchmark_as_list:
    type: task
    debug: false
    script:
        - define parsed_list <player.flag[test_list].as[list]>
        - define start_ticks <util.current_tick>
        - repeat 1000:
            - define value <[parsed_list].get[500]>
        - define end_ticks <util.current_tick>
        - define duration_millis <[end_ticks].sub[<[start_ticks]>].mul[50]>
        - narrate "Parsed List Access Time: <[duration_millis]> ms"

combined_benchmark:
    type: task
    debug: false
    script:
        - define start_ticks_raw <util.current_time_millis>
        - define counter 0
        - define flag_path "test_list.item_name_99"
        - repeat 1:
            - define v <player.flag[<[flag_path]>]>
            #- debug log "<red>Map: <[v]>"
            # THIS FAILS, why
            #[19:27:24 INFO]: Additional Error Info: The returned value from initial tag fragment '[filter_value]' was: 'map@[t = l@1773, 111, -1282, world; c = l@1773, 111, -1281, world; i = false; g = false]'. 
            #[19:27:24 INFO]: Additional Error Info: Almost matched but failed (possibly bad input?): get
            #[19:27:24 INFO]: Additional Error Info: Tag <[filter_value].get[chest].equals['-9999,19,9999@nether']> is invalid!
            #[19:27:24 INFO]: Additional Error Info: Unfilled or unrecognized sub-tag(s) 'get[chest].equals['-9999,19,9999@nether']' for tag <[filter_value].get[chest].equals['-9999,19,9999@nether']>!
            - define v <player.flag[<[flag_path]>].filter_tag[<[filter_value].get[c].equals['-9999,19,9999@nether']>]>
            - debug log "<green>Entries found: <[v]>"
        - define end_ticks_raw <util.current_time_millis>
        - define duration_millis_raw <[end_ticks_raw].sub[<[start_ticks_raw]>]>
        - narrate "RAW List Access Time: <[duration_millis_raw]> ms for <[counter]> list size"
        - stop


        - define parsed_list <player.flag[test_list].as[list]>
        - define start_ticks_parsed <util.current_time_millis>
        - define counter 0
        - repeat 1000:
            #- foreach <[parsed_list]> as:v :
            - define value <[parsed_list].get[500]>
            - define counter <[counter].add[1]>
        - define end_ticks_parsed <util.current_time_millis>
        - define duration_millis_parsed <[end_ticks_parsed].sub[<[start_ticks_parsed]>]>
        - narrate "Parsed List Access Time: <[duration_millis_parsed]> ms for <[counter]> list size"




# =================================
# ==== MOVE TO COMMON LIBRARY elements
# ====  Place tasks/prcedures here for easy testing then migrate to pl_common (paradise labs) when known to work and may be useful to other scripts
# ====


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
#
#
# = A refactor is probably needed but watch out for performance
#    issues with proc calls. They add up. But worse case it's probably one proc per feeder + flag path to use.
#    Which means task must return a vaue. Looks like we can via determine xxx trhen caller can use the following. AI
#    suggested this but 'determination' does exist (note this use Robb's Denizen GPT). Review how wildcards affect
#    the looping before deciding. But it would make overflow easier. Just make it a new list!
#       - run my_task_script save:result
#       - define outcome <entry[result].determination>
#       - narrate "Task returned: <[outcome]>"

# - Suport Round Robin
#   - ADD disbtruction type to feeder signs. Second line contains '[random]' or '[nearest]' (default)
#       - Note: Frame Feeders cannot are always nearest
#       - Future - we may support a x suffix to limit feeder rang to x blocks. Makes everythign a distance. 
#           - In loop code we can just skip cheststo far away, not worth the cost to rebuild the list since most of the time it will stop on the first match
#   - Add a new key to feeders 'd' for distribution. It will be 'r' or 'n'. For now just run repair instead of working about backwards compatibility
#   X change item list sorting to use the new feeder 'd' key to select proper mode
#
# - Sign optimizations
#   - For NORMAL item entries add to the items list. THis is much more performant
#   - Wildcard are added to the wild card  index and that table is sorted in the same way as the others
#  
# - Wildcards
#   - add wildcard processing that occurs after item processing.
#
# - Overflow
#   - Overflow (overflow) is used if no chest can hold the item. If we refactor code to use a a seperate task for moving
#   then this is easy. We just call the that ask with the item name overflow. But I am not sure what impact that will have.
#   Otherwise it is a lot trikier.
#
# - Tie into world tick, probably every 4 ticks maybe 8 (like hoppers but full stacks)
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
    # X - range limit, closest ( 1.5 > dist < 32)
    # - LONG distance transport: water streams, tricky but works. Easier with bubble elevators (souls and), trains work as well but can be more/less  complex depdnign on route
    #  - Do NOT support interworld inventory or LONG range chaining. Do that the minecraft way. Kepe it simple and clean


# TODO command to rebuild inventory matrix based on x chunks around player (default is bed-spawn chunks if that flag exists), elase 5 chunks


# ***
# *** Configuration data
# ***
si_config:
    type: data
    data:
        # Access to this data: define max_items <script[si_config].data_key[data].get[feeder].get[max_items]>
        feeder:
            # Feeder location data (trigger) is proccessed every x ticks where the x is calculated
            # by a simple hash that when moded by tick_delay being zero the feeder is processed.
            #   Use 0 to fire every tick, useful for debugging
            tick_delay: 0
            # TODO:  maximum number of slots that can be moved per pass from each feeder
            #max_slots: 1
            # Maximum items that is allowed to be transfered per pass. Normally maximum slot size is 64
            max_quantity: 64
            # Minimum and maximum distance
            #   Use a minium of .5 to prevent a feeder placing items into self if also an inventory
            #   Use a 1 to prevent macthing NSEWUP of container
            #   Use 1 .5 to also prevent diaganols, which can help make the setup more consistent. From a human perspective 1 block shoudl includ diagnols
            min_distance: 1.5
            max_distance: 32


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
            - run open_chest_gui def:<player>|<[chest]>
            - determine cancelled
        - else:
            # AUTO REPAIR: If there is no chest something broke, fix it
            - run si__remove_mapping def:<player>|<context.entity.location>


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
        - if <list[BROKEN|REMOVE].contains_text[<[action]>]>:
            #- debug log "<green> ON <[action]> called remove ON <[frame]>"
            - run si__remove_mapping def:<player>|<[frame]>
        - else:
            # Triggered by: PLACE
            #- debug log "<green> ON <[action]> called add ON <[details]>"
            - run si__add_mapping def:<player>|<[details].escaped>


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
    # TIP: Do NOT Adjust all locations to block level, this prevents multiple frames per chest
    - define trigger_loc <[data].get[trigger]||false>
    - define chest_loc <[data].get[chest]||false>
    - define item <[data].get[item]||false>
    - define wildcard <[data].get[wildcard]||false>
    - define overflow <[data].get[is_overflow]||false>
    - define is_feeder <[data].get[is_feeder]||false>
    - define facings <[data].get[facings].if_null[<list[]>]>
    - define max_distance <[data].get[max_distance]||false>
    - define sort_order <[data].get[sort_order]||false>

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

    # if a Feeder then by indexed by LOCATION
    - if <[is_feeder]>:
        # Optimize for feeder, all we need are feeder/chest location
        - define entry <map[t=<[trigger_loc]>;c=<[chest_loc]>;d=<[max_distance]>;s=<[sort_order]>;f=<[facings]>;e=<[is_entity]>]>
        - define flag_feeders <[flag_root]>.feeder
        - flag <[player]> <[flag_feeders]>:->:<[entry]>
    - else:
        - if <[item]>:
            # ** ITEMS indexed by item name. Minimmal item settings, no need to keep name as that is in the index
            - define item_list <[item].as[list]>
            - foreach <[item_list]> as:entry:
                - define entry <map[t=<[trigger_loc]>;c=<[chest_loc]>;i=<[item]>;w=0;e=<[is_entity]>]>
                - define flag_loc <[flag_root]>.item.<[item]>
                - flag <[player]> <[flag_loc]>:->:<[entry]>
        - if <[wildcard]>:
            # ** wildcards are a advanced_match string (not an array)
            - define entry <map[t=<[trigger_loc]>;c=<[chest_loc]>;w=<[wildcard]>;i=0;e=<[is_entity]>]>
            - define flag_loc <[flag_root]>.wildcard
            - flag <[player]> <[flag_loc]>:->:<[entry]>
        - if <[overflow]>:
            # ** Overflow is just a boolean, if true then ADD to the oveflow flags
            - define entry <map[t=<[trigger_loc]>;c=<[chest_loc]>;e=<[is_entity]>]>
            - define flag_loc <[flag_root]>.overflow
            - flag <[player]> <[flag_loc]>:->:<[entry]>


    - define end_ticks <util.current_time_millis>
    - define duration_millis <[end_ticks].sub[<[start_ticks]>]>

    - define data <[player].flag[<[flag_root]>.item.cobblestone]>
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
    #  Sometimes we receive a NON location element, liske a .../item_frame so we handle it.
    #  We do not have an 'is[location]' or anything close so we try to use '.location' , if it works we continue using that.
    #  as it is probably a frame object NOT location (sucha s sent during REMOVE). If the check fails we handle it with
    # a fallback (is_null) to capture/hide the error logging and we use the item AS IS since a location does not support
    # location, This works for sings, frames and changing frame items.
    #  TODO: This check feels hacky, but not totlaly out of Denizen scope
    - if <[trigger_loc].location.if_null[null]> == null:
        - define search_loc <[trigger_loc]>
    - else:
        - define search_loc <[trigger_loc].location>

    - define flag_root <proc[si__flag_path].context[<[search_loc]>]>

    # Remove items, these are indexed by NAME, then a list of maps with t=target location (full)
    - define flag_path <[flag_root]>.item
    - if <[player].has_flag[<[flag_path]>]>:
        # Each item as it's on list scan. A bit slow but it is safe. This is only
        # done on changes to frames/signs or whatever feeders
        - define item_names <[player].flag[<[flag_path]>].keys>
        - foreach <[item_names]> as:item_name :
            - define flag_path_data <[flag_path]>.<[item_name]>
            - run si__remove_locations def:<[player]>|<[flag_path_data]>|<[search_loc]>

    # Remove Wildcard / groups which are not indexed, just a list of maps
    - define flag_path_data <[flag_root]>.wildcard
    - run si__remove_locations def:<[player]>|<[flag_path_data]>|<[search_loc]>

    # Remove Feeders which ar eno indexed, just a list of maps. Usually under 20 or so
    - define flag_path_data <[flag_root]>.feeder
    - run si__remove_locations def:<[player]>|<[flag_path_data]>|<[search_loc]>

# ***
# *** Remove all entries that match the target key (t) from the list specified by the flag path
si__remove_locations:
  type: task
  definitions: player|flag_path|trigger_loc
  debug: false
  script:

    # THis method is likley faster for cases needing multiple deletes, RARE.
    - if <[player].has_flag[<[flag_path]>]>:
        - define trigger_block <[trigger_loc]>

        # = DEPRECATED : This works but is 3ms for 40 chests and one or zero duplicates. Which is the norm
        #- define keep_entries <[player].flag[<[flag_path]>].filter_tag[<[filter_value].get[t].equals[<[trigger_loc]>].not>]>
        #- flag <[player]> <[flag_path]>:!
        #- flag <[player]> <[flag_path]>:<[keep_entries]>

        # THis method is likley faster for cases needing one or zero deletes, COMMON
        # = Loop is faster, about 1ms for 40 chests
        - define found_entries <[player].flag[<[flag_path]>].filter_tag[<[filter_value].get[t].equals[<[trigger_block]>]>]>
        - foreach <[found_entries]> as:entry :
            #- debug log "<red>REMOVING entry: <[entry]>"
            - define remove_flag true
            - flag <[player]> <[flag_path]>:<-:<[entry]>


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

    # Frames are peculary, so they need to be trated a bit different, hande object OR loc
    - define frame_loc <[frame].location.if_null[<[frame]>]>
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
    - determine <map[trigger=<[frame_loc]>;chest=<[attached]>;item=<[item_filter]>;wildcard=false;is_feeder=<[is_feeder]>;message=false;is_entity=true]>


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
        - determine <[no_match]>

    - define block_name <[trigger].material.name>
    - if !<[block_name].ends_with[_sign]>:
        - determine <[no_match]>

    # Signs re SO much simpler than frames, so optimize for signs (bug backward/forward still seem weird, and not reliable)
    - define facing <[trigger].block_facing||null>
    # This is NOT just attached blocks but also blocks behind the sign. Filter for only attached  proved annoying so allow a sign to be in FRONT of chest
    - if !<[facing]>:
        - determine <[no_match]>

    - define chest <[location].relative[<[facing].mul[-1]>]>
    - define is_allowed <proc[is_chest_like].context[<[chest]>]>
    - if !<[is_allowed]>:
        - determine <[no_match]>

    # Get sign data and assign internal postional
    - define data <proc[si__process_sign_text].context[<[trigger]>]>
    - if !<[data]>:
        - determine <[no_match]>
    - else:
        - define data <[data].with[trigger].as[<[trigger]>].with[chest].as[<[chest]>]>
        - determine <[data]>


# ***
# *** Given a location to a sign, generate a map for the sign data. This happens at sign edit via a player.
# ***
# *** Benchmarking measured a complex sign parsing (INV, options, items, wildcard, distance) at 0.19 ms per sign
# ***
# = TODO: look for glowing tag or other speed indicator - in parsing, if we want more speed? FUTURE
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

    # Parsed data either returned or adjusted
    - define facings <list[]>
    - define sort_order distance
    - define items <list[]>
    - define wildcards <list[]>
    - define overflow false
    # Use (0) to use the default system, in any case a value > max will be ignored
    - define distance 0

    # Get constants
    - define max_distance <script[si_config].data_key[data].get[feeder].get[max_quantity]>

    # Instead of geting fancy I am going to do a DEAD SIMPLE code.
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
        - if <[sign_type]> == feeder:
            - define is_feeder true
        - else:
            - if <[sign_type]> == inv:
                - define is_feeder false
            - else:
                # A normal sing skip it
                - determine false

        # Containue parsing spec. Data is parsed for inv/feeder the same for easy coding.
        # THe calling code will store the data applicable to the type fo sign, and ignore the rest
        - define sign_lines <[sign_lines].remove[1]>
        - define sign_spec <[sign_lines].separated_by[|]>

        - define tokens <[sign_spec].to_lowercase.replace[<[open]>].with[ ].replace[<[close]>].with[ ].split[regex:\s+|\||,]>
        - define known_facings <list[n|s|e|w|u|d]>
        - foreach <[tokens]> as:token:
            - define token <[token].trim>
            - if <[token]> == distance:
                - define sort_order distance
                - foreach next
            - if <[token]> == random:
                - define sort_order random
                - foreach next
            - if <[token]> == overflow:
                - define overflow true
                - foreach next
            - if <[token].is_empty||false>:
                - foreach next
            - if <[token].starts_with[regex]>:
                - define message "Regex not supported in sign options, skipping that (<[token]>)"
                - foreach next
            - if <[known_facings].contains_text[<[token]>]>:
                - define facings:->:<[token]>
                - foreach next
            - if <[token].is_integer>:
                - define distance <[token].min[<[max_distance]>]>
                - if <[distance]> > <[max_distance]>:
                    - define message "Distance (<[distance]>) blocks ignored, exceeds maximum <[max_distance]>"
                    - define distance 0
                - foreach next
            - if <item[<[token]>].exists>:
                - define items:->:<[token]>
                - foreach next
            - else:
                - define wildcards:->:<[token]>
                - foreach next

        # Build a single advanced match string
        - define wildcard <[wildcards].separated_by[|]>

    - define result <map[item=<[items]>;wildcard=<[wildcard]>;facings=<[facings]>;sort_order=<[sort_order]>;is_feeder=<[is_feeder]>;overflow=<[overflow]>;max_distance=<[distance]>;message=<[message]>;is_entity=false]>
    - determine <[result]>


# ***
# Scan all feeders
# ***
# *** Benchamrk issues
# ***  - scanning a full double chest of items (unique) that MATCH a target but all targets are full (worse case): 48ms
# ****  
si__process_feeders:
  type: task
  debug: false
  definitions: player|do_diag
  script:

    - define ticks_start <util.current_time_millis>
    - define counter 0

    - define elapsed_chunk_loaded 0
    - define elapsed_inv 0
    - define elapsed_distance 0
    - define elapsed_setup 0
    - define elapsed_move 0
    - define bad_chest <location[1809,119,-1272,world]>

    - define feeder_constants <script[si_config].data_key[data].get[feeder]>
    - define min_distance <[feeder_constants].get[min_distance]>
    - define max_distance <[feeder_constants].get[max_distance]>
    - define max_quantity <[feeder_constants].get[max_quantity]>
    - define diagnostics null

    - define chunk_cache <map[]>
    - foreach <proc[get_all_players]> as:owner:
        - if <[owner].has_flag[si].not>:
            - foreach next
        - if <[owner].flag[si_enabled].if_null[false].not>:
            - debug log "<red> <[owner]> - Mod disabled"
            - foreach next

        # Easy, if suboptimal way to filte on passed player
        - if <[player]>:
            - if <[player].uuid> != <[owner].uuid>:
                - foreach next
        - else:
            # Turn of diag unless player is specified
            - define do_diag false


        - define world_keys <[owner].flag[si].keys>
        - foreach <[world_keys]> as:world_name:
            - define feeders <[owner].flag[si.<[world_name]>.feeder].if_null[<list[]>]>
            - foreach <[feeders]> as:feeder:
                # Whent his becomes true the current feeder is DONE
                - define move_completed false

                # Check feeder location (trigger)
                - define trigger_loc <[feeder].get[t]>
                - if <[trigger_loc].chunk.is_loaded.not>:
                    - foreach next

                # Check chest location
                - define feeder_chest <[feeder].get[c]>
                - if <[feeder_chest].chunk.is_loaded.not>:
                    - foreach next

                # If feeder chest is powered skip it
                - define is_powered <proc[powerlevel_blocks].context[<[feeder_chest]>]>
                - if <[is_powered]> > 0:
                    - foreach next

                # ** Sign/chest chunks are both loaded.
                #   check if feeder is inventory like. Be QUICK, the longer procedure for this is FAR too sslow
                - define feeder_inventory <[feeder_chest].inventory.if_null[null]>
                - if <[feeder_inventory]> == null:
                    - run si__remove_mapping def:<[owner]>|<[feeder_chest]>
                    - foreach next

                # If empty then nothing to do so exit
                - if <[feeder_inventory].is_empty>:
                    - foreach next

                - define feeder_facings <[feeder].get[f].if_null[<list[]>]>

                # Loop on each item in feeder until SOMETHING can be moved
                - define feeder_slots <[feeder_inventory].map_slots.values>
                - define ticks_after_setup <util.current_time_millis>

                # Scan feeder chest until a move is found, quickly skipping items already identied as haveing no available target
                - define feeder_skip_next_time <list[]>
                - foreach <[feeder_slots]> as:feeder_item :
                    - if <[move_completed]>:
                        - foreach stop

                    # Exit as soon as any item be moved by any quantity
                    - define tmp_start <util.current_time_millis>
                    - define feeder_item_name <[feeder_item].material.name>
                    - define feeder_item_quantity <[feeder_item].quantity>

                    # == ELiminating prior failed items ONLY happens if algorhtm decides to allow scans of feeder UNTIL a matching item is found.
                    # == This causes some significant bottlenecks and increases the code complexity considerably so I decided to BLOCK. If first
                    # === item cannot move it will BLOCK. Keeping this code for possible future use
                    ## If this item was seen before then it was NOT moved and should be quickly skipped
                    #- if <[feeder_skip_next_time].contains_text[<[feeder_item_name]>]>:
                    #    - foreach next
                    ## Remember that this item WAS processed and as such should be skipped if seen again for this chest
                    #- define feeder_skip_next_time:->:<[feeder_item_name]>


                    - define elapsed <util.current_time_millis.sub[<[tmp_start]>]>
                    - define elapsed_inv <[elapsed_inv].add[<[elapsed]>]>

                    - define diagnostics "<gold>No matching target container found for <[feeder_item_name]>."

                    # Loop through each available list, each list is tried before moving to the next
                    # = *** Limit LIST to scan to 'item' during debugging, allow others as testing completes
                    - define target_list_names <list[item|wildcard|overflow]>
                    - define target_list_names <list[item]>
                    - foreach <[target_list_names]> as:list_name :
                        - if <[move_completed]>:
                            - foreach stop

                        - if <[list_name]> == item:
                            # Item has one more depth based on item
                            - define target_path si.<[world_name]>.item.<[feeder_item_name]>
                        - else:
                            - define target_path si.<[world_name]>.<[list_name]>
                        - define targets_list <[owner].flag[<[target_path]>].if_null[<list[]>]>

                        # Scan these locations in order, on match Try to move

                        # Benchmark:
                        #   Original: 211 ms for 1000
                        #   Inline 140ms for 1000 -- drop 2nd proc
                        #   O(n): 45ms for 1000 -- use O(n) for distance then sprting that list. Changes [index,distance] but that is perfectly usable to me
                        #   Random: 3ms for 1000
                        - define tmp_start <util.current_time_millis>

                        # Get starting list
                        - define distances <list[]>

                        # Perform a scan to build a list: [[index, distance], ....]
                        #   This calls the slow distance (and skips the proc) once per list (old code was called 6 tiems for 3 elements qsort)
                        #   The call also gets the plane(s) the. Timing is 154ms for 5,000 elements ==> .031 ms per item. Most item lists will
                        #   by only a few, but even if 10 that is 0.1 ms and we can round to 1ms and be ok.
                        - foreach <[targets_list]> as:entry key:loop_index :
                            # THis compares chest inventory block possitions. Note that for double chests this gets a bit
                            # strange and no effort is made to normalize it. Multiple trigger frame/sign on different parts of a double chest
                            # will have differnet block positions. That's just the way it is for performance reasons. This may impact
                            # distances bt (1).
                            - define planes <map[n=0;e=0;s=0;w=0;u=0;d=0]>
                            # Block rounding helps with distance and plane more dertministic
                            - define target_block <[entry].get[c].block>
                            - define source_block <[feeder_chest].block>
                            - define dist <[target_block].block.distance[<[feeder_chest].block>]>
                            # Super easy to filter out here. Tha main list is unchanged but if the indexed list (distances)
                            # is what is looped on so this is a very effecient way to filte rout before even sorting
                            # Tip: Doagnalos should also be skipped , if that is not desired use 1 instead of 1.5
                            - if <[dist]> <= <[max_distance]> and <[dist]> >= <[min_distance]>:
                                - define dx <[target_block].x.sub[<[source_block].x>]>
                                - define dy <[target_block].y.sub[<[source_block].y>]>
                                - define dz <[target_block].z.sub[<[source_block].z>]>
                                - if <[dz]> < 0:
                                    - define planes <[planes].with[n].as[1]>
                                - if <[dz]> > 0:
                                    - define planes <[planes].with[s].as[1]>
                                - if <[dx]> > 0:
                                    - define planes <[planes].with[e].as[1]>
                                - if <[dx]> < 0:
                                    - define planes <[planes].with[w].as[1]>
                                - if <[dy]> > 0:
                                    - define planes <[planes].with[u].as[1]>
                                - if <[dy]> < 0:
                                    - define planes <[planes].with[d].as[1]>

                                # If feeder has a facings array it then ANY facing that aligns with a the current target passes.
                                # if facing syas 'N' and 'E' then the planes for target must be n the N and/or E facing.
                                #   If there is no plane specified, then all is OK
                                #   Else all planes specified in facings MUST be in the plane of the current target
                                #   Tip: targets not in that facing direction are not
                                #   Note: AN AND condition (so only targets NE) is possible it is not intutive and hard to manage. That migth require routing around other blocks
                                #       Also cosndier using a distance value to limit transfer range
                                - define allowed true
                                - foreach <[feeder_facings]> as:f :
                                    - if <[planes].get[<[f]>]> == 0:
                                      - define allowed false
                                    - else:
                                        - define allowed true
                                        - foreach stop

                                - if <[allowed]>:
                                    - define distances:->:<list[<[loop_index]>|<[dist]>|<[planes]>]>

                        # Now we want to sort the list using a tag into the each list item, which is itself a list. And in this case a tag of 1 gets the index
                        # TIP: This is useful to remember as it allows list with maps to be sorted by their key as long as the key is a pure numeric or alpah (see sort_by_value)
                        - if <[feeder].get[s].if_null[distance]> == random:
                             - define distances <[distances].random[<[distances].size>]>
                        - else:
                            # Default sort is by distance, 2nd term of distances
                            - define distances <[distances].sort_by_number[2]>

                        - define elapsed <util.current_time_millis.sub[<[tmp_start]>]>
                        - define elapsed_distance <[elapsed_distance].add[<[elapsed]>]>

                        - foreach <[distances]> as:distance_matrix :
                            - define tmp_start <util.current_time_millis>

                            # Skip any block that is not at least 1 from the feeder chest, this voids infinite loops
                            # and assists with chaining.
                            # Also skip any imventory over X away from trigger inventory
                            - define distance_from_trigger <[distance_matrix].get[2]>
                            - define target <[targets_list].get[<[distance_matrix].get[1]>]>
                            - define target_chest <[target].get[c]>

                            # not all blocks support power so fall back to 0
                            # The BLOCK the redstone feeds into (not below the redstone) wills how power level
                            #    THis works for chest_loc and chest or hopper inventories : <[target_chest]> == power level, often below 15
                            # Oddly enough the block UNDERNEATH the chest/hopper shows a power level of 15 which makes NO sense
                            #   <[target_chest].add[0,-1,0]> == 15 (WHY?)
                            - define is_powered <proc[powerlevel_blocks].context[<[target_chest]>]>
                            - if <[is_powered]> > 0:
                                - foreach next

                            # DO a FAST check here to avoid excpetions. If things need repaired that
                            # can be done with commands. If abuse occurs (not sure I care) we can address that later
                            - define target_inventory <[target_chest].inventory.if_null[null]>
                            - if <[target_inventory]> == null:
                                - debug log "<red>Feeder no longer a valid inventory, removing: <[owner]> -- <[target_chest]>"
                                - run si__remove_mapping def:<[owner]>|<[target_chest]>
                                - foreach next


                            - define space_available <[target_inventory].can_fit[<[feeder_item_name]>].count>
                            - define items_to_move <[space_available].min[<[feeder_item_quantity].min[<[max_quantity]>]>]>
                            - if <[items_to_move]> <= 0 :
                                # No space in the target so continue scanning items
                                - define diagnostics "<gold>Found matching target(s) for <[feeder_item_name]> but they are full."
                                - foreach next

                            - define elapsed <util.current_time_millis.sub[<[tmp_start]>]>
                            - define elapsed_setup <[elapsed_setup].add[<[elapsed]>]>


                            - define diagnostics "<green>Allowed <[feeder_item]>X<[items_to_move]> FROM <[feeder_chest].block> TO <[target_chest].block>"
                            - debug log <[diagnostics]>
                            - if <[do_diag]>:
                                - narrate <[diagnostics]> targets:<[owner]>
                                - stop


                            # Transfer item
                            #   Note we need to specify quantity force more than one on TAKE
                            - define tmp_start <util.current_time_millis>
                            - take item:<[feeder_item_name]> quantity:<[items_to_move]> from:<[feeder_chest].inventory>
                            - give item:<[feeder_item_name]> quantity:<[items_to_move]> to:<[target_chest].inventory>
                            - define elapsed <util.current_time_millis.sub[<[tmp_start]>]>
                            - define elapsed_move <[elapsed_move].add[<[elapsed]>]>

                            - define counter <[counter].add[1]>
                            # After moving an item we STOP
                            - define move_completed true
                            - foreach stop


                - define ticks_after_move <util.current_time_millis>
                #- debug log "<red>Elapsed (<[counter]>): <[ticks_after_setup].sub[<[ticks_start]>]>"
                - debug log "<red>Elapsed for (<[counter]>) ms: <[ticks_after_move].sub[<[ticks_start]>]>"
                - debug log "<gold> elapsed_chunk_loaded: <[elapsed_chunk_loaded]>"
                - debug log "<gold> elapsed_inv: <[elapsed_inv]>"
                - debug log "<gold> elapsed_distance: <[elapsed_distance]>"
                - debug log "<gold> elapsed_setup: <[elapsed_setup]>"
                - debug log "<gold> elapsed_move: <[elapsed_move]>"




# ***
# *** Sorts a list that contains SI map data so the list is ordered by nearest (3D) to the source
# *** This procedure is typically called via:
# ***   define sorted <[items_list].sort[si__sort_by_distance].context[<[feeder].get[t]>]>
# ***   Where the context is usually a feeder map but can be anything that provides a location
# ***
# *** This function is seldom called directly but if so:
# ***  a : Simple Inventory mapping where key 't' is the trigger (sign/frame) position provided by 'sort.proc.context' (first element)
# ***  b : Simple Inventory mapping where key 't' is the trigger (sign/frame) position provided by 'sort.proc.context' (second element)
# ***  feeder_loc : Usually via feeder.get[t] but can be anything that provides a location
#
# *** Returns: -1 for a < b, 1 for a > b, 0 for equality
si__sort_by_distance:
  type: procedure
  definitions: a|b|feeder_loc
  debug: false
  script:
    - define da <[a].get[t].distance[<[feeder_loc]>]>
    - define db <[b].get[t].distance[<[feeder_loc]>]>
    - if <[da]>  < <[db]>:
        - determine -1
    - else:
        - if <[da]>  > <[db]>:
            - determine 1
    - determine 0

# ***
# *** HELP TEXT
# ***
# TODO: Prototype - clean this up when code structure is done
si__help:
  type: command
  name: simple_inventory
  description: List or reset simple inventory feeders
  usage: /simple_inventory [player] [list/clear/rebuild/enable/disable] [rebuild-radius-chunks]
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
    - if <list[list|clear|repair|enable|disable].contains_text[<[command].to_lowercase>].not>:
        - define show_help true

    - if <[show_help]>:
        - narrate "<gold>Simple Inventory Help:"
        - narrate "<yellow>/simple_inventory [player] list"
        - narrate "<gray> View all active inventory feeders for that player"
        - narrate "<yellow>/simple_inventory [player] enable"
        - narrate "<gray>  Enable plugin for player"
        - narrate "<yellow>/simple_inventory [player] disable"
        - narrate "<gray>  Disable inventory handling (only) for player, all data is maintained"
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

    - if <player.is_op.not> and <[owner].uuid> != <player.uuid>:
        - narrate "<red>Only OPs can specify other players, please use your own name."
        - stop

    # get current mode
    - define enabled <[owner].flag[si_enabled].if_null[false]>
    - if <[enabled]>:
        - define enable_message "<green>Status: Inventory handling is ENABLED. To disable use:/simple_inventory [name] disable"
    - else:
        - define enable_message "<yellow>Status: Inventory handling is DISABLED. To enable use:/simple_inventory [name] enable"

    # All commands have a player component for ease of parsing
    - if <[command]> == list:
        # Using '||' fallback is not reliable in Denizen due to parser limitations
        - if !<[owner].has_flag[si]>:
            - narrate "<gray>No inventory data stored." targets:<player>
        - else:
            - define inv_map <player.flag[si]>
            - narrate "<green>Inventory map: <[inv_map]>"
        - narrate <[enable_message]>
        - stop

    - if <[command]> == clear:
        - flag <player> si:!
        - narrate "<red>Inventory locations cleared for <[owner]>"
        - narrate "<yellow>Click each sign/frame OR use /simple_inventory <player> repair"
        - narrate <[enable_message]>
        - stop

    - if <[command]> == repair:
        - define radius <context.args.get[3]||5>
        - narrate "<green>Repairing <[radius]> radius chunks around player"
        - run si_repair_triggers_nearby def:<[owner]>|<[radius]>
        - narrate "<yellow>Move to next location and run again"
        - narrate <[enable_message]>
        - stop

    - if <[command]> == disable:
        - flag <[owner]> si_enabled:false
        - narrate "<yellow>Inventory handling disabled but data will be maintained."
        - stop
    - if <[command]> == enable:
        - flag <[owner]> si_enabled:true
        - narrate "<green>Inventory handling ENABLED."
        - stop


# ***
# *** Reapir by finding all signs within range of the character
si_repair_triggers_nearby:
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
            - define chunk ch@<[cx]>,<[cz]>,<[loc].world.name>
            - define chunk <[chunk].as[chunk]>
            - define area <[chunk].cuboid>

            # Scan for all signs (blocks)
            - define found_list <[area].blocks[*_sign]>
            - if <[found_list].is_empty.not>:
                # A chunk scan is pretty slow so give up time for others
                - foreach <[found_list]> as:sign :
                    - define details <proc[si__parse_sign].context[<[player]>|<[sign]>]>
                    - run si__add_mapping def:<[player]>|<[details].escaped>


            # Scan for FRAMES with ITEMS
            - define found_list <[area].entities[*_frame]>
            - if <[found_list].is_empty.not>:
                - foreach <[found_list]> as:frame :
                    - define item  <[frame].framed_item>
                    - if <[item]>:
                        - define details <proc[si__parse_frame].context[<[player]>|<[frame]>|<[item]>]>
                        - define trigger <[details].get[trigger]>
                        - run si__add_mapping def:<[player]>|<[details].escaped>


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



benchmark_proc_vs_inline:
  type: task
  definition: v
  debug: false
  script:
    - define a 5
    - define b 10

    # --- Inline addition benchmark ---
    - define start_inline <util.current_time_millis>
    - repeat 10000:
        - define result <[a].add[<[b]>]>
    - define end_inline <util.current_time_millis>
    - define elapsed_inline <[end_inline].sub[<[start_inline]>]>
    - debug log "<green>Inline elapsed: <[elapsed_inline]> ms"

    # --- Procedure call benchmark ---
    - define start_proc <util.current_time_millis>
    - repeat 10000:
        - define result <proc[add_values].context[<[a]>|<[b]>]>
    - define end_proc <util.current_time_millis>
    - define elapsed_proc <[end_proc].sub[<[start_proc]>]>
    - debug log "<red>Proc call elapsed: <[elapsed_proc]> ms"



add_values:
  type: procedure
  definitions: a|b
  debug: false
  script:
    - determine <[a].add[<[b]>]>

# =================================
# ==== MOVE TO COMMON LIBRARY elements
# ====  Place tasks/prcedures here for easy testing then migrate to pl_common (paradise labs) when known to work and may be useful to other scripts
# ====


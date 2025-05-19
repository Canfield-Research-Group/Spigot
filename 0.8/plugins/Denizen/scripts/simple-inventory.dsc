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

# == TODO:
# - Make it so leading and trailing '_' auto add wildcard internally (saves space)
# - the '!' is currently useless for inventory. Instead make a new NOT filter key
# and place all those into that key (same sign). Then apply NORMAL filters followed by
# NOT. Note that this only is useful for wildcard (since items are moved to item match)
# so a ! without a wildcard is NOT supported and will be ignored.
#   Example: *!stone stone
#   Match anythign ending with stone BUT not stone. Note order of ! within other tokens is
#   not relevant. For performance is happens after all wildcards.
#       See if performance is that critical or maybe we should look through each ???
#       or maybe '!' is not very useful.

# ====== Inventory Hanlding STARTUP
# = TO Stop from console
# =     ex flag server si__stop:true
# =
# = To start up again the flag must be removed, setting to false is not enough
# =     ex flag server si__stop:!
# =

feeder_loop_starter:
  type: world
  debug: false
  events:

    # Switched code to run process feeders in a tihter controlled loop that does not need the
    # overhead of queues. THis taks no just starts and keeps it running in case it crashes out
    # due to denizen or reloads.
    #   Only run this occasionally to reduce overhead
    #
    # == HISTORIAL NOTES
    # WHile `on delta time` is recomneded it cannot do fractional seconds and every 1s is FAR too slow
    # Instead use every tick but no every tick, say every X or so which gives the feeder enough chance
    # to move 1 stack every X per feeder but the feeders are also on a tick boundry. There is a lot
    # of effort to prevent lagging out the server so lets fire every tick and see how horrible it is
    # using the spark plugin (which I usually load on my servers for just this purpose)
    # lock and this taks just handles cases of restart. That would be mor eperformant if the actual
    # capture on this event is what is the problem.
    #  - the loop_feeder is recrsive, this taks exists only to restart it if it fails, only every few seconds
    on delta time secondly every:5 :
        # THis taks handles it's own locking
        - run si__loop_feeders

    # Reset the loop on script reload so it will startup again properly, instead of waiting for flag TTL
    on reload scripts:
        # HACK to clear all queues for emergency diagnostics on restart
        # THis will may generate warnings reagrging queu clear even through precautions have been taken
        #   Do NOT run this in production, it breaks lots of things as it is NOT limited to any one script file
        - if false:
            - foreach <util.queues> as:q :
                - if <[q].is_valid> and <[q].numeric_id> != <queue.numeric_id>:
                    - debug log "<red>Stop: <[q]>"
                    # Clear does NOT work until the queue finishes and if it has not yet started I am not sure it fires
                    # in anycase on reload STOP all running. Be Aware thgis might break things
                    - queue <[q]> stop

# ***
# *** Signs/Frames can make clicking on chests very challenging. Adjust the right-click to
# *** pass through the right-click to the chest unless crouching
# ***
si__sign_or_frame_events:
  type: world
  debug: false
  events:

    # === Right click on item frame
    # This just allows the open chest mechanism for frames. The actual inventory managment handling
    # is handled via 'changes framed item'. WE do do a repair here just in case
    on player right clicks entity:
        # TIP: Do NOT use context.location here, it will error out
        - if <player.is_sneaking>:
            - stop

        - define details <proc[si__frame_details].context[<player>|<context.entity>]>
        - run narrate_list def.list:<[details].get[messages]> def.color:<green>
        - run si__feeder_notify def:<[details].get[trigger]>|<[details].get[is_feeder]>

        # an auto repair, in case something went wrong, this should not impact performance in any meaningful way
        #     allow chest sbehind signs NOT part of inevntory system to be opened
        - run si__add_mapping def:<player>|<[details]>
        - define chest <[details].get[chest]||false>
        - if <[chest]>:
            - run open_chest_gui def:<player>|<[chest]>
            - determine cancelled


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

        # an auto repair, in case something went wrong, this should not impact performance in any meaningful way
        - if <list[BROKEN REMOVE].contains_text[<[action]>]>:
            - define details <[details].with[is_valid].as[0]>
        - else:
            - run si__feeder_notify def:<[details].get[trigger]>|<[details].get[is_feeder]>

        - run si__add_mapping def:<player>|<[details].escaped>
        - run narrate_list def.list:<[details].get[messages]> def.color:<green>


    # === Right click on sign
    on player right clicks *_sign:
        # make sure location is defined, if not then exit now (sucha s right clicking in air and SPigot/purpur routed it to 'clocks blokc' event' event anyway)
        # Exit as quick as possible if this event is not applicable (crouching bypasses the override)
        - define loc <context.location||null>
        - if <[loc]> == null:
            - stop

        # Sneaking and right click lets you edit a sign SOMETIMES but it is NOT reliable, it was a few hour ago. Not sure what's up with that
        # in any case we need a bypass so stick allows edit
        - if <player.is_sneaking> || <player.item_in_hand.material.name.advanced_matches[stick|*frame|*_sign]>:
            - stop

        - define details <proc[si__parse_sign].context[<player>|<[loc]>]>
        - run narrate_list def.list:<[details].get[messages]> def.color:<green>

        # an auto repair, in case something went wrong, this should not impact performance in any meaningful way
        - run si__add_mapping def:<player>|<[details].escaped>|true

        # now check the chest, which will ALWAYS be set if if not a special sign
        - define chest <[details].get[chest]>
        - if <[chest]>:
            - run open_chest_gui def:<player>|<[chest]>

        - determine cancelled

    # == Changes Sign
    after player changes sign:
        - define loc <context.location||null>
        - if <[loc]> != null :
            - run si__remove_mapping def:<player>|<[loc]>
            - define details <proc[si__parse_sign].context[<player>|<[loc]>]>
            - run narrate_list def.list:<[details].get[messages]> def.color:<green>
            - run si__add_mapping def:<player>|<[details].escaped>
            - run si__feeder_notify def:<[details].get[trigger]>|<[details].get[is_feeder]>

            # DO NOT copy on change sign - it gets too confusing, especially since edit sign
            # pops up for sign placement as well

    # === (Sign) placed AFTER ===
    after player places *_sign:
        # Call parser
        - define details <proc[si__parse_sign].context[<player>|<context.location>]>
        - run narrate_list def.list:<[details].get[messages]> def.color:<green>
        - run si__add_mapping def:<player>|<[details].escaped>
        - run si__feeder_notify def:<[details].get[trigger]>|<[details].get[is_feeder]>

    # === Sign broken ===
    after player breaks *_sign:
        - define trigger <context.location>
        - define block_name <[trigger].material.name>
        - run si__remove_mapping def:<player>|<[trigger]>


    # === Frame entity broken (REMOVED) ===
    # This is NOT reliable as the 'on entioty dies' is not reliable called when a frame is broken.
    # Favor code that dynamically removes missing items during auto sorting procesing.


# ***
# *** If a Feeder issue any current log data for it to the player
# ***
# *** Given a feeder location (typically the trigger data). Raw lcoation data is allowed, this data is normalized by the procedure
# *** And an optional is_feed flag (defualt true). Some callers can save an IF check by passing this.
# *** An owner can be passed as well, default is <player>
si__feeder_notify:
    type: task
    definitions: feeder_loc|is_feeder|owner
    debug: false
    script:
        # If data is passed then  we use it, otherwse assume its a location. Fallbacks seem easiest in this case
        - if <[feeder_loc].is_truthy> AND <[is_feeder].is_truthy>:
            - define feeder_block <[feeder_loc].block||null>
            - if <[feeder_block]> != null:
                - define owner <[owner].if_null[<player>]>
                - define world_name <[feeder_block].world.name>
                - define diag_key <[owner].name>.<[world_name]>.<[feeder_block]>
                - define diag_status <server.flag[si_diag.<[diag_key]>].if_null[No Data]>
                - if <[diag_status].starts_with[JAM]>:
                    - define color "<red>"
                - else:
                    - define color "<green>"
                - define loc_simple <proc[location_noworld].context[<[feeder_block]>]>
                - narrate "<gold>Feeder Status: <[color]><[diag_status]> <gold>(<[loc_simple]>)" targets:<[owner]>

# ***
# *** Add the data element to the applicable indexes. This also removes any other locations in any index that exists.
# *** This tends to help auto reapir things a bit.
# ***
# *** 30 Item chests being scanned for duplciates and repairs: 3ms
# ***
#
# Simple Inventory matrix uses shorthand names to save space and improve performance to make feeder processing as fast and
# lowest lag as possible.
#
# **All**
#   t: Trigger location (sign/frame), a full location that should be 'block' level. This is what is used when removing/adding inventory matrix entries
#   c: Chest/Inventory location associated with trigger), a full location that should be 'block' level
#
# **Targets** items/wildcards/etc types associated with inbound inventories
#   f: The filter this entry responds to. Can be a item-name or advanced_match string.
#   ft: The filter type: w = wil;dcard aka advanced_matches(), i = item exact match, n (no filter, always match, normally used for fallback)
#
# **Feeders**
#   face: AN array of faces (planes) the trigger will allow targets in.
#   e: Is e trigger an entity 0 for no (a block) or 1 (yes an entity)
#   r: Range in blocks this trigger is allowd to send items.
#   q: 0 for is quite (no parttical or other visuals on erorrs), 1 enables such visual elements
#
si__add_mapping:
  type: task
  definitions: player|data|is_nottify
  debug: false
  script:
    - define start_ticks <util.current_time_millis>

    # unescape restores the data type, since in Denzien I think EVERYTHING is a string there is no 'data-type' in the normal
    # sense. If the string starts with 'map@' it is a map, if 'l@' it is a location and so on. All data types are faked.
    # Which might make code REALLY REALLY slow.
    - define data <[data].unescaped>

    # Common location data - no trigger data, then someone called us wrong and there is nothing to do
    - define trigger_loc <[data].get[trigger]||false>
    - if !<[trigger_loc]>:
        - determine false
    - else:
        - define trigger_loc <[trigger_loc].block>

    # Note: A missing chest is delayed until after we remove any defintions for this event
    - define chest_loc <[data].get[chest]||false>
    - if <[chest_loc]>:
        - define chest_loc <[chest_loc].block>


    # Remove any existing objects for inventory matrix
    - run si__remove_mapping def:<[player]>|<[trigger_loc]>

    # If missign a trigger or chest location this is a sign of incomplet or aborted parsing, it is
    # actually normal to be called with this to avoid adding conditions to every caller.
    - if <[data].get[is_valid].is_truthy.not> or !<[chest_loc]>:
        - determine stop


    # Expect to get full data element, we will optimize these in the when updating flags
    # TIP: Do NOT Adjust all locations to block level, this prevents multiple frames per chest
    - define is_item <[data].get[is_item]||false>
    - define is_feeder <[data].get[is_feeder]||false>
    - define is_overflow <[data].get[is_overflow]||false>
    - define is_unknown <[data].get[is_unknown]||false>

    # Make these availbel for all types
    - define item <[data].get[item]||false>
    - define wildcard <[data].get[wildcard]||false>

    # Entity check is used during repairs/item-moves to make sure the object is still present for so auto repair
    # can be triggered during item move.
    - define is_entity <[data].get[is_entity]||0>

    # The parser cannot handle the colon delimiter and ',' inside the entity_text being built. So use '='
    # OR build the map structure directly using ';' but that involves aleays storing item/group. In this
    # case I decided to always define item/group ("" it not set/passed) for consitency. So we just built
    # the map directly using ONE LINE to avoid parsing issues
    #  * !!! Always use '=' in maps even through doc shows ':' as being more common. The ':' is often mis-parsed
    #  * Denzien just gets weirder and weirder


    # Build flag path
    - define flag_root <proc[si__flag_path].context[<[trigger_loc]>]>

    # = Currently a frame/sign can only mark an inventory as a single type. You cannot
    # - mix wildcard with overflow for example. This COULD change some day, and if so the
    # - adjust the following by allow a type to be added to multiple lists. Note that the
    # - remove code will always remove a trigger location from ALL lists

    # =
    # = NOTE: IF adding or removing keys please update the documentation above
    # =


    # Assume things failed
    - define rtn_flag false

    # if a Feeder then by indexed by LOCATION
    - if <[is_feeder]>:
        - define accum_facings <[data].get[accum_facings].if_null[<list[]>]>
        - define range <[data].get[range]||0>
        - define sort_order <[data].get[sort_order]||nearest>
        - define be_quiet <[data].get[be_quiet]||0>

        # Optimize for feeder, all we need are feeder/chest location
        #   A range of 0 means to use the system default
        - define entry <map[t=<[trigger_loc]>;c=<[chest_loc]>;r=<[range]>;s=<[sort_order]>;face=<[accum_facings]>;q=<[be_quiet]>;e=<[is_entity]>]>
        - flag <[player]> <[flag_root]>.feeder:->:<[entry]>
        # No more actions are possible for FEEDERS, exit NOW
        - determine true

    # Item/Wildcard can be combined, process both
    - if <[item]>:
        # ** ITEMS indexed by item name. Minimmal item settings, no need to keep name as that is in the index
        - if <[is_overflow]>:
            - define item_path overflow_item
        - else:
            - define item_path item

        - define item_list <[item].as[list]>
        - foreach <[item_list]> as:item:
            - define entry <map[t=<[trigger_loc]>;c=<[chest_loc]>;f=<[item]>;ft=i;e=<[is_entity]>]>
            - flag <[player]> <[flag_root]>.<[item_path]>.<[item]>:->:<[entry]>
        - define rtn_flag true


    # Wildcards are added  to the applicable table
    - if <[wildcard]>:
        # ** wildcards are a advanced_match string (not an array)
        - if <[is_overflow]>:
            - define item_path overflow_wildcard
        - else:
            - define item_path wildcard

        - define entry <map[t=<[trigger_loc]>;c=<[chest_loc]>;f=<[wildcard]>;ft=w;e=<[is_entity]>]>
        - flag <[player]> <[flag_root]>.<[item_path]>:->:<[entry]>
        - define rtn_flag true


    # Overflow uses three lists, one for overflow_item (above, one for overflow_wildcard (above) and finally 
    # 'overflow_fallback' which have no filters and is done last (assuming overflow is in effect)
    - if <[is_overflow]> :
        - define is_fallback <[data].get[overflow_fallback]||0>
        - if <[is_fallback]>:
            - define entry <map[t=<[trigger_loc]>;c=<[chest_loc]>;ft=n;e=<[is_entity]>]>
            - flag <[player]> <[flag_root]>.overflow_fallback:->:<[entry]>
        - define rtn_flag true


    - if <[is_unknown]>:
        # ** Overflow is just a boolean, if true then ADD to the oveflow flags
        # adjust type to n (none) which implies ALWAYS MATCH (no filter)
        - define entry <map[t=<[trigger_loc]>;c=<[chest_loc]>;ft=n;e=<[is_entity]>]>
        - flag <[player]> <[flag_root]>.unknown:->:<[entry]>
        - define rtn_flag true


    - determine rtn_flag


# ***
# *** Remove a location key from all indexes
# ***
si__remove_mapping:
  type: task
  definitions: player|trigger_loc|lookup_key
  debug: false
  script:

    # - player : Player object
    # - triger_loc : A location object to filter (and remove) fro item matrix
    # - looup_key : usually 't' (Default trigger a sign/frame), 'c' (by inventory)

    # If trigger location is not set then we cannot proces it
    - if !<[trigger_loc]>:
        - determine false

    # NOTE: This is VERY unoptimized but it's easy. And even at that it only takes 1-2 ms to process removals. In the
    # case of frame edits, whch can trigger 2 or sometiems 3 times, that is still on 8ms max. And it is a GUI triggered
    # event by the player so, I am not going to worry about. It works.
    - define lookup_key <[lookup_key].if_null[t]>
    - if <[trigger_loc].location.if_null[null]> == null:
        - define search_loc <[trigger_loc].block>
    - else:
        - define search_loc <[trigger_loc].location.block>

    - define flag_root <proc[si__flag_path].context[<[search_loc]>]>

    # Round trigger to block level, which is what the item matrix contains
    - define trigger_loc <[trigger_loc].block>

    #- debug log "<green>Key: <[lookup_key]> -- <[search_loc]> -- <[trigger_loc]>""

    - define group_keys <[player].flag[<[flag_root]>].if_null[<map[]>].keys>
    - foreach <[group_keys]> as:group_name:
        - define flag_list_path <[flag_root]>.<[group_name]>
        # Items are indexed by name, so loopt hat extra depth
        - if <[player].has_flag[<[flag_list_path]>]>:
            - if <[group_name]> == item or <[group_name]> == overflow_item:
                # Items are indexed by item name so we need some more looping
                - define item_names <[player].flag[<[flag_list_path]>].keys>
                - foreach <[item_names]> as:item_name :
                    - run si__remove_locations def:<[player]>|<[flag_list_path]>.<[item_name]>|<[search_loc]>|<[lookup_key]>
            - else:
                - run si__remove_locations def:<[player]>|<[flag_list_path]>|<[search_loc]>|<[lookup_key]>


# ***
# *** Remove all entries that match the target key (t) from the list specified by the flag path
si__remove_locations:
  type: task
  definitions: player|flag_path|trigger_loc|lookup_key
  debug: false
  script:

    # THis method is likley faster for cases needing multiple deletes, RARE.
    - if <[player].has_flag[<[flag_path]>]>:
        #- debug log "<green>Key: <[lookup_key]> -- <[trigger_loc]>""

        # = NOTE: It is apparently unreliable to remove complex keys indivually via :<-: which aligns with my experience with it being weird ...
        # = NOTE: This algiorthm us great and FAST but it does not allow cleanup of diag logs for removed feeders
        #- define original <[player].flag[<[flag_path]>]>
        #- define keep_entries <[original].filter_tag[<[filter_value].get[<[lookup_key]>].equals[<[trigger_loc]>].not>]>
        #- if <[original].size> != <[keep_entries].size>:
        #    - flag <[player]> <[flag_path]>:<[keep_entries]>
        #    - define new <[player].flag[<[flag_path]>]>
        #- stop

        - define world_name <[trigger_loc].world.name>
        - define diag_key <[player].name>.<[world_name]>.<[trigger_loc].block>

        - define remove_entries <[player].flag[<[flag_path]>].filter_tag[<[filter_value].get[<[lookup_key]>].equals[<[trigger_loc]>]>]>
        - foreach <[remove_entries]> as:entry :
            #- debug log "<red>Remove: <[flag_path]> :: <[trigger_loc]> -- <[entry]>"
            - flag <[player]> <[flag_path]>:<-:<[entry]>
            - if <server.has_flag[si_diag.<[diag_key]>]>:
                - flag server si_diag.<[diag_key]>:!
        - stop


        # THis method is likley faster for cases needing one or zero deletes, COMMON - BUT it can have issues with removing complex items (MAYBE)
        #- define log <Element[]>
        #- define found_entries <[player].flag[<[flag_path]>].filter_tag[<[filter_value].get[<[lookup_key]>].equals[<[trigger_loc]>]>]>
        #- foreach <[found_entries]> as:entry :
        #    - debug log "<red>Remove: <[flag_path]> :: <[trigger_loc]> -- <[entry]>"
        #    - flag <[player]> <[flag_path]>:<-:<[entry]>
        #- stop

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
    - define result <proc[si__base_parser_result]>

    # Exit as quick as possible if this event is not applicable (wrong type)
    - if <[frame].entity_type.advanced_matches[item_frame|glow_item_frame]>:
        - define result <[result].with[is_entity].as[1]>
    - else:
        - define result <[result].with[is_entity].as[0]>
        - determine <[result]>

    # Frames are peculary, so they need to be trated a bit different, hande object OR loc
    - define frame_loc <[frame].location.if_null[<[frame]>]>
    - define result <[result].with[trigger].as[<[frame_loc]>]>

    - define rotation_vector <[frame].rotation_vector>
    - define attached <[frame_loc].add[<[rotation_vector].mul[-1]>]>
    - if <[attached].has_inventory.if_null[null]>:
        # Update no-match so frames thata re not item matching (empty) can pass on clicks (for example to chests)
        - define result <[result].with[chest].as[<[attached]>]>

    - define is_allowed <proc[is_chest_like].context[<[attached]>]>
    - if <[is_allowed].not>:
        - determine <[result]>

    # If itemw as not passed then fetch from passed frame data
    - define item <[item]||<[frame].framed_item>>

    # get item filter, this is easy, it is the item name
    - define item_filter <[item].material.name>

    - if <[item_filter]> == air:
        # Empty frame - use 'not applciable' (common in this script, and saves space in large maps)
        - determine <[result]>
    - else:
        - define is_feeder false
        - define result <[result].with[item].as[<[item_filter]>]>
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
        - define result <[result].with[is_feeder].as[<[is_feeder]>]>

    # Return both feeder and chest-like inventory location. use a map to self-document. This is all internal
    # data so size is not relevent.
    - define result <[result].with[is_valid].as[1]>
    - determine <[result]>


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
# NUANCE:
#  The trigger is FALSE-LIKE if it is NOT a valid sign BUT the 'chest' may be set if the sign is attached to an inventory regardless of
#  the signs qualifications. This allows for code to check passthrough (like right click opens) even for non inevtory signs
#
si__parse_sign:
  type: procedure
  definitions: player|location
  debug: false
  script:
    # Id no match is found return nulls for each element
    - define base_data <proc[si__base_parser_result]>

    - define trigger <[location]||null>
    - if !<[trigger]>:
        - determine <[base_data]>

    - define base_data <[base_data].with[trigger].as[<[trigger]>]>

    - define block_name <[trigger].material.name>
    - if !<[block_name].ends_with[_sign]>:
        - determine <[base_data]>

    # Signs re SO much simpler than frames, so optimize for signs (bug backward/forward still seem weird, and not reliable)
    - define facing <[trigger].block_facing||null>
    # This is NOT just attached blocks but also blocks behind the sign. Filter for only attached  proved annoying so allow a sign to be in FRONT of chest
    - if !<[facing]>:
        - determine <[base_data]>

    - define chest <[location].relative[<[facing].mul[-1]>]>
    - if <[chest].has_inventory.if_null[null]>:
        - define base_data <[base_data].with[chest].as[<[chest]>]>

    - define is_allowed <proc[is_chest_like].context[<[chest]>]>
    - if !<[is_allowed]>:
        - determine <[base_data]>

    # Get sign data and assign internal postional
    - define data <proc[si__process_sign_text].context[<[trigger]>]>
    - define result <[base_data].include[<[data]>]>

    #- debug log "<red>SIGN Parsed: <[result]>"
    - determine <[result]>


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

    # Parsed data either returned or adjusted
    - define accum_facings <list[]>
    - define accum_items <list[]>
    - define accum_wildcards <list[]>
    - define accum_messages <list[]>

    # Track sign type detected
    - define is_feeder false
    - define is_item false
    - define is_overflow false
    - define is_unknown false

    # Build basic result set to minimums
    - define result <map[]>

    # Instead of geting fancy I am going to do a DEAD SIMPLE code.
    - define sign_contents <[sign_obj].sign_contents||null>
    - if <[sign_contents]> == null:
        - determine <[result]>
    - define sign_lines <list[]>
    - foreach <[sign_contents]> as:line :
        # Clean lines of special cpracters
        - define line <[line].unescaped.strip_color.trim.to_lowercase>
        # Split these into more lines based on special characters
        - foreach <[line].split[regex:[,;| ]]> as:part :
            - define part <[part].trim>
            - if <[part].length> > 0:
                # Appen item to list
                - define sign_lines:->:<[part]>

    # = Rules for tokenizer
    # -     The 'result' set is built as needed
    # -     Users of this data may have to use fallbacks when accessing data as this parser is not responsible
    # -     for guarnteeing parsing.
    # -     For singular values added directly to the result set as needed
    # -     For accumulator values use variables with 'accum_*' and process them at end of token loop if NOT empty

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
        - define sign_pattern [*]
        - if <[type].advanced_matches[<[sign_pattern]>].not>:
            - determine <[result]>
        # Note that if .before fails the entire string is returned not false-like as one might expect
        - define sign_type <[type].after[<[open]>].before[<[close]>]>
        - define range 0

        # Controls if particles are emitted
        - define be_quiet 0
        - choose <[sign_type]>:
            - case feeder:
                - define is_feeder true
                - define result <[result].with[is_feeder].as[<[is_feeder]>]>
            - case inv:
                # For syntax we need something here and it might be useful someday
                - define is_item true
                - define result <[result].with[is_item].as[<[is_item]>]>
            - case overflow:
                - define is_overflow true
                - define result <[result].with[is_overflow].as[<[is_overflow]>]>
            - case unknown:
                - define is_unknown true
                - define result <[result].with[is_unknown].as[<[is_unknown]>]>
            - default:
                # A normal sing so skip parsing it and exit
                - determine <[result]>

        # Containue parsing spec. Data is parsed for inv/feeder the same for easy coding.
        # THe calling code will store the data applicable to the type fo sign, and ignore the rest
        - define sign_lines <[sign_lines].remove[1]>
        - define sign_spec <[sign_lines].separated_by[|]>

        - define tokens <[sign_spec].to_lowercase.replace[<[open]>].with[ ].replace[<[close]>].with[ ].split[regex:\s+|\||,-]>
        - define known_facings <list[n|s|e|w|u|d]>
        - define template null
        - foreach <[tokens]> as:token:
            - define token <[token].trim>
            - if !<[token]>:
                - foreach next

            # Item and overflow can pars from signs. The flag is_item / is_overflow is used when adding ite,s/wildcards
            # to the look tables.
            - if <[is_item]> or <[is_overflow]>:
                - if <[token].starts_with[regex]>:
                    - define accum_messages <[accum_messages].include["<red>Regex not supported in sign options, skipping (<[token]>)"]>
                    - foreach next

                - if <[token].contains_text[%]>:
                    # Group tokenization
                    - define template <[token]>
                    #- debug log "<red>:Template found: <[template]>"
                    - foreach next

                - if <[template]>:
                    - define token <[template].replace_text[%].with[<[token]>]>
                    #- debug log "<red>Template resolved: <[token]>"
                    # Fall through to process this new token

                - if <item[<[token]>].exists>:
                    - define accum_items:->:<[token]>
                    - foreach next
                # ! is no longer supported, see TODO
                - if <[token].contains_any_text[*].not> or <[token].contains_any_text[!]>:
                    - define accum_messages <[accum_messages].include[<red>Invalid Item name:  (<yellow><[token]><gold>) does not look like an wildcard match (! is NOT supported) but is not a known item name. Remember to use minecraft names (with underscores but no minecraft: prefix). <yellow>Example: wheat_seeds]>
                    - foreach next
                # = Assume a wilcard, these are accumulated below
                - define accum_wildcards:->:<[token]>
                - foreach next

            - if <[is_feeder]>:
                # These are only available to feeders, ignore for others
                - if <[token]> == nearest:
                    - define result <[result].with[sort_order].as[nearest]>
                    - foreach next
                - if <[token]> == random:
                    - define result <[result].with[sort_order].as[random]>
                    - foreach next

                # Range
                - if <[token].is_decimal>:
                    - define sign_range <[token]>
                    - define range <proc[si__range_normalize].context[<[sign_range]>]>
                    - if <[sign_range]> and <[range]> != <[sign_range]>:
                        - define accume_messages <[accum_messages].include[<gold>Range value (<yellow><[sign_range]>)<gold> is out of bounds, will be dynamiclaly adjusted to: <yellow><[range]>]>
                    - define result <[result].with[range].as[<[sign_range]>]>
                    - foreach next

                - if <[known_facings].contains_text[<[token]>]>:
                    - define accum_facings:->:<[token]>
                    - foreach next

                - if <[token]> == quiet:
                    - define result <[result].with[be_quiet].as[<[be_quiet]>]>
                    - foreach next
                - define accum_messages <[accum_messages].include[<red>Feeder spec warning: <gold>The token (<yellow><[token]>) <gold>is not a valid feeder token, ignoring. For <yellow>Sort<gold> use: nearest,random, <yellow>Faceings:<gold> n,s,e,q,w,d,u, <yellow>Range:<gold> number, <yellow>Quiet:<gold> quiet]>
                - foreach next

            # = Else we only care about the tag (for now). Do not exit early, this code only
            # - runs on GUI events so need not be performant and this makes it easier to add tokens with less risk of breaking things


    # Overflow is given a wildcard setting
    - if <[accum_wildcards].is_empty.not>:
        - define wildcard_pattern <[accum_wildcards].separated_by[|]>
        - define result <[result].with[wildcard].as[<[wildcard_pattern]>]>

    # See if this is an empty overflow, in which case it is fallback
    - if <[is_overflow]>:
        - if <[accum_items]> or <[accum_wildcards]>:
            - define result <[result].with[overflow_fallback].as[0]>
        - else:
            # This forms the final overflow mechanism
            - define result <[result].with[overflow_fallback].as[1]>

    - if <[accum_items].is_empty.not>:
        - define result <[result].with[item].as[<[accum_items]>]>

    - if <[accum_facings].is_empty.not>:
        - define result <[result].with[facings].as[<[accum_facings]>]>

    # Always add messages, even if empty. Many callers check this and it's easier if it always exists
    - define message_escaped <[accum_messages].escaped>
    - define result <[result].with[messages].as[<[message_escaped]>]>
    - define result <[result].with[is_valid].as[1]>

    - determine <[result]>



# ***
# *** Loop processes feeders continuously using local code management for ticks.
# *** Prevent smultiple istances from running.
# ***
# *** To STOP set flag to anything:
# ***   - ex flag server si_stop:true
# ***       Debug by calling si__process_feeders directlry, reload, do whatever but the
# ***       automated looping is stopped.
# ***
# *** To START (remove flag):
# ***   - ex flag server si_stop:!
# ***
si__loop_feeders:
  type: task
  debug: false
  script:
    # Prevent recursive runing of this job. If somethign horrible goes
    # wrong with task auto remove flag after 2 seconds.
    - if <server.has_flag[si_stop]>:
        - stop

    # Give a bit of time to close out the task that called us.
    #    This works better than than using `run ... delay` which adds a queue whcihc an confuse the queue handler

    # Add a small de-lag
    - wait 2t


    # One of the simplest ways to make it so only 1 queue (or actually x) queues for a task are runing.
    # Filter, get count, exit current one if count is reached. This stops timed events, watchdogs or
    # rogue calls from occuring. Simple clean.
    #   THis does nto stop any backgroudn queues so those continue to runt o completion
    - define queues <script.queues.filter_tag[<[filter_value].id.starts_with[SI__LOOP_FEEDERS_]>]>
    - if <[queues].size> > 1:
        #- debug log "<red>Stopping queue <queue.numeric_id> there are too many others running: <[queues].size>"
        - stop

    # Tip: '~run ' is waitable. And per testing, the run will WAIT until the task is done
    #   See: https://meta.denizenscript.com/Docs/Search/run#run
    #   See: https://meta.denizenscript.com/Docs/Languages/~waitable
    - define s_time <util.current_time_millis>
    - ~run si__process_feeders

    # Setup to run on next tick to reduce lag
    - run si__loop_feeders


# ***
# Scan all feeders
# ***
# *** Benchamrk issues
# ***  - scanning a full double chest of items (unique) that MATCH a target but all targets are full (worse case): 48ms
# ****
# **** WARNING: This does NOT block multiple calls, but it also does not loop more than once across all feeders.
# **** It is fine to call this while main loop is running to do a quick test or something.
si__process_feeders:
  type: task
  debug: false
  definitions: tick_delay|filter_player
  script:
    - define counter 0
    - define elapsed_chunk_loaded 0
    - define elapsed_inv 0
    - define elapsed_distance 0
    - define elapsed_setup 0
    - define elapsed_move 0
    - define feeder_constants <proc[pl__config].context[simple-inventory.feeder]>

    - define feeder_tick_delay <[tick_delay].if_null[<[feeder_constants].get[tick_delay]>]>
    - define min_distance <[feeder_constants].get[min_distance]>
    - define max_distance <[feeder_constants].get[max_distance]>
    - define max_quantity <[feeder_constants].get[max_quantity]>
    - define max_runtime <[feeder_constants].get[max_runtime]>
    - define wait_time <[feeder_constants].get[wait_time]>
    - define preferred_list_order <[feeder_constants].get[list_order].as[list]>
    - define diagnostics null
    - define jam_message "(Jam detected: Provide a/more targets for item)"

    # Override the tick_delay if passed
    - define filter_player <[filter_player].if_null[false]>

    - define start_time <util.current_time_millis>

    # Build a list of all feeders for all players
    - define all_worlds <server.worlds>

    # Diag logs need to build on prior data
    #  But if the feeder is skipped really early (due to tick mod check)
    #  then there is and should notbe a diag message. SO we need to preserve it
    #  Note: It is faster to do this than havea GC to remove old unused log entries
    - define diag_log <server.flag[si_diag].if_null[<map[]>]>

    # Loop on each world and limit processing per world
    - define current_feeder_sequence <server.flag[si.feeder_sequence]||-1>
    - define current_feeder_sequence:++
    - flag server si.feeder_sequence:<[current_feeder_sequence]> expire:10s
    - foreach <[all_worlds]> as:world:
        - define world_name <[world].name>
        - define feeder_master_list <list[]>

        - foreach <proc[get_all_players]> as:owner:
            - if <[owner].has_flag[si].not>:
                - foreach next
            - if <[owner].flag[si_enabled].if_null[false].not>:
                - foreach next

            # Easy, if suboptimal way to filte on passed player
            - if <[filter_player]>:
                - if <[owner].uuid> != <[owner].uuid>:
                    - foreach next

            # Get all feeders for for this player/world
            - define feeders <[owner].flag[si.<[world_name]>.feeder].if_null[<list[]>]>
            - if <[feeders].size> == 0:
                # No feeders for this world so just continue
                - foreach next

            - foreach <[feeders]> as:feeder :
                # A bit of a hack to add particales for any JAM
                - define feeder_loc <[feeder].get[t].block>

                # ONly add feeders that are applicable to the current tick
                - if <proc[should_run_this_tick].context[<[feeder_loc]>|<[feeder_tick_delay]>|<[current_feeder_sequence]>]>:
                    - define feeder_master_list:->:<list[<[owner]>|<[feeder]>]>
                    # Particales only occur if NOT quiet
                    - if !<[feeder].get[q].if_null[0]>:
                        - define diag_key <[owner].name>.<[world_name]>.<[feeder].get[t].block>
                        - define log <[diag_log].deep_get[<[diag_key]>]||element[]>

                        - if <[log].starts_with[JAM]>:
                            # Adjust effect location, note that the playeffec.offset is more a random flucation around each particale effect so is not precise for positioning
                            # - For angry_villager a single particale is visible fine and lower lag on client than 2
                            - define effect_loc <[feeder_loc].add[.5,.0,.5]>
                            - playeffect <[effect_loc]> effect:angry_villager quantity:1 offset:0.1,0.1,0.1 visibility:10
                            #- define effect_loc <[feeder_loc].add[.5,.25,.5]>
                            #- playeffect <[effect_loc]> effect:smoke quantity:2 offset:0.1,0.1,0.1 visibility:10

                            # = Item particles are quite cool and fun, bu carry some load for the client, stick to more basic
                            #- define effect_loc <[feeder_loc].add[.5,1,.5]>
                            #- playeffect <[effect_loc]> effect:item special_data:pumpkin quantity:2 offset:0.1,0.1,0.1 visibility:10 velocity:0,.1,0

            # Randomize this list for fairness
            - define feeder_master_list <[feeder_master_list].random[<[feeder_master_list].size>]>
        # Now process the feeder list for this world
        - foreach <[feeder_master_list]> as:feeder_to_process :
            - define owner <[feeder_to_process].get[1]>
            - define feeder <[feeder_to_process].get[2]>
            - define diag_key <[owner].name>.<[world_name]>.<[feeder].get[t].block>
            # Unless something odd happened this staet should be replaced by one of the others, if its seen look for issues
            # Do NOT store this in feeder log, it erases the last move data
            #- define diag_state "Info: not processed"
            #- define diag_log <[diag_log].deep_with[<[diag_key]>].as[<[diag_state]>]>

            # When this becomes true the current feeder is DONE
            - define move_completed false


            # Check chest location
            # o this first as it is quick and easy. Note that inventory is null/empty if chunk is not loaded
            - define feeder_chest <[feeder].get[c]>
            - define feeder_inventory <[feeder_chest].inventory.if_null[null]>
            - if <[feeder_inventory]> == null:
                - if <[feeder_chest].chunk.is_loaded.not>:
                    - foreach next
                # Inventory is NULL AND chunk is loaded so chest is GONE
                - debug log "<red>Feeder chest missing: <[feeder_chest]>"
                - run si__remove_mapping def:<[owner]>|<[feeder_chest]>|c
                - foreach next
            - else:
                - if <[feeder_inventory].is_empty>:
                    - foreach next
            # Get other feeder chest (double chest), if none just set to self. Makes for faster code as we save multiple ifs later
            - define feeder_chest_other <[feeder_chest].other_block.if_null[<[feeder_chest]>]>



            # If empty then nothing to do so exit
            - if <[feeder_inventory].is_empty>:
                # Do NOT store this in feeder log, it erases the last move data
                # - define diag_state "Info: empty"
                #- define diag_log <[diag_log].deep_with[<[diag_key]>].as[<[diag_state]>]>
                - foreach next


            # Check feeder location (trigger)
            - define feeder_loc <[feeder].get[t]>
            - if <[feeder_loc].chunk.is_loaded.not>:
                #- define diag_state "Info: chunk not loaded"
                #- define diag_log <[diag_log].deep_with[<[diag_key]>].as[<[diag_state]>]>
                - foreach next


            - define feeder_chest_other <[feeder_chest].other_block.if_null[<[feeder_chest]>]>

            # If feeder chest is powered skip it
            - define is_powered <proc[powerlevel_blocks].context[<[feeder_chest]>]>
            - if <[is_powered]> > 0:
                - define diag_state "Info: powered, ignored"
                - define diag_log <[diag_log].deep_with[<[diag_key]>].as[<[diag_state]>]>
                - foreach next

            - define feeder_facings <[feeder].get[face].if_null[<list[]>]>

            # Dyanmically set max range, this allows signs to be set to a HIGH value but
            # be throttled dyannically and if configuation changes then range data in the items matrix will just be dynamically adjusted to new max
            - define feeder_range <proc[si__range_normalize].context[<[feeder].get[r].if_null[0]>]>
            # get cuboid for feeder range, this makes limit chcks very FAST
            #  Tip: For consistency with player expectations all bounds/ranges are from the inventories. For cases
            #  where the inventory is a double block we just use the blok the sing/frames elements are attached to. Imperfect, yea, but a lot faster and good enough
            - define feeder_bounds <proc[create_cuboid_from_location].context[<[feeder_chest]>|<[feeder_range]>]>

            # Loop on each item in feeder until SOMETHING can be moved
            - define feeder_slots <[feeder_inventory].map_slots>

            # Scan feeder chest until a move is found, quickly skipping items already identied as haveing no available target
            - define feeder_skip_next_time <list[]>
            - foreach <[feeder_slots]> as:feeder_item key:feeder_slot :
                # THis seems like a good time to wait,  after all init AND before moves start. This loop
                - define process_runtime <util.current_time_millis.sub[<[start_time]>]>
                - if <[process_runtime]> > <[max_runtime]>:
                    - debug log "<red>Script runtime exceed: <[process_runtime]> EXCEEDS <[max_runtime]>"
                    - wait <[wait_time]>
                    - define start_time <util.current_time_millis>

                - if <[move_completed]>:
                    - foreach stop

                # Exit as soon as any item be moved by any quantity
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

                # Set a default
                - define diag_state "JAM: target not found for: <[feeder_item_name]> <[jam_message]>"
                - define diag_log <[diag_log].deep_with[<[diag_key]>].as[<[diag_state]>]>

                # = Loop through each available list, each list is tried before moving to the next
                # Track is all found targets are full, and indirectly if unknown
                - define targets_all_full false
                - foreach <[preferred_list_order]> as:list_name :
                    - if <[move_completed]>:
                        - foreach stop

                    - if <[list_name]> == item || <[list_name]> == overflow_item:
                        # Item has one more depth based on item
                        - define target_path si.<[world_name]>.<[list_name]>.<[feeder_item_name]>
                    - else:
                        - define target_path si.<[world_name]>.<[list_name]>

                    - define targets_list <[owner].flag[<[target_path]>].if_null[<list[]>]>

                    # Scan these locations in order, on match Try to move
                    # Get starting list
                    - define sorted <list[]>

                    # = Perform a scan to build a list: [[index, distance], ....]) (this loop does not move items, it just builds the list)
                    #   This calls the slow distance (and skips the proc) once per list (old code was called 6 tiems for 3 elements qsort)
                    #   The call also gets the plane(s) the. Timing is 154ms for 5,000 elements ==> .031 ms per item. Most item lists will
                    #   by only a few, but even if 10 that is 0.1 ms and we can round to 1ms and be ok.

                    - foreach <[targets_list]> as:entry key:loop_index :
                        # The targets_all_full works as a overflow and unknown flag but are only viable if checked AFTER all item filters are applied (item, wildcard)
                        #   If FALSE then we reached the overflow/unknown without finding a suitable move. So Unknown
                        #       Since otherwise we would have MOVED the item and exited the loop
                        #   If FALSE then we reached the overflow/unknown and found a target (or more) but they were full. So Overflow is triggered
                        #       If a target was found it was moved OR there was no room, so is consdiered full
                        # Our logic is skip based so the above is REVERSED
                        - if <[list_name].starts_with[overflow]> and <[targets_all_full].not>:
                            # NOT uoverflow since no target was found to be empty
                            - foreach next

                        # The uknown will ONLY fire if a no targets were found
                        - if <[list_name]> == unknown and <[targets_all_full]>:
                            # NOT unknonw, targets were found
                            - foreach next

                        # Wild card filter types need to be limited to what matches. This is, hopefully faster than distance check, if not add below distance
                        #   Expect this to be i (item - which is not used at this point) , w (wildcard matchonlything we care abut here), n (no filters)
                        - if <[entry].get[ft]||n> == w:
                            # Wild card match, make sure feeder item matchs filter
                            - define filter <[entry].get[f]>
                            - if <[feeder_item_name].advanced_matches[<[filter]>].if_null[false].not>:
                                # NO match - so do NOT add to distance list
                                - foreach next


                        # From here on all that we need is the keys tc (chest) key in the target lists. So thjis works for entries within an item name group,
                        # wildcard, overflow and unknown, as well as any other fallback/priority elements

                        # This compares chest inventory block possitions. Note that for double chests this gets a bit
                        # strange and no effort is made to normalize it. Multiple trigger frame/sign on different parts of a double chest
                        # will have differnet block positions. That's just the way it is for performance reasons. This may impact
                        # distances bt (1).
                        - define planes <map[n=0;e=0;s=0;w=0;u=0;d=0]>
                        # Block rounding helps with distance and plane more dertministic
                        - define target_block <[entry].get[c]>

                        # Verify target is in cuboid and then get ecludian distance
                        #  Faster for cases where a lot of chest are out of range by eliminating complex distance claculation (it does start to matter at 100's of chest)
                        #  Still allows sorting by nearest within that space
                        - define dist <proc[cuboid_distance_from_center].context[<[feeder_bounds]>|<[target_block]>|<[feeder_chest]>]>
                        # Normally a check on min-distance would suffic but I want o remember and codifiy this is a tad more complex in case
                        # min_distance is changed (I doubt it would need change lower than zero through)
                        - if <[dist]> < 0 or <[dist]> <= <[min_distance]>:
                            # Not in cuboid so forbidden
                            - foreach next

                        # Super easy to filter out here. Tha main list is unchanged but if the indexed list (distances)
                        # is what is looped on so this is a very effecient way to filte rout before even sorting
                        # Tip: Doagnalos should also be skipped , if that is not desired use 1 instead of 1.5
                        - if <[dist]> <= <[feeder_range]> and <[dist]> >= <[min_distance]>:
                            - define dx <[target_block].x.sub[<[feeder_chest].x>]>
                            - define dy <[target_block].y.sub[<[feeder_chest].y>]>
                            - define dz <[target_block].z.sub[<[feeder_chest].z>]>
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

                            # If feeder has a accum_facings array it then ANY facing that aligns with a the current target passes.
                            # if facing syas 'N' and 'E' then the planes for target must be n the N and/or E facing.
                            #   If there is no plane specified, then all is OK
                            #   Else all planes specified in accum_facings MUST be in the plane of the current target
                            #   Tip: targets not in that facing direction are not
                            #   Note: AN AND condition (so only targets NE) is possible it is not intutive and hard to manage. That migth require routing around other blocks
                            #       Also cosndier using a distance value to limit transfer range
                            - define allowed true
                            - foreach <[feeder_facings]> as:f :
                                # Ona n empty list Denzien can sometimes still process it, likley due to the weird way it
                                # handles some list (@li and @li|)
                                - if <[f]>:
                                    - if <[planes].get[<[f]>]> == 0:
                                        - define allowed false
                                    - else:
                                        - define allowed true

                            - if <[allowed]>:
                                - define sorted:->:<list[<[loop_index]>|<[dist]>|<[planes]>]>

                    # Now we want to sort the list using a tag into the each list item, which is itself a list. And in this case a tag of 1 gets the index
                    # TIP: This is useful to remember as it allows list with maps to be sorted by their key as long as the key is a pure numeric or alpah (see sort_by_value)
                    - if <[feeder].get[s].if_null[nearest]> == random:
                            - define sorted <[sorted].random[<[sorted].size>]>
                    - else:
                        # Default sort is by nearet (aka distance), 2nd term of list
                        - define sorted <[sorted].sort_by_number[2]>

                    - foreach <[sorted]> as:distance_matrix :
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

                        # If feeder and target chest are the same, then that would cause recursion so avoid
                        #   A min distance 1.1 would also resolve this but that is not always desired as it makes feeders inside storage walls more challenging
                        - if <[target_chest].block> == <[feeder_chest].block> or  <[target_chest].block> == <[feeder_chest_other].block>:
                            - foreach next

                        # DO a FAST check here to avoid excpetions. If things need repaired that
                        # can be done with commands. If abuse occurs (not sure I care) we can address that later
                        - define target_inventory <[target_chest].inventory.if_null[null]>
                        - if <[target_inventory]> == null:
                            - debug log "<red>Feeder no longer a valid inventory, removing: <[owner]> -- <[target_chest]>"
                            - run si__remove_mapping def:<[owner]>|<[target_chest]>|c
                            - foreach next

                        - define space_available <[target_inventory].can_fit[<[feeder_item_name]>].count>
                        - define items_to_move <[space_available].min[<[feeder_item_quantity].min[<[max_quantity]>]>]>
                        - if <[items_to_move]> <= 0 :
                            # No space in the target so continue scanning items
                            - define diag_state "JAM: all targets full: <[feeder_item_name]> <[jam_message]>"
                            - define diag_log <[diag_log].deep_with[<[diag_key]>].as[<[diag_state]>]>
                            - define targets_all_full true
                            - foreach next

                        # Space was found so NOT all full
                        - define targets_all_full false

                        # All OK, initiate a move
                        - define from <proc[location_noworld].context[<[feeder_chest]>]>
                        - define to <proc[location_noworld].context[<[target_chest]>]>
                        - define diag_state "Info: Moved <[items_to_move]> <[feeder_item_name]> : [<[from]>]  To  [<[to]>] PER <[list_name]> list matched on (<[target].get[f]||anything>)"
                        - define diag_log <[diag_log].deep_with[<[diag_key]>].as[<[diag_state]>]>

                        # Transfer item
                        #   Note we need to specify quantity force more than one on TAKE
                        #   WARNING: use the original feeder_item NOT the name (which looses NBT data)
                        #       Taking the item cannot be an ITEM, it might need to be a SLOT but let's see if the
                        #       name works, but we need to store the actual ITEM
                        - take item:<[feeder_item]> quantity:<[items_to_move]> from:<[feeder_chest].inventory>
                        - if <[feeder_item_quantity].sub[<[items_to_move]>]> == 0 :
                            # Get rid of ghost Items, Denizen will create ghost items when removing takeing 1 item to 0
                            #   TO be safe we just detect any case where we empty the slot
                            #   NOTE: For this command origin is an ITEM not an inventory (the SWAP woudl be an origin).
                            #   Yes that is very inconsitent  and rather horrid, welcome to Minecraft coding
                            - inventory set destination:<[feeder_chest].inventory> slot:<[feeder_slot]> origin:air
                        - give item:<[feeder_item]> quantity:<[items_to_move]> to:<[target_chest].inventory>
                        - define counter <[counter].add[1]>

                        # This is used to allow a more intelligent loop exit logig that can leave multiple levels base don logic
                        # Found target all done
                        - define move_completed true
                        - foreach stop

                # Feeders ONLY process ONE item, to avoid abuses (and work like hoppers)
                - define move_completed true
    # Record all logs for player for use in player diagnostics
    - flag server si_diag:<[diag_log]>

# ***
# *** HELP TEXT
# ***
# TODO: Prototype - clean this up when code structure is done
si__help:
  type: command
  name: simple-inventory
  description: List or reset simple inventory feeders
  usage: /simple-inventory [player] [list/clear/repair/enable/disable/diag] [repair-radius-chunks]
  #permission: false
  debug: false
  tab completions:
    # This will complete any online player name for the second argument
    1: <proc[get_all_players].parse[name]>
    # This will complete "alpha" and "beta" for the first argument
    2: list|clear|repair|enable|disable|diag
    # This will allow flags "-a", "-b", or "-c" to be entered in the third, fourth, or fifth argument.
    3: [radius]
  script:
      # Definitions
    - define owner <context.args.get[1]||null>
    - define command <context.args.get[2]||help>
    - define radius <context.args.get[3]||5>

    - define feeder_constants <proc[pl__config].context[simple-inventory.feeder]>
    - define preferred_list_order <list[feeder].include[<[feeder_constants].get[list_order].as[list]>]>

    # Help block (called when command is missing or unknown)
    - define show_help false
    - if <[command]> == help:
        - define show_help true
    - if <context.args.size> < 2:
        - define show_help true
    - if <list[list|clear|repair|enable|disable|diag].contains_text[<[command].to_lowercase>].not>:
        - define show_help true

    - if <[show_help]>:
        - narrate "<gold>Simple Inventory Help:"
        - narrate "<yellow>/simple-inventory [player] list"
        - narrate "<gray> View all active inventory feeders for that player"
        - narrate "<yellow>/simple-inventory [player] enable"
        - narrate "<gray>  Enable plugin for player"
        - narrate "<yellow>/simple-inventory [player] disable"
        - narrate "<gray>  Disable inventory handling (only) for player, all data is maintained"
        - narrate "<yellow>/simple-inventory [player] clear"
        - narrate "<gray>  Remove all inventory feeder data"
        - narrate "<yellow>/simple-inventory [player] repair [radius]"
        - narrate "<gray>  Scan signs/frames around player to repair system"
        - narrate "<gray>  Default radius is <white>5<yellow> chunks."
        - narrate "<yellow>/simple-inventory [player] diag"
        - narrate "<gray>  Show last status of feeders"
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
        - define enable_message "<green>Status: Inventory handling is ENABLED. To disable use:/simple-inventory [name] disable"
    - else:
        - define enable_message "<yellow>Status: Inventory handling is DISABLED. To enable use:/simple-inventory [name] enable"

    # All commands have a player component for ease of parsing
    - if <[command]> == list:
        # Using '||' fallback is not reliable in Denizen due to parser limitations
        - if !<[owner].has_flag[si]>:
            - narrate "<red>No inventory data stored." targets:<player>
        - else:
            - narrate "<red>Inventory Matrix." targets:<player>
            - define inv_map <[owner].flag[si]>
            - foreach <[inv_map]> key:world_name as:world_list:
                # Order of lists to process
                - foreach <[preferred_list_order]> as:group_name:
                    - define group_list <[world_list].get[<[group_name]>].if_null[false]>
                    - narrate "<gold><[world_name]> / <[group_name]> list"
                    - if !<[group_list]>:
                        - narrate "  <yellow>Empty"
                        - foreach next

                    # Determin list handler type
                    - choose <[group_name]>:
                        - case feeder:
                            - define handler feeder
                        - case item:
                            - define handler item
                        - case wildcard:
                            - define handler wildcard
                        - case overflow_item:
                            - define handler item
                        - case overflow_wildcard:
                            - define handler wildcard
                        - default:
                            - define handler other

                    # use handler to render list
                    - choose <[handler]>:
                        - case feeder:
                            - foreach <[group_list]> as:entry:
                                - define loc <[entry].get[t]>
                                - define accum_facings <[entry].get[face].separated_by[;]>
                                - if <[accum_facings].is_truthy.not>:
                                    - define accum_facings All
                                - define range <[entry].get[r]>
                                - define range_adj <proc[si__range_normalize].context[<[range]>]>
                                - define be_quiet <[entry].get[q].if_null[0]>

                                - narrate "-- <yellow>Feeder <gray>@ <green><proc[location_noworld].context[<[loc]>]>"
                                - narrate "--- <gray>Sort: <[entry].get[s]>, Range: <[range_adj]>(<[range]>), Facings: <[accum_facings]>"
                                - narrate "--- <gray>Be Quiet: <[be_quiet]>"
                        - case item:
                            # item liusts are keyed by item_name (performance)
                            - define sorted_items <[group_list].keys.alphanumeric>
                            - foreach <[sorted_items]> as:item_name:
                                - define item_list <[group_list].get[<[item_name]>]>
                                - foreach <[item_list]> as:entry:
                                    - define loc <[entry].get[t]>
                                    - narrate "-- <yellow><[item_name]> <gray>@ <green><proc[location_noworld].context[<[loc]>]>"
                        - case wildcard:
                            # Others liusts do not have an extra key
                            - foreach <[group_list]> as:entry:
                                - define item_name <[entry].get[f]>
                                - define loc <[entry].get[t]>
                                - narrate "-- <yellow><[item_name]> <gray>@ <green><proc[location_noworld].context[<[loc]>]>"
                        - case other:
                            # Overflow, not-found, etc. In any case these are NOT filtered in any way they are usually event based
                            - foreach <[group_list]> as:entry:
                                - define loc <[entry].get[t]>
                                - narrate "--  @ <green><proc[location_noworld].context[<[loc]>]>"

            #- narrate "<green>Inventory map: <[inv_map].to_json>"
            #- if <player.is_op>:
            #    - debug log "<red><[inv_map].to_json>"

        - narrate <[enable_message]>
        - stop

    - if <[command]> == clear:
        - flag <[owner]> si:!
        - narrate "<red>Inventory locations cleared for <[owner].name>"
        - narrate "<yellow>Click each sign/frame OR use /simple-inventory <[owner].name> repair"
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

    - if <[command]> == diag:
        # per Player
        - define changes false
        - define owner_name <[owner].name>
        - define diag_key si_diag
        - define log_player <server.flag[si_diag.<[owner_name]>].if_null[<list[]>]>
        - narrate "<gold>Checking diagnostic messages" targets:<[owner]>
        - foreach <[log_player]> key:world as:feeders :
            - narrate "<gold><[owner_name]> / <[world]>" targets:<[owner]>
            - foreach <[feeders]> key:feeder_loc as:status :
                - narrate "<green><[status]>" targets:<[owner]>

        - debug log "<[log_player]>"

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
            # TODO: Scan chunks async (a task) and wait for results
            # TODO: IF we can reliable get results back OR even better
            # TODO: Call back into a MAIN thread to process data then continue async
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
            - wait 2t

        - define elapsed <util.current_time_millis.sub[<[start_ticks_raw]>]>
        - narrate "<yellow>Working (chunks: <[counter]>/<[area_size]>) in <[elapsed]> ms ..."
    - narrate "<gold>Finished"


# ***
# *** Convert passed range to allowed range, Range can be a floating point value.
# ***
# *** If range is not set or 0 then defaults to script max-distance. The common case is 0 when sign range is not specified
# *** iF range is less than min (but not the above) then set to script min-distance
# *** iF range is less than min (but not the above) then set to script max=distance
# *** Else range is return as is
si__range_normalize:
  type: procedure
  debug: false
  definitions: range
  script:
    - define max_distance <proc[pl__config].context[simple-inventory.feeder.max_distance]>
    - define min_distance <proc[pl__config].context[simple-inventory.feeder.min_distance]>
    - if !<[range]>:
        - determine <[max_distance]>
    - if <[range]> <= <[min_distance]>:
        - determine <[min_distance]>
    - if <[range]> > <[max_distance]>:
        - determine <[max_distance]>
    - determine <[range]>



# === set up a default sign/frame map that is guarnteed to have minimum element smany functions
# === count on for quick checks
# - assuming I don't screw up the code
si__base_parser_result:
  type: procedure
  debug: false
  definitions: range
  script:
    - determine <map[trigger=false;chest=false;is_valid=false;is_feeder=false;is_item=false;is_overflow=false;is_unknown=false;messages=false]>


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
                - define entry <map[trigger='-9999,61,9999@nether';chest='-9999,<[value]>,9999@nether';item=false;wildcard=false;is_feeder=false;messages=<[value]>]>
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



# ESCAPE/UNESCAPE is VERY fast at 40ms oer 10,000 for a resonable
# size map.
#
# But an unreasonbale sized match, like an simple inventory flag map that is a a few KB
# is VERY SLOW:
#   4139 ms  for 10,000
# Loading it from flags 10,000 times is 115 ms
benchmark_flags:
  type: procedure
  definitions: v
  debug: false
  script:

    - define test_player <server.match_player[mrakavin]>
    #- define test_map <map[is_valid=false;is_feeder=false;is_item=false;is_overflow=false;is_unknown=false;facings=false;messages=false;items=false;wildcard=false;entity=false;range=false;be_quite=false]>
    #- define test_map <[test_player].flag[si.world]>

    # Create a temporary are to work with
    - define f <[test_player].flag[si]>
    - flag <[test_player]> si_tmp:<[f]>
    - define test_map <[test_player].flag[si_tmp.world]>


    # --- Inline addition benchmark ---
    - define start_t <util.current_time_millis>
    - define counter 0
    - repeat 1:
        # = 4161ms
        #- define e <[test_map].escaped>
        #- define t <[test_map].unescaped>

        # = 115ms
        #- define test_map <[test_player].flag[si_tmp.world]>


        # - 266ms 10,000 using flags for all work in sub-task (append / remove last)
        #- run benchmark_flag def:<[test_player]>|item.dirt|HELLO]

        # - 148ms reading flags into a list, maniuplating list but NOT saving to flag
        #- run benchmark_flag_list def:<[test_player]>|item.dirt|HELLO]

        # - 257ms to do all work (add/remove) to temp list then assign at end
        #- run benchmark_flag_list def:<[test_player]>|item.dirt|HELLO]

        # - 44ms to just FECTH the desired key from the flag, in this case 4. SHowing fetcing flag data is fast
        #- run benchmark_flag_list def:<[test_player]>|item.dirt|HELLO]
        - run benchmark_flag def:<[test_player]>|item.dirt|HELLO]


        # == Conslusion: workingd irectly with flags is not horrible slow
        # - it is still faster (within a procedure) to grab just the map you need and work it, then save
        # - DO NOT PASS any excpet the smalles lists, just use flags if possible


        - define counter:++
    - define end_t <util.current_time_millis>
    - define elapsed_t <[end_t].sub[<[start_t]>]>
    - debug log "<green>Escaped/unescaped: <[elapsed_t]> ms for <[counter]> iterations"
    #- debug log "<red>t = <[t]>"


benchmark_flag:
  type: task
  definitions: player|path|key|value
  debug: false
  script:
    #- debug log "<red>Before: <[player].flag[si_tmp.world.<[path]>]>"
    - define old <[player].flag[si_tmp.world.<[path]>]>
    - debug log "<green>Original: <[old]>"

    #- debug log "<gold>Entry: <[old]>""
    - define new <[old].get[1].with[f].as[ROCK]>
    #- debug log "<gold>Entry New: <[new]>"
    #- flag <[player]> si_tmp.world.<[path]>[1]:<[new]>  FAILS
#   - flag <[player]> si_tmp.world.<[path]>:->:<[new]>
    #- flag <[player]> si_tmp.world.<[path]>[1]:HELLO

    # WORKS: the .2 is ignored and the  path (item.dir) was SET to a map wiht key 2 = the new litem as a list
    #- flag <[player]> si_tmp.world.<[path]>[2]:<[new]>
    #- debug log "<gold>Entry changed 2: <[player].flag[si_tmp.world.<[path]>]>"


    # FAILS: the [2].f  the 'f' is ignored and everytign ends at [2]
    #- flag <[player]> si_tmp.world.<[path]>[2].f:COMPUTER
    #- debug log "<gold>Entry changed 2.f: <[player].flag[si_tmp.world.<[path]>]>"

    # FAILS: the [2].[f] - nothing changed - weird
    - flag <[player]> si_tmp.world.<[path]>[2][f]:COMPUTER
    - debug log "<gold>Entry changed [2][f]: <[player].flag[si_tmp.world.<[path]>]>"

    # WORKS: Replace item offset 2 (2nd item) (like [last])
    #- flag <[player]> si_tmp.world.<[path]>[2]:<[new]>
    #- debug log "<gold>Entry changed [2]: <[player].flag[si_tmp.world.<[path]>]>"

    # WORKS: LAST is valid with chnage
    #- flag <[player]> si_tmp.world.<[path]>[last]:->:<[new]>
    #- debug log "<gold>Entry changed [last]: <[player].flag[si_tmp.world.<[path]>]>"



    # Specific index: OK
    #- flag <[player]> si_tmp.world.<[path]>[1]:<[new]>
    # LAST ITEM OK (here we remove it) VERY COOL
    #- flag <[player]> si_tmp.world.<[path]>[last]:<-
    #- debug log "<green>After: <[player].flag[si_tmp.world.<[path]>]>"
    # Using si_tmp.world.<[path]>[f]:ROCK  : FAILED to set the f element in the map. The [f] was IGNORED

benchmark_flag_list:
  type: task
  definitions: player|path|key|value
  debug: false
  script:
    - define test_map <[player].flag[si_tmp.world.<[path]>]>
    - stop

    #- debug log "<red>Before: <[test_map]>""
    - define new <[test_map].get[1].with[f].as[ROCK]>
    - define test_map:->:<[new]>
    #- debug log "<gold>Entry: <[test_map]>"
    # LAST ITEM OK (here we remove it
    - define test_map[last]:<-
    #- debug log "<red>after: <[test_map]>"
    - flag <[player]> si_tmp.world.<[path]>:<[test_map]>


benchmark_matches:
  type: task
  definitions: source
  debug: false
  script:
    # Nice LONG match, way longer than would in actual practice
    # = RESULTS: On a list of 9 wildcards on 10 players each with 100 filters the time is approx 2-3ms (initial load may be 6ms)
    #   - "*stone|*_leaves|*wool*|apples|*_ores|!*_wood|*_ingot|*_stone|*chicken"
    #   - This is longer than I would like but its a rather excessive count
    # = Results: 5 players with 20 wildcards using a more reasonable sign, 1ms
    #   - "*stone|*_leaves|*wool*|apples|*_ores"
    # = CONCLUSION: THis seems like it should be fast enough unless players actually try to abuse the system, in which case we can
    # = limit the number of wildcard OR just abort the wild card loop and set a feeder chest diagnostic
    - define source <[source].if_null[red_chicken]>
    - define matches 0
    - define no_matches 0
    - define targets "*stone|*_leaves|*wool*|*apples|*_ores|!*_wood|*_ingot|*_stone|*chicken"

    - define start_time <util.current_time_millis>
    # Simulates player count
    - repeat 10:
        # SImulates a list size of y
        - repeat 100:
            - define match <[source].advanced_matches[<[targets]>]>
            - if <[match]>:
                - define matches:++
            - else:
                - define no_matches:++

    - define elapsed <util.current_time_millis.sub[<[start_time]>]>
    - debug log "<gold>For <[source]> : Found <[matches]>, not found <[no_matches]> in <[elapsed]> ms"

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


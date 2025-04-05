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
sign_or_frame_redirect:
  type: world
  debug: false
  events:

    # Right click on sign or item frame
    on player right clicks entity:
        # Exit as quick as possible if this event is not applicable (crouching bypasses the override)
        - if <player.is_sneaking>:
            - stop

        # If NOT an item_frame or player is sneaking then pass through normally
        - if <player.is_sneaking> || <context.entity.entity_type> != item_frame:
            - stop

        # Get the location without rounding (block/simple round) and round down so we get the REAL block
        #   * Place this string on ONE line, otherwise spaces can get added and that BREAKS the string
        - define raw_loc <context.entity.location>
        - define frame_loc <location[<[raw_loc].x.round_down>,<[raw_loc].y.round_down>,<[raw_loc].z.round_down>,<[raw_loc].world.name>]>

        # Defines the rotation of the FRAME (which is waht we want) NOT the item in the frame
        #   * rotation : Capital of direction name (NORTH)
        #   * rotation_vector: The direction vector: l@-1,0,0  (suitable for relative location math)
        #   * NOTE: THis is the direction it is facing so the opposite of the direction the PLAYER is looking at it (normally)
        #   so you need the opposite direction to get the block behind here.
        - define rotation_vector <context.entity.rotation_vector>

        # NOTE on forward/backword : THese do NOT do what you expect with item frames. For some reason
        # if the entity is facing WEST the forward/backword change the z axis (N/S). Why? No clue but item
        # frame sare insanely complicated when it comes to location.
        #
        # But .add works using relative vector combined with ,mul
        #   To get the block BEHIND the ftrame we multiple the vector by -1. This works because rotation vector is always a x,y,z with only one value set to 1 (ex: 1,0,0)
        - define attached <[frame_loc].add[<[rotation_vector].mul[-1]>]>
        - define is_allowed <proc[is_chest_like].context[<[attached]>]>

        - if <[is_allowed].not>:
            - stop

        - inventory open destination:<[attached]>
        - determine cancelled

    # Right click on sign or item frame
    on player right clicks block:
        # Exit as quick as possible if this event is not applicable (crouching bypasses the override)
        - if <player.is_sneaking>:
            - stop

        # If NOT an item_frame or player is sneaking then pass through normally
        - define block <context.location||null>
        - if !<[block]>:
            - stop

        - define block_name <[block].block.material.name>
        - if <[block_name].ends_with[_sign].not>:
            - stop

        # Signs re SO much simpler than frames, so optimize for signs (bug backward/forward still seem weird, and not reliable)
        - define facing <[block].block_facing>
        # This is NOT just attached blocks but also blocks behind the sign. Oh well, filter this out proved annoying so allow it
        - define attached <context.location.block.relative[<[facing].mul[-1]>]>
        - define is_allowed <proc[is_chest_like].context[<[attached]>]>
        - if <[is_allowed].not>:
            - stop

        - inventory open destination:<[attached]>
        - determine cancelled


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

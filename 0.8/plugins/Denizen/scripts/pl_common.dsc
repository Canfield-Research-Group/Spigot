# Return all players online or off
get_all_players:
  type: procedure
  debug: false
  script:

  - define all_players <server.offline_players>
  - define all_players <[all_players].include[<server.online_players>]>
  - determine <[all_players]>


# ***
# *** See if trigger is a chest like object. Not a furance. This is a whitelist
# *** so is NOT ideal. It was designed for use by simple_inventory which should
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
    # We could combine the defines into a single line as possible -- or not. Denizen can screw that up in parsing 
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

# ***
# *** Simple open chest call used with the following to prevent double events  (like click entoty) from
# *** actually opening the chest twice:
# ***       - run open_chest_gui def:<player>|<[chest]> delay:1t
open_chest_gui:
  type: task
  definitions: player|chest
  debug: false
  script:
    # If chest is open avoid opening again. Inventory objects contain location data but are not directlry
    # comapriable. We need to make sure both are inventory.
    # This compexlity is not absiliyte;y needed, we culd just open the chest twice. But that could cause
    # other plugins to fail, or the gui the be glicthy asn it woudl send two chest open events. So
    # keep things clean
    - if <[player].open_inventory> != <[chest].inventory>:
        - inventory open destination:<[chest]>



# ****
# **** Find all weird flags (usually a result of bugs in quoting) and remove them
# ****
# **** WARNING: This is a utility function, and should be used only in a debug mode
# ****
# **** USAGE from Seerv Console:
# ****      ex run debug_cleanup_malformed_flags def:player=p@mrakavin
# *****
debug_cleanup_malformed_flags:
  type: task
  debug: false
  definitions: player
  script:
    # There should be a way to loop on flags without list_flags, but I cannot find it
    - foreach <[player].list_flags> as:flagname:
        # ESCAPE the flag so it can be properly tested
        - debug log "<green><[flagname]>"
        # Escape this data so it is not interoplated in more a complex  usage
        - define rawflag <[flagname].escaped>
        # contains_text is a object related operation (not ... CONTAINS ...)
        - if <[rawflag].contains_text[lt]> || <[rawflag].contains_text[lb]>:
            - debug log "<red>Removing malformed flag for user <[player]>: <[flagname]>"
            # Unescape INLINE to avoid quoting
            - flag <[player]> <[rawflag].unescaped>:!

# ***
# *** Is powered?
# *** Returns power level for block. If block is a double block, like a chest, returns
# *** The (max) power level of the blocks.
# ***
powerlevel_blocks:
  type: procedure
  debug: false
  definitions: block
  script:
    #  Use fallbacks is usually faster than lots of checks
    - define other_block <[block].other_block.if_null[<[block]>]>
    - determine <[block].power.if_null[0].max[<[other_block].power.if_null[0]>]>

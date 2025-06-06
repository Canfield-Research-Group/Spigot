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
  debug: false
  script:
    # We could combine the defines into a single line as possible -- or not. Denizen can screw that up in parsing 
    # There does not appear to be an .is[location]
    - define loc_obj <[loc].as[location].if_null[loc_obj]>
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


# ***
# *** should_run_this_tick
# *** Returns true if the current server tick matches this location's tick group.
# ***
# *** NOTE: This uses millis as that is more random than ticks (with are every 50ms)
# ***
# *** Spreads work across ticks by hashing the X/Y/Z of a LocationTag and comparing
# *** the result against the current tick modulo group size.
# ***
# *** PARAMETERS:
# *** location     - A LocationTag (must include world)
# *** group_size   - Number of ticks over which to spread processing (e.g., 8)
# *** current_tick - Pass a current tick (suaully an incrementing value tracked via a flag). This is the most fair
# ***               since wait operastions tend to allign on ms boundries there is a tendency to have mod to result in non-random distribution
# ***
# *** RETURNS:
# *** true or false (Boolean) — true if this tick is the correct one for this location
# ***
# *** EXAMPLE:
# *** - if <proc[should_run_this_tick].context[<[location]>|8]>:
# ***     - ... process logic
# ***
should_run_this_tick:
  type: procedure
  definitions: location|group_size|current_tick
  debug: false
  script:
    - define x <[location].x.round>
    - define y <[location].y.round>
    - define z <[location].z.round>
    - define hash <[x].mul[31].add[<[y].mul[13]>].add[<[z].mul[7]>].abs>
    - define tick_group <[hash].mod[<[group_size]>]>
    - define current_tick <[current_tick]||<util.current_time_millis>>
    - determine <[tick_group].is[==].to[<[current_tick].mod[<[group_size]>]>]>

# ***
# *** Given a radius in blocks of a cubid calculate a spherical radius
# *** that will cover that block. Use this when you want to a apply a
# *** rough limit (for gameplay or performance) but also want players
# *** to have easier way to identify distance.
# ***
# *** See also Manhatten and Chebyshev methods but they are not suitable
# *** for cmapritive distances such as nearest sorting.
# ***   - This provides an approx 57% greater range assumign a 160 block diameter
# ***
# *** Alterative: See if target block is in a cuboid centered on source
# *** if os then use normal elcudian distance (per Denzien distance)
sphercial_range_for_cube:
  type: procedure
  definitions: cube_diameter
  debug: false
  script:

  # Half of each dimension (assuming center point origin)
  - define dx <[cube_diameter].div[2]>
  - define dz <[cube_diameter].div[2]>

  # Compute max spherical radius (Pythagorean)
  - define max_radius <[dx].mul[<[dx]>].add[<[dz].mul[<[dz]>]>].sqrt.round_up>
  - determine max_radius


# ***
# *** BUild a cuboid around a location
# ***
# *** Use this to verify if the block is in the cubiod and only if it
# *** use calculate distance. This provides a CUBE check and a REAL distance check.
# *** In some cases users may find that more comfortable since it is easier to
# *** visualize a cube ox X size in mincraft than a sphere of X size
# ***
# *** Check target
# ***   - define bounds <proc[create_cuboid_from_location].context[<[source_chest].location.block>]>|<[max_distance]>]>
# ***   - if <[bounds].contains[<[target_location]>]>:
# ***     - define distance <[center].distance[<[target_location]>]>

create_cuboid_from_location:
  type: procedure
  definitions: location|cube_size
  debug: false
  script:

    # Round to block cordinates, more predicability
    - define center <[location].block>

    - define min_loc <[center].sub[<[cube_size]>,<[cube_size]>,<[cube_size]>]>
    - define max_loc <[center].add[<[cube_size]>,<[cube_size]>,<[cube_size]>]>
    - define bounds <[min_loc].to_cuboid[<[max_loc]>]>
    - determine <[bounds]>


# ***
# *** cuboid_distance_from_center
# ***
# *** Given a cuboid and a location, determines the Euclidean distance
# *** from the center of the cuboid to the target location.
# *** Returns -1 if the location is outside the cuboid.
# ***
# *** Optionally (RECOMENDED) give your own center location. If not provided
# *** the cuboid center is used. That may not be exactly what you due to
# *** some internal cunboid rounding and, more critically, the y (height)
# *** flooring that is done. It will nto allow world boundries to be exceeded
# *** so the veriical center is often lost from what was original used to create the cuboid.
# ***
# *** Useful for accurate nearest-target sorting with a cubic limit for user clarity.
# ***
cuboid_distance_from_center:
  type: procedure
  definitions: bounds|target_location|center_location
  debug: false
  script:
    - if <[bounds].contains[<[target_location]>]>:
        - define center <[center_location].if_null[<[bounds].center>]>
        - determine <[center].distance[<[target_location]>]>
    - determine -1


# ***
# *** Narrate the list to the player, optionally prefixes each output with the color
# *** does nothign if ist is empty.
# ***
# *** list : A line of text, a list, or (RECOMENDED an escaped list/text
# *** color : Color to use as default for each line, do not pass or use false-like for no special color
# *** player : Player object, defaults to current player
narrate_list:
  type: task
  definitions: list|color|player
  debug: false
  script:
    - if <[list].is_truthy>:
      - define list <[list].unescaped>
      - if <[list].object_type> != list:
        - define list <[list].as[list]>

      - if <[list].is_empty.not>:
        # Use current player if player not passed
        - define target_player <[player]||<player>>
        # Default color to empty if not passed
        - define use_color <[color]||"">

        - foreach <[list]> as:line:
            - narrate <[use_color]><[line]> targets:<[target_player]>





# === Get current points for a player (round down)
xp_points_of_player:
  type: procedure
  debug: false
  definitions: player
  script:
    # Level to lowest integer (floor)
    - define level <[player].xp_level>
    # Get amount of XP the player has to the next level
    - define progress <[player].xp>
    # Number of XP required to reach next level
    - define to_next <[player].xp_to_next_level>
    # Convert level to XP
    - define base_xp <proc[xp_points_for_level].context[<[level].round_down>]>

    - define extra_xp <[progress].div[100].mul[<[to_next]>]>
    - define total_xp <[base_xp].add[<[extra_xp]>]>
    - determine <[total_xp].round_down>



# === Get points for a specific level. This forces whole number levels only (round down)
# Best used to identify how many points a cost of 5 levels means without regard to current players level.
xp_points_for_level:
  type: procedure
  debug: false
  definitions: level
  script:
    - define level <[level].round_down>
    - if <[level].is_less_than_or_equal_to[16]>:
      - define base_xp <[level].mul[<[level]>].add[<[level].mul[6]>]>
    - else :
      - if <[level].is_less_than_or_equal_to[31]>:
          - define base_xp <[level].mul[2.5].mul[<[level]>].sub[<[level].mul[40.5]>].add[360]>
      - else:
        - define base_xp <[level].mul[4.5].mul[<[level]>].sub[<[level].mul[162.5]>].add[2220]>

    # Not all callers can handle fractional amounts (points)
    - determine <[base_xp].round>

# === Procedure: Get level from XP points (rounded up to 1 decimal place)
# Uses iterative way to locate level, which is probably fine, likley fast enough for anything except extreme levels
# Craeted for use in HELP to express XP costs for tasks using XP points in a way more familier to players
xp_level_from_points:
  type: procedure
  debug: false
  definitions: xp_points
  script:
  - define xp <[xp_points]||0>
  - define level 0
  - while <[xp].is_more_than_or_equal_to[0]>:
      - define next_level <[level].add[1]>
      - define xp_for_next <proc[xp_points_for_level].context[<[next_level]>]>
      - if <[xp].is_less_than[<[xp_for_next]>]>:
          - define xp_for_current <proc[xp_points_for_level].context[<[level]>]>
          - define level_fraction <[xp].sub[<[xp_for_current]>].div[<[xp_for_next].sub[<[xp_for_current]>]>]>
          - define result <[level].add[<[level_fraction]>]>
          - determine <[result].mul[10].round.div[10]>
      - define level <[next_level]>
  - determine <[level]>


# === process a queue name and return a normalized return result
# - run_queue : USAGE
#   - ~run helpers_find_nearest_working_area def.location:<context.entity.location> save:<[sid]>
#   - define results <proc[queue_parse].context[<entry[<[sid]>].created_queue.determination||false>]>
# - Returns
#   - false : Invalid queue received or parsed
#   - MAP
#     - cancelled=false | true # always set for a map
#     - then key:value based on one or more `determine key:value`
queue_parse:
  type: procedure
  debug: false
  definitions: run_queue
  script:
    - if <[run_queue]>:
      - define result <map[cancelled=false]>
      - foreach <[run_queue]> as:command key:key_specified:
        - if <[command]> == cancelled:
          - define result <[result].with[cancelled].as[true]>
        - else:
          # Sometimes extra is set to extra
          - if <[key_specified]||false>:
            - define result <[result].with[<[key_specified]>].as[<[command]>]>
          - else:
            # if there is no delimiter return the entire string
            - define key <[command].before[:]>
            # if there is no delimiter return a blank
            - define value <[command].after[:]>
            - define result <[result].with[<[key]>].as[<[value]>]>
      - determine <[result]>
    - else:
      - determine false

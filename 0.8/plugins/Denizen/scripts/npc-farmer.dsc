# WIP EXPERIMETNAL

# Farmer for Denizen/Citizen2
# Mostly AI example
#
# Versions:
#   latest as of 2025-04-29 is and FAILS in MC 1.21.4 : Citizens-2.0.38-b3786.jar 
#   Identified version based on Spigot uplaod date (which is paid): Citizens-2.0.38-b3781.jat (2025-04-14 09:00:57)
#
# Working
#   - harvest crops in an area (not dynamic)
#   - moves looks, etc, but not graceful
#   - moves items from inventory to chest (dynamically found on composter)
#   - currently FREE
#
# TODO:
#   - detect a villager touching beocming a farmer and if composter has a frame with a hoe remove and change to NPC Farmer
#     - See if we can keep villagers clothing
#   - range : scan for a plantable block types (a whitelist) around composter
#           - NSEW
#           - Upon finding first non plantable NON water STOP
#           - Create a cuboid of this area
#

# USAGE:
#  /npc create TestFarmer --type player
#  /npc select (click the NPC)
#  /npc assignment --set farmer_brain


# MOSTLY for admins, reset flag when farmer respawns
farmer_teleport_reset:
  type: world
  debug: false
  events:
    # === THIS DOES NOT WORK
    on entity teleports:
    - if false:
      - debug log  "<gold>AFTER TELEPORT"
      - if <context.entity.is_npc>:
        - define assignments <context.entityt.scripts>
        - debug log  "<gold>Assignments: <[assignments]>"
        - if <[assignments].contains[farmer_brain]>:
          - debug log "<red>Farmer teleported, resetting farm location."
          - flag npc farmer_home:<context.entity.location>


farmer_brain:
  type: assignment
  debug: false
  actions:
    # Use this to structure to make sure the NPCs resume on server start
    on spawn:
      - flag npc farmer_home:<npc.location>
      - run farmer_ai_task delay:5s

    on assignment:
      - flag npc farmer_spawn:<npc.location>

      # Trigger reset
      - flag npc base_loc:null

      - trigger name:click state:true
      - trigger name:proximity state:true
      - run farmer_ai_task delay:5s

    on click:
      - if <player.item_in_hand.material.name> != lead:
          - stop
      - if <npc.has_flag[leashed]>:
          - narrate "<green><npc.name> released!"
          - flag npc leashed:!
          - stop
      - flag npc leashed:<player>
      - narrate "<yellow><npc.name> following"


farmer_ai_task:
  type: task
  debug: false
  script:

    # If despawned stop script
    - if <npc.is_spawned.not>:
      - stop

    # TODO: Add to configs
    # How many blocks to search around Farmer (radius) for a valid copomster/chest, nearest wins
    - define max_home_search 16
    # Valid chests
    - define valid_chests barrel|chest|trapped_chest|*_shulker_box
    # Valid crops the farm will harvest
    - define valid_crops carrots|potatoes|wheat|beatroots|nether_wart
    - define wait_time 2s


    # - Simulate LEASH
    - if <npc.has_flag[leashed]>:
      # Force a re-evaluation of the farm
      - debug log "<green><npc.name>  is Following"
      - flag npc base_loc:null
      - ~run leash_follow_task
      # This task runs much quicker so NPC keeps up
      - run farmer_ai_task id:farmer_ai_<npc.id> delay:10t
      - stop

    # Check if the environment is Sane for this farmer
    #   TIP: if any of these become null then all are invalid. Bets practice is to clear the base_loc to be forward compatible
    - define base_loc <npc.flag[base_loc]||null>
    - define chest_loc <npc.flag[chest_loc]||null>
    - define farm_area <npc.flag[farm_area]||null>

    # - Performance is not an issue here, since the script has extensive pauses

    # Identify if the farmer home has been identified
    - if <[base_loc]> == null or <[chest_loc]> == null or <[farm_area]> == null:
      - define base_loc_tmp null
      - define chest_loc_tmp  null
      - define farm_area_tmp null

      - define composters <npc.location.find_blocks[composter].within[<[max_home_search]>]>
      - debug log "<aqua>CALC FARM: <[composters]>"
      - if <[composters].size> > 0:
        - define base_loc_tmp <[composters].get[1]>
        # See if there is a chest on it
        - define chest_loc_tmp <[base_loc_tmp].add[0,1,0]>
        - if <[chest_loc_tmp].material.name.advanced_matches[<[valid_chests]>]>:
          # Identify farm area, for performance we stick with a cuboid
          # Scan NSEW to identify farm. Just get close enough, players can
          # craft impossible farms, in which case they will not work very well.
          - define farm_area <proc[farm_find_bounds_fast].context[<[base_loc_tmp]>]>
          - define blocks <[farm_area].blocks>
          - define base_loc <[base_loc_tmp]>
          - define chest_loc  <[chest_loc_tmp]>
          - debug log "<gold> C: <[chest_loc]> -- B: <[base_loc]> -- F: <[farm_area]>"


      - flag npc base_loc:<[base_loc]>
      - flag npc chest_loc:<[chest_loc]>
      - flag npc farm_area:<[farm_area]>
    - else:
      # If environment is NOT valid then clear elements
      - if <[base_loc].material.name> != composter or <[chest_loc].material.name.advanced_matches[<[valid_chests]>].not>:
        - debug log "<aqua>**** Farm BROKE, waiting for it to be fixed"
        - flag npc base_loc:null
        - run farmer_ai_task id:farmer_ai_<npc.id> delay:<[wait_time]>
        - stop

    - if <[base_loc]>  == null:
        # Set animation over villager
        - debug log "<red>Farm broken, please fix"
        - define effect_loc <npc.location.add[0,.5,0]>
        - playeffect <[effect_loc]> effect:angry_villager quantity:1 offset:0.1,0.1,0.1 visibility:10

        - flag npc "log:Cannot find composter with chest on top""
        - run farmer_ai_task id:farmer_ai_<npc.id> delay:<[wait_time]>
        - stop

    # - Set associated cuboids
    # Drop area is one below cuboid (items site on TOP of a block so you need to look at the block one below you expect to, or so it seems)
    - define drop_area <[farm_area].expand_one_side[0,-1,0].shrink_one_side[0,1,0]>


    # - Check for HOE pickup
    # See if Farmer can find a hoe and equip it, once grabbed the hoe
    # is forver the Farmer, by design. A new hoe replaces CURRENT
    - define hoes <[drop_area].entities[item]>
    - foreach <[hoes]> as:hoe :
      # Pick up the hoe
      - define hoe_item <[hoe].item>
      - define hoe_loc <[hoe].location>
      - look <npc> <[hoe_loc]>
      - ~walk <npc> <[hoe_loc]> speed:1 auto_range
      # Check hoe near it to make the mesage clearer
      - if <[hoe_item].enchantment_map.is_empty.not>:
        - adjust <npc> "name:<yellow>I can't use enchanted items"
        - run farmer_ai_task id:farmer_ai_<npc.id> delay:<[wait_time]>
        - stop

      # Remove any existing hoes, they are instantly consumed
      - define existing_hoes <npc.inventory.list_contents.filter_tag[<[filter_value].material.name.advanced_matches[*_hoe]>]>
      - debug log "<yellow>Existing: <[existing_hoes]>"
      - foreach <[existing_hoes]> as:item :
        - debug log "<red>Dropping old HOE"
        - take item:<[item]> from:<npc.inventory>

      # Transfer hoe from ground to the NPC
      - equip <npc> hand:<[hoe_item]>
      - remove <[hoe]>
      - adjust <npc> "name:<yellow>Thank you!"
      - run farmer_ai_task id:farmer_ai_<npc.id> delay:<[wait_time]>
      - stop

    # - Check for NPC inventory needing emptying
    # Check if farmer needs to add to the chest, and if full add animation
    - if <npc.inventory.quantity_item> > 32:
        - debug log "<red>INV full, unloading"
        - ~run farmer_deliver_task
        # If after transfering items the farm still does not have an empty slow then we assume they are full
        # and the chest is full. Since tasks do NOT return (easily) a value this seems the fastest way
        - if <npc.inventory.empty_slots> == 0:
          # Set animation over chest location
          - define effect_loc <[chest_loc].add[.5,0,.5]>
          - playeffect <[effect_loc]> effect:angry_villager quantity:1 offset:0.25,0.5,0.25 visibility:10
          - flag npc "log:Farmer inventory is full"
          - run farmer_ai_task id:farmer_ai_<npc.id> delay:<[wait_time]>
          - stop

    # Clear log
    - flag npc log:null

    - if <npc.inventory.contains_item[*_hoe].not>:
      - adjust <npc> "name:<yellow>Please drop me a hoe"
      - run farmer_ai_task id:farmer_ai_<npc.id> delay:<[wait_time]>
      - stop


    # - Process Harvesting
    - define harvested false
    - adjust <npc> "name:<yellow>Farmning ..."
    - if <npc.inventory.contains_item[*_hoe]>:
      # Check inventory
      - define crops <[farm_area].blocks[<[valid_crops]>]>
      # .within[<[search_radius]>].filter_tag[<[filter_value].material.age.is[or_more].than[<[crop_max_age]>]>]>
      - if <[crops].size>:
          - define crop <[crops].get[1]>
          - if <[crop].material.age.is[or_more].than[<[crop].material.maximum_age>]>:
            - break <[crop]> <npc>
            # In theory this could pick up a hoe (or anything) but that's fine since we look in inventory
            # for any NPC items instead o using flags.
            - define nearby_items <npc.location.find_entities[item].within[2]>
            - foreach <[nearby_items]> as:item:
              - debug log "<gold>Gave NPC <[item]>"
              - give item:<[item].item> to:<npc.inventory>
              - remove <[item]>
            # Plant with what was originally there
            - modifyblock <[crop].location> <[crop].material.name>
            - define harvested true
            - if false:
              - ~walk <npc> <[crop]> speed:1 auto_range
              - if <npc.location.sub[0,1,0].block> != <[crop].block>:
                - adjust <npc> "name:<red>I am Stuck!"
                #- debug log "<red>Farmer cannot reach <[crop].block>"
                #- flag npc "log:Farmer cannot reach: <[crop].block>"
                - define effect_loc <npc.location.add[.5,.25,.5]>
                - playeffect <[effect_loc]> effect:angry_villager quantity:3 offset:0.1,0.1,0.1 visibility:10
              - else:
                # - HARVEST, use normal break and pick up items that dropped
                - define look_target <[crop].add[0,.25,0]>
                - look <npc> <[look_target]>
                - ~run farmer_harvest_task def:<[crop]>|<[crop_type]>
                - define harvested true

    - if <[harvested].not>:
        # Wander a bit between harvesting
        - run farmer_wander_task instantly

    # Run each NPC in it's own queue
    # NOTE: AVOID WHILE Loops or any long lived loop as the script here can be tied to the NPC
    # and surive reloads, spawn, despawn. The only way to stop it is to remove the npc
    - run farmer_ai_task id:farmer_ai_<npc.id> delay:<[wait_time]>


farmer_harvest_task:
  type: task
  debug: false
  definitions: location|crop_type
  script:
    - define loc <[location]>
    - define crop <[crop_type]>
    - animate <npc> animation:swing_main_hand
    - modifyblock <[loc]> air
    - wait .5
    - modifyblock <[loc]> <[crop]>
    # Normal carrots is 1 to 4 but 1 is always used for planting
    # Block name for a crop and it's inventory name are often different
    - choose <[crop_type]>:
      - case carrots:
        - define item carrot
      - case potatoes:
        - define item potatoe
      - default:
        - define item <[crop_type]>

    - define count <util.random.int[1].to[3]>
    - give item:<[item]> quantity:<[count]> to:<npc.inventory>


farmer_deliver_task:
  type: task
  debug: false
  script:
    - define home <npc.flag[farmer_home]>
    - define chestloc <[home].find_blocks[chest].within[5].random>
    - if <[chestloc].exists.not>:
        - debug log "<red>No chest found!"
        - stop

    - define look_target <[chestloc].add[0,0,0]>
    - look <npc> <[look_target]>
    - ~walk <npc> <[chestloc]> speed:1 auto_range

    - define chest <[chestloc].inventory>

    # Skip air and hoe, unload all the rest
    - define items <npc.inventory.list_contents.filter_tag[<[filter_value].material.name.advanced_matches[air|*_hoe].not>]>
    - foreach <[items]> as:item:
      # Simpel quick check for space available, if not then just stop
      - define space_available <[chest].can_fit[<[item]>]>
      - if <[space_available].not>:
        # Place animation over chest
        - stop


      # Inventory sucks -- to avoid ghost items we move by name, it's easier but cannot reliable move
      # special items. Which we do not have.
      # TODO: Consider splitting simple-inventory feeder mover into a procedure, it is a lot more sophisticated
      - take item:<[item].material.name> from:<npc.inventory> quantity:<[item].quantity>
      - give item:<[item].material.name> to:<[chest]> quantity:<[item].quantity>

    - wait 0.25s
    - playsound block.chest.close <[chestloc]>


farmer_wander_task:
  type: task
  debug: false
  script:
    - define farm_area <npc.flag[farm_area]>
    - define wander_loc <[farm_area].random>

    # BUG: IN Denizen if lootat and target are the same the NPC ZOOMS to the target, even when walk speed is 0.5
    # Apparently this is a citizen's thing?????
    # The fix is to look THEN move
    - define look_target <[wander_loc].add[0,.5,0]>
    - look <npc> <[look_target]>
    # To reduce loads only move 1/4 of the time
    - if <util.random_chance[25]>:
      - walk <npc> <[wander_loc]> speed:1 auto_range



# - Give an origin identify boundries of a farm based on PLANTED crops
# - of any mix.
farm_find_bounds_fast:
  type: procedure
  debug: false
  definitions: origin
  script:
    # Relative cordinates for each axis
    - define world <[origin].world.name>
    - define north <proc[scan_direction].context[<[origin]>|<location[0,0,-1]>]>
    - define south <proc[scan_direction].context[<[origin]>|<location[0,0,1]>]>
    - define west <proc[scan_direction].context[<[origin]>|<location[-1,0,0]>]>
    - define east <proc[scan_direction].context[<[origin]>|<location[1,0,0]>]>

    #- debug log "<red>N: <[north]>, S: <[south]>, W: <[west]>, E: <[east]> -- <[origin]>"

    - define corner1 <location[<[west].x>,<[origin].y.sub[0]>,<[south].z>,<[world]>]>
    - define corner2 <location[<[east].x>,<[origin].y.add[0]>,<[north].z>,<[world]>]>

    - determine <[corner1].to_cuboid[<[corner2]>]>


scan_direction:
  type: procedure
  debug: false
  definitions: origin|delta
  script:
    - debug log "<green>FIND BOUNDS: <[origin]> ----- <[delta]>"

    # TODO: move to configuration
    - define valid_farm <list[carrots|potatoes|wheat|beetroots|nether_wart]>
    - define max_dist 32

    # Add composter, we ignore thse
    - define valid_farm:->:composter

    - define scan_loc <[origin]>
    - define found_loc <[origin]>
    - repeat <[max_dist]> as:step:
      - define scan_loc <[scan_loc].add[<[delta]>]>
      - define mat <[scan_loc].material.name>
      - if <[valid_farm].contains[<[mat]>].not>:
        - define block_below <[scan_loc].below>
        # Not all blocks can be waterlogged, and if theyc annot be then Denizen will toss an exception, so catch that
        # Probably faster than checking if it can or cannot be waterlogged.
        - if <[block_below].material.name> != water and <[block_below].material.waterlogged.if_null[false].not>:
          # Invalid block found
          - determine <[found_loc]>
      - define found_loc <[scan_loc]>

    # Reached maximum distance
    - determine <[found_loc]>


leash_follow_task:
  type: task
  debug: false
  script:
  - define leash_holder <npc.flag[leashed]||null>
  - if <[leash_holder]> == null or <[leash_holder].is_online.not> or <[leash_holder].item_in_hand.material.name> != lead:
    - narrate "<green><npc.name> Released, lead dropped or player off line."
    - flag npc leashed:!
    - stop

  - if <util.current_tick.mod[5]> == 0:
    - playeffect <npc.location.add[0,1,0]> effect:heart quantity:3 visibility:10 offset:0.1,0.1,0.1

  - if <npc.location.distance[<[leash_holder].location>].is[or_more].to[2]>:
    - walk <npc> <[leash_holder].location> auto_range speed:1


# WIP EXPERIMETNAL

# Farmer for Denizen/Citizen2
# Mostly AI example
#
# Versions:
#   latest as of 2025-04-29 is and FAILS in MC 1.21.4 : Citizens-2.0.38-b3786.jar 
#   Identified version based on Spigot uplaod date (which is paid): Citizens-2.0.38-b3781.jat (2025-04-14 09:00:57)
#
# Working
#
# Todo:
# - harvest broken but was working
# - using NAME as status works well
# - hoe pickup logic working
# - finds farm area
# - leash/follow working but needs testing
# - TODO: Break /pickup logic not working (new)
# - TODO: Villager to Famer logic
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

      # - Cause other scripts for this NPC to stop. Any script in an infinite loop OR uses 'RUN' to recycle needs to
      # - monitor this flag. Normally just the keep-alive controller needs to do so
      # Tell all controllers or other NPC scripts to NOT recucle or to exit if in long loops
      #  Wait a second or two for the other tasks to stop, then clear flag and spin up again
      # - Change this to a monitor for queus runing with controller name, which is complicated
      - flag npc reset:true
      - wait 5s
      - flag npc reset:!

      - run farmer_ai_controller


    on click:
      - if <player.item_in_hand.material.name> != lead:
          - stop
      - if <npc.has_flag[leashed]>:
          - narrate "<green><npc.name> released!"
          - flag npc leashed:!
          - stop
      - flag npc leashed:<player>
      - narrate "<yellow><npc.name> following"



farmer_ai_controller:
  type: task
  debug: false
  script:
    # If despawned stop script
    - if <npc.is_spawned.not>:
      - stop

   # Used to close out any running controllers, usually called by assignment
    - if <npc.has_flag[reset]>:
      - stop

    - define wait_time  <proc[pl__config].context[farmer.wait_time]>


    - define queue_id farmer_ai_task<npc.id>
    #- if <server.queues.filter[id.is[==].to[<[queue_id]>]]>.is_empty>:
    - define queues <util.queues>
    #- debug log "<green>Queues: <[queues]>"
    #- foreach <[queues]> as:q :
    #  - debug log "<yellow>Calc ID: <[queue_id]>"
    #  - debug log "<yellow>ID: <[q].id>"
    #- debug log "<gold>RUNING"
    #
    - ~run farmer_ai_task id:<[queue_id]> save:farm_ai_controller

    # SEE: Queues : https://meta.denizenscript.com/Docs/Search/queuetag[]
    # - Parse determine results, not there may a cancel command present, we just ignore anything we do not
    # - care about.
    - define queue <entry[farm_ai_controller].created_queue.determination||list[]>
    - define delay <[wait_time]>
    - foreach <[queue]> as:command :
      - define option <[command].before[:]>
      - define value <[command].after[:]>
      - if <[option]> == delay:
        - debug log "<red>Returned delay time: <[value]>"
        - define delay <[value]>

    - run farmer_ai_controller id:farmer_ai_controller<npc.id> delay:<[delay]>
    - stop


farmer_ai_task:
  type: task
  debug: false
  script:

    # How many blocks to search around Farmer (radius) for a valid copomster/chest, nearest wins
    - define max_home_search <proc[pl__config].context[farmer.max_home_search]>
    # Valid chests
    - define valid_chests <proc[pl__config].context[farmer.valid_chests]>
    # Valid crops the farm will harvest
    - define valid_crops <proc[pl__config].context[farmer.valid_crops]>


    # - Simulate LEASH
    - if <npc.has_flag[leashed]>:
      # Force a re-evaluation of the farm
      - debug log "<green><npc.name>  is Following"
      - flag npc base_loc:null
      - ~run leash_follow_task
      # This task runs much quicker so NPC keeps up
      - determine delay:10t
      - stop

    # Check if the environment is Sane for this farmer
    #   TIP: if any of these become null then all are invalid. Bets practice is to clear the base_loc to be forward compatible
    - define base_loc <npc.flag[base_loc]||null>
    - define chest_loc <npc.flag[chest_loc]||null>
    - define farm_area <npc.flag[farm_area]||null>

    # - Performance is not an issue here, since the script has extensive pauses
    # Identify if the farmer home has been identified
    - if <[base_loc]> == null or <[chest_loc]> == null or <[farm_area]> == null:
      - debug log "<aqua>NULL"
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
          - define farm_size <[farm_area].volume>
          - if <[farm_size]> < 9:
            - ~run message_scrolling_status def:farm_to_small
            - determine delay:4s

          - define base_loc <[base_loc_tmp]>
          - define chest_loc  <[chest_loc_tmp]>
          - debug log "<gold> C: <[chest_loc]> -- B: <[base_loc]> -- F: <[farm_area]>"


      - flag npc base_loc:<[base_loc]>
      - flag npc chest_loc:<[chest_loc]>
      - flag npc farm_area:<[farm_area]>
    - else:
      # If environment is NOT valid then clear elements
      - if <[base_loc].material.name> != composter or <[chest_loc].material.name.advanced_matches[<[valid_chests]>].not>:
        - define base_loc null
        - flag npc base_loc:null

    # Catch all
    - if <[base_loc]>  == null:
      - ~run message_scrolling_status def:farm_broken
      - determine delay:4s


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
      - if <[hoe_item].material.name.advanced_matches[*_hoe].not>:
        - foreach next

      - define hoe_loc <[hoe].location>
      - look <npc> <[hoe_loc]>
      - ~walk <npc> <[hoe_loc]> speed:1 auto_range
      # Check hoe near it to make the mesage clearer
      - if <[hoe_item].enchantment_map.is_empty.not>:
        - ~run message_scrolling_status def:invalid_item
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
      - ~run message_scrolling_status def:thank_you
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
          - stop

    # Clear log
    - flag npc log:null

    - if <npc.inventory.contains_item[*_hoe].not>:
      - ~run message_scrolling_status def:need_item
      - stop

    # - Process Harvesting
    - define harvested false
    - ~run message_scrolling_status def:farming
    - if <npc.inventory.contains_item[*_hoe]>:
      # Check inventory
      - define crop_list <[farm_area].blocks[<[valid_crops]>]>

      # TIP: We cannot easily prefilter since different crops have different maximum mages, so we scan it ...
      # .within[<[search_radius]>].filter_tag[<[filter_value].material.age.is[or_more].than[<[crop_max_age]>]>]>
      - if <[crop_list].size>:
          # Randomize list to be a bit more fun an alive
          - define crop_list <[crop_list].random[<[crop_list].size>]>
          - foreach <[crop_list]> as:crop :
            #- debug log "<red>NPC Sees GROWN crops <[crop].material.name> -- <[crop].material.age> -- <[crop].material.maximum_age> -- <[crop]>"
            - if <[crop].material.age.is[or_more].than[<[crop].material.maximum_age>]>:
              #- debug log "<red>Crop: <[crop]> -- <[farm_area]>"
              - ~walk <npc> <[crop]> speed:1 auto_range
              # using distance sqared means we need to 2x the allowed distance, so within 2 means gt 4
              - if <npc.location.distance_squared[<[crop]>].is[more].to[4]>:
                - adjust <npc> "name:<red>I am Stuck!"
                - define effect_loc <npc.location.add[.5,.25,.5]>
                - playeffect <[effect_loc]> effect:angry_villager quantity:3 offset:0.1,0.1,0.1 visibility:10

              #- debug log "<yellow>Breaking <[crop]>"
              - define prior_crop <[crop].material.name>
              - break <[crop]> <npc>
              # Need to wait a tick for item to pop into the world reliably, but for athetics we wait a bit longer
              - wait 10t
              # In theory this could pick up a hoe (or anything) but that's fine since we look in inventory
              # for any NPC items instead o using flags.
              - define nearby_items <npc.location.find_entities[item].within[3]>
              #- debug log "<red>Drops: <[nearby_items]>"
              - foreach <[nearby_items]> as:item:
                #- debug log "<gold>Gave NPC <[item]>"
                - give item:<[item].item> to:<npc.inventory>
                - remove <[item]>
              # Plant with what was originally there
              #- debug log "<gold>Replant <[prior_crop]>"
              # TODO: Currenlty this does not cost a seed/item to avoid a matrix table of what plants are needed for what.
              #  - I will probably leave this as a bonus since you cannot get enchanted elements and it avoids all kinds
              #  - of inventory reserves and that matrix table I am too lazy to build and maintain
              #       - Remember, the farmer will n REPLANT, they will never plant from scratch.
              - modifyblock <[crop]> <[prior_crop]>
              - define harvested true
              # Only one harvested block per AI run
              - foreach stop


    - if <[harvested].not>:
        # Wander a bit between harvesting
        - run farmer_wander_task instantly

    # Run each NPC in it's own queue
    # NOTE: AVOID WHILE Loops or any long lived loop as the script here can be tied to the NPC
    # and surive reloads, spawn, despawn. The only way to stop it is to remove the npc
    - stop



# - Delivery items from NPC to chest
farmer_deliver_task:
  type: task
  debug: false
  script:
    - define chest_loc <npc.flag[chest_loc]||null>
    - define look_target <[chest_loc].add[0,0,0]>
    - look <npc> <[look_target]>
    - ~walk <npc> <[chest_loc]> speed:1 auto_range

    - define chest <[chest_loc].inventory>

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
    - playsound block.chest.close <[chest_loc]>


# - Famer wanders a bit randomly, turning head looking around and occasionally walking. Simplistic but works
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
    - if <util.random_chance[15]>:
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

    #- debug log "<red>Corner 1: <[corner1]>, 2: <[corner2]>""
    #- define c <[corner1].to_cuboid[<[corner2]>]>
    #- debug log "<red>Cuboid: <[c]>"

    - determine <[corner1].to_cuboid[<[corner2]>]>


# - Scan a direction, specified by an relative cordinate (0,0,1) as delta
# - When encountering an invalid crop block stop and return prior value
scan_direction:
  type: procedure
  debug: false
  definitions: origin|delta
  script:
    #- debug log "<green>FIND BOUNDS: <[origin]> ----- <[delta]>"

    # TODO: move to configuration
    - define valid_crops <proc[pl__config].context[farmer.valid_crops]>
    - define max_dist <proc[pl__config].context[farmer.farm_radius_max]>

    # Add composter, we ignore thse
    - define valid_farm:->:composter

    - define scan_loc <[origin]>
    - define found_loc <[origin]>
    - repeat <[max_dist]> as:step:
      - define scan_loc <[scan_loc].add[<[delta]>]>
      - define mat <[scan_loc].material.name>
      - if <[valid_crops].contains[<[mat]>].not>:
        - define block_below <[scan_loc].below>
        # Not all blocks can be waterlogged, and if theyc annot be then Denizen will toss an exception, so catch that
        # Probably faster than checking if it can or cannot be waterlogged.
        - if <[block_below].material.name> != water and <[block_below].material.waterlogged.if_null[false].not>:
          # Invalid block found
          - determine <[found_loc]>
      - define found_loc <[scan_loc]>

    # Reached maximum distance
    - determine <[found_loc]>


# - NPC follows leash
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


# - NPC scrolling message. Will displaye each message over the NPC head (name area) and move to next
# - after a few ticks. Supports as many messages as desired.
# -
# - status : Name of message action, see configuration file. If nothing is passed then the prior state
# - is maintained. Use this to update scrolling messages/emotion animations when in loops without a know state
message_scrolling_status:
  type: task
  debug: false
  definitions: status
  script:
    # This allows messages to be passed as a LIST of  unspecified size
    - define current_tick <util.current_tick>

    # State is only reset if status is different than prior.
    - define prior_status <npc.flag[status]||null>
    - if <[status]> && <[status]> != <[prior_status]>:
      - flag <npc> status:<[status]>
      - flag npc message.timer:<[current_tick]>
      - flag npc emotion.timer:<[current_tick]>
      - flag npc message.seq:1

    # Recover prior state, if this is too slow then use local variables. But this is cleaner code
    # Do add fallback in case we are initially called with nothing
    - define status <npc.flag[status]||farming>
    - define message_timer <npc.flag[message.timer]||<[current_tick]>>
    - define message_sequence <npc.flag[message.seq]||1>
    - define emotion_timer <npc.flag[emotion.timer]||<[current_tick]>>

    - define messages <proc[pl__config].context[farmer.status.<[status]>.messages]>
    - define emotion <proc[pl__config].context[farmer.status.<[status]>.emotion]>

    - if <[messages]>:
      - if <[current_tick].sub[<[message_timer]>]> > 40:
        - define message_sequence:++
        - if <[message_sequence]> > <[messages].size>:
          - define message_sequence 1

        - flag npc message.timer:<[current_tick]>
        - flag npc message.seq:<[message_sequence]>
        - adjust <npc> name:<[messages].get[<[message_sequence]>]>

    # In general emotions need to occur on every 5 ticks
    #    This will normallyu always file sinze there are a lot of waits in NPC handling. But some actions may
    #    run considerbly faster (such as following), so add tis to stop massive accumulation
    - if <[emotion]> :
      - if <[current_tick].sub[<[emotion_timer]>]> > 10:
        # Set animation over villager: See also: 
        # - https://meta.denizenscript.com/Docs/Commands/PlayEffect
        # - https://meta.denizenscript.com/Docs/Languages/Particle%20Effects

        - flag npc emotion.timer:<[current_tick]>
        - choose <[emotion]>:
          - case angry:
            - playeffect <npc.location.add[0,.5,0]> effect:angry_villager quantity:3 visibility:10 offset:0.4,0.1,0.4

          - case love:
            - playeffect <npc.location.add[0,.5,0]> effect:heart quantity:3 visibility:10 offset:0.4,0.1,0.4

          - case happy:
            - playeffect <npc.location.add[0,.75,0]> effect:happy_villager quantity:3 visibility:10 offset:0.4,.1,0.4

          - case gratitude:
            - playeffect <npc.location.add[0,.5,0]> effect:happy_villager quantity:3 visibility:10 offset:0.4,0.1,0.4

          - case confused:
            - playeffect <npc.location.add[0,1,0]> effect:cloud quantity:3 visibility:10 offset:0.4,.1,0.4

          # - All others do no effects, this includes OK
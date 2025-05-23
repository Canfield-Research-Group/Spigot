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

# TODO: Vines (ticky) (DONE?)
# TODO: Lumberjack
#   TODO: normalize professions by inheritence from 'default_profession:' at config loading

# = Flags
#   - Server:
#     - helpers
#       - farm
#         - <location.simple> = map of farm data (aka farm_key)
#           - # See also helpers_find_nearest_working_area()
#           - farm_key = <location.simple> but can change
#           - farm = @location of trigger block (eg; composter)
#           - profession = <profession> - profession name matches with config YAML
#           - chest = @location of Chest for storing items farmer gathered
#           - area = @cuboid of farm arear
#       - farm_highlight (for performance on lookup)
#         - <location.simple> = highlight expiration (expires)
#   - NPC:
#     -  helpers
#       - farm
#         - key = <location.simple> for farm
#     - reset (general control key functions should treat as an exit)
#     - is_following (general npc flag for is NPC following player)
#     - message : Scrolling message data
#       - status : key value into mesage (config YAML)
#       - message_timer : used to toggle message sequence
#       - emotion_timer : emotion timer (special effects)
#       - sequence : starts at 1 and incements through each message available (one or more)


# MOSTLY for admins, reset flag when farmer respawns
helpers_villager:
  type: world
  debug: false
  events:

    # These MUST finish before code can run
    on server start:
      - flag server helpers.config_merged:false
      - ~run _helpers_config_merge
    on script reload:
      - flag server helpers.config_merged:false
      - ~run _helpers_config_merge

    # use AFTER since we need to entity fully spawned, then remove it
    after villager changes profession:
      # Villager must be within radius to composter and within x of a player (ANY PLAYER)
      - define villager <context.entity>
      - define player_radius <proc[helpers_config].context[player_radius]>
      - define players <[villager].location.find_players_within[<[player_radius]>]>
      - define player <[players].get[1]||null>
      - if <[player]>:
        - define sid helpers_village_<util.current_time_millis>
        - ~run helpers_find_nearest_working_area save:<[sid]> def.location:<context.entity.location>
        - define result <proc[queue_parse].context[<entry[<[sid]>].created_queue.determination||false>]>
        - if <[result]>:
          - ~run helpers_npc_spawn def:<[villager]>|<[player]>|<[result].get[farm_key]>

    on player right clicks composter:
      - ratelimit <player> 1s
      - define sid helpers_village_<util.current_time_millis>
      - ~run helpers_find_nearest_working_area save:<[sid]> def.location:<context.location> def.radius:1
      - define result <proc[queue_parse].context[<entry[<[sid]>].created_queue.determination||false>]>
      - if <[result]>:
        - define farm_key <[result].get[farm_key]>
        - run helpers_highlight_farm def.farm_key:<[farm_key]>
      - else:
        - narrate "<red>Block is not a farm trigger. Is it crafted correctly?"


    on player right clicks npc:
      - ratelimit <player> 10t
      - if <npc.owner.item_in_hand.material.name> == torch:
        - define scripts <npc.scripts>
        # SET will clear then add and trigger the 'on assignment'
        - assignment set script:helpers_brain to:<npc>
        - narrate "<green>Repair performed <npc>" targets:<npc.owner>


helpers_brain:
  type: assignment
  debug: false
  actions:

    on assignment:
      # Force farm to be re-scaned
      - flag <npc> helpers.farm_key:!
      - trigger name:click state:true
      - trigger name:proximity state:true

      # - Cause other scripts for this NPC to stop. Any script in an infinite loop OR uses 'RUN' to recycle needs to
      # - monitor this flag. Normally just the keep-alive controller needs to do so
      # Tell all controllers or other NPC scripts to NOT recucle or to exit if in long loops
      #  Wait a second or two for the other tasks to stop, then clear flag and spin up again
      # - Change this to a monitor for queus runing with controller name, which is complicated
      - flag <npc> reset:true
      - wait 5s
      - flag <npc> reset:!
      - run helpers_ai_controller

    # Tip: triggers (assignment) ar elimted to right click
    on click:
      - if <npc.owner.item_in_hand.material.name> == apple:
        - spawn entity:VILLAGER <npc.location> save:new_villager
        - adjust <entry[new_villager].spawned_entity> profession:NONE

        - remove <npc>
        - take iteminhand
        - narrate "<green>Returned to a villager"
        - stop
      - if <npc.owner.item_in_hand.material.name> == lead:
        - if <npc.has_flag[is_following]>:
            - narrate "<green>released!"
            - flag <npc> is_following:!
        - else:
          - flag <npc> is_following:true
          - run helpers_scrolling_nametag def:finishing_work
        - stop


helpers_ai_controller:
  type: task
  debug: false
  script:
    # If despawned stop script
    - if <npc.is_spawned.not>:
      - stop

    # FIlter QUEUE to THIS NPC and if more than one stop the current being attempted (see simple-inventory for why this works)
    # - be sure to wait 1 tick for calling QUEUE to end otherwise we will the recustive one
    - wait 1t
    - define queues <script.queues.filter_tag[<[filter_value].id.starts_with[helpers_ai_controller_].and[<[filter_value].npc.equals[<npc>].if_null[false]>]>]>
    - if <[queues].size> > 1:
      - debug log "<red>Stopping queue <queue.numeric_id> there are too many others running: <[queues].size>"
      - stop

    - define queue_id helpers_ai_task<npc.id>
    - define sid myscript_<util.current_tick>
    - ~run helpers_ai_task id:<[queue_id]> save:<[sid]>
    - define results <proc[queue_parse].context[<entry[<[sid]>].created_queue.determination||list[]>]>

    - define wait_time <proc[helpers_npc_get_value].context[ai_wait_time]>
    - define delay <[results].get[delay]||<[wait_time]>>
    - wait <[delay]>

    # Recycle to keep brain controler alive
    - run helpers_ai_controller


helpers_ai_task:
  type: task
  debug: false
  script:
    # Used to close out any running controllers, usually called by assignment
    - if <server.has_flag[reset]>:
      - stop
    # Make sure configs are loaded first, we cannot have a wait inside a procedure ()
    - ~run _helpers_config_is_ready

    # Valid chests
    - define valid_chests <proc[helpers_npc_get_value].context[valid_farm.chest]>
    # Valid crops the farm will harvest
    - define valid_crops <proc[helpers_npc_get_value].context[crops].keys>

    # - Simulate LEASH
    - if <npc.has_flag[is_following]>:
      # Force a re-evaluation of the farm
      - flag <npc> helers.farm.key:!
      - ~run helpers_npc_follow
      # This task runs much quicker so NPC keeps up
      - determine delay:10t
      - stop

    # Check if the environment is Sane for this farmer
    #   TIP: if any of these become null then all are invalid. Bets practice is to clear the base_loc to be forward compatible
    - define farm_data <proc[helpers_farm_for_npc]>
    - if <[farm_data]>:
      - define farm_loc <[farm_data].get[farm]>
      - define chest_loc <[farm_data].get[chest]>
      - define farm_area <[farm_data].get[area]>
      - define profession <[farm_data].get[profession]>

    #- define farm_key <proc[helpers_npc_get_value].context[farm_key]>
    #- if <[farm_key]>:
    #  - define farm_loc <proc[helpers_npc_get_value].context[farm]>
    #  - define chest_loc <proc[helpers_npc_get_value].context[chest]>
    #  - define farm_area <proc[helpers_npc_get_value].context[area]>
    #  - define profession <proc[helpers_npc_get_value].context[profession]>

      # The target block (base loc) and chest MUST exist otherwise everything breaks.
      - if <[farm_loc].material.name> != composter or <[chest_loc].material.name.advanced_matches[<[valid_chests]>].not>:
        - define farm_key <proc[helpers_npc_get_value].context[farm_key]>
        - flag server helpers.farm.<[farm_key]>:!
        - flag <npc> helpers.farm_key:!
    - else:
      # - IDENTIFY Farm Boundries
      # - This takes abou 2ms to 3ms to scan a farly large farm area na update settings. Assuming 20 or so total farms and that is faro too much to do every cycle
      # - By only scanning if needed this is VERY fast (under 1 ms)
      - define sid helpers_village_<util.current_time_millis>
      - ~run helpers_find_nearest_working_area save:<[sid]> def.location:<context.entity.location>
      - define result <proc[queue_parse].context[<entry[<[sid]>].created_queue.determination||false>]>
      - if <[result]>:
        # Update local settings
        - define farm_loc <[result].get[farm]>
        - define chest_loc <[result].get[chest]>
        - define profession <[result].get[profession]>
        - define farm_area <[result].get[area]>

        # Update persistence data
        - flag <npc> helpers.farm.key:<[result].get[farm_key]>

    # Catch all
    - if <[farm_loc]>  == null:
      - run helpers_scrolling_nametag def:farm_broken
      - determine delay:4s

    - define tool_required <proc[helpers_npc_get_value].context[tool_match]>

    # - Tool pickup
    - ~run helpers_pick_up_tool

    # - Check for NPC inventory needing emptying
    # Check if farmer needs to add to the chest, and if full add animation
    - if <npc.inventory.quantity_item> > 32:
        - ~run helpers_deliver_task
        # If after transfering items the farm still does not have an empty slow then we assume they are full
        # and the chest is full. Since tasks do NOT return (easily) a value this seems the fastest way
        - if <npc.inventory.empty_slots> == 0:
          # Set animation over chest location
          - define effect_loc <[chest_loc].add[.5,0,.5]>
          - playeffect <[effect_loc]> effect:angry_villager quantity:1 offset:0.25,0.5,0.25 visibility:10
          - stop

    - if <npc.inventory.contains_item[<[tool_required]>].not>:
      - run helpers_scrolling_nametag def:need_item
      - stop

    # - Process Harvesting
    - define harvested false
    # Tracks if the NPC should be forced towalk during idle, useful to try and get unstuck from harvesting
    - define force_walk false

    - run helpers_scrolling_nametag def:working
    - if <npc.inventory.contains_item[<[tool_required]>]>:
      # TIP: We cannot easily prefilter since different crops have different maximum mages, so we scan it ...
      # .within[<[search_radius]>].filter_tag[<[filter_value].material.age.is[or_more].than[<[crop_max_age]>]>]>
      - define crop_list <[farm_area].blocks[<[valid_crops]>]>
      - if <[crop_list].size>:
          # Randomize list to be a bit more fun an alive
          - define crop_list <[crop_list].random[<[crop_list].size>]>
          - foreach <[crop_list]> as:crop :
            # Make sure the crop is still valid, for some reason AIR was seen, especially when a villager entered the farm
            # But not sure how that is possible when everything should be in the same tick
            - if <[crop_list].contains[<[crop]>].not>:
              - foreach next

            # not all crops haev age/maximum age, for example melons and pumpkins. We can use seeds (none) to detect that for all known items
            - define prior_crop <[crop].material.name>
            - define direction <[crop].material.direction||null>
            - define seed <proc[helpers_npc_get_value].context[crops.<[prior_crop]>.plant]>
            - define max_age <proc[helpers_npc_get_value].context[crops.<[prior_crop]>.max_age]>
            - if <[seed]> == none or <[max_age]> == null or <[crop].material.age.is[or_more].than[<[crop].material.maximum_age>]>:
              # This complex mantra call as task, waits for it to finish and then sees if it was cancled (errored)
              - define near_crop <proc[helpers_find_safe_loc].context[<npc.location>|<[crop]>]>

              - define sid myscript_<util.current_tick>
              # WARNING: THis method can CHANGE destination due to path blocked. So let it handle any anomolies
              - ~run helpers_walk_to def:<[crop]> save:<[sid]>
              - define results <proc[queue_parse].context[<entry[<[sid]>].created_queue.determination||list[]>]>
              - if <[results].get[cancelled]||false>:
                  # Stop scanning, it gets expensive, just let it try again next opertunity
                  - foreach stop


              - animate <npc> animation:SWING_MAIN_HAND
              # Prevent modest race conditions where two farmers race to a single crop. THis is not perfect
              # but should prevent most of the "dups"
              - if <[crop].material.name> = air :
                - stop
              - if <[seed]> == null or <[max_age]> == null or <[crop].material.age.is[less].than[<[crop].material.maximum_age>]>:
                - stop
              - ~break <[crop]> <npc>

              # Some items do NOT break and drop items unless special devices are used (Farmers using hoe on Vines)
              # To reduce maintenance and complications we allow drops to be extended. Note this does NOT eliminate
              # the normal drops via BREAK. If an item appears multiple times each occurance is a seperate drop. A
              # quantity can also be suffixed using a ':' for example' cobblestone:32
              - define extra_drops <proc[helpers_npc_get_value].context[crops.<[prior_crop]>.drops]>
              - if <[extra_drops]> != null:
                - foreach <[extra_drops]> as:drop :
                  - if <[drop].contains[:]>:
                    - define quantity <[drop].after[:]>
                    - define drop <[drop].before[:]>
                  - else:
                    - define quantity 1
                  - drop <[drop]> <npc.location> quantity:<[quantity]>


              # Need to wait a tick for item to pop into the world reliably, but for athetics we wait a bit longer
              - wait 3t

              # In theory this could pick up a hoe (or anything) but that's fine since we look in inventory
              # for any NPC items instead o using flags.
              - define nearby_items <npc.location.find_entities[item].within[3]>
              - foreach <[nearby_items]> as:item:
                - give item:<[item].item> to:<npc.inventory>
                - remove <[item]>

              # Plant with what was originally there
              #   Remove plant seed, IGNORE if non left to avoid the overhead of adding a mecabusm to give seeds to an NPC
              #   In most cases the NPC will have the seed from picking up dropped items
              - if <[seed]> != none:
                - take item:<[prior_crop]> from:<npc.inventory> quantity:1

                - if <[direction]>:
                  # No Pyhics is needed during placement , otherwise for coca, vines and other attached blocks the MC engine
                  # phtics (block update) can cause th eitem to break. This must be done as well as the waiting break (~break) if using break
                  - modifyblock <[crop]> <[prior_crop]>[direction=<[direction]>]  no_physics
                - else:
                  - modifyblock <[crop]> <[prior_crop]>

              # Reduce duability of tool
              - define durability <proc[helpers_npc_get_value].context[tool_duability_loss]>
              - if <[durability]> < 1:
                - if <util.random_chance[<[durability].mul[100].round_down>]>:
                  - define loss 1
                - else:
                  - define loss 0
              - else:
                - define loss <[durability].round_down>
              # This will automatically adjust durability and handl ebreaking the item, removing it from NPC inventory
              # TIP: use'adjust `<npc.item_in_hand> durability:x` did not work
              - adjust <npc> damage_item:[slot=hand;amount=<[loss]>]

              - define harvested true

              # NOTE: Only one harvested block per AI run
              - foreach stop

    - if <[harvested].not>:
        # Wander a bit between harvesting
        - run helpers_wander_task instantly

    # Run each NPC in it's own queue
    # NOTE: AVOID WHILE Loops or any long lived loop as the script here can be tied to the NPC
    # and surive reloads, spawn, despawn. The only way to stop it is to remove the npc
    - stop



# - Delivery items from NPC to chest
helpers_deliver_task:
  type: task
  debug: false
  script:
    - run helpers_scrolling_nametag def:unloading

    - define chest_loc <proc[helpers_npc_get_value].context[chest]>
    - define look_target <[chest_loc].add[0,0,0]>
    - look <npc> <[look_target]>
    - ~walk <npc> <[chest_loc]> speed:1 auto_range

    - define chest <[chest_loc].inventory>

    # Skip air and tool match, unload all the rest
    - define ignore <proc[helpers_npc_get_value].context[tool_match]>
    - define items <npc.inventory.list_contents.filter_tag[<[filter_value].material.name.advanced_matches[<[ignore]>].not>]>
    - foreach <[items]> as:item:
      # Simpel quick check for space available, if not then just stop
      # Also check for air as lat as possible to avoid race conditions
      - if <[item].material.name> == air:
        - foreach next

      - define space_available <[chest].can_fit[<[item]>]>
      - if <[space_available].not>:
        - stop

      # Inventory sucks -- to avoid ghost items we move by name, it's easier but cannot reliable move
      # special items. Which we do not have.
      # TODO: Consider splitting simple-inventory feeder mover into a procedure, it is a lot more sophisticated
      - take item:<[item].material.name> from:<npc.inventory> quantity:<[item].quantity>
      - give item:<[item].material.name> to:<[chest]> quantity:<[item].quantity>
      - wait 1t

    - wait 0.25s
    - playsound block.chest.close <[chest_loc]>


# - Famer wanders a bit randomly, turning head looking around and occasionally walking. Simplistic but works
helpers_wander_task:
  type: task
  debug: false
  definitions: force_walk
  script:
    - define farm_area <proc[helpers_npc_get_value].context[area]>

    - define wander_loc <[farm_area].random>
    - define force_walk <[force_walk]||false>

    # BUG: IN Denizen if lootat and target are the same the NPC ZOOMS to the target, even when walk speed is 0.5
    # Apparently this is a citizen's thing?????
    # The fix is to look THEN move
    - define look_target <[wander_loc].add[0,.5,0]>
    - look <npc> <[look_target]>
    # To reduce loads only move 1/4 of the time
    #   In any case do NOT check for sucess on walking, it is not worth it and could result in very long delays
    #   Caller uses to to just look busy OR to help get unstuck, and will just try again if needed
    - if <[force_walk]> or <util.random_chance[15]>:
      - ~run helpers_walk_to def:<[wander_loc]>


# - NPC follows leash
helpers_npc_follow:
  type: task
  debug: false
  script:
  - define is_following <npc.flag[is_following]||null>
  - if <[is_following]> == null or <npc.owner.is_online.not> or <npc.owner.item_in_hand.material.name> != lead or <npc.owner.is_sneaking>:
    - narrate "<yellow>Following canceled"
    - flag <npc> is_following:!
    - stop

  - run helpers_scrolling_nametag def:following

  - if <npc.location.distance[<npc.owner.location>].is[or_more].to[2]>:
    - walk <npc> <npc.owner.location> auto_range speed:1



# - NPC walk to location and handle navigation failure. After handling numerous MC relat
# - Handles numerous MC realetd anomolies
#   - If target is not reachable then find a reachables target nearby starting at radius 1 then 2
#   - If the current NPC y is not an int then teleport slightly upward.
#     - A hack to work around MC somtimes placing y below the block, enough to fail some path finding targets
#     - After implementing this pathing was dramatically improved, Y offises of .9374 were quite common
#   - Checks if taget was reached within 2 or so, issues a cancel if not.
#     - caller can monitor this with some effort
#     - Recomended: Just ignore and continue on assuming caller uses a relative random target location, usually clears up very quickly
helpers_walk_to:
  type: task
  debug: false
  definitions: location
  script:
    # TO work around cases where MC places character a tad under a block, and thus prevents movement
    # in some directions we adjust that
    - define npc_loc <npc.location>
    - if <[npc_loc].y> != <[npc_loc].y.round>:
      # .1 is not enough to break things and is JUST enough to work (even through the common .9374 + .05 is not quite on the surface it is close enough)
      #  Adding .05 worked very well, but still failed
      - teleport <npc> <npc.location.add[0, .1, 0]>
    - define debug_start <npc.location>

    # FInd location to walk to
    - define location <[location].block.add[.5,0,.5]>
    - if <[location].is_passable.not>:
      - define location <proc[helpers_find_safe_loc].context[<npc.location>|<[location]>]>

    - ~walk <npc> <[location]> speed:1 auto_range

    # using distance sqared means we need to 2x the allowed distance, so within 2 means gt 4
    - if <npc.location.distance_squared[<[location]>].is[more].to[4]>:
      - determine cancelled


# - Find a block next to the target that is walkable. Often used to walk UP tot he crop/harvestable entity but not onto it
# - to help avoid pathing issues and be suiatble for lumberjacks, miners, havesting cocoa and vines
# - targets CENTER of block (target) to reduce edge issues with walking path
helpers_find_safe_loc:
  type: procedure
  debug: false
  definitions: source|target
  script:
    #  Get adjacent blocks, use a cuboid. This makes it easy to expand if needed
    # Center on target block to help reduce block offsets when walking
    - define target <[target].block.add[.5,0,.5]>
    # Scan up to 2r around the target, this helps get around obsticals (leaves are a problem here)
    - repeat 2 as:r:
      - define adjacent <[target].add[<[r]>,0,<[r]>].to_cuboid[<[target].sub[<[r]>,0,<[r]>]>].outline_2d[<[target].y>]>
      # Filter out non-walkable
      - define valid_adjacent <[adjacent].filter_tag[<[filter_value].below.material.is_solid.and[<[filter_value].is_passable>]>]>
      # And now get nearest, start with a match that is WAY WAY off
      - define prior_distance 9999
      - define adjacent_target null
      - foreach <[valid_adjacent]> as:loc :
        # Use slower sperical distance, helps break ties and for 8 blocks is FAST enough
        - define loc <[loc].add[.5,0,.5]>
        - define distance <[source].distance[<[loc]>]>
        - if <[distance]> < <[prior_distance]>:
          - define prior_distance <[distance]>
          - define adjacent_target <[loc]>

      - if <[adjacent_target]> != null:
        - determine <[adjacent_target]>

    - debug log "<red>No valid walkable blocks near <[target]>"
    - debug log "<red>Adjacent: <[adjacent]>"
    - debug log "<red>valid_adjacent: <[valid_adjacent]>"
    # Someone asked for this so assume they knew what they were doing
    - determine <[target]>



# - NPC scrolling message. Will displaye each message over the NPC head (name area) and move to next
# - after a few ticks. Supports as many messages as desired.
# -
# - status : Name of message action, see configuration file. If nothing is passed then the prior state
# - is maintained. Use this to update scrolling messages/emotion animations when in loops without a know state
helpers_scrolling_nametag:
  type: task
  debug: false
  definitions: status
  script:
    # State is only reset if status is different than prior.
    - define message_data <npc.flag[message]||<map[status=null]>>
    - define prior_status <[message_data].get[status]||false>
    - if <[status]> != <[prior_status]>:
      - define message_data <map[status=<[status]>;message_timer=0;emtion_timer=9;sequence=1]>

    # Recover prior state, if this is too slow then use local variables. But this is cleaner code
    # Do add fallback in case we are initially called with nothing
    - define status <[message_data].get[status]||working>
    - define message_timer <[message_data].get[message_timer]||0>
    - define emotion_timer <[message_data].get[emotion_timer]||0>
    - define sequence <[message_data].get[sequence]||1>

    - define messages <proc[helpers_npc_get_value].context[status.<[status]>.messages]>
    - define emotion <proc[helpers_npc_get_value].context[status.<[status]>.emotion]>
    - define current_tick <util.current_tick>

    - if <[messages]>:
      # Use ABS to handle restarts on ticks
      - if <[current_tick].sub[<[message_timer]>].abs> > <proc[helpers_npc_get_value].context[status_message_delay]>:
        - define sequence:++
        - if <[sequence]> > <[messages].size>:
          - define sequence 1

        - define message_timer <[current_tick]>
        - define new_name <[messages].get[<[sequence]>]>

        # Per web:
        # this triggers on spawn again if it causes the NPC to be despawned and re-spawned under the hood — which can happen if:
        # You change the NPC's name while it's not currently spawned, and then some other code or Citizens automatically respawns it.
        # Or worse: some edge cases in Citizens can cause a name change to trigger a re-initialization that looks like a respawn.
        #
        #  This can be  triggered by a name change due to citizens interactions
        #  Tried teleporting to see if that fixed NPCs with the respawn issue in the on spawn).
        #  And so far nothing is preventing this access except reducing the name change
        - if <npc.is_spawned> and <npc.name> != <[new_name]>:
          - adjust <npc> name:<[new_name]>

    # In general emotions need to occur on every 5 ticks
    #    This will normallyu always file sinze there are a lot of waits in NPC handling. But some actions may
    #    run considerbly faster (such as following), so add tis to stop massive accumulation
    - if <[emotion]> :
      - if <[current_tick].sub[<[emotion_timer]>]> > <proc[helpers_npc_get_value].context[status_emotion_delay]>:
        # Set animation over villager: See also: 
        # - https://meta.denizenscript.com/Docs/Commands/PlayEffect
        # - https://meta.denizenscript.com/Docs/Languages/Particle%20Effects

        - define emotion_timer <[current_tick]>
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

          # - Any other emotions specified in config are considerd invalid and are just ignored

    # Update message state
    - flag <npc> message:<map[status=<[status]>;message_timer=<[message_timer]>;emotion_timer=<[emotion_timer]>;sequence=<[sequence]>]>


# === Find nearest valid NPC structure of any profession
# === TODO: This is sub-optimal, a better way is to find all trigger blocks, then loop through those, but that is more work and this shoudl be plenty fast enought and easier to maintain
# = location : Location to initiate search from.
# = radius : Range around the location to search
helpers_find_nearest_working_area:
  type: task
  debug: false
  definitions: location|radius
  script:

    # Location - a reaonable default, mostly for utilities
    - define location <[location]||<player.location>>
    # Radius using default if none passed
    - if <[radius]||null> == null:
      - define radius <proc[helpers_config].context[search_radius]>

    # Create a cuboid to search, radius is a spwhere and a rectangle will work better as above/below is less critical
    #   We coudl search for surface but we need to support underground farms as well
    # Upper / lower cuboid
    # Get blcoks that make up the dection matrix for this farm
    - define farm_search_area_1 <location[<[location].x.sub[<[radius]>]>,<[location].y.sub[1]>,<[location].z.sub[<[radius]>]>,<[location].world>]>
    - define farm_search_area_2 <location[<[location].x.add[<[radius]>]>,<[location].y.add[1]>,<[location].z.add[<[radius]>]>,<[location].world>]>
    - define farm_search_area <[farm_search_area_1].to_cuboid[<[farm_search_area_2]>]>

    # Get a list of all trigger blocks, this prevents double scanning and the confusion that can arise from that
    - define all_triggers <list[]>
    - foreach <proc[helpers_config].context[professions]> as:config key:profession :
      - if <[config].get[enabled].if_null[true].not>:
        - foreach next
      - define all_triggers:->:<[config].deep_get[valid_farm.trigger]>
    - define all_triggers <[all_triggers].deduplicate>
    - define found_triggers <[farm_search_area].blocks[<[all_triggers]>]>

    # Sort by distance location
    - define found_triggers <[found_triggers].sort[_helpers_sort_by_distance].context[<[location]>]>
    # Scan each found (in nearest sorted order) and exit on first found
    - foreach <[found_triggers]> as:base_loc_tmp :
        - foreach <proc[helpers_config].context[professions]> as:config key:profession :
          - define valid_chests <[config].deep_get[valid_farm.chest]>
          - define trigger_block <[config].deep_get[valid_farm.trigger]>
          # See if this structure matches the curent profession, exit ASAP on mismatch
          - if <[base_loc_tmp].material.name> == <[trigger_block]>:
              # Check validtiy of farm structure
            - define block_below <[base_loc_tmp].below>

            - if <[block_below].material.name> == water or <[block_below].material.waterlogged||false>:
              - define block_below <[block_below].below>
            - define base_substrate <[config].deep_get[valid_farm.substrate]>
            - if <[block_below].material.name.advanced_matches[<[base_substrate]>]>:
              # See if there is a chest on it
              - define chest_loc_tmp <[base_loc_tmp].add[0,1,0]>
              - if <[chest_loc_tmp].material.name.advanced_matches[<[valid_chests]>]>:
                - define area <proc[helpers_get_working_area].context[<[base_loc_tmp]>|<[config]>]>
                # - SEE: maintain comment block at top to align with this
                - define farm_key  <[base_loc_tmp].simple>
                - define farm_data <map[farm_key=<[farm_key]>;farm=<[base_loc_tmp]>;profession=<[profession]>;chest=<[chest_loc_tmp]>;area=<[area]>]>
                - flag server helpers.farm.<[farm_key]>:<[farm_data]>
                - determine <[farm_data]>
                # task exits now

    - determine false


# = Used for <ListTag.sort[<procedure>].context[<context>]> to return a list sorted by nearest first. If equal it is
# = non deterministic which one is selected first.
# - list is assumed to be location objcts
# - context a base location
# -
# - Performance not a factor here, there is only every a few farms (usually 1) whithin the limits of the player an NPC
# - but even 10 would not be an issue. But 100s would, if farm search/players radius is that large then this may need
# - to be adapated. But even then this is typically called only for NPC triggering to a profession or maintenance operations
# -
_helpers_sort_by_distance:
  type: procedure
  debug: false
  definitions: locationA|locationB|origin
  script:

    - define d1 locationA.distance[<[origin]>]
    - define d2 locationB.distance[<[origin]>]
    - if <[d1]> < <[d2]>:
      - determine -1
    - else:
      - if <[d1]> < <[d2]>:
        - determine 1
      - else:
        - determine 0


# - Give an origin identify boundries of a farm based on PLANTED crops
# - of any mix. Designed to be called from `helpers_find_nearest_working_area` and other internal farm maintenance
# - Requires the origin of the farm AND the current config, which is: professions.<[profession]>.....
helpers_get_working_area:
  type: procedure
  debug: false
  definitions: origin|config
  script:
    # Relative cordinates for each axis
    - define world <[origin].world.name>
    - define north <proc[helpers_scan_to_edge].context[<[origin]>|<location[0,0,-1]>|<[config]>]>
    - define south <proc[helpers_scan_to_edge].context[<[origin]>|<location[0,0,1]>|<[config]>]>
    - define west <proc[helpers_scan_to_edge].context[<[origin]>|<location[-1,0,0]>|<[config]>]>
    - define east <proc[helpers_scan_to_edge].context[<[origin]>|<location[1,0,0]>|<[config]>]>

    # Farm height is a delta, as the default is to add 0 to the base cuboid. So we subtract 1
    - define farm_height <proc[helpers_npc_get_value].context[farm_height]>
    - define corner1 <location[<[west].x>,<[origin].y.sub[0]>,<[south].z>,<[world]>]>
    #- define corner2 <location[<[east].x>,<[origin].y.add[<[farm_height]>]>,<[north].z>,<[world]>]>
    - define corner2 <location[<[east].x>,<[origin].y.add[0]>,<[north].z>,<[world]>]>

    - define farm_area <[corner1].to_cuboid[<[corner2]>]>
    - determine <[farm_area]>


# - Scan a direction, specified by an relative cordinate (0,0,1) as delta
# - When encountering an invalid crop block stop and return prior value
helpers_scan_to_edge:
  type: procedure
  debug: false
  definitions: origin|delta|config
  script:
    - define max_radius <[config].get[farm_radius_max]>
    - define valid_blocks <[config].deep_get[valid_farm.blocks]>
    - define y_delta <[config].deep_get[valid_farm.y_offset]>

    # Add composter, we ignore thse
    - define valid_farm:->:composter

    # The farm delta is applied just once
    - define scan_loc <[origin]>
    - define found_loc <[origin]>

    - repeat <[max_radius]> as:step:
      # The scan increments by delta for each pass
      - define scan_loc <[scan_loc].add[<[delta]>]>
      - define mat_loc <[scan_loc].add[0,<[y_delta]>,0]>
      - define mat <[mat_loc].material.name>
      - if <[valid_blocks].contains[<[mat]>].not>:
          # Water level is always one block below farm base
          - define water_level <[scan_loc].sub[0,1,0]>
          # Water like blocks are ALLWOED so if not a water block (and not a valid mat per above) we found an invalid block
          # Probably faster than checking if it can or cannot be waterlogged.
          - if <[water_level].material.name> != water and <[water_level].material.waterlogged.if_null[false].not>:
            - determine <[found_loc]>
      # A valid block was found so add to the list
      - define found_loc <[scan_loc]>

    # Reached maximum distance
    - determine <[found_loc]>


# = Set farm to be highlighted
helpers_highlight_farm:
  type: task
  debug: false
  definitions: farm_key
  script:
    - flag server helpers.farm_highlight.<[farm_key]>:<util.current_time_millis>
    - run helpers_highlight_refresh_farm


# = Highlight base
#   - Keep farms highlighted
helpers_highlight_refresh_farm:
  type: task
  debug: false
  script:
    # Try this as a method to stop too many of these running, it seems tow rok well just
    # need to get the timing right. Does not need to be exact just close enough. And this
    # mechanism  ends up NOT needing an event delay which should speed things up
    - ratelimit <player> 8t

    # Show outline of farm for a few seconds
    - define highlight_max <util.current_time_millis.sub[<proc[helpers_config].context[highlight_duration]>]>
    - define highlight <server.flag[helpers.farm_highlight].if_null[<map[]>]>

    - define active 0
    - foreach <[highlight]>  key:farm_key as:start_ms :
      - if <[start_ms]> < <[highlight_max]>:
        # Highlight expired close it
        - flag server helpers.farm_highlight.<[farm_key]>:!
        - foreach next


      - define farm_area <proc[helpers_npc_get_value].context[area|<[farm_key]>]>

      # If farm is no longer valid just skip it and let normal timeout clear it, cleaner, easier, more reliable
      - if <[farm_area]> :
        - define y_height <[farm_area].max.y.add[2]>
        - define farm_border <[farm_area].outline_2d[<[y_height]>]>
        - define farm_border <[farm_border].parse_tag[<[parse_value].center>]>
        - playeffect effect:flame at:<[farm_border]> quantity:1  visibility:32 offset:0.0,0.1,0.0
        - define active:++

    - if <[active]>:
      - run helpers_highlight_refresh_farm delay:15t



# = Scan for tool item and if found use it
helpers_pick_up_tool:
  type: task
  debug: false
  script:
    # - Check for HOE pickup
    # - Set area to look equipment being dropped for NPX
    #   Drop area is one below cuboid (items site on TOP of a block so you need to look at the block one below you expect to, or so it seems)
    - define farm_area <proc[helpers_npc_get_value].context[area]>

    # Expand top and bottom to make it easier to find item that might have fallen into water
    # or ot top of something else. It's fast since entity scanning is WAY faster than block scanning
    - define drop_area <[farm_area].expand_one_side[0,-2,0].expand_one_side[0,1,0]>
    - define tool_matcher <proc[helpers_npc_get_value].context[tool_match]>

    # See if Farmer can find a hoe and equip it, once grabbed the hoe
    # is forver the Farmer, by design. A new hoe replaces CURRENT
    #- define found_tools <[drop_area].entities[<[tool_matcher]>]>
    # Dropped items are NOT named entities
    #   'dropped_item' - will match items fro breaking blocks, possibly killing npcs and player dropped but NOT dispenser drops
    #   'item' - matches any items but no players or NPCs
    #     And we want dispensors to be able to auto replenish farms so 'item' it us
    - define found_tools <[drop_area].entities[item]>
    - foreach <[found_tools]> as:entity :
      # This if handles if an item is not a material (which should never happen since we filter in entiies[item] above, but it's a nice safety)
      - if <[entity].item.material.name.if_null[false].advanced_matches[<[tool_matcher]>].not>:
        - foreach next

      - define tool <[entity].item>
      - define tool_loc <[entity].location>
      - look <npc> <[tool_loc]>
      - ~walk <npc> <[tool_loc]> speed:1 auto_range
      # Check hoe near it to make the mesage clearer
      - if <[tool].enchantment_map.is_empty.not>:
        - run helpers_scrolling_nametag def:invalid_item
        - stop

      #  NOTE: ignoring race conditions If players want to carefully time things for modest item duplication
      #  such as farm harvests and farm tools, call it a game mechanic. Getting it perfect is hard anyway given minecrafts
      #  lack of atomic inventory handling.
      - if <[entity].is_spawned.not>:
        - stop

      # Remove any existing hoes, they are instantly consumed
      - define existing_tools <npc.inventory.list_contents.filter_tag[<[filter_value].material.name.advanced_matches[<[tool_matcher]>]>]>
      - foreach <[existing_tools]> as:item :
        - take item:<[item]> from:<npc.inventory>

      # Transfer hoe from ground to the NPC
      - animate <npc> animation:SWING_MAIN_HAND
      - equip <npc> hand:<[tool]>
      - remove <[entity]>
      - run helpers_scrolling_nametag def:thank_you


# == Convert a villager to an NPC
# - Profession is the helper profession and must be passed. Sometime this helper plugin may have a profession
# - that MC does not
helpers_npc_spawn:
  type: task
  debug: false
  definitions: villager|owner|farm_key
  script:
    - define villager_location <[villager].location>
    # A farm key can be passed instead of an NPC (at least for this usage)
    - define profession <proc[helpers_npc_get_value].context[profession|<[farm_key]>]>
    - create player Helper<[profession]> <[villager_location]> save:npc_new
    - define new_npc <entry[npc_new].created_npc>
    - adjust <[new_npc]> owner:<[owner]>
    # remove villager
    - remove <[villager]>

    # Set attributes for this NPC
    - flag <[new_npc]> helpers.farm.key:<[farm_key]>

    # Dress NPC basd on configuration file
    # - ...uniform.hat.type, .color
    - define uniform <proc[helpers_config].context[professions.<[profession]>.uniform]||null>
    - if <[uniform]>:
      - foreach <[uniform]> as:style key:item_type :
        - define item <item[<[style].get[type]>]>
        - define color <[style].get[color]||null>
        - if <[color]>:
          - adjust <[item]> color:<[color]>
        # The equip requires a constant and apparently that happens before PARSING (so parsing is even weirder than I suspected). IN this case tags of the form 'tag_name:' are processed as arguments literals and their right side then PARSED.
        - choose <[item_type]>:
          - case head:
            - equip <[new_npc]> head:<[item]>
          - case chest:
            - equip <[new_npc]> chest:<[item]>
          - case legs:
            - equip <[new_npc]> legs:<[item]>
          - case boots:
            - equip <[new_npc]> boots:<[item]>
    - else:
      - debug log "<red>Villager at <[villager_location]> cannot find uniform for <[profession]>"

    - adjust <[new_npc]> set_protected:false
    - pushable npc:<[new_npc]> state:true
    - adjust <[new_npc]> collidable:true

    - assignment set script:helpers_brain to:<[new_npc]>



# = General purpose NPC data access. Seemlessly access the professional configuraton data
# = and the NPC specific farm data based on key path.
# - Using this is recomended over invidually acessing underlying data from config.professions OR famr data or
# - in the future per-npc data
# - If properly designed there are NO key duplicates unless overrides are someday implement. In any case the
# - path search order is:
#   - NPC flag data. NOTE: Flag paths support DOT seperated paths
#     -  Note: IGNORE if location is passed
#   - FARM Data from location key is retrieved and then searched for path. Just like NPC flags these are flag, ideally do not use DOT keys here
#   - CONFIG Data for this module using the 'professions' key from the farm data. This is NOT available if farm data cannot be retrieved. DOT (deep keys) are fully supported
# - Performance: This is the recomended way to fetch data for an NPC that may be comining from config, or NPC or famr data
# - but it can be 5x as slow as direct for farm_data when using individual keys. This is caused by checking
# - getting farm key and then full farm data every call. In such cases using helpers_farm_for_npc() is much faster then
# - using get on the returned map.
#   - see helpers_farm_for_npc()
# = path : DOT path to key to retrieve, do NOT include 'professions.<procession>' component as that is already preset
# = npc_or_loc : The NPC to access, or a location or form_key
# = default : defaults to null, otherwise the value to return if key path does not exist
# = RETURNS the value for the configuration path OR false if there is no farm data/configuration

helpers_npc_get_value:
  type: procedure
  definitions: path|npc_or_loc|default
  debug: false
  script:

  # If no npc data passed use current NPC
  - define npc_or_loc <[npc_or_loc].if_null[null]>
  - if <[npc_or_loc]> == null:
    - if <npc.if_null[null]> == null:
      - determine false
    - define npc_or_loc <npc>

  - if <[npc_or_loc].is_npc||false>:
    # *** Use NPC data
    - define npc_path helpers.farm.<[path]>
    - if <[npc_or_loc].has_flag[<[npc_path]>]> :
      - determine <[npc_or_loc].flag[<[npc_path]>]>
    # Get farm data
    - define farm_data <proc[helpers_farm_for_npc].context[<[npc_or_loc]>]||false>
  - else:
    # Assume a location
    - define farm_data <proc[_helpers_farm_for_location].context[<[npc_or_loc]>]||false>

  # Farm data and configuration data applie to both NPC and FARM (currently, this could change someday)
  - if ! <[farm_data]>:
    # No farm data so we cannot fetch profession which is needed for this npc
    - determine false

  - define value <[farm_data].get[<[path]>].if_null[false]>
  - if <[value]>:
    - determine <[value]>

  # - Not a valid farm flag so check configuration
  # - for now assume profession exists, otherwise a log will be generated
  - define profession <[farm_data].get[profession]||false>
  - define value <proc[helpers_config].context[professions.<[profession]>.<[path]>]>
  - if <[value]> == null:
    # Trap error and return null
    - define value <[default].if_null[null]>
  - determine <[value]>


# = return value for the configuration path for this module, not NPC specific
# - will return null if path does not exist
helpers_config:
  type: procedure
  definitions: path
  debug: false
  script:

  - determine <proc[pl__config].context[helpers.<[path]>]||null>


# = merge professions configuration
_helpers_config_merge:
  type: task
  debug: false
  script:

    # - Ideally we would use the ID from a call tp pl__config but requires that the config script file to be loaded. 
    # YAML data is NOT unloaded on a 'reload' command. This means data can be stale. Using a yaml version woudl work but it is prone to
    # maintenance problems, especially in a simple Dneizen workflow. Instead wait a bit to give the system time to
    # load the file. This is NOT ideal as delays in startup can cause problems but we don;t have a lot of other
    # mechacnisms to manage this. A server RESTART works fine as the YAML will be gone.
    #    This code ONLY runs on startup so performance is not critical. Normal script loading is REALLY fast but give it time anyway.
    #    We could also just re-merge every 30 seconds or so but that seems overkill sicne 'denzien reloads' are rare on production
    # - Alterantive it so manually run merge if needed: ex run _helpers_config_merge
    - wait 20t
    - define accumulated_wait_time 0
    - while <yaml.list.contains[pl__config].not>:
      - wait 1t
      - define accumulated_wait_time:++
      - if <[accumulated_wait_time].mod[100]> == 0:
        - debug log "<red>ERROR: _helpers_config_merge() cannot detect YAML loading, likely a bug. Waiting for: <[accumulated_wait_time]> ticks"

    - define yaml_id <proc[pl__load_config_id]>
    - define defaults <proc[helpers_config].context[profession_default]>

    - define old <yaml[pl__config].read[helpers.professions.farmer.tool_duability_loss].if_null[no-data]>

    - foreach <proc[helpers_config].context[professions]> as:config key:profession :
      - define combined <[defaults]>

      # Loop through all changes for this profession and apply to the new combined list
      - foreach <[config]> as:value key:key_path :
        - define combined <[combined].deep_with[<[key_path]>].as[<[value]>]>

      # Update Yaml
      - yaml id:<[yaml_id]> set helpers.professions.<[profession]>:<[combined]>

    - flag server helpers.config_merged:true


# = Waits until configuation is ready. Used by some code (such as task:assigned) to make sure configs are loaded
_helpers_config_is_ready:
  type: task
  debug: false
  script:

  - while <server.has_flag[helpers.config_merged].not> or <server.flag[helpers.config_merged].not>:
    - wait 20t

# = returns true if this NPC is a farmer (of any type)
helpers_npc_is_farmer:
  type: procedure
  definitions: curent_npc
  debug: false
  script:
  - define current_npc <[current_npc]||<npc>>
  - define farm_data <proc[helpers_farm_for_npc].context[<[curent_npc]>]||false>
  - if <[farm_data]>:
    # No farm data so we cannot fetch profession which is needed for this npc
    - determine true
  - determine false

# = return the farm data associated with the current NPC, allows override npc, otherwise uses context NPC
helpers_farm_for_npc:
  type: procedure
  debug: false
  definitions: current_npc
  script:
    - define current_npc <[current_npc].if_null[<npc>]>
    - define farm_key <[current_npc].flag[helpers.farm.key]||false>
    - if <[farm_key]>:
      - determine <proc[_helpers_farm_for_location].context[<[farm_key]>]>
    - determine false

# = return the farm data associated with the current NPC, allows override npc, otherwise uses context NPC
_helpers_farm_for_location:
  type: procedure
  debug: false
  definitions: location
  script:
    # normalize location so it can be a location or a simple, needed since [location].location does not work (it should but alas it does not)
    - define location <location[<[location]>]>
    - define farm_key helpers.farm.<[location].simple>
    - determine  <server.flag[<[farm_key]>]||false>


# = Cleanup all missing farm keys and all removed NPC flags (ours and othres)
helpers_garbage_collection:
  type: task
  debug: false
  script:
    # - clear farm flags (server data) for any farms that are obviously invalid
    - define valid_chests <proc[helpers_npc_get_value].context[valid_farm.chest]>
    - define farm_flags <server.flag[helpers.farm]>
    - foreach <[farm_flags]> as:farm_flag :
      - define farm_data <server.flag[farm_flag]>
      - define base_loc <[farm_data].get[farm]>
      - define chest_loc <[farm_data].get[chest]>
      - if <[base_loc].material.name> != composter or <[chest_loc].material.name.advanced_matches[<[valid_chests]>].not>:
        # Old / removed farm
        - flag server <[farm_flag]>:!
        - debug log "<red>GC: Farm broken/incomplete. Removed: <[farm_flag]>"

    # - IGNORE: Clear NPC data for NPCs that do not exist
    #  - I am not sure NPC data is actually retained on the NPC being removed. And I cannot find anyway to scan for all NPCs and all flags 



# 60ms
helpers_bm_farm_each:
  type: procedure
  debug: false
  definitions: npc
  script:

  - define start_t <util.current_time_millis>
  - repeat 1000:
      - define farm_key <proc[helpers_npc_get_value].context[farm_key|<[npc]>]>
      - define farm <proc[helpers_npc_get_value].context[farm|<[npc]>]>
      - define chest <proc[helpers_npc_get_value].context[chest|<[npc]>]>
      - define area <proc[helpers_npc_get_value].context[area|<[npc]>]>
  - define end_t <util.current_time_millis>
  - define elapsed <[end_t].sub[<[start_t]>]>
  - debug log "<green>Benchmark: <[elapsed]>"
  - determine <[elapsed]>

# 11ms
helpers_bm_farm_once:
  type: procedure
  debug: false
  definitions: npc
  script:

  - define start_t <util.current_time_millis>
  - repeat 1000:
      - define farm_data <proc[helpers_farm_for_npc].context[<[npc]>]>
      - define farm_key <[farm_data].get[farm_key]>
      - define farm <[farm_data].get[farm]>
      - define chest <[farm_data].get[chest]>
      - define area <[farm_data].get[area]>
  - define end_t <util.current_time_millis>
  - define elapsed <[end_t].sub[<[start_t]>]>
  - debug log "<green>Benchmark: <[elapsed]> -- <[farm_data]> -- <[area]>"
  - determine <[elapsed]>
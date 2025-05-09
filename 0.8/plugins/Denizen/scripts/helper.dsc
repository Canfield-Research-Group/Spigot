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
# - move farm working flags to NPC
#   - KEY is server.helpers_LOC.
#     - area : Farm area
#     - profession : Farm profression (key in config)
#     - npc_attached : LIST of all NPCs IDs attached to farm (not sure we will use this or not)
#     - chest : Chets location for this farm
#   - NPC now get (some duplicate just for performance)
#     - farm_loc : The trigger block and thus the key to the flag (prefixed)
#       - proc: helpers_set_farm(loc)
#       - proc: helpers_npc_get(path) relative to profession related to farm_loc
#     - profession (this is reset on any loosing and then regaining a farm, but NPC retains this even if farm is broke so keep it)



# MOSTLY for admins, reset flag when farmer respawns
helpers_villager:
  type: world
  debug: false
  events:

    # use AFTER since we need to entity fully spawned, then remove it
    after villager changes profession:
      # Villager must be within radius to composter and within x of the player
      #- debug log "<red>Villager changes: <context.entity> -- <context.profession> -- <context.reason>"
      #- debug log "<green>Loc: <context.entity.location>"
      - define villager <context.entity>
      - define player_radius <proc[helpers_config].context[player_radius]>
      - define players <[villager].location.find_players_within[<[player_radius]>]>
      - define player <[players].get[1]||null>
      - if <[player]>:
        - define search_radius <proc[helpers_config].context[search_radius]>
        - define result <proc[helpers_find_nearest_working_area].context[<context.entity.location>|<[search_radius]>]>
        - if <[result].get[ok]>:
          - debug log "<green><[result].get[profession]> Helper found at <[villager].location>, near player (<[player].name>) and near farm (<[result].get[farm]>)"
          - ~run helpers_npc_spawn def:<[villager]>|<[player]>|<[result].get[profession]>


    on player right clicks composter:
      - define result <proc[helpers_find_nearest_working_area]>
      - if <[result].get[ok]>:
        - debug log "<green>Result: <[result]>"
        - define farm_area <[result].get[farm_area]>
        - debug log "<green>DONE: <[farm_area]>"
        - run helpers_highlight_farm def.farm_area:<[farm_area]> def.force:true
      - else:
        - narrate "<red>Block is not a farm trigger. Is it crafted correctly?"

helpers_brain:
  type: assignment
  debug: false
  actions:

    on assignment:
      # Force farm to be re-scaned
      - flag <npc> base_loc:null
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
      #- debug log "<red>ASSIGNMENT"
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

    - define wait_time  <proc[helpers_config_for_npc].context[wait_time]>

    - define queue_id helpers_ai_task<npc.id>
    - define sid myscript_<util.current_tick>
    - ~run helpers_ai_task id:<[queue_id]> save:<[sid]>
    - define results <proc[queue_parse].context[<entry[<[sid]>].created_queue.determination||list[]>]>
    - define delay <[results].get[delay]||<[wait_time]>>
    #- debug log "<aqua><util.queues>"
    # Recycle to keep brain controler alive
    - run helpers_ai_controller id:helpers_ai_controller<npc.id> delay:<[delay]>


helpers_ai_task:
  type: task
  debug: false
  script:
    - stop
    # Used to close out any running controllers, usually called by assignment
    - if <server.has_flag[helpers_reset]>:
      - stop

    # Valid chests
    - define valid_chests <proc[helpers_config_for_npc].context[valid_farm.chest]>
    # Valid crops the farm will harvest
    - define valid_crops <proc[helpers_config_for_npc].context[crops].keys>

    # - Simulate LEASH
    - if <npc.has_flag[is_following]>:
      # Force a re-evaluation of the farm
      - flag <npc> base_loc:null
      - ~run helpers_npc_follow
      # This task runs much quicker so NPC keeps up
      - determine delay:10t
      - stop

    # Check if the environment is Sane for this farmer
    #   TIP: if any of these become null then all are invalid. Bets practice is to clear the base_loc to be forward compatible
    - define base_loc <npc.flag[base_loc]||null>
    - define chest_loc <npc.flag[chest_loc]||null>
    - define farm_area <npc.flag[farm_area]||null>
    - define profession <npc.flag[profession]||null>

    # - IDENTIFY Farm Boundries
    # - This takes abou 2ms to 3ms to scan a farly large farm area na updtae settings. Assuming 20 or so total farms and that is faro too much to do every cycle
    # - By only scanning if needed this is VERY fast (under 1 ms)
    # Identify if the farmer home has been identified
    - if <[base_loc]> == null or <[chest_loc]> == null or <[farm_area]> == null:
      - define result <proc[helpers_find_nearest_working_area].context[<npc.location>]>
      - if <[result].get[ok]>:
        # Update local settings
        - define base_loc <[result].get[farm]>
        - define chest_loc <[result].get[chest]>
        - define profession <[result].get[profession]>
        - define farm_area <[result].get[farm_area]>

        # Update persistence data
        - flag <npc> base_loc:<[result].get[farm]>
        - flag <npc> chest_loc:<[result].get[chest]>
        - flag <npc> profession:<[result].get[profession]>
        - flag <npc> farm_area:<[farm_area]>

        #- debug log "<Aqua>Settings: <[base_loc]> -- <[chest_loc]> -- <[profession]> -- <[farm_area]>"

        # Highlight base
        - flag npc farm_highlight:0
    - else:
      # The target block (base loc) and chest MUST exist otherwise everything breaks.
      - if <[base_loc].material.name> != composter or <[chest_loc].material.name.advanced_matches[<[valid_chests]>].not>:
        - define base_loc null
        - flag <npc> base_loc:null

    # Catch all
    - if <[base_loc]>  == null:
      - run helpers_scrolling_nametag def:farm_broken
      - determine delay:4s

    - define tool_required <proc[helpers_config_for_npc].context[tool_match]>


    # Keeps farm highlight alive for a time
    - run helpers_highlight_farm

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
          - flag <npc> "log:Farmer inventory is full"
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

            - if <[crop].material.age.is[or_more].than[<[crop].material.maximum_age>]>:
              # This complex mantra call as task, waits for it to finish and then sees if it was cancled (errored)
              - define near_crop <proc[helpers_find_safe_loc].context[<npc.location>|<[crop]>]>

              - define sid myscript_<util.current_tick>
              # WARNING: THis method can CHANGE destination due to path blocked. So let it handle any anomolies
              - ~run helpers_walk_to def:<[crop]> save:<[sid]>
              - define results <proc[queue_parse].context[<entry[<[sid]>].created_queue.determination||list[]>]>
              - if <[results].get[cancelled]||false>:
                  # Stop scanning, it gets expensive, just let it try again next opertunity
                  - foreach stop

              # Check (indirectly) if crop is directional (ie; cocoa bans)
              - define prior_crop <[crop].material.name>
              - define direction <[crop].material.direction||null>

              - animate <npc> animation:SWING_MAIN_HAND
              # WAIT for the break to finish, otherwis it can harvest the placed item (even with 3t) delay
              # this was seen with cocoa
              # Prevent modest race conditions where two farmers race to a single crop. THis is not perfect
              # but should prevent most of the "dups"
              - if <[crop].material.name> != air && <[crop].material.age.is[less].than[<[crop].material.maximum_age>]>:
                - stop

              - ~break <[crop]> <npc>

              # Need to wait a tick for item to pop into the world reliably, but for athetics we wait a bit longer
              - wait 3t

              # In theory this could pick up a hoe (or anything) but that's fine since we look in inventory
              # for any NPC items instead o using flags.
              - define nearby_items <npc.location.find_entities[item].within[3]>
              - foreach <[nearby_items]> as:item:
                - give item:<[item].item> to:<npc.inventory>
                - remove <[item]>

              # Plant with what was originally there
              # TODO: Currenlty this does not cost a seed/item to avoid a matrix table of what plants are needed for what.
              #  - I will probably leave this as a bonus since you cannot get enchanted elements and it avoids all kinds
              #  - of inventory reserves and that matrix table I am too lazy to build and maintain
              #       - Remember, the farmer will n REPLANT, they will never plant from scratch.

              - if <[direction]>:
                # No Pyhics is needed during placement , otherwise for coca, vines and other attached blocks the MC engine
                # phtics (block update) can cause th eitem to break. This must be done as well as the waiting break (~break) if using break
                - modifyblock <[crop]> <[prior_crop]>[direction=<[direction]>]  no_physics
              - else:
                - modifyblock <[crop]> <[prior_crop]>

              - define harvested true
              # Only one harvested block per AI run

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

    - define chest_loc <npc.flag[chest_loc]||null>
    - define look_target <[chest_loc].add[0,0,0]>
    - look <npc> <[look_target]>
    - ~walk <npc> <[chest_loc]> speed:1 auto_range

    - define chest <[chest_loc].inventory>

    # Skip air andtool match, unload all the rest
    - define ignore <proc[helpers_config_for_npc].context[tool_match]>
    - define ingnore:->:air
    - define items <npc.inventory.list_contents.filter_tag[<[filter_value].material.name.advanced_matches[<[ignore]>].not>]>
    - foreach <[items]> as:item:
      # Simpel quick check for space available, if not then just stop
      - define space_available <[chest].can_fit[<[item]>]>
      - if <[space_available].not>:
        - stop

      # Inventory sucks -- to avoid ghost items we move by name, it's easier but cannot reliable move
      # special items. Which we do not have.
      # TODO: Consider splitting simple-inventory feeder mover into a procedure, it is a lot more sophisticated
      - take item:<[item].material.name> from:<npc.inventory> quantity:<[item].quantity>
      - give item:<[item].material.name> to:<[chest]> quantity:<[item].quantity>

    - wait 0.25s
    - playsound block.chest.close <[chest_loc]>


# - Famer wanders a bit randomly, turning head looking around and occasionally walking. Simplistic but works
helpers_wander_task:
  type: task
  debug: false
  definitions: force_walk
  script:
    - define farm_area <npc.flag[farm_area]>

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
    - narrate "<green>Following canceled"
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
      #- define npc_start <npc.location>
      # .1 is not enough to break things and is JUST enough to work (even through the common .9374 + .05 is not quite on the surface it is close enough)
      #  Adding .05 worked very well, but still failed
      - teleport <npc> <npc.location.add[0, .1, 0]>
      #- debug log "<aqua>Misalignment detected: adjusting from: <yellow><[npc_loc].y> TO <green><npc.location.y>"
    - define debug_start <npc.location>

    # FInd location to walk to
    - define location <[location].block.add[.5,0,.5]>
    - if <[location].is_passable.not>:
      - define location <proc[helpers_find_safe_loc].context[<npc.location>|<[location]>]>

    - ~walk <npc> <[location]> speed:1 auto_range
    #- debug log "<yellow>FROM: <[debug_start]> TO <green> <[location]>"

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
    # This allows messages to be passed as a LIST of  unspecified size
    - define current_tick <util.current_tick>

    # State is only reset if status is different than prior.
    - define prior_status <npc.flag[status]||null>
    - if <[status]> == null || <[status]> != <[prior_status]>:
      - flag <npc> status:<[status]>
      - flag <npc> message.timer:0
      - flag <npc> emotion.timer:0
      - flag <npc> message.seq:1

    # Recover prior state, if this is too slow then use local variables. But this is cleaner code
    # Do add fallback in case we are initially called with nothing
    - define status <npc.flag[status]||working>
    - define message_timer <npc.flag[message.timer]||0>
    - define message_sequence <npc.flag[message.seq]||1>
    - define emotion_timer <npc.flag[emotion.timer]||0>

    - define messages <proc[helpers_config_for_npc].context[status.<[status]>.messages]>
    - define emotion <proc[helpers_config_for_npc].context[status.<[status]>.emotion]>

    - if <[messages]>:
      - if <[current_tick].sub[<[message_timer]>]> > 40:
        - define message_sequence:++
        - if <[message_sequence]> > <[messages].size>:
          - define message_sequence 1

        - flag <npc> message.timer:<[current_tick]>
        - flag <npc> message.seq:<[message_sequence]>
        - define new_name <[messages].get[<[message_sequence]>]>

        # Per web:
        # this triggers on spawn again if it causes the NPC to be despawned and re-spawned under the hood — which can happen if:
        # You change the NPC’s name while it’s not currently spawned, and then some other code or Citizens automatically respawns it.
        # Or worse: some edge cases in Citizens can cause a name change to trigger a re-initialization that looks like a respawn.
        #
        #  This can be  triggered by a name change due to citizens interactions
        #  Tried teleporting to see if that fixed NPCs with the respawn issue in the on spawn).
        #  And so far nothing is preventing this access except reducing the name change
        - if <npc.is_spawned> and <npc.name> != <[new_name]>:
            #- debug log "NPC <npc> is spawned. Renaming <npc.name> to: <[new_name]>"
            - adjust <npc> name:<[new_name]>

    # In general emotions need to occur on every 5 ticks
    #    This will normallyu always file sinze there are a lot of waits in NPC handling. But some actions may
    #    run considerbly faster (such as following), so add tis to stop massive accumulation
    - if <[emotion]> :
      - if <[current_tick].sub[<[emotion_timer]>]> > 10:
        # Set animation over villager: See also: 
        # - https://meta.denizenscript.com/Docs/Commands/PlayEffect
        # - https://meta.denizenscript.com/Docs/Languages/Particle%20Effects

        - flag <npc> emotion.timer:<[current_tick]>
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


# = Get a list of valid crops
helpers_valid_crops:
  type: procedure
  debug: false
  script:
    - determine <proc[helpers_config_for_npc].context[crops].keys>


# === Find nearest valid NPC structure of any profession
# === TODO: This is sub-optimal, a better way is to find all trigger blocks, then loop through those, but that is more work and this shoudl be plenty fast enought and easier to maintain
# = location : Location to initiate search from.
# = radius : Range around the location to search
helpers_find_nearest_working_area:
  type: procedure
  debug: false
  definitions: location|radius
  script:

    # Location - a reaonable default, mostly for utilities
    - define location <[location]||<player.location>>

    # Find all valid professions
    - define found_profession null
    - define found_farm null
    - define found_chest null
    - define ok false
    - define profession null
    - define valid_triggers <list[]>

    # Create a cuboid to search, radius is a spwhere and a rectangle will work better as above/below is less critical
    #   We coudl search for surface but we need to support underground farms as well
    # Upper / lower cuboid
    # Get blcoks that make up the dection matrix for this farm
    - if <[radius]||null> == null:
      - define radius <proc[helpers_config].context[search_radius]>

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

    # scan each trigger block in the area against every profession to identiy the nearest proper helper working area
    - define found_farm false
    - foreach <[found_triggers]> as:base_loc_tmp :
        - foreach <proc[helpers_config].context[professions]> as:config key:profession :
          # Skip any not enabled, if a farm cannot be found then villager conversion to NPC is also disabled
          - if <[config].get[enabled].if_null[true].not>:
            - foreach next

          - define valid_chests <[config].deep_get[valid_farm.chest]>
          - define trigger_block <[config].deep_get[valid_farm.trigger]>

          #- debug log "<red>Found Potential farm: <[profession]>"

          # See if this structure matches the curent profession, exit ASAP on mismatch
          - if <[base_loc_tmp].material.name> == <[trigger_block]>:
            - if <[found_farm]>:
              - debug log "<aqua>: <[found_farm].distance[<[location]>]> LT? <[base_loc_tmp].distance[<[location]>]>"

              - if <[found_farm].distance[<[location]>]> <= <[base_loc_tmp].distance[<[location]>]>:
                # current potential farm is Further away, ignore it
                #- debug log "<red>Profession farther away: <[profession]> -- <[base_loc_tmp]>"
                - foreach next

          #- debug log "<red>Farm is closer checking strcuture: <[profession]> -- <[base_loc_tmp]>"

          # Check validtiy of farm structure
          - define block_below <[base_loc_tmp].below>
          #- debug log "<aqua>BELOW: <[block_below]>"
          - if <[block_below].material.name> == water or <[block_below].material.waterlogged||false>:
            #- debug log "<red>Found water/logged: <[block_below]>"
            - define block_below <[block_below].below>
          - define base_substrate <[config].deep_get[valid_farm.substrate]>
          #- debug log "<red>Substrate?: <[block_below].material> -- <[base_substrate]>"
          - if <[block_below].material.name.advanced_matches[<[base_substrate]>]>:
            #- debug log "<red>Found Substrate: <[base_substrate]>"
            # See if there is a chest on it
            - define chest_loc_tmp <[base_loc_tmp].add[0,1,0]>
            - if <[chest_loc_tmp].material.name.advanced_matches[<[valid_chests]>]>:
              #- debug log "<red>Found Chest: <[chest_loc_tmp]>"
              - define found_profession <[profession]>
              - define found_farm <[base_loc_tmp]>
              - define found_chest <[chest_loc_tmp]>
              - define found_config <[config]>
              - define ok true
              #- debug log "<red>Farm is valid and closest so far: <[profession]> -- <[base_loc_tmp]>"
              # Found a farm structure, so this composter is fine (if farms are not defined as unique thins become rather non-detrerminstic)
              # I dislike this style but it is better than flags
              - foreach stop

    - if <[ok]>:
      - define farm_area <proc[helpers_get_working_area].context[<[found_farm]>|<[found_config]>]>
      # Save this configruation

    - else:
        - define farm_area null

    - determine <map[ok=<[ok]>;profession=<[found_profession]>;farm=<[found_farm]>;chest=<[found_chest]>;farm_area=<[farm_area]>]>


# - Give an origin identify boundries of a farm based on PLANTED crops
# - of any mix. Designed to be called from `helpers_find_nearest_working_area` and other internal farm maintenance
# - Requires the origin of the farm AND the current config, which is: professions.<[profession]>.....
helpers_get_working_area:
  type: procedure
  debug: false
  definitions: origin|config
  script:
    # TODO: If config is NOT passed pull config data using server flags associated with the origin

    # Relative cordinates for each axis
    - define world <[origin].world.name>
    - define north <proc[helpers_scan_to_edge].context[<[origin]>|<location[0,0,-1]>|<[config]>]>
    - define south <proc[helpers_scan_to_edge].context[<[origin]>|<location[0,0,1]>|<[config]>]>
    - define west <proc[helpers_scan_to_edge].context[<[origin]>|<location[-1,0,0]>|<[config]>]>
    - define east <proc[helpers_scan_to_edge].context[<[origin]>|<location[1,0,0]>|<[config]>]>

    - debug log "<green>N: <[north]>, S: <[south]>, W: <[west]>, E: <[east]> -- <[origin]>"

    - define corner1 <location[<[west].x>,<[origin].y.sub[0]>,<[south].z>,<[world]>]>
    - define corner2 <location[<[east].x>,<[origin].y.add[0]>,<[north].z>,<[world]>]>

    - define farm_area <[corner1].to_cuboid[<[corner2]>]>
    - debug log "<green>Cuboid Farm: <[farm_area]>"
    - determine <[farm_area]>


# - Scan a direction, specified by an relative cordinate (0,0,1) as delta
# - When encountering an invalid crop block stop and return prior value
helpers_scan_to_edge:
  type: procedure
  debug: false
  definitions: origin|delta|config
  script:
    #- debug log "<green>FIND BOUNDS: <[origin]> ----- <[delta]>"

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
          #- debug log "<red>Chect water: <[water_level]> --- <[scan_loc]> -- <[water_level].material.name>"
          # Water like blocks are ALLWOED so if not a water block (and not a valid mat per above) we found an invalid block
          # Probably faster than checking if it can or cannot be waterlogged.
          - if <[water_level].material.name> != water and <[water_level].material.waterlogged.if_null[false].not>:
            - determine <[found_loc]>
      # A valid block was found so add to the list
      - define found_loc <[scan_loc]>

    # Reached maximum distance
    - determine <[found_loc]>



# = Highlight base
# Pass the farm area, if not passed will use curent NPC's farm area, if none then nothin ghighlys
helpers_highlight_farm:
  type: task
  debug: false
  definitions: farm_area|force
  script:
    # Show outline of farm for a few seconds
    - if <[force]||false>:
      - flag server helpers_farm_highlight:<util.current_tick>

    - if <util.current_tick.sub[<server.flag[helpers_farm_highlight]||0>]> < 500:
      - define farm_area <[farm_area]||<npc.flag[farm_area]||null>>
      - if <[farm_area]> == null:
        - stop

      - define y_height <[farm_area].max.y.add[2]>
      - define farm_border <[farm_area].outline_2d[<[y_height]>]>
      - define farm_border <[farm_border].parse_tag[<[parse_value].center>]>
      #- debug log "<gold>Farm border: <[farm_border]>"
      - playeffect effect:flame at:<[farm_border]> quantity:1  visibility:32 offset:0.0,0.1,0.0
      - wait 5t


# = Scan for tool item and if found use it
helpers_pick_up_tool:
  type: task
  debug: false
  script:
    # - Check for HOE pickup
    # - Set area to look equipment being dropped for NPX
    #   Drop area is one below cuboid (items site on TOP of a block so you need to look at the block one below you expect to, or so it seems)
    - define farm_area <npc.flag[farm_area]>
    - define profession <npc.flag[profession]>
    # Expand top and bottom to make it easier to find item sthat might have fallen into water
    # or ot top of something else. It's fast since entity scanning is WAY faster than block scanning
    - define drop_area <[farm_area].expand_one_side[0,-2,0].expand_one_side[0,1,0]>
    - define tool_matcher <proc[helpers_config_for_npc].context[tool_match]>

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
      - debug log "<red>Removing HOE"
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
  definitions: villager|owner|profession
  script:
    - define debug "<gold>NPC Spawn Logic"
    - define location <[villager].location>
    - create player Helper<[profession]> <[location]> save:npc_new
    - define new_npc <entry[npc_new].created_npc>
    - adjust <[new_npc]> owner:<[owner]>
    # remove villager
    - remove <[villager]>

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
      - debug log "<red>Villager at <[location]> cannot find uniform for <[profession]>"

    - adjust <[new_npc]> set_protected:false
    - pushable <[new_npc]>:true
    - adjust <[new_npc]> collidable:true

    - assignment set script:helpers_brain to:<[new_npc]>

# = Fetch the NPC configuration path
# - Uses current NPC
helpers_config_for_npc:
  type: procedure
  definitions: path
  debug: false
  script:
  - define profession <npc.flag[profession]>
  - determine <proc[pl__config].context[helpers.professions.<[profession]>.<[path]>]>

helpers_config:
  type: procedure
  definitions: path
  debug: false
  script:
  - determine <proc[pl__config].context[helpers.<[path]>]||null>


# === Access global farm data. Uses location and a dot seperated path (map) to access Farm data
# - location (an object) of the farm location (composter, etc.) to fetch data for. This results in a MAP
#   - A full location key can be passed, such as from `helpers_farms_flag_all`
# - path (optional) uses deep_get to process traverse the MAP. If not present  (or false) returns the entire location data (relatively small)
# - Returns data found (or whatever type was stored) OR null for not found
helpers_farm_flag_get:
  type: procedure
  definitions: location|path
  debug: false
  script:
    - define data null
    - if <[location]||false>:
        - if <[location].starts_with[helpers_farms_]>:
          - define loc_key <[location]>
        - else:
          - define loc_key helpers_farms_<[location].simple>
        - define data <server.flag[<[loc_key]>].if_null[<map[]>]>
        - if <[path]||false>:
          - define data <[data].deep_get[<[path]>]||null>
    - determine <[data]>


helpers_farm_flag_set:
  type: procedure
  definitions: location|path|value
  debug: false
  script:
    - define data null
    - if <[location]||false>:
        - if <[location].starts_with[helpers_farms_]>:
          - define loc_key <[location]>
        - else:
          - define loc_key helpers_farms_<[location].simple>


        - if <[path]||false>:
          # Fetch data
          - define data <server.flag[<[loc_key]>].if_null[<map[]>]>
          - define data <[data].deep_with[<[path]>].as[<[value]>]>
        - else:
          # Update the ENTIRE KEY
          - flag server <[loc_key]>:<[value]>

    - determine <[value]>


# - returns a list of all helpers_farms_ keys. Suitable fo helpers_farm_flag
helpers_farm_flag_all:
  type: procedure
  debug: false
  script:
    - determine <server.list_flags.filter_tag[<[filter_value].starts_with[helpers_farms_]>]>




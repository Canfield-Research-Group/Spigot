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
      - flag npc farmer_home:<npc.location>
      - trigger name:click state:true
      - trigger name:proximity state:true
      - run farmer_ai_task delay:5s


farmer_ai_task:
  type: task
  debug: false
  script:
    - define crop_type carrots
    - define search_radius 6
    - define home <npc.flag[farmer_home].block>
    - define crop_max_age <material[carrots].maximum_age>
    # If despawned stop script
    - if <npc.is_spawned.not>:
      - stop

    # Check inventory
    - debug log "<aqua>INV B: <npc.inventory.list_contents>"
    - if <npc.inventory.quantity_item> > 4:
        - ~run farmer_deliver_task

    - define crops <[home].find_blocks[<[crop_type]>].within[<[search_radius]>].filter_tag[<[filter_value].material.age.is[or_more].than[<[crop_max_age]>]>]>
    - define harvested false
    - if <[crops].size>:
        - define crop <[crops].get[1]>
        - ~walk <npc> <[crop]> speed:1 auto_range
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
    - run farmer_ai_task id:farmer_ai_<npc.id> delay:2s

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

    - debug log "<gold>Dropping off harvest!"

    - define chest <[chestloc].inventory>
    - define items <npc.inventory.list_contents>

    - playsound block.chest.open <[chestloc]>
    - foreach <[items]> as:item:
      # Simpel quick check for space available, if not then just stop
      - define space_available <[chest].can_fit[<[item]>]>
      - if <[space_available].not>:
        - debug log "<red>Chest full! Stopping transfer."
        - foreach stop
      
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
    - define home <npc.flag[farmer_home]>
    - define xoff <util.random.int[-5].to[5]>
    - define zoff <util.random.int[-5].to[5]>
    - define wander_target <[home].relative[<[xoff]>,0,<[zoff]>]>

    # BUG: IN Denizen if lootat and target are the same the NPC ZOOMS to the target, even when walk speed is 0.5
    # Apparently this is a citizen's thing?????
    # The fix is to look THEN move
    - define look_target <[wander_target].add[0,.5,0]>
    - look <npc> <[look_target]>
    - walk <npc> <[wander_target]> speed:1 auto_range

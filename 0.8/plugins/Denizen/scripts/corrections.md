# Script Corrections


A series of scripts as originally suggested by AI, followed by the corrected versions.


## Farmer_brain

### Has Issues

farmer_brain:
  type: assignment
  actions:
    on assignment:
    - trigger name:click state:true
    - trigger name:proximity state:true
    - run farmer_ai_task delay:5s

farmer_ai_task:
  type: task
  script:
  - while true:
    - define crops <npc.location.find.blocks[potatoes].within[8].filter[is_ageable && age.is[>=].to[7]]>
    - if <[crops].is_empty>:
      - random:
        - walk <npc.location.offset[x=<util.random.int[-5,5]>;z=<util.random.int[-5,5]>]>
        - walk <npc.location.offset[x=<util.random.int[-8,8]>;z=<util.random.int[-8,8]>]>
      - wait 5s
      - queue clear
    - define crop <[crops].random>
    - navigate <[crop].location>
    - wait until <npc.location.distance_squared[<[crop].location]>.lt[2]>
    - modifyblock <[crop].location> air
    - wait 2s
    - modifyblock <[crop].location> potatoes
    - wait 10s

### Corrected with mdoern Denizen

# WIP EXPERIMETNAL

# Farmer for Denizen/Citizen2
# Mostly AI example

# USAGE:
#  /npc create TestFarmer --type player
#  /npc select (click the NPC)
#  /npc assignment --set farmer_brain


farmer_brain:
  type: assignment
  actions:
    on assignment:
    - trigger name:click state:true
    - trigger name:proximity state:true
    - run farmer_ai_task delay:5s

farmer_ai_task:
  type: task
  script:
  - while true:
    - define crops <npc.location.find_blocks[potatoes].within[8].filter[is_ageable && age.is[ge].to[7]]>
    - if <[crops].is_empty>:
      - random:
        - define xoff <util.random.int[-5].to[-5]>
        - define zoff <util.random.int[-5].to[-5]>
        - define wander_target <npc.location.add[x=<[xoff]>;z=<[zoff]>]>
        - walk <[wander_target]>

      - wait 5s
      - stop
    - define crop <[crops].random>
    - walk <npc> <[crop].location> speed:1.5 auto_range
    - wait until <npc.location.distance_squared[<[crop].location>].is[lt].to[2]>
    - modifyblock <[crop].location> air
    # (Optional replant)
    - wait 2s
    - random:
      - modifyblock <[crop].location> wheat
      - modifyblock <[crop].location> potatoes
    - wait 10s

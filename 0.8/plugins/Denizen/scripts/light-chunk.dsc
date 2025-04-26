# === Light a chunk with torches
#  TODO: find a spawnable blocks with 16x16x16 ciboid based on player current chunk
#  TODO: Pull torch from player inventory and place it
#  TODO: wait 1 tick and repeat for every block that is spawnable IN cubiod
#  TODO: charge EXP for each torch placed approx 1 level of exp points (adjust to be fair)
#  TODO: if player moves stop placing torches
#  TODO: if player is already placing torches do not allow movement


# Event trigger: Player left-clicks a block with a stick while holding a torch in the off-hand
torch_trigger:
  type: world
  debug: false
  events:
    on player left clicks block with:torch :
        - if <player.item_in_offhand.material.name> == torch:
            - run torch_placer def:<player>

    on player left clicks block with:emerald_block :
        - run mobcount def:<player>


torch_placer:
  type: task
  debug: false
  definitions: player
  script:
    - define start <util.current_time_millis>
    - define xp_cost_per_torch 10
    - if <[player].inventory.contains_item[torch].not> :
        - narrate "<red>You are out of torches, cannot autoplace."
        - stop

    - if <proc[xp_points_of_player].context[<[player]>]> < 10 :
        - narrate "<red>Not enough XP to place a torch (<[xp_cost_per_torch]>)."
        - stop

    - define base_loc <[player].location>
    - define aligned_x <[base_loc].x.div[16].round_down.mul[16]>
    - define aligned_y <[base_loc].y.div[16].round_down.mul[16]>
    - define aligned_z <[base_loc].z.div[16].round_down.mul[16]>
    - define aligned_loc_lower <location[<[aligned_x]>,<[aligned_y]>,<[aligned_z]>,<[base_loc].world>]>
    - define aligned_loc_upper <[aligned_loc_lower].add[15,15,15]>
    - define scan_area <[aligned_loc_lower].to_cuboid[<[aligned_loc_upper]>]>
    # TODO: If we used the location find spawnable that would be faster as it sorts for use BUT it uses the player center and for game play this uses chunk boundry
    - define spawnable_blocks <[scan_area].spawnable_blocks>

    # Sort by distance using an easy sort, but will tend to calculate distance 3x per location
    - define center <[player].location>
    - define by_distance <list[]>
    - foreach <[spawnable_blocks]> as:loc :
        - define d <[loc].distance[<[center]>]>
        - define by_distance:->:<list[<[d]>|<[loc]>]>
    - define by_distance <[by_distance].sort_by_number[1]>

    # Find first valid (based on light) nearest player
    - foreach <[by_distance]> as:entry :
        - define loc <[entry].get[2]>
        - if <[loc].light.blocks> < 8 :
            - modifyblock <[loc]> torch
            - take item:torch from:<[player].inventory>
            - experience take <[xp_cost_per_torch]> player:<[player]>
            #- define elapsed <util.current_time_millis.sub[<[start]>]>
            #- narrate "<green>Torch placed at <[loc]> using <[xp_cost_per_torch]> XP (<[elapsed]>)."
            - narrate "<green>Torch placed at <[loc]> using <[xp_cost_per_torch]> XP."
            - stop

    #- define elapsed <util.current_time_millis.sub[<[start]>]>
    #- narrate "<yellow>This chunk (16x16x16) is fully lit (<[elapsed]>)."
    - narrate "<yellow>This chunk (16x16x16) is fully lit."
    - stop

# == simple mob count - working
# == TODO: seems a bit OP, proably needs a LOT of experience to use, currently hidden behind needing to know the function
mobcount:
  type: command
  debug: false
  name: mobcount
  description: EXPERIMETNAL Count mobs around player
  usage: /mobcount [radius]
  permission: true
  tab completions:
    1: [radius]
  script:
    # XP of 103 points is around level6.57 and allows 2 scans at level 10
    #   Level 30 is 1,395 points allowing 13 scans for mobs
    #   The 90 XM is probably too low
    - define xp_cost_per_mob_query 90
    - if <proc[xp_points_of_player].context[<player>]> < <[xp_cost_per_mob_query]> :
        - narrate "<red>Not enough XP to do a mob scan (<[xp_cost_per_mob_query]>)."
        - stop

    - define radius <context.args.get[1].if_null[128].max[128]>
    - define mobs <player.location.find_entities[monster].within[<[radius]>]>
    - define mob_types <map[]>
    - define nearest_distance 9999
    - define nearest_mob null
    - define player_loc <player.location>
    - foreach <[mobs]> as:mob:
        - define mob_distance <[mob].location.distance[<[player_loc]>].round>
        - if <[mob_distance]> < <[nearest_distance]>:
            - define nearest_distance <[mob_distance]>
            - define nearest_mob <[mob]>
        - define mob_name <[mob].name>
        # This is WAY WAY more difficult than it shoudl be, it shoudl be one simple command
        - define current <[mob_types].get[<[mob_name]>]||0>
        - define new_value <[current].add[1]>
        - define mob_types <[mob_types].with[<[mob_name]>].as[<[new_value]>]>
    - foreach <[mob_types]> key:mob_name as:count :
        - narrate "<yellow><[mob_name]><yellow> -- <red><[count]><red>"
    - if <[nearest_mob]> == null:
        - narrate "<red>No monstores found in range <[radius]> of player, , XP Cost: <[xp_cost_per_mob_query]>"
    - else:
        - narrate "<red>Monstors within <[radius]> of player: <[mobs].size>, XP Cost: <[xp_cost_per_mob_query]>"
        - if <player.is_op>:
            - define l <proc[location_noworld].context[<[nearest_mob].location>]>
            - narrate "<red>Nearest mob <[nearest_mob].name> at distance <[nearest_distance]> at location <[l]>"
        - else:
            - narrate "<red>Nearest mob <[nearest_mob].name> at distance <[nearest_distance]>"

    - experience take <[xp_cost_per_mob_query]> player:<player>
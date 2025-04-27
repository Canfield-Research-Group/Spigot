# === Light a chunk with torches


# Event trigger: Player left-clicks a block with a stick while holding a torch in the off-hand
# - use a restone torch as a MAGIC WAND with off hand being the type
torch_trigger:
  type: world
  debug: false
  events:
    on player left clicks block with:redstone_torch :
        - if <player.item_in_offhand.material.name> == torch:
            - run torch_placer def:<player>
            - stop

        - if <player.item_in_offhand.material.name> == emerald_block:
            - run mobcount def:<player>
            - stop

torch_placer:
  type: task
  debug: false
  definitions: player
  script:
    - define start <util.current_time_millis>
    - define xp_cost_per_torch <proc[pl__config].context[light-chunk.torch.xp_points]>

    - if <[player].inventory.contains_item[torch].not> :
        - narrate "<red>You are out of torches, cannot autoplace."
        - stop

    - if <proc[xp_points_of_player].context[<[player]>]> < 10 :
        - narrate "<red>Not enough XP to place a torch w(<[xp_cost_per_torch]>)."
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
    #  Uses a blacklist and update as needed.
    - define non_placeable *_leaves
    - foreach <[by_distance]> as:entry :
        - define loc <[entry].get[2]>
        - if <[loc].light.blocks> < 8  and <[loc].below.material.name.advanced_matches[<[non_placeable]>].not>:
            - modifyblock <[loc]> torch
            - take item:torch from:<[player].inventory>
            - experience take <[xp_cost_per_torch]> player:<[player]>
            #- define elapsed <util.current_time_millis.sub[<[start]>]>
            #- narrate "<green>Torch placed at <[loc]> using <[xp_cost_per_torch]> XP (<[elapsed]>)."
            - narrate "<green>Torch placed using <[xp_cost_per_torch]> XP."
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
    # Factor out special permissions to here so it can be disable for testing
    - define is_admin <player.is_op>
    - define is_admin false

    # XP of 103 points is around level6.57 and allows 2 scans at level 10
    #   Level 30 is 1,395 points allowing 13 scans for mobs
    #   The 90 XM is probably too low
    - define xp_cost_per_mob_query <proc[pl__config].context[light-chunk.mobcount.xp_points]>
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

    # A bit OP for anyone to see list, so only OPS player (Add ths as a permisison later)
    - if <[is_admin]>:
        - foreach <[mob_types]> key:mob_name as:count :
            - narrate "<yellow><[mob_name]><yellow> -- <red><[count]><red>"
    - if <[nearest_mob]> == null:
        - narrate "<red>No<gold> monstores found in range <[radius]> of player, (XP Cost: <[xp_cost_per_mob_query]>)"
    - else:
        - narrate "<red><[mobs].size><gold> monstors within <[radius]> of player. (XP Cost: <[xp_cost_per_mob_query]>)"
        - define l <[nearest_mob].location>
        - if <[is_admin]>:
            # Allow ops to see exact location (cleaner)
            - define l <proc[location_noworld].context[<[l]>]>
            - narrate "<gold>Nearest mob <[nearest_mob].name> at distance <[nearest_distance]> at location <[l]>"
        - else:
            # Everyone else gets the chunk center
            - define near_x <[l].x.div[16].round_down.mul[16].add[8]>
            - define near_y <[l].y.div[16].round_down.mul[16].add[8]>
            - define near_z <[l].z.div[16].round_down.mul[16].add[8]>
            #- narrate "<gold>Nearest mob <[nearest_mob].name> at distance <[nearest_distance]> near (<[near_x]>, <[near_y]>, <[near_z]>)"
            - narrate "<gold>Nearest mob is <[nearest_distance]> from player, near (<[near_x]>, <[near_y]>, <[near_z]>)"

    - experience take <[xp_cost_per_mob_query]> player:<player>


lc__help:
  type: command
  name: light-chunk
  description: Mobs and Light control
  usage: /light-chunk [help]
  permission: true
  debug: false
  tab completions:
    1: help
  script:
    # Definitions
    #   none

    - define show_help true
    - define xp_cost_per_torch  <script[lc__config].data_key[data].get[torch].get[xp_points]>
    - define xp_level_torch <proc[xp_level_from_points].context[<[xp_cost_per_torch]>]>
    - define xp_cost_per_mob_query  <script[lc__config].data_key[data].get[mobcount].get[xp_points]>
    - define xp_level_mob_query <proc[xp_level_from_points].context[<[xp_cost_per_mob_query]>]>

    - if <[show_help]>:
        - narrate "<gold>Light Chunk Help:"
        - narrate "<gold>Equip a redstone torch as active item."
        - narrate "<gold>This acts as a 'magic wand'and is activated by stricking."
        - narrate "<gold>A block. All actions are based on players CURRENT LOCATION"
        - narrate "<gold>not the block stricked."
        - narrate "<gold>Action is controlled by <yellow>offhand item"
        - narrate "  <yellow>Torch: Place torch on nearest spawnable dark block"
        - narrate "  <gold>  within PLAYERS cube 16x16x16 aligned on chunk boarder"
        - narrate "  <gold>  Low XP cost <red>(<[xp_cost_per_torch]> / <[xp_level_torch]>L)<gold> to place, 0 xp if chunk is lit"
        - narrate "  <yellow>Emerald Block: Scans 128 blocks (not chunk aligned)."
        - narrate "  <gold>  Lists mob types found, count and distance/chunk cords to nearest mob"
        - narrate "  <gold>  Moderate XP cost <red>(<[xp_cost_per_mob_query]> / <[xp_level_mob_query]>L)"
        - stop


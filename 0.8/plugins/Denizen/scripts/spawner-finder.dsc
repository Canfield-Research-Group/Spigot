#  = Place torches to light up the world as an expanding radius from the player block (manhatten)


# USAGE FROM CONSOLE: exs run spawner_sonar_scanner def:<player[mrakavin]>|1
# Spawner Scanner Script

# Spawner Scanner Script
# ========================
# This script scans for naturally generated spawners (e.g., in dungeons) by examining the world in aligned 16x16x16 cube segments (chunk cubes).
# It uses modern Denizen best practices, throttles based on real-time (ms), and exits early when a spawner is found.

spawner_sonar_scanner:
  type: task
  debug: false
  definitions: player|radius_chunks
  script:
    - debug log "<red>Player: <[player]>"
    - define start_time <util.current_time_millis>
    # Start the timed scan loop based on chunk cube radius
    - run timed_spawner_scan def:<[player]>|<[radius_chunks]> instantly

    - define end_time <util.current_time_millis>
    - define elapsed <[end_time].sub[<[start_time]>]>
    - debug log "<gold>Total scan time: <[elapsed]> ms"

timed_spawner_scan:
  type: task
  debug: false
  definitions: player|radius_chunks
  script:
    # Align to base chunk and Y-layered chunk cube
    - define base_loc <[player].location.chunk>
    - define base_x <[base_loc].x.mul[16]>
    - define base_z <[base_loc].z.mul[16]>
    - define base_y <[player].location.y.div[16].round_down.mul[16]>
    - define scan_count 0
    - define last_wait <util.current_time_millis>

    # Expand scan in all 3 dimensions (chunk cube-based)
    - repeat <[radius_chunks].mul[2].add[1]> from:-<[radius_chunks]> as:cx:
        - repeat <[radius_chunks].mul[2].add[1]> from:-<[radius_chunks]> as:cz:
            - repeat <[radius_chunks].mul[2].add[1]> from:-<[radius_chunks]> as:cy:
                # Throttle if more than 10ms elapsed since last wait
                - define now <util.current_time_millis>
                - if <[now].sub[<[last_wait]>]> > 10:
                    - wait 1t
                    - define last_wait <util.current_time_millis>

                # Calculate origin of current chunk cube
                - define ox <[base_x].add[<[cx].mul[16]>]>
                - define oy <[base_y].add[<[cy].mul[16]>]>
                - define oz <[base_z].add[<[cz].mul[16]>]>
                - define scan_origin <location[<[ox]>,<[oy]>,<[oz]>,<[player].world.name>]>
                - if <[scan_origin].chunk.is_loaded.not>:
                    - debug log "<gold>Chunk at <[scan_origin]> (unloaded) - SKIPPED"
                    - repeat next
                #- debug log "<gold>Scanning chunk cube at origin: <[scan_origin]>"

                # Spot check every 4th block in 3x3x3 grid inside the 16x16x16 cube
                - repeat 3 as:x:
                    - repeat 3 as:y:
                        - repeat 3 as:z:
                            - define dx <[x].mul[4].add[3]>
                            - define dy <[y].mul[4].add[3]>
                            - define dz <[z].mul[4].add[3]>
                            - define pos <[scan_origin].add[<[dx]>,<[dy]>,<[dz]>]>
                            - define mat <[pos].material.name>
                            # Heuristic match: looking for typical dungeon floors
                            - if <[mat]> == cobblestone || <[mat]> == mossy_cobblestone:
                                - debug log "<aqua>Potential dungeon floor at <[pos]>"

                                - define found <[pos].find_blocks[spawner].within[5]>
                                - if <[found].is_empty.not> :
                                    - define spawner_loc <[found].get[1]>
                                    # verify the block under the spawner is desire dtype
                                    - define block_below  <[spawner_loc].add[0,-1,0]>
                                    - define block_name <[block_below].material.name>
                                    - debug log "<red>Below: <[block_name]>"
                                    - if <[block_name].advanced_matches[cobblestone|mossy_cobblestone]> :
                                        - give <item[compass].with[display="Spawner Tracker";lore="Points to a spawner";lodestone_location=<[spawner_loc]>;lodestone_tracked=false]> to:<[player].inventory>
                                        - debug log "<green>Found: <[spawner_loc]>, Type: <[spawner_loc].spawner_type>"
                                        - stop
                                    - else :
                                        - debug log "<yellow>Not native spawner: <[spawner_loc]>, Type: <[spawner_loc].spawner_type>"
                            - if false :
                                - repeat 10 as:x:
                                    - repeat 10 as:y:
                                        - repeat 10 as:z:
                                            # Get center
                                            - define dx <[x].sub[5]>
                                            - define dy <[y].sub[5]>
                                            - define dz <[z].sub[5]>
                                            - define spawner_scan <[pos].add[<[dx]>,<[dy]>,<[dz]>]>
                                            - debug log "<red>Pos: <[spawner_scan]> contains: <[spawner_scan].material.name>"
                                            - if <[spawner_scan].material.name> == mob_spawner:
                                                - define mob_type <[spawner_scan].spawner_type||null>
                                                # Call the report before stopping to ensure result is logged
                                                - debug log "<green>Spawner found at <[location]> with mob: <[mob_type]>"
                                                #- run report_spawner def:<[pos]>|<[mob_type]>
                                                #- determine <[mob_type]>
                                                - stop

# == simple mob count - working
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
    - define radius <context.args.get[1]||128>
    - define mobs <player.location.find_entities[monster].within[<[radius]>]>
    - define mob_types <map[]>
    - foreach <[mobs]> as:mob:
        - define mob_name <[mob].name>
        - debug log "<green><[mob_name]>"
        # This is WAY WAY more difficult than it shoudl be, it shoudl be one simple command
        - define current <[mob_types].get[<[mob_name]>]||0>
        - define new_value <[current].add[1]>
        - define mob_types <[mob_types].with[<[mob_name]>].as[<[new_value]>]>
    - foreach <[mob_types]> key:mob_name as:count :
        - narrate "<yellow><[mob_name]><yellow> -- <red><[count]><red>"
    - narrate "<red>Total monstors within <[radius]> of player is <[mobs].size>"

#  = Place torches to light up the world as an expanding radius from the player block (manhatten)


# - works, but does not grow in expanding circles -- consider using a cuboid that expands  by 4 in all directions. Then search
# - every 4 (2d) of each face. This should realtively fast 

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
    - define base_loc <[player].location.chunk>
    - define player_y <[player].location.y>
    
    - run chunk_spawner_scan def:<[base_loc]>|<[player_y]>|<[radius_chunks]> save:scan_spawners speed:0
    - while <entry[scan_spawners].created_queue.is_valid>:
        - debug log "<gold>Waiting for async"
        - wait 10t

    - narrate "<red>Found spawnes: <entry[scan_spawners].created_queue.determination.formatted>"


    - define end_time <util.current_time_millis>
    - define elapsed <[end_time].sub[<[start_time]>]>
    - debug log "<gold>Total scan time: <[elapsed]> ms"


    - stop

    # verify the block under the spawner is desire dtype
    - define block_below  <[spawner_loc].add[0,-1,0]>
    - define block_name <[block_below].material.name>
    - debug log "<red>Below: <[block_name]>"

    - if <[block_below].material.name.advanced_matches[cobblestone|mossy_cobblestone]> :
        - give <item[compass].with[display="Spawner Tracker";lore="Points to a spawner";lodestone_location=<[spawner_loc]>;lodestone_tracked=false]> to:<[player].inventory>
        - debug log "<green>Found: <[spawner_loc]>, Type: <[spawner_loc].spawner_type>"
        - stop
    - else :
        - debug log "<yellow>Not native spawner: <[spawner_loc]>, Type: <[spawner_loc].spawner_type>"



chunk_spawner_scan:
  type: task
  debug: false
  definitions: base_loc|player_y|radius_chunks
  script:
    # Align to base chunk and Y-layered chunk cube

    - define base_x <[base_loc].x.mul[16]>
    - define base_z <[base_loc].z.mul[16]>
    - define base_y <[player_y].div[16].round_down.mul[16]>
    - define scan_count 0
    - define found_spawners <list[]>
    - define world_name <[base_loc].world.name>
    - define last_wait <util.current_time_millis>

    # Expand scan in all 3 dimensions (chunk cube-based)
    - repeat <[radius_chunks].mul[2].add[1]> from:-<[radius_chunks]> as:cx:
        - repeat <[radius_chunks].mul[2].add[1]> from:-<[radius_chunks]> as:cz:
            - repeat <[radius_chunks].mul[2].add[1]> from:-<[radius_chunks]> as:cy:
                - define scan_count:++

                # Calculate origin of current chunk cube
                - define ox <[base_x].add[<[cx].mul[16]>]>
                - define oy <[base_y].add[<[cy].mul[16]>]>
                - define oz <[base_z].add[<[cz].mul[16]>]>
                - define scan_origin <location[<[ox]>,<[oy]>,<[oz]>,<[world_name]>]>
                # ASSUME we always have loaded since this is around player location
                - if <[scan_origin].chunk.is_loaded.not>:
                    #- debug log "<gold>Chunk at <[scan_origin]> (unloaded) - SKIPPED"
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

                                - if true:
                                    # = find_blocks is a tad faster but less flexible
                                    # - Radius 6 is enough since we scan very 4 and more optimizsations are likley possible
                                    - repeat 6 as:x:
                                        - repeat 6 as:y:
                                            - repeat 6 as:z:
                                                # Get center
                                                - define dx <[x].sub[3]>
                                                - define dy <[y].sub[3]>
                                                - define dz <[z].sub[3]>
                                                - define spawner_scan <[pos].add[<[dx]>,<[dy]>,<[dz]>]>
                                                #- debug log "<red>Pos: <[spawner_scan]> contains: <[spawner_scan].material.name>"
                                                - if <[spawner_scan].material.name> == spawner:
                                                    - debug log "<green>Spawner found at <[spawner_scan]>"
                                                    - define found_spawners:->:spawner_scan

                                                # - define mob_type <[spawner_scan].spawner_type||null>
                                                    # Call the report before stopping to ensure result is logged
                                                    #- debug log "<green>Spawner found at <[location]> with mob: <[mob_type]>"
                                                    #- run report_spawner def:<[pos]>|<[mob_type]>
                                                    #- determine <[mob_type]>
                                                    #- stop

                                - else :
                                    # = NOTE: this can apparently be slower than manual loop as it plays it safes and drops to SYNC mode plus it will scan, on average, more blocks than the manual loop
                                    # = but I found this to actually be a tad faster
                                    - define found <[pos].find_blocks[spawner].within[5]>
                                    - if <[found].is_empty.not> :
                                        - define spawner_loc <[found].get[1]>
                                        - define found_spawners:->:<[spawner_loc]>
                                        - debug log "<green>Spawner confirmed <[spawner_loc]>"

                            # Throttle if more than 10ms elapsed since last wait
                            - define now <util.current_time_millis>
                            - if <[now].sub[<[last_wait]>]> > 5:
                                - wait 1t
                                - define last_wait <util.current_time_millis>
                #- if <[scan_count].mod[10]> == 0:
                #    - wait 1t

    - debug log "<red>Scan Count: <[scan_count]>"
    - determine <[found_spawners]>



sonar_spawner_scan:
  type: task
  debug: false
  definitions: base_loc|player_y|radius_chunks
  script:
    # Align to base chunk and Y-layered chunk cube

    # = TODO: this is currently a copy of chunk scanning mode -- try to use cuboid surface scanning.

    - define base_x <[base_loc].x.mul[16]>
    - define base_z <[base_loc].z.mul[16]>
    - define base_y <[player_y].div[16].round_down.mul[16]>
    - define scan_count 0
    - define found_spawners <list[]>
    - define world_name <[base_loc].world.name>
    - define last_wait <util.current_time_millis>

    # Expand scan in all 3 dimensions (chunk cube-based)
    - repeat <[radius_chunks].mul[2].add[1]> from:-<[radius_chunks]> as:cx:
        - repeat <[radius_chunks].mul[2].add[1]> from:-<[radius_chunks]> as:cz:
            - repeat <[radius_chunks].mul[2].add[1]> from:-<[radius_chunks]> as:cy:
                - define scan_count:++

                # Calculate origin of current chunk cube
                - define ox <[base_x].add[<[cx].mul[16]>]>
                - define oy <[base_y].add[<[cy].mul[16]>]>
                - define oz <[base_z].add[<[cz].mul[16]>]>
                - define scan_origin <location[<[ox]>,<[oy]>,<[oz]>,<[world_name]>]>
                # ASSUME we always have loaded since this is around player location
                - if <[scan_origin].chunk.is_loaded.not>:
                    #- debug log "<gold>Chunk at <[scan_origin]> (unloaded) - SKIPPED"
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

                                - if true:
                                    # = find_blocks is a tad faster but less flexible
                                    # - Radius 6 is enough since we scan very 4 and more optimizsations are likley possible
                                    - repeat 6 as:x:
                                        - repeat 6 as:y:
                                            - repeat 6 as:z:
                                                # Get center
                                                - define dx <[x].sub[3]>
                                                - define dy <[y].sub[3]>
                                                - define dz <[z].sub[3]>
                                                - define spawner_scan <[pos].add[<[dx]>,<[dy]>,<[dz]>]>
                                                #- debug log "<red>Pos: <[spawner_scan]> contains: <[spawner_scan].material.name>"
                                                - if <[spawner_scan].material.name> == spawner:
                                                    - debug log "<green>Spawner found at <[spawner_scan]>"
                                                    - define found_spawners:->:spawner_scan

                                                # - define mob_type <[spawner_scan].spawner_type||null>
                                                    # Call the report before stopping to ensure result is logged
                                                    #- debug log "<green>Spawner found at <[location]> with mob: <[mob_type]>"
                                                    #- run report_spawner def:<[pos]>|<[mob_type]>
                                                    #- determine <[mob_type]>
                                                    #- stop

                                - else :
                                    # = NOTE: this can apparently be slower than manual loop as it plays it safes and drops to SYNC mode plus it will scan, on average, more blocks than the manual loop
                                    # = but I found this to actually be a tad faster
                                    - define found <[pos].find_blocks[spawner].within[5]>
                                    - if <[found].is_empty.not> :
                                        - define spawner_loc <[found].get[1]>
                                        - define found_spawners:->:<[spawner_loc]>
                                        - debug log "<green>Spawner confirmed <[spawner_loc]>"

                            # Throttle if more than 10ms elapsed since last wait
                            - define now <util.current_time_millis>
                            - if <[now].sub[<[last_wait]>]> > 5:
                                - wait 1t
                                - define last_wait <util.current_time_millis>
                #- if <[scan_count].mod[10]> == 0:
                #    - wait 1t

    - debug log "<red>Scan Count: <[scan_count]>"
    - determine <[found_spawners]>







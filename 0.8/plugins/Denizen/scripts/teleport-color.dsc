# Simple color chained teleport
#
# Create: Create copper block, place a carpet on top
# Remove: Break carpet.
# Usage: Crouch on top of carpet for approx 1 second, be carefuill to be on the carpet.
# Dimension Suport: Fully supports mulieple dimensions including PhantomWorlds.
#
# Every teleport is grouped by player and carpet color. This means that PlayerA's blue telporters are a distinct
# group to PlayerB's blue teleporters. Teleporters can be used by any player but the groups are local to each player.
#
# Limitation: breaking Copper block does NOT remove the teleport from internal matrix BUT will cause
# issues.

teleporter_script:
  type: world
  debug: false
  events:

    # Track copper + carpet placement
    on player places *_carpet:
      - if <proc[is_base_block].context[<context.location.below.material>]>:
          - run add_teleporter def:<player>|<context.location>

    on player breaks *_carpet:
      - if <proc[is_base_block].context[<context.location.below.material>]>:
        # The tilde (~) allows the run in the same queue which allows the CANCEL via determine to be propogated to the orihiona event
        - ~run remove_teleporter def:<player>|<context.location>|<context.material.name>
        - if <player.flag[teleport_delete]||0> == 0:
          - determine cancelled


    # Detect sneaking on teleporter
    on player starts sneaking:
      # For carpet the player is actually hovering a tad above it (what a mess)
      - define loc <player.location.block>
      - define mat <[loc].material.name>
      - define under <[loc].below.material.name>
      - if <[mat].ends_with[_carpet]> && <proc[is_base_block].context[<[loc].below.material>]>:
        - run begin_teleport def:<player>|<[loc]>

# Add a teleporter to player storage
add_teleporter:
  type: task
  debug: false
  definitions: player|loc
  script:
    - define color <[loc].material.name>
    - define loc_key <[loc].simple>
    - define path teleporters.<[color]>.<[loc_key]>

    - if <[player].has_flag[<[path]>]>:
        - stop

    - define base_path teleporters.<[color]>
    - define group_teleporters <[player].flag[<[base_path]>]>

    # Check if color group already has too many teleporters
    - if <[group_teleporters].size> >= 16:
        - narrate "<red>You already have 16 <[color]> teleporters." targets:<[player]>
        - stop

    - define created <util.current_time_millis>
    # DO NOT add spaces around semi-collons or '=' these will contirbute to the KEY name.'
    - define data_map <map[loc=<[loc]>;created=<[created]>;owner=<player.name>]>
    - flag <[player]>  teleporters.<[color]>.<[loc_key]>:<[data_map]>

    - narrate "<green>Teleporter added: <[color]> for <[player].name>"


remove_teleporter:
  type: task
  debug: false
  definitions: player|loc|color
  script:
    # WARNING: Call via '~run' to allow cancel to get passed back to event
    - define loc_key <[loc].simple>
    - define path teleporters.<[color]>.<[loc_key]>
    - define owner null

    # It is most common that the current player is the owner but that adds a number of more lines
    # and the modest performance gain is not worth it for a seldom used operation
    - define all_players <proc[get_all_players]>
    - foreach <[all_players]> as:check:
      - if <[check].has_flag[<[path]>]>:
          - define owner <[check]>
          - foreach stop

    # This check is a PAIN in the ass because Denizen parser is HORRID
    - define allow_removal false
    - if <[owner]> == null:
      - narrate "<red>Teleport structure detected but not not in list; allowing it to break"
      # This is an exception allow it to break normally (no flag changes)
      - flag player teleport_delete:1
      - determine cancelled
      - stop
    - else if <[owner].name.to_lowercase> == <[player].name.to_lowercase> || <player.is_op>:
      - define allow_removal true
    - else:
      - narrate "<red>Teleport cannot be deleted by you <[player].name>, check with owner <[owner].name>"

    - if <[allow_removal]>:
      # Step 3: Delete from owner's flags
      - flag <[owner]> <[path]>:!
      - flag player teleport_delete:1
      - narrate "<yellow>Teleporter removed: <[color]> (owner: <[owner].name>)"
    - else:
      - flag player teleport_delete:0 duration:1s
      - determine cancelled



# Begin crouch detection
begin_teleport:
  type: task
  debug: false
  definitions: player|loc
  script:
    - wait 1s
    # Make sure player is still senaking after 1 second AND in the same location (they did not move, use block rounding to avoid jitter)
    - if <[player].is_sneaking> && <[player].location.block> == <[loc].block>:
      - run do_teleport def:<[player]>|<[loc]>

# Perform teleport
#  * fix_only : (0) : If truethy will ONLY fix teleporters, otherwise will fix AND teleport player
do_teleport:
  type: task
  debug: false
  definitions: player|loc
  script:
    # Get material color (carpet) and loc key
    - define color <[loc].material.name>
    - define loc_key <[loc].simple>
    - define owner null

    # Find the owner of this teleporter (online only)
    - define all_players <proc[get_all_players]>
    - foreach <[all_players]> as:player_search:
        - if <[player_search].has_flag[teleporters.<[color]>.<[loc_key]>]>:
            - define owner <[player_search]>
            - foreach stop

    - if <[owner]> == null:
        - narrate  "<red>Teleporter at <[loc]> has no known owner. Please report as a bug."
        - stop

    # Retrieve teleporter map for owner and color
    - define map <proc[get_teleporter_list].context[<[owner]>|<[color]>]>
    - if <[map].size> <= 1:
        - narrate "<gold>Only one teleporter in group; no teleport triggered."
        - stop

    # Scan loop (once) finding first / next assuming 'created' is unique
    - define first null
    - define next null

    # Avoid nesting tags when possible, it more than not fails in Denzien parser and makes things more complicated
    - define item <[map].get[<[loc_key]>]>
    - define current_created <[item].get[created]>

    - foreach <[map].keys> as:key:
        - define item <[map].get[<[key]>]>
        - define found_loc <[item].get[loc]>

        - define chunk <[found_loc].chunk>
        - if !<[chunk].is_loaded>:
          - chunkload <[chunk]>
          - wait 1t


        # Remove and skip teleporters that are broken (often from a deleted world or bug/development)
        - define world <[loc].world>

        # TIP: Checking for is_loaded is NOT always going to work since the world may never have been loaded
        # BUT MInecraft always loads base worlds and IF we force Phantomworld to auto load it's worlds
        # then is_loaded  will work. Otherwise things get a lot more complex with file checking and
        # force loading worlds since Denizen cannot access files OUTSIDE Denizen folder we cannot check for the
        # world files existing on disk.!!!
        - if !<server.worlds.contains[<[world]>]>:
            - define is_valid false
        - else if !<[found_loc].material.name.ends_with[_carpet]>:
            - define is_valid false
        - else:
            - define is_valid true

        - if <[is_valid]>:
          - define teleporter_current <[item].get[created]>
          # Track lowest for firtst
          - if <[first]> == null || <[teleporter_current]> < <[first].get[created]>:
              - define first <[item]>

          # Track nearest higher (wraps)
          - if <[teleporter_current]> > <[current_created]>:
              - if <[next]> == null || <[teleporter_current]> <[next].get[created]>:
                  - define next <[item]>
        - else:
          - narrate "<gold>Found broken teleport, removed and skipping: <[found_loc]>"
          - flag <[owner]> teleporters.<[color]>.<[key]>:!

    # identify where to go, this shoudl always find a match since we checked for more than 1 teleporter abobe
    - if <[next]> !=  null:
      - define found <[next]>
    - else if <[first]> !=  null:
      - define found <[first]>
    - else:
        - narrate "<gold>Cannot find another teleporer in color group. Posisbly due to cleanup of broken teleporters."
        - stop

    # Find next teleport target (with wraparound)
    - define next_loc <[found].get[loc]>

    # Teleport and show effect
    - teleport <[player]> <[next_loc].add[0,1,0]>
    - playeffect <[next_loc].add[0,1,0]> effect:ender_signal visibility:50



is_base_block:
  type: procedure
  debug: false
  definitions: material
  script:
  - define name <[material].name.to_lowercase>
  - if <[name].ends_with[_copper]> || <[name]> == copper_block:
      - determine true
  - determine false


get_teleporter_list:
  type: procedure
  definitions: player|color
  debug: false
  script:
    - if <[player].has_flag[teleporters.<[color]>]>:
        - determine <[player].flag[teleporters.<[color]>].as[map]>
    - determine <map[]>


# *** COMMANDS
teleport_color_commands:
  type: command
  name: teleport-color
  debug: false
  description: Manages teleport color teleporters
  usage: /teleport-color [clear | list | assign ] [color|all] [player (OP only)]
  tab complete:
    - define sub <context.args.get[1]||null>
    - if <[sub]> == null:
        - determine <list[clear|list|assign]>
    - if <[sub]> == "clear" || <[sub]> == "list":
        - define colors <player.flag[teleporters].keys||list[]>
        - define suggestions <[colors].parse[].include[all]>
        - determine <[suggestions]>
    - if <[sub]> == "assign":
        - define suggestions <list[]>
        - determine <[suggestions]>
    - determine <list[]>

  script:
    - define sub <context.args.get[1]||null>
    - define color <context.args.get[2].to_lowercase||all>
    - define target <player>

    # Optional player override for OPs
    - if <context.args.size> > 2:
        - if !<player.is_op>:
            - narrate "<red>You do not have permission to manage other players' teleporters." targets:<player>
            - stop

        - define player_name <context.args.get[3]>
        # Match_offline_ wills earch for online/offline by a case insensitive flexible matching.
        # The online_players and offline_players are specific to these states.
        - define target <server.match_offline_player[<[player_name]>]>
        - if <[target]> == -1:
            - narrate "<red>Player '<context.args.get[3]>' not found." targets:<player>
            - stop

    # === CLEAR MODE ===
    - if <[sub]> == "clear":
        - define base <[target].flag[teleporters]>
        - if <[color]> == "all":
            - flag <[target]> teleporters:!
            - narrate "<gray>All teleporters1 cleared for <[target].name>." targets:<player>
            - stop
        - if !<[base].keys.contains[<[color]>]>:
            - narrate "<red>No teleporters found for color '<[color]>'." targets:<player>
            - stop
        - flag <[target]> teleporters.<[color]>:!
        - narrate "<gray>Teleporters for color '<[color]>' cleared for <[target].name>. (BUT remain in world)" targets:<player>
        - stop

    # === LIST MODE ===
    - if <[sub]> == "list":
        - define base <[target].flag[teleporters]>
        - if <[base].keys.is_empty>:
            - narrate "<red><[target].name> has no teleporters saved." targets:<player>
            - stop
        - if <[color]> == "all":
            - narrate "<green>Teleporters for <[target].name>:"
            - foreach <[base].keys> as:color:
                - define locs <[base].get[<[color]>]>
                - foreach <[locs]> as:loc:
                    - narrate " - <[color]>: <[loc]>" targets:<player>
            - stop
        - if !<[base].keys.contains[<[color]>]>:
            - narrate "<red>No teleporters found for color '<[color]>' for <[target].name>." targets:<player>
            - stop
        - define locs <[base].get[<[color]>]>
        - if <[locs].is_empty>:
            - narrate "<red>No teleport locations saved under: <[color]>." targets:<player>
            - stop
        - narrate "<green>Teleporters for color <[color]> (<[target].name>):" targets:<player>
        - foreach <[locs]>:
            - narrate " - <[value]>" targets:<player>
        - stop


    # Removes teleporters that are no longer present
    # === Repair MODE ===
    # REMOVED - teleports auto repair on use

    # === ASSIGN MODE ===
    # Handles multi-assignment (repair) only keeper assigned user and remove from all others
    - if <[sub]> == "assign":
        - if !<player.is_op>:
            - narrate "<red>You must be an OP to use this command." targets:<player>
            - stop
        - if <context.args.size> < 2:
            - narrate "<red>Usage: /teleport-color assign <player>" targets:<player>
            - stop

        # Determine new owner
        - define new_owner_name <context.args.get[2]>
        - define new_owner <server.match_offline_player[<[new_owner_name]>]>
        - if <[new_owner]> == -1:
            - narrate "<red>Player '<[new_owner_name]>' not found." targets:<player>
            - stop

        # Check if this looks like a teleporter
        - define loc <player.location.block>
        - define mat <[loc].material.name>
        - if !(<[mat].ends_with[_carpet]> && <proc[is_base_block].context[<[loc].below.material>]>):
          - narrate "<red>Player is not standing on a teleporter."
          - stop

        # Find telepoeter, performance is not an issue here so write easiets code possible
        - define loc_key <[loc].simple>
        - define color <[loc].material.name>
        - define path teleporters.<[color]>.<[loc_key]>

        # Search all players for the current owner
        - define all_players <proc[get_all_players]>
        - define old_owner null
        - foreach <[all_players]> as:check:
            - if <[check].has_flag[<[path]>]>:
                # SUppot cleanup code for accidental multi-ownership. That is possible
                # due to bugs or sometimes using ASSIGN in creative mode
                - if <[old_owner]> != null:
                  - flag <[check]> <[path]>:!
                  - narrate  "<yellow>Teleporter multi-assigned remove duplicate owner: <[check].name>"
                - else:
                  - define old_owner <[check]>

        - if <[old_owner]> == null:
            - narrate "<red>No existing owner found for this teleporter." targets:<player>
            - stop

        # Copy flag to new owner and remove from old
        - define data <[old_owner].flag[<[path]>]>
        - if <[data]> == null:
            - narrate "<red>Teleporter exists but could not retrieve data. Plrease report bug." targets:<player>
            - stop
        - flag <[old_owner]> <[path]>:!
        # Add telpoter via normal task. Can use three types:
        #  * def: prefix with '| delimiter: '  def:<[new_owner]>|<[loc]>
        #  * def.def-name (see task defintions:) def.player:<[new_owner]> def.loc:<[loc]>
        #     * I like this as it is rather self documenting
        #  * Or a weird compresse style: https://meta.denizenscript.com/Docs/Search/run
        - run add_teleporter def.player:<[new_owner]> def.loc:<[loc]>
        - narrate "<green>Teleporter reassigned to <[new_owner].name>. (was <[old_owner].name>)" targets:<player>
        - stop

    # === UNKNOWN SUBCOMMAND ===
    - narrate "<red>Usage: /teleport-color [clear|list] [color|all] [player (op only)]" targets:<player>

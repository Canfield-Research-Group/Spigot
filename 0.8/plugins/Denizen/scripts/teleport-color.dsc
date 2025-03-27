# Simple color chained teleport

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
      - run remove_teleporter def:<player>|<context.location>|<context.material.name>

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
    - define list <proc[get_teleporter_list].context[<player>|<[color]>]>
    - if <[list].contains[<[loc]>]>:
        - stop
    - if <[list].size> >= 16:
        - narrate "<red>You already have 16 <[color]> teleporters." targets:<[player]>
        - stop
    - flag <[player]> teleporters.<[color]>:->:<[loc]>
    - narrate "<green>Teleporter added: <[color]>" targets:<[player]>


# Remove teleporter from player storage
remove_teleporter:
  type: task
  debug: false
  definitions: player|loc|color
  script:
    - flag <[player]> teleporters.<[color]>:<-:<[loc]>
    - narrate "<yellow>Teleporter removed: <[color]>" targets:<[player]>


# Begin crouch detection
begin_teleport:
  type: task
  debug: false
  definitions: player|loc
  script:
    - wait 1s
    # Make sure player is still senaking after 1 second AND in the same location (they did not move)
    - if <[player].is_sneaking> && <[player].location.block> == <[loc]>:
      - run do_teleport def:<[player]>|<[loc]>

# Perform teleport
do_teleport:
  type: task
  debug: false
  definitions: player|loc
  script:
    - define color <[loc].material.name>
    - define list <proc[get_teleporter_list].context[<[player]>|<[color]>]>
    - if <[list].size> <= 1:
      - stop
    # Denizen index_of forces the search key to a string BUT the elements we are searching on are
    # NOT strings and so the match fails. Normally that is a -1 but due to weird Denzien coercion that is turned
    # in 22 due to weird deep bugs/processes.
    # FIX: Either loop on the array and manually process it
    #- define norm_list <[list].map[<entry.simple>]>
    #- define index <[norm_list].index_of[<[loc].simple>]>

    # NOTE: Denizien lists start at (1) not (0) but algorithmically it is easier
    # to assume a zero offset and fix at the end. This makes wrapping easier
    - define counter 0
    - define index -1
    - define loc_simple <[loc].simple>
    - foreach <[list]> as:val:
      - define val_simple <[val].simple>
      - if <[val].simple> == <[loc_simple]>:
        - define index <[counter]>
        # THis requires a realrive mdoern Denizien (works as of this attempt on 2025-03-25)
        - foreach stop
      - define counter <[counter].add[1]>

    - if <[index]> == -1:
        - debug error "<red>Teleport origin <[loc]> not found in list: <[list]>"
        - stop
    # mod keeps the next_index within list size (0,1,2) and as such auto wraps for us without a condition being needed
    - define next_index <[index].add[1].mod[<[list].size>]>
    # NOW we need to tweak the index to be offset 1 for Denziein
    - define next <[list].get[<[next_index].add[1]>]>
    - teleport <[player]> <[next].add[0,1,0]>
    - playeffect <[next].add[0,1,0]> effect:ender_signal visibility:50


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
        - define list <[player].flag[teleporters.<[color]>]>
    - else:
        - define list <list[]>
    - determine <[list]>


# *** COMMANDS
teleport_color_commands:
  type: command
  name: teleport-color
  description: Manages teleport color teleporters
  usage: /teleport-color [clear | list] [color|all] [player (OP only)]
  tab complete:
    - define sub <context.args.get[1]||null>
    - if <[sub]> == null:
        - determine <list[clear|list]>
    - if <[sub]> == "clear" || <[sub]> == "list":
        - define colors <player.flag[teleporters].keys||list[]>
        - define suggestions <[colors].parse[].include[all]>
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
        - define target <server.match_player[<context.args.get[3]>]>
        - if <[target]> == null:
            - narrate "<red>Player '<context.args.get[3]>' not found." targets:<player>
            - stop

    # === CLEAR MODE ===
    - if <[sub]> == "clear":
        - define base <[target].flag[teleporters]>
        - if <[color]> == "all":
            - flag <[target]> teleporters:!
            - narrate "<gray>All teleporters cleared for <[target].name>." targets:<player>
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
        - narrate "<green>Teleporters for color <[color]> (<[target].name]>):" targets:<player>
        - foreach <[locs]>:
            - narrate " - <[value]>" targets:<player>
        - stop

    # === UNKNOWN SUBCOMMAND ===
    - narrate "<red>Usage: /teleport-color [clear|list] [color|all] [player (op only)]" targets:<player>

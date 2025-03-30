# Keep x chunks around the player's current spawn loaded


bed_chunk_loader:
  type: world
  debug: false
  events:
    # Startup task to initialize chunk loading for all online players

    on server start:
        - run bed_enable_chunkloader_all

    # Trigger on player join to set up initial chunk load
    on player joins:
        # Just re-scan for evbery player, should not be a performance issue
        - run bed_enable_chunkloader_for_player context:<player>

    # Detect a player adding a bed
    on player places *_bed:
        # Wait for event to fire (a few ticks is enough)
        - wait 2t
        - narrate "<green>Tip: Bed placement detected, chunk loading updated"
        - run bed_enable_chunkloader_for_player context:<player>

    # Detect when player right-clicks a bed to possibly set spawn
    on player right clicks *_bed:
        # Wait for event to fire (a few ticks is enough)
        - wait 2t
        - define bed_loc <context.location>
        - define current_spawn <player.bed_spawn||null>
        - if <[current_spawn]> == null || <[bed_loc]>.simple != <[current_spawn]>.simple:
            - narrate "<green>Spawn point update detected. Updating chunk loader..."
            - run bed_enable_chunkloader_for_player context:<player>

    # If a bed block is broken, check if it's a spawn point for any player
    #   * this allows any player to break a bed, arguably this should NOT be allowed, but for now just handle it
    on player breaks *_bed:
        - define broken_bed <context.location>
        - define all_players <proc[get_all_players]>
        - foreach <[all_players]> as:pl:
            - define bed_chunk <[broken_bed].chunk>
            - define pl_chunk <[pl].bed_spawn.chunk>
            - debug debug "<red>Break : <[bed_chunk]>  --- <[pl_chunk]>"
            - if <[bed_chunk]> == <[pl_chunk]>:
                - run bed_disable_chunkloader_for_player context:<[pl]>
                - narrate "<red>Bed at <[pl].name> at <[bed_chunk]> was removed. Chunk loading disabled."

# Contants
bed_chunk_constants:
  type: procedure
  definitions: key
  script:
    - choose <[key]>:
        - case chunk_radius:
            - determine 5


# Refresh all players spawn chunks
bed_enable_chunkloader_all:
  type: task
  script:
    - define all_players <proc[get_all_players]>
    - foreach <[all_players]> as:owner:
        - run bed_enable_chunkloader_for_player context:<player>
    # Auto repair
    - run bed_enable_chunkloader_all delay:5m


# Refresh chunk loading for a specific player
bed_enable_chunkloader_for_player:
  type: task
  debug: false
  definitions: player
  script:
    # Block radius around bed (should match default_radius)
    - define bed_loc <[player].bed_spawn>
    - if <[bed_loc]||null> == null:
        - stop

    # Make sure old spawn is removed
    - run bed_disable_chunkloader_for_player context:<player>

    - define center_chunk <[bed_loc].chunk>
    - define chunk_radius <proc[bed_chunk_constants].context[chunk_radius]>
    - define loaded_chunks <list[]>
    - define world <[bed_loc].world.name>

    - define range_x <util.list_numbers[from=-<[chunk_radius]>;to=<[chunk_radius]>]>
    - foreach <[range_x]> as:dx:
        - define cx <[center_chunk].x.add[<[dx]>]>
        - define range_z <util.list_numbers[from=-<[chunk_radius]>;to=<[chunk_radius]>]>
        - foreach <[range_z]> as:dz:
            - define cz <[center_chunk].z.add[<[dz]>]>
            # Oddly enough, Denizen, does NOT allow chunk cordinates to be used to creat a chunk tag, so convert to blocks -- gotta love this mess
            - define block_loc <location[<[cx].mul[16]>,64,<[cz].mul[16]>,<[world]>]>
            - define chunk_loc <[block_loc].chunk>
            - if !<[chunk_loc].is_loaded>:
                - chunkload <[chunk_loc]>
            - define loaded_chunks <[loaded_chunks].include[<[chunk_loc]>]>

    - flag <[player]> bed_chunks:<[loaded_chunks]>


# Disable chunks for player
bed_disable_chunkloader_for_player:
  type: task
  definitions: owner
  script:
    # Block radius around bed (should match default_radius)
    - if <[owner].has_flag[bed_chunks]>:
        - define player_chunks <[owner].flag[bed_chunks]>
        - foreach <[player_chunks]> as:chunk:
            - if <[chunk].is_loaded>:
                - chunkload remove <[chunk]>
        - flag <[owner]> bed_chunks:!


# ***
# *** Commands for Bedchunks management
# ***
bedchunks_command:
  type: command
  name: bedchunks
  usage: /bedchunks [reload|show]
  description: Manage bed chunk loading
  permission: op
  script:
    - define sub <context.args.get[1]||null>

    - if <[sub]> == reload:
        - if !<player.is_op>:
            - narrate "<red>Op required to manage bed chunks"
            - stop
        - run bedchunks_reload_cmd
        - stop

    - if <[sub]> == show:
        - run bedchunks_show_cmd
        - stop

    - narrate "<red>Usage: /bedchunks [reload|show]"

bedchunks_reload_cmd:
  type: task
  script:
    - run bed_enable_chunkloader_all
    - narrate "<green>Chunk loading triggered for all players."

bedchunks_show_cmd:
  type: task
  script:
    - define chunks <player.flag[bed_chunks]||list[]>
    - if <[chunks].is_empty>:
        - narrate "<gold>No spawn chunks identified. Do you have a bed?"
    - else:
        - define first_chunk <[chunks].get[1]>
        - define last_chunk <[chunks].get[<[chunks].size>]>
        - narrate "<green>Player bed chunks:"
        - narrate "  <green>First: <yellow><[first_chunk].simple>"
        - narrate "  <green>Last: <yellow><[last_chunk].simple>"
        - narrate "  <green>Total: <yellow><[chunks].size> chunks"

# Keep x chunks around the player's current spawn loaded


bed_chunk_loader:
  type: world
  debug: false
  events:
    # Startup task to initialize chunk loading for all online players

    on server start:
        - run bed_reload

    on script reload:
        - run bed_reload


    on system time minutely:
        - define chunk_refresh <proc[bed_chunk_constants].context[chunk_refresh_minutes]>
        - if <context.minute.mod[<[chunk_refresh]>]> == 0:
            - run bed_reload

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
            - if <[bed_chunk]> == <[pl_chunk]>:
                - run bed_disable_chunkloader_for_player context:<[pl]>
                - narrate "<red>Bed at <[pl].name> at <[bed_chunk]> was removed. Chunk loading disabled."

# Contants
bed_chunk_constants:
  type: procedure
  definitions: key
  debug: false
  script:
    - choose <[key]>:
        - case chunk_radius:
            - determine 5
        - case chunk_refresh_minutes:
            - determine 2
        - case chunk_ttl_minutes:
            # Chunk time to libe shoudl be a least a minute or 2 more than refresh to deal with lag.
            # Do NOT use really long times as we count on the chunk live (Denizen) to cleanup chunks
            # to avoid SLOW chunk unload lops in the script.
            - determine 5


# Run bed refresh with an ID to avoid multiple queus running
bed_reload:
    type: task
    debug: false
    script:
        - run bed_enable_chunkloader_all id:bed_chunkloader_refresh


# Refresh all players spawn chunks
bed_enable_chunkloader_all:
  type: task
  debug: false
  script:
    - define all_players <proc[get_all_players]>
    - foreach <[all_players]> as:owner:
        - run bed_enable_chunkloader_for_player context:<[owner]>
        # Wait 1 tick beteween players
        - wait 1t


# Refresh chunk loading for a specific player
bed_enable_chunkloader_for_player:
  type: task
  debug: false
  definitions: owner
  script:
    # Block radius around bed (should match default_radius)
    - define bed_loc <[owner].bed_spawn>
    - if <[bed_loc]||null> == null:
        - stop

    - define start_time <util.current_time_millis>
    - define trigger_time <[start_time]>
    # Make sure old spawn is removed
    - define center_chunk <[bed_loc].chunk>
    - define chunk_radius <proc[bed_chunk_constants].context[chunk_radius]>
    - define chunk_ttl <proc[bed_chunk_constants].context[chunk_ttl_minutes]>m
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
            # TIP use `if !<[chunk_loc].is_loaded>` is not really needed and did not impact script time

            # Only keep chunks loaded for a bit over the refresh time. This removes the need
            # to have this tas clean up old chunks which gets a tad complex. It does mean that
            # it's possible to add/remove many beds to temporarily have a LOT of chunks loaded.
            #   * Not considered a huge deal for polite players, and if not pllite BAN them
            #   * TODO: Compare arrays and only remove beds that are in the old list and not new list
            - chunkload <[chunk_loc]> duration:<[chunk_ttl]>
            - define loaded_chunks <[loaded_chunks].include[<[chunk_loc]>]>
            - define now_time <util.current_time_millis>
            # One tick is 20ms so this should limit us to 1 tick (approx) at a time making this a VERY light weight operation
            # especially as it runs on events and every few minutes
            - if <[now_time].sub[<[trigger_time]>]> > 1:
                # Instead of using a count, let's trigger when time is exuaysed
                - wait 1t
                - define trigger_time <util.current_time_millis>

    - flag <[owner]> bed_chunks:<[loaded_chunks]>
    - define elapsed <util.current_time_millis.sub[<[start_time]>]>

# Disable chunks for player
bed_disable_chunkloader_for_player:
  type: task
  debug: false
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
  debug: false
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
  debug: false
  script:
    - run bed_enable_chunkloader_all
    - narrate "<green>Chunk loading triggered for all players."


bedchunks_show_cmd:
  type: task
  debug: false
  script:
    - define chunks <player.flag[bed_chunks]||list[]>
    - if <[chunks].is_empty>:
        - narrate "<gold>No spawn chunks identified. Do you have a bed?"
    - else:
        - define loaded 0
        - define first_chunk <[chunks].get[1]>
        - define last_chunk <[chunks].get[<[chunks].size>]>
        - foreach <[chunks]> as:chunk:
            - if <[chunk].is_loaded>:
                - define loaded <[loaded].add[1]>

        - narrate "<green>Player bed chunks:"
        - narrate "  <green>First: <yellow><[first_chunk].simple>"
        - narrate "  <green>Last: <yellow><[last_chunk].simple>"
        - narrate "  <green>Total: <yellow><[chunks].size> chunks"
        - narrate "  <green>Total: <yellow><[loaded]> loaded"

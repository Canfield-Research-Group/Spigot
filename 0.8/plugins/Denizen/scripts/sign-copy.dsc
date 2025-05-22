
#== A very simple sign copy
# Sign Copy mod.
# Created to work with Simple Inventory and make it easier to copy signs when
# moving inventory, adding multiple inventory with the same sign, and other
# sign operations. But does not require any other Denizen scripts
# 
# Usage: left click on a sign to copy it. Breaking a sign is considered an aggressive left
# click and will also copy the sign tot he sign clipboard. When another sign is edited either though normal
# edit sign OR placing a new sign then the sign  clipboard will be applied ONLY if the edited
# sign is BLANK.
# 
# A simple message is presented on each copy/paste. Use the /sign-copy quiet/verbose to disable enable
# that.
# 
# TIPS:
# 
# A single space will prevent the copy from occurring
# The clipboard is cleared after being applied. This makes things consistent. To chain copy
# Simple Left Click to COPY, place new sign, left click to copy, place new sign, etc.

sci__sign_copy_events:
  type: world
  debug: false
  events:

    after player changes sign:
        # We cannot intercept the bEFORE CHANGE or apply the change on placement
        # BEFORE dit appears (edit is manage dby Minecraft and we have no BEFORE for it)
        #  To AVOID applying buffer just set sign to anything including a space
        - define copied_text <player.flag[sc.sign_copy]||null>
        - if <[copied_text]> != null:
            - define existing_length <context.location.sign_contents.separated_by[].length||0>
            - if <[existing_length]> == 0:
                - if !<player.has_flag[sc.quiet]||false>:
                    - narrate "<green>Text applied, and clipboard cleared"
                - sign <[copied_text]> <context.location>
                # Clear sign clipboard otherwise there is no easy way to do that
                # - to copy to multiples just left click on sign you just placed
                - flag <player> sc.sign_copy:!

                # DO NOT copy on change sign - it gets too confusing, especially since edit sign
                # pops up for sign placement as well


    # === on player left clicks *_sign:
    on player left clicks *_sign:
        - run sc__copy_sign_text def:<player>|<context.location>

    # === Sign broken ===
    on player breaks *_sign:
        # A simple undo AND is kind of a left click so grab it
        - run sc__copy_sign_text def:<player>|<context.location>


# ===Copies text from sign into player's sign copy
sc__copy_sign_text:
    type: task
    definitions: player|sign_loc
    debug: false
    script:
        # Instead of geting fancy I am going to do a DEAD SIMPLE code.
        # If not a sign object then SKIP IT, and if no text skip it
        - define sign_contents <[sign_loc].sign_contents||null>
        - if <[sign_contents]> != null:
            # Save sign contents only if NOT blank (blanks do NOT count)
            - define existing_length <[sign_contents].separated_by[].trim.length||0>
            - if <[existing_length]> > 0:
                - flag <[player]> sc.sign_copy:<[sign_contents]>
                - if !<[player].has_flag[sc.quiet]||false>:
                    - narrate "<yellow>Copied text to clipboard"



sc__help:
  type: command
  name: sign-copy
  description: Control sign copy
  usage: /sign-copy [player] help/quiet/verbose]
  debug: false
  permission: true
  tab completions:
    # This will complete any online player name for the second argument
    1: <proc[get_all_players].parse[name]>
    # This will complete "alpha" and "beta" for the first argument
    2: help|quiet|verbose

  script:
      # Definitions
    - define owner <context.args.get[1]>
    - define command <context.args.get[2]||help>

    # Help block (called when command is missing or unknown)
    - define show_help false
    - if <[command]> == help:
        - define show_help true
    - if <context.args.size> < 2:
        - define show_help true
    - if <list[quiet|verbose].contains_text[<[command].to_lowercase>].not>:
        - define show_help true

    - if <[show_help]>:
        - narrate "<gold>Sign Copy:"
        - narrate "<yellow>/simple-inventory [player] quiet"
        - narrate "<gray> Disables copy/paste messages"
        - narrate "<yellow>/simple-inventory [player] verbose"
        - narrate "<gray>  Enables copy/paste messages"
        - narrate "<yellow>Usage"
        - narrate "<gray>  Left click/beak a sign to copy sign text to sign clipboard"
        - narrate "<gray>  Edit/Add a sign, leave text empty, any sign clipboard"
        - narrate "<gray>  will be applied and cleared."
        - narrate "<gray>  Tip: A single space will prevent clipboard from being applied"
        - stop

    # Match_offline_ wills earch for online/offline by a case insensitive flexible matching.
    # The online_players and offline_players are specific to these states.
    - define all_players <proc[get_all_players]>
    - define found <[all_players].filter_tag[<[filter_value].name.to_lowercase.contains[<[owner].to_lowercase>]>]>
    - if <[found].is_empty> :
        - narrate "<red>Player '<[owner]>' match not found."
        - stop
    - define owner <[found].get[1]>

    - if <player.is_op.not> and <[owner].uuid> != <player.uuid>:
        - narrate "<red>Only OPs can specify other players, please use your own name."
        - stop

    - if <[command]> == quiet:
        # Using '||' fallback is not reliable in Denizen due to parser limitations
        - flag <[owner]> sc.quiet:true
        - narrate "<yellow>Sign copy will be quiet, see help"

    - if <[command]> == verbose:
        # Using '||' fallback is not reliable in Denizen due to parser limitations
        - if <[owner].has_flag[sc.quiet]>:
            - flag <[owner]> sc.quiet:!
        - narrate "<green>Sign copy status will be displayed in chat. See help"


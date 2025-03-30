

# STATE:
#   Everything seems to be working, some targets may need to be tweaked


# Call as: proc.PluralizeCount.context[my-text|integer]
# Returns: "<integer> <my-text><optional-s>"
# Tip: Do NOT quote the text when making a call as the quotes WILL become part of the output string
PluralizeCount:
    debug: false
    type: procedure
    definitions: text | count
    script:
        # Callers need to pass the text WIHOUT quotes. We trim it in case spaces are adding around PIPE cahracter
        - define phrase "<[count]> <[text].trim>"
        - if <[count]> != 1:
            - define phrase <[phrase]>s
        - determine <[phrase]>


# ****************
# * General scan for items procedure. Uses a passed matrix and types to locate items
# *
# ****************
scanForItems:
    debug: true
    type: task
    # Tip: The MAP must be done last, otherwise the following '|' option seems to modify the map and breaks it
    #   matrix : MAP keyed by off hand element name, then the keys
    #   dry-run: Optional but if TRUE then enables a info only message (no block scan) to indicate costs and detected tool attributes
    #   loc: (optional) The context of the block hit, used for fix of items in bedrock
    definitions: matrix|dry_run|struck_loc
    script:
        # in  case the scan peformed is still set
        - flag <player> scan_performed:!

        # NOTE: cooldown  commands do NOT seem very reliable for some reason. But PLAYER based  flags using expire work reliably
        #  - Be carefuls as the flag will NOT exist initially so check for that
        #  - TIP: Expired flags return NULL which is fine for this scripts needs
        - if <player.has_flag[cooldown_scanner]>:
            #- narrate "COOLING DOWN"
            - stop
        - else:
            # Use tick cooldown, 2t seems generous enough and catches more double events than 1t
            - flag <player> cooldown_scanner:true expire:2t

        - define scan_status ok

        - define sample <player.item_in_offhand>
        - define sample_name <[sample].material.name>
        - define holding <player.item_in_hand>

        # Get elements from the matrix that control costs
        #  TODO: make the lookup a procedure that tracks errors and allows them to be checked at end for an abort (????)
        - define error 0
        - define matrix_type <[matrix.type]>
        - if <[matrix_type]> == null:
            - debug ERROR "Missing 'type' in matrix, suggestion: block | entity"
            - define error 1
        - define scan_range <[matrix.scan_range]>
        - if <[scan_range]> == null:
            - debug ERROR "Missing 'scan_range' in matrix, suggestion: 8"
            - define error 1
        - define durability_area_type <[matrix.durability_area_type]>
        - if <[durability_area_type]> == null:
            - debug ERROR "Missing 'durability_area_type' in matrix, suggestion: circle"
            - define error 1
        - define durability_cost <[matrix.durability_cost]>
        - if <[durability_cost]> == null:
            - debug ERROR "Missing 'matrix.durability_cost' in matrix, suggestion: 0.375 - branch mining ratio"
            - define error 1
        - define durability_custom_multiplier <[matrix.durability_custom_multiplier]>
        - if <[durability_custom_multiplier]> == null:
            - debug ERROR "Missing 'matrix.durability_custom_multiplier' in matrix, suggession: 2"
            - define error 1
        - define golden_scan_range_multipler <[matrix.golden_scan_range_multipler]>
        - if <[golden_scan_range_multipler]> == null:
            - debug ERROR "Missing 'matrix.golden_scan_range_multipler' in matrix, suggesion: 2"
            - define error 1
        - define golden_durability_as <[matrix.golden_durability_as]>
        - if <[golden_durability_as]> == null:
            # all tools os same material are same durability. But best to use the same tool as EVENT in case mods changed stuff
            - debug ERROR "Missing 'matrix.golden_durability_as' in matrix, suggesion: golden_pickaxe | golden_sword"
            - define error 1

        # Check the above if any are null abort the script
        # This ends up with tons of lines or a few lines but in any case it rather sucks
        - if <[error]>:
            - debug ERROR "Missing data in matrix, see error logs. Aborting."
            - stop

        # Set default
        - define is_applicable false
        - define scan_targets false
        - define found_location false

        # if sample_name item has a matrix then use that list, otherwise use the block held AS the scanning block
        - if <[matrix.samples].contains[<[sample_name]>]>:
            - define is_applicable true
            - define scan_target_specs <[matrix.samples.<[sample_name]>]>
            - define scan_message <[scan_target_specs.message]>
            - if  <[scan_target_specs].contains[targets]>:
                - define scan_targets <[scan_target_specs.targets]>
            - else:
                - debug ERROR "Scan samples.<[sample_name]> missing key (targets) for "
                - stop
        - else if <[durability_custom_multiplier]> > 0:
            # EXPERIMENTAL: Use th offhand item as a search filter. The issue is the item held is NOT always obvious.
            # for example 'wheat' is a BLOCK and fully grown wheet can be found WITH a pickaxe!
            - if <material[<[sample_name]>].is_block>:
                - if <[holding].material.name> matches *_sword:
                    - define is_applicable false
                    - define scan_status wrong_tool_pickaxe_required
            - else:
                - else if <[holding].material.name> matches *_pickaxe:
                    # Pretty much anything else is allowed. Unless it is a block (not in the whitelist)
                    # for example WHEAT is considerd a block but seeds are not
                    - define is_applicable false
                    - define scan_status wrong_tool_sword_required

            # If scan sample_name is not in matrix then adjust duability cost by multiplier
            # If everything is OK so far, See if offhand is applicable - no wrning as this action may be done in some other context
            - if <[is_applicable]>:
                - define scan_message <[sample_name].to_sentence_case>
                - define scan_targets <list[<[sample_name]>]>
                # Adjust durability multiplier
                - define durability_cost <[durability_cost].mul[<[durability_custom_multiplier]>]>

        # To support a better '/scanner info' result do this check after the tool check
        - if <player.item_in_offhand.material.name> == air:
            - define scan_status offhand_is_empty
            - define is_applicable false
        - else if <player.item_in_offhand.material.name> matches *_shield:
            - define scan_status offhand_has_a_shield
            - define is_applicable false

        - define is_golden false
        - if <[holding].material.name> matches golden_*:
            - define is_golden true

        # Make scan targets a matches string
        - define scan_targets_matching <list>
        - if <[scan_targets]>:
            - define scan_targets_matching <[scan_targets].separated_by[|]>

        # See if the current item being looked at matches the target, if so skip it (waste of time)
        #   - TIP: .target. works only for entities NOT blocks. And we don't want to use context for damage here
        #   here as he INFO command does nto require that AND if the player's cursor is on it it should obviously be visible
        - if <player.cursor_on.material.name> matches <[scan_targets_matching]>:
            - define scan_status you_are_looking_at_it
            - define is_applicable false



        # *****************
        # ** Only process the rest of the script if the action appears valid
        # *****************
        - if <[is_applicable]>:
            # All conditions passed so scanning is applicable

            # Calculate cost based on area type. This is done BEFORE golden check which just increases elemetns for FREE
            # util.pi should work, pi might, maybe math.pi NOPE and I am tired of tracking it down. Cool idea but the language is  tedious. Maybe due to Java
            - define pi 3.14159
            - choose <[durability_area_type]>:
                - case fixed:
                    - define durability_area 1
                - case sphere:
                    # (pi * r^3 * 4/3)
                    - define range_cubed <[scan_range].power[3]>
                    - define durability_area <[range_cubed].mul[<[pi]>].mul[4].div[3]>
                - case circle:
                    # (pi * r^2)
                    - define range_squared <[scan_range].power[2]>
                    - define durability_area <[range_squared].mul[<[pi]>]>
                - case square:
                    # (r*2)^3
                    - define length_size <[scan_range].mul[2]>
                    - define durability_area <[length_size].power[3]>
                - case cube:
                    # (r*2)^2
                    - define length_size <[scan_range].mul[<[pi]>]>
                    - define durability_area <[length_size].power[2]>
                - default:
                    - debug debug "WARNING: the durability_area_type (<[durability_area_type]>) is not known. Aborting"
                    - determine cancelled
                    - stop

            # Allow GOLD items (theya re more magical) alter scan range without changing area cose
            # and scale durability to act as if they are a different item
            - if <[is_golden]>:
                - define scan_range <[scan_range].mul[<[golden_scan_range_multipler]>]>

                # Adjust duability factor to make golden look like whatever was specified
                - define item_durability_max <[holding].max_durability>
                - define item_durability_masquerade <item[<[golden_durability_as]>].max_durability>
                - define item_durability_scale <[item_durability_max].div[<[item_durability_masquerade]>]>
                - define durability_cost <[durability_cost].mul[<[item_durability_scale]>]>

            # Calculate total durability adjustment - round otherwise gold adjustmes get far too cheap and for others
            # it has minimal effect
            - define durability_adjustment <[durability_cost].mul[<[durability_area]>].round>

            # Get item current durability and max. Note that current is AMOUNT of durabiliity USED, not what is left. So 0 is NOT USED yet
            - define tool_durability_max <[holding].max_durability>
            - define tool_durability_current <[holding].durability>
            # Get a value showing how much is available
            - define tool_durability_remaining <[tool_durability_max].sub[<[tool_durability_current]>]>
            - if <[tool_durability_remaining]> < <[durability_adjustment]>:
                - define scan_allowed false
                - define scan_status tool_too_week
                - define scan_result_message "WARING: Tool does not have enough durability to scan with. Need <[durability_adjustment]> but only have <[tool_durability_remaining]> from a max of <[tool_durability_max]> left"
                # set durability to no effective change allowing caller to always adjust durability and be safe doing so
                - define tool_durability_new <[tooL_durability_current]>
            - else:
                - define scan_allowed true
                - define tool_durability_new <[tool_durability_current].add[<[durability_adjustment]>]>

            # Turn off scan if in dry-run
            - if <[dry_run]>:
                - define scan_allowed false

            # Perform the search only if allowed
            - if <[scan_allowed]> || <player.gamemode> == creative::
                - if <[matrix_type]> == block:
                    - define found <player.location.find_blocks[<[scan_targets_matching]>].within[<[scan_range]>]>
                - else:
                    - define found <player.location.find_entities[<[scan_targets_matching]>].within[<[scan_range]>]>

                # process results
                - if <[found].any>:
                    - define found_count <[found].size>
                    - define found_nearest <[found].get[1]>
                    - if <[matrix_type]> == block:
                        # Blocks return a list of locations for find, so that's perfect
                        - define found_location <[found_nearest]>
                        - define found_name <[found_nearest].block.material.name>
                    - else:
                        # Entities return a list of entitiy loctions for find, so we need a location
                        - define found_location <[found_nearest].location>
                        # Normalize the item
                        - define found_name <[found_nearest].name>

                    # make item found a bit more readsbale
                    - define found_name <[found_name].to_sentence_case>

                    - define found_distance <player.location.distance[<[found_location]>].round>

                    # For this message assume the scan range is ALWAYS > 1 and skip plurazing it
                    # Since values can change over time apply them all to result at end : not entirely happy with this construct but it keeps things together and is easier to check security
                    - define found_distance_text <proc[PluralizeCount].context[block|<[found_distance]>]>
                    - define scan_result_message "<[found_name]> <[found_distance_text]> away. Scanned for: <[scan_message]>, Detected: <[found_count]>, In Spherical radius: <[scan_range]> blocks."
                    - define scan_status found
                - else:
                    - define scan_result_message "No (<[scan_message]>) found within a sphere of radius <[scan_range]> blocks around the player"
                    - define scan_status nothing_found



        - define better_tool_avail false
        - if !<[is_golden]>:
            # A .hotbar.  does not seem present so use slots 0 - 9
            # Determin what item to look for, to handle future items limit to know golden element
            - if <[holding]> matches *_sword:
                - define look_for golden_sword
            - else if <[holding]> matches *_pickaxe:
                - define look_for golden_pickaxe
            - else:
                - define look_for false

            - if <[look_for]>:
                - repeat 9:
                    - define slot <player.inventory.slot[<[value]>].material.name>
                    - if <[slot]> == <[look_for]>:
                        - define better_tool_avail true
                        #- inventory adjust slot:<player.held_item_slot> destination:<[value]>
                        #- narrate "Automatically changed in hand to: <[look_for]>. See /scanner auto off"
                        ## Since we are in a loop this only exist the loop
                        #- stop


        # Check for info message at end but do not show sections that are not applicable due to earlier halting
        - if <[dry_run]>:
            # Generate an INFO message
            # Disable applicable flag to avoid any additional work
            - narrate "*** Scanner Status (no scan performed)"
            - if <[is_applicable]>:
                - narrate  " - Scan valid: Yes -- Scan would run"
            - else:
                - narrate  " - Scan valid: NO -- Scan would NOT run, see below"
            - narrate " - Status: <[scan_status]>"
            - narrate " - In hand: <[holding].material.name>"
            - if <[is_golden]>:
                - define t Yes
                - define golden_message "(golden adjusted)"
            - else:
                - define t No
                - define golden_message <empty>
            - narrate " - Using golden tool: <[t]>"
            - if <material[<[sample_name]>].is_block>:
                - define t block
                - if <[holding].material.name> matches *_sword:
                    - define t "<[t]> (tip: use a pickaxe)"
            - else:
                - define t entity
                - if ! <[holding].material.name> matches *_pickaxe:
                    - define t "<[t]> (tip: use a sword)"
            - narrate " - Off hand: <[sample_name]> of type <[t]>"
            - if <[better_tool_avail]>:
                - narrate "- TIP: You may want to use your GOLDEN tool for scanning"
            - if <[is_applicable]>:
                - narrate " - Will scan for: <[scan_message]>"
                - narrate " - Scan range: <[scan_range]> spherical redius <[golden_message]>"
                - narrate " - Item Durability: <[tool_durability_remaining]> from max <[tool_durability_max]>"
                - narrate " - Durability cost: <[durability_adjustment]> <[golden_message]>"
                - define uses <[tool_durability_remaining].div[<[durability_adjustment]>].round>
                - narrate " - Scans left: <[uses]>"
                - narrate " - See also: /scanner help"

            - define is_applicable false


        # *****
        # Handle results
        - if <[is_applicable]>:
            # Fix (2025) for cases where an item might be trapped in unreakble blocks which is VERY frustrating foe the player. This
            # happens most often for diamonds in bedrock. There are number of potential solutions:
            #   * scanner could ignore blocks that are unreachable. This can be done by a 6 sided scan for any unbreakable but that
            #   is not overly reliable, there is still a chance the target block could be trapped. Making the scan even harder/slower
            #       * Plus tt is really tedious to find items in bedrock, so frustraing users often avoid that area.
            #   * Destroy the block in the way even if unbreakable
            #       * BAD idea to break unbreakable blocks
            #       * Denizen does not allow this, only Creative Mode allows this
            #   * Retrieve block as if user hit it with the tool
            #       * For gameplay ignore distance (sine there is no guarentee the user can get within range)
            #       * Do not require anything beyond sensore durability as that is just tedious. Besides bedrock sucks anyway
            #       * This is just a cool advanced extra ability ASSUMING user hit the bedrock
            #       * Not ideal, seems a tad OP so make sure user is facing proper direction?
            #
            # Check if current context (the block hit)
            #
            # To reduce confusion avoid the GOLD detection check on unbrekablae as this also avoids the requirement for a QUICK STRIKE
            - if <proc[is_block_unbreakable].context[<[struck_loc]>]> && <[scan_status]> != tool_too_week:
                - define tool <player.item_in_hand>
                - define drops <[found_location].drops[<[tool]>]>
                - if <[drops].is_empty>:
                    # More help would be nice but very long:
                    #   Example: Found item in unbreakable area, but current tool cannot mine the detected item. Use a better tool to scan and enable remote mining of the item. Be sure to be in range of the target item when using the new tool."
                    - narrate "<gold>Hit in unbreakable area, but your tool can't REMOTE mine the found item. Use a stronger tool to scan and remote-mine. Stay in range!"
                - else:
                    - foreach <[drops]>:
                        # Applies to curent user, no need for player
                        - give <[value]>
                        - modifyblock <[found_location]> air
                        - playeffect effect:BLOCK_BREAK <[found_location]> data:<[found_location].material>
                        - narrate "<gold>Remote mining triggered: Hit on Unbrekable block area detected and block was retrived."
                        - define scan_durability_triggered true
            - else:
                - if <[better_tool_avail]> && !<player.has_flag[better_tool_available]>:
                    - playsound <player.location> sound:ENTITY_GLOW_SQUID_SQUIRT
                    - narrate "- TIP: You may want to use your GOLDEN tool for scanning, stricke again rapidly to force scan using current tool."
                    - flag <player> better_tool_available:true expire:10t
                - else:
                    # Adjust durability since script reached here and nothing blew up!
                    - if <[scan_status]> == tool_too_week:
                        - playsound <player.location> sound:ENTITY_ITEM_BREAK
                        - narrate "WARNING: Tool too weak to scan"
                    - else:
                        - narrate <[scan_result_message]>
                        - define scan_durability_triggered true

            - if <[scan_durability_triggered]>:
                - if <player.gamemode> != creative:
                    # - Must use an inventory item for this - see https://meta.denizenscript.com/Docs/Search/durability
                    #   - See also hammer script: https://forum.denizenscript.com/resources/hammer-time-incl-resource-pack.104/updates#resource-update-181
                    - inventory adjust slot:hand durability:<[tool_durability_new]>

                - if <[found_location]>:
                    - look <player> <[found_location]>
                # clear flag even if it has not expired
                - flag <player> better_tool_available!

                    # Set flag if scan was OR would have been done so caller can cancel context as needed to allow events to propogate
                - flag <player> scan_performed:true


# Scanner help pages
#   - simple help screen that hopefully is concise in describing how to use this mod
scanner_command:
  type: command
  debug: true
  name: scanner
  description: Scanner help
  usage: /scanner help [page]
  #permission: scanner.use
  script:
    - if <context.args.is_empty>:
        - define command help
        - define new_args <list>
    - else:
        # args count the options from the command
        - define command <context.args.get[1]>
        # shift off that item to reveal reaminng args
        - define new_args <context.args.remove[1]>

    - choose <[command]>:
        - case help:
            - if <[new_args].is_empty>:
                - define page intro
            - else:
                - define page <[new_args].get[1]>
            - run scannerCommandHelp def.page:<[page]>
        - case info:
            - run scannerCommandInfo

        - default:
            - narrate "*** ERROR: Operation not known: help | info"



# Info page
#   - simple help screen that hopefully is concise in describing how to use this mod
scannerCommandInfo:
  type: task
  debug: false
  name: scanner_command_info
  description: Scanner info
  script:
    - run scanForItems def.matrix:<script[ScannerTypes].data_key[data.mining]> def.dry_run:true


# *****************
# * Process the (scanner help [page]) command
scannerCommandHelp:
    type: task
    debug: false
    name: scanner_command_help
    description: Scanner help
    definitions: page

    script:
        - define matrix <script[ScannerTypes].data_key[data]>
        - choose <[page]>:
            - case intro:
                #          <========== Chat Width ==============================>
                - narrate <empty>
                - narrate "***** Intro *****"
                - narrate "Will scan for blocks/items and rotate the player to face the"
                - narrate "nearest one. Type type of scan is based on the active tool"
                - narrate "and what to scan for is managed by the item in you OFFFHAND."
                - narrate "Finally CROUCH then right click (like normal mining or attack)"
                - narrate "to engage the scanner."
                - narrate <empty>
                - narrate "An off hand of AIR or a Shield is always ignored and no scan"
                - narrate "action will occur."
                - narrate <empty>
                - narrate "Tip: use '/scanner info' to see what the scan would do. This ignores"
                - narrate "crouching."

                # https://meta.denizenscript.com/Docs/Search/click#&click.type
                - narrate <proc[scannerHelpLinks].context[tips|blocks]>

            - case blocks:
                - narrate <empty>
                - run scanForItems def.dry_run:false def.matrix:<script[ScannerTypes].data_key[data.mining]>
                - narrate "***** Scanning for Blocks *****"
                - define type <[matrix.mining]>
                - narrate "Block scan within a radius of <[type.scan_range]> blocks."
                - narrate "Enabled by equiping a Pickaxe and the scan item in offhand:"
                - foreach <[type.samples]> key:key as:search_pattern:
                    - debug debug "KEY: <[key]> --- <[search_pattern]>""
                    - narrate " - <[key].to_sentence_case>: <[search_pattern.message]>"
                - narrate " - Other blocks: Scan for this block (cost 2x)"
                - narrate " - Tip: Silk touch is normally needed to get a specific block"
                - narrate <proc[scannerHelpLinks].context[intro|entities]>


            - case entities:
                - narrate <empty>
                - narrate "***** Scanning for Items *****"
                - define type <[matrix.creatures]>
                - narrate "Item/Entity scan within a radius of <[type.scan_range]> blocks."
                - narrate "Enabled by equiping a Sword and the scan item in offhand:"
                - foreach <[type.samples]> key:key as:search_pattern:
                    - debug debug "KEY: <[key]> --- <[search_pattern]>""
                    - narrate " - <[key].to_sentence_case>: <[search_pattern.message]>"
                - narrate " - Other Items: Scan for this item (cost 2x)"
                - narrate " - Tip: Items can be pecular and tricky. Consider using the"
                - narrate "   the above defined items to avoid waisting durability."
                - narrate <proc[scannerHelpLinks].context[blocks|golden]>

            - case golden:
                - narrate <empty>
                - narrate "***** Using Golden Tools *****"
                - narrate "Golden tools are very useful for scanning with. They increase"
                - narrate "the range (usually 2x) with no extra durability cost."
                - narrate " Additionally Golden tool durability is, for purposes of"
                - narrate " scanning, the same as Netherite tools."
                - narrate <empty>
                - narrate "Consider using gold tools when scanning then swap to a another"
                - narrate "tool for mining, hunting, exploring, etc."
                - narrate <proc[scannerHelpLinks].context[entities|tips]>

            - case tips:
                - narrate <empty>
                - narrate "***** Tips *****"
                - narrate "Useful tips:"
                - narrate " - Wood tools are useless for scanning they do not work"
                - narrate " - If there is not enough durabulity the item will NOT break"
                - narrate " - Stone tools are still very useful even though they get 1"
                - narrate "   scan per tool. Two or three will usually get you lots of iron."
                - narrate " - Once you get gold, craft gold tools to use for scanning"
                - narrate " - Get silk touch so your scans can be more focused."
                - narrate "   - But remember, this uses 2x the durability."
                - narrate "   - This is very useful for rare items like Artifacts"
                - narrate " - Use the (/scanner info) command to see what the scan"
                - narrate "  will try to do: list of targets, range, durabulity cost"
                - narrate <proc[scannerHelpLinks].context[golden|intro]>



            - default:
                - narrate "** Warning: Unknown help page. Please try: /scanner help"

# ****************
# ** Build prior/next page links
scannerHelpLinks:
    type: procedure
    debug: false
    definitions: prior | next
    script:
        - define link_color aqua
        - define message "---- More Help:"
        - if <[prior]>:
            - define message "<[message]> <&click[/scanner help <[prior]>]><&color[<color[<[link_color]>]>]><[prior]><&end_click>"
        - define message "<[message]> ----- "
        - if <[next]>:
            - define message "<[message]> <&click[/scanner help <[next]>]><&color[<color[<[link_color]>]>]><[next]><&end_click>"
        - determine <[message]>



# ***
# * Check if player's offhand seems a potental scanner target item
# * - Designed to be quick and isolated
# *
# * - Uses current player data (offhand)
# * - Returns offhand material name if it is a potential target, else returns FALSE
# ***
is_offhand_valid:
    debug: false
    type: procedure
    script:
        - define offhand_name <player.item_in_offhand.material.name>
        # This allows for targets being tools and such, whcih can be handy if you lost your diamond pickaxe. Assuming
        # you have another of the same material name to use as a target.
        - if <[offhand_name]> == air|*_shield:
            - determine false
        - else:
            - determine <[offhand_name]>



# ***
# * Check if the player state and offhand meet the Scan UX conditions and is not being used too quickly
# * - Designed to be quick and isolated
# *
# * - Uses current player data (offhand)
# * - Returns offhand material name if it is a potential target, else returns FALSE
# ***
is_scan_allowed:
    debug: false
    type: procedure
    script:
        - if <player.is_sneaking>:
            - define offhand  <proc[is_offhand_valid]>
            - if <[offhand]>:
                - determine <[offhand]>
            - else:
                # invalid offhand
                - determine false
        - else:
            - determine false


# ***
# *** Event to handle scanning for blocks
# ***
scan_blocks:
    debug: false
    type: world
    events:
        on player damages block with:*_pickaxe:
            # Only enable scanning if player is sneaking AND has something in off hand
            - define offhand_name <proc[is_scan_allowed]>
            - if <[offhand_name]>:
                # Task handling needs the location data to handle the new (2025) unbreaking area fix
                - define loc <context.location>
                - ~run scanForItems def.matrix:<script[ScannerTypes].data_key[data.mining]> def.dry_run:false def.struck_loc:<[loc]>
                - if <player.has_flag[scan_performed]>:
                    - if <player.flag[scan_performed]>:
                        - determine cancelled
                - stop



# ***
# *** Event to handle scanning for entiries / creatures / items
# ***
scan_creatures:
    debug: false
    type: world
    events:
        on player damages block with:*_sword:
        # Only enable scanning if player is sneaking AND has something in off hand
        # Only enable scanning if player is sneaking AND has something in off hand
            - define offhand_name <proc[is_scan_allowed]>
            - if <[offhand_name]>:
                # Run syncronous and only cancel if scan was done, otherwise allow other actions to run
                # Task handling needs (not really needed for sword but be consistent) the location data to handle the new (2025) unbreaking area fix
                - define loc <context.location>
                - ~run scanForItems def.matrix:<script[ScannerTypes].data_key[data.creatures]> def.dry_run:false def.struck_loc:<[loc]>
                - if <player.has_flag[scan_performed]>:
                    - determine cancelled

                - stop

# ***
# *** Detects if the block at the current location is a listed unbrekable block. THis is not ideal
# *** but appears the only reliablae way to detect this. We avoid using a tool as we want ALWAYS unbrekable
# *** not those not unbrekable with current ool.
# *** It should be good enough for out scanner fix for detecting items in bedrock
# ***
is_block_unbreakable:
  type: procedure
  definitions: loc
  script:
    - define material <[loc].material>
    - define unbreakables list[bedrock|barrier|end_portal|end_gateway|command_block|structure_block|structure_void]
    - if <[material]> in <[unbreakables]>:
        - determine true
    - determine true


# *******************
# **
# ** Define matrix for all scanner lookups
#       - Usage: <ScriptTag.data_key[<keyname>]>
#       - <...data_key[blocks]>
# See: https://meta.denizenscript.com/Docs/Search/script#data%20script%20containers
# ** 
# *******************
ScannerTypes:
    type: data
    data:
        # TIP: If localizing this data to a specific scrupt place the TYPE data it under a key: `- definemap matrix`
        # and call it as a procedure via `- define result <proc[scanForItems].context[entities|<[matrix]>]>`.
        # Make the the path `matrix.scan_range` resolves to the scan_range.

        # *** BLOCK based scanes
        mining:
            # What type of item is being scanned for block|entity
            type: block

            # Equation: DUR/((pi*RANGE^2)*.375) = number o scans
            #   - wooden: 59  = 0 scans of 8
            #   - gold: 32 =  26 scans of 16 (same as netherite for 8)
            #   - stone: 131 = 1.7 scans of 8 (so one scan and some digging)
            #   - iron: 250 = 3 scans of 8
            #   - diamond: 1561 = 20 scans of 8
            #   - netherite: 2031 = 26 scans of 8
            # NOTE: All of these values a re bit fuzzy but they scale across area and type of item. Tweak
            # them as needed but in general a stone tool should get at least 1 use and diamond approx 5+ uses
            scan_range: 8
            # technically it should be a spehere but the cost gets insane)
            durability_area_type: circle
            # Cost per block in area, breanch mining is approx 37.5% of total blocks
            durability_cost: 0.375
            # scan range for golden items, but charge is still based on normal scan range
            golden_scan_range_multipler: 2
            # scale durability as if this item had the durability of the item mentioned
            #   - netherite seems fair since most of the time gold items need to be swapped for some more useful tool after every scan
            #   and gold is not exactly common.
            #
            golden_durability_as: netherite_pickaxe
            # If NOT using a item in the matrix the duability cost rises by this amount
            durability_custom_multiplier: 2

            samples:
                # Sample justification - favor LOG runing costs over a gateway
                # These should be blocks for this to  work properly
                stone:
                    message: Coal, Iron ore and Copper ore
                    targets:
                        - *coal_ore
                        - *iron_ore
                        - *copper_ore
                iron_ingot:
                    message: Gold ore, Redstone, and Lapis
                    targets:
                        - *redstone_ore
                        - *gold_ore
                        - *lapis_ore
                gold_ingot:
                    message: Diamonds and Emeralds
                    targets:
                        - *diamond_ore
                        - *emerald_ore
                lapis_block:
                    message: All blocks ending with ORE
                    targets:
                        - *ore
                iron_bars:
                    message: Spawners
                    targets:
                        - spawner

        # Entitie based scans
        creatures:
            # What type of item is being scanned for block|entity
            type: entities

            # Equation: DUR/78  (rougly same number of scans as gor blocks)
            #   - wooden: 59  = 0 scans of 32
            #   - gold: 32 =  26 scans of 64 (same as netherite for 32)
            #   - stone: 131 = 1 scans of 32
            #   - iron: 250 = 3 scans of 32
            #   - diamond: 1561 = 28 scans of 32
            #   - netherite: 2031 = 26 scans of 32
            # NOTE: All of these values a re bit fuzzy but they scale across area and type of item. Tweak
            # them as needed but in general a stone tool should get at least 1 use and diamond approx 5+ uses
            scan_range: 32
            # technically it should be a spehere but the cost gets insane)
            durability_area_type: fixed
            # Fixed cost, ends up being about the same as for blocks
            durability_cost: 78
            # scan range for golden items, but charge is still based on normal scan range
            golden_scan_range_multipler: 2
            # scale durability as if this item had the durability of the item mentioned
            #   - netherite seems fair since most of the time gold items need to be swapped for some more useful tool after every scan
            #   and gold is not exactly common.
            golden_durability_as: netherite_sword
            # If NOT using a item in the matrix the duability cost rises by this amount, 0 disables custom scanning
            durability_custom_multiplier: 2


            samples:
                # Entities based on the item associated with the entity
                # Wildcards are allowed, or multiple entries but that can make the UI confusing and posisbly OP
                carrot:
                    message: Pigs
                    targets:
                        - pig
                wheat:
                    message: Cows and Sheep
                    targets:
                        - cow
                        - sheep
                wheet_seeds:
                    message: Chicken
                    targets:
                        - chicken
                apple:
                    message: Horses
                    targets:
                        - horse
                paper:
                    message: Villagers
                    targets:
                        - villager
                ender_perl:
                    message: Endermen
                    targets:
                        - enderman
                # Disable these, they seem a bit OP
                #bone:
                #    message: Skeletons
                #    entities:
                #        - skeleton
                #rotten_flesh:
                #    message: Zombies
                #    entities:
                #        - zombie



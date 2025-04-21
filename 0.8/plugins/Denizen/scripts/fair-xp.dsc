
# # Fair XP Anvil
#
# Changes the XP Level cost for Anvil use to an XP Points based on those levels.
# This resolves a long standing issue with anvils that would indicate the cost was 5 levels
# and would deduct 5 levels even if you are at 50. Going from level 0 to 5 is about 55 points
# BUT from 45 to 50 is around 4,000 points. This tended to cause players to carefully
# manage their xp and use it as quickly as possible, which is tedious.
#
# Fair XP now deducts the XP points base on the level from level 0. So no matter if you are a level
# 5 or a level it's the same points.
#
# Minimum Required Level:
#
# Due to internal handling the check to see if player can perform the enchantment is
# done outside of this plugins ability to control. This means that if the enchanement shows a levelc ost
# of 23 the player MUST be at that level for the core engine to allow the enchantment. Once done the
# this plugin will set the player experience based on Points not kevels.
#
# This means if the enchantment cost should be read as Enchantment Level Required. Actual
# cost will be paid in the fair xp. It is unknown exactly how Denzien could work around this
# but at this time we will call this gameplay balance, you NEED the XP level to perform the enchantment
# ut you only pay the Fair XP.
#
#
# Limitations:
#   If the player has accumulated XP between placing items in anvil and removing  the result ( such as an automated XP farm)
#   that accumulated XP will be lost. This is considered rare and in any case, the loss is typical far less than what was gained with FAIR XP.
#   The work around for that is a rather complex 'on player' check, followed by waiting for a clock tick then applying a COST adjustment.
#   That solutions is VERY fragile and has added complexity over far simpler and good enough solution:
#
#   Enchanting table is NOT supported; it is a more complex object than the anvil
#
#
#  TODO: Consdier adding support to enchanting table
#


fxp_commands:
  type: command
  debug: false
  name: xptotal
  description: Shows your detailed experience info
  usage: /xptotal
  permission: xptotal.use
  script:
    - narrate "<gold>Player XP Details"
    - define player_level <player.xp_level>
    - narrate "XP Level: <[player_level]>"
    - define calculated <proc[fxp_points_for_player].context[<player>]>
    - narrate "XP Points: <[calculated]>"
    - narrate "Progress to next level: <player.xp>%"
    - narrate "XP to next level: <player.xp_to_next_level>"
    # The xp_total is quite weird, it DOES get reset sometimes and is then in sync with player level
    # but othertimes it is wildy off. I suspect it goes off during add/remove but a SET *such as the anvil code) resets it
    # In any case it is NOT relaible from a player perspective
    #- narrate "Lifetime XP: <player.xp_total> (not really useful)"


# === Events to handle anvil using points instead of levels
fxp_point_anvil:
  type: world
  debug: false

  events:
    # Fires when player clicks the result slot to complete the anvil merge
    #   Inventory objct: <context.inventory||null>
    #   Inventory Type: <context.inventory.inventory_type||none>   -- (UPPERCASED) ANVIL / ...
    #   Slot type: <context.slot_type||null> -- (UPPERCASED) CRAFTING / RESULT / ...
    #   Action : <context.action||null> -- (UPPERCASED) PLACE / PICKUP_ALL / NOTHING (usually not enough xp)
    #
    # On sucess will set player xp to the calculated level at anvil setup
    #
    # Algorithm:
    #   The current and prior XP are used to POST adjust the Experience after Anvil cose (and any mods) were
    #   applied. Then total level difference (see 'anvil craft item') is used to adjust the XP to fair use. This
    #   algorhtm is not immediatly intuitive but it handles odd Minecraft and mod interaction
    #     XP use may not always be available in the Anvil Cost caclaution (example; Disenchant mod does nto seem to set this).
    #     Intercepting the ON event is a problem as this script can run in an non-deterministic order comapred to whe
    #     XP is adjusted per internals. So it's best to do a POST cleanup,
    #   Note that this is the ONLY even we need to monitor for this algorithm. And seems to be reliable but wa challening
    #   to identiy the proper sequence.
    #
    #   Limitation: If the player accumulated XP between placing items in anvil and taking result then they
    #   will loose that XP. This is considered rare and in any case, the loss is typical far less than what was gained with FAIR XP.
    #   The work around is a rather complex 'on player' check, followed by waiting for a clock tick then applying a COST adjustment.
    #   That is VERY fragile and has added complexity over farr simpler and good enough solution:
    #         See: https://meta.denizenscript.com/Docs/Search/clicks%20in%20inventory
    after player clicks in inventory:
      #- if !<player.is_op>:
      #  - stop

      # Only monitor ANVIL
      - if <context.inventory.inventory_type||null> != ANVIL:
        - stop

      # - WARNING: THis gets tricky, the goal is to track the XP before an action is fired an ideally
      # - set XP to 0 when slots are empty, but that's just nice.

      - define player_prior_level <player.flag[fxp.anvil_prior_level]||0>
      - define action <context.action>
      - define slot_type <context.slot_type||element[]>
      #- debug log "<gold>Slot: <[slot_type]> --- Action: <[action]>"

      # Player is picking up RESULT item so fire XP corrector.
      - if <[slot_type]> == RESULT and <[action]> == PICKUP_ALL:
        # This call will only do something if an XP change was detected
        - run fxp_adjust_player def:<player>
        - stop

      # An item was removed so clear values
      #  CONTAINER is the inventory shown on the anvil, events here we do not really need to see and we do
      #  not want to trigger storing prior XP
      - if  <[slot_type]> != CONTAINER:
        - if <[action]> == PICKUP_ALL:
          # ****
          # Clear cost flag anytime an item is picked up (RESULT pickup is done above)
          - flag <player> fxp.anvil_prior_xp:!
          - flag <player> fxp.anvil_prior_level:!
        - else:
          # Otherwise capture player XP
          # - Use a timer long enough for a player to even do modest AFK, but still allow for auto cleanup
          # - If a plyer foes AFK for longer than this, then click exactly on the result they will get charge the FULL amoumt, tough luck, sorry.
          - flag <player> fxp.anvil_prior_level:<player.xp_level> duration:10m
          - flag <player> fxp.anvil_prior_xp:<proc[fxp_points_for_player].context[<player>]> duration:10m

      #- debug log "<red>SAVED XP: <player.flag[fxp.anvil_prior_xp]||0>"



# === Adjust player EXP based on current and stored flags
# - If there is no prior XP then exits
# - If there is no XP change then exist
# - Caclulates 
fxp_adjust_player:
  type: task
  debug: false
  definitions: player
  script:

      # Calculate difference between remembered XP and now. Then apply cost based on core XP for the level (from 0)
      # an adjust player to that.
      - define player_prior_level <[player].flag[fxp.anvil_prior_level]||0>
      - define player_prior_xp <[player].flag[fxp.anvil_prior_xp]||0>
      - if <[player_prior_xp]> == 0:
        # Something is a bit odd, no prior data so SKIP
        - debug log "<red>Prior XP Level cannot be identified. That's weird"
        - stop

      # Calculate the level change and the diffreence in XP. Handle ADD/SUB in case a mod does that
      - define minecraft_player_level <player.xp_level>
      - define minecraft_player_xp <proc[fxp_points_for_player].context[<player>]>
      - define level_change <[player_prior_level].sub[<[minecraft_player_level]>]>
      #- debug log "<green>Player Prior: <[player_prior_level]> -- After: <[minecraft_player_level]> -- Change: <[level_change]>"

      - if <[level_change]> == 0:
        - stop

      - if <[level_change]> < 0:
        # Expected adjustment, subtract
        - define sign 1
      - else:
        # SUpport adding experience in case a mod did that
        - define sign -1

      # Get experience points for level difference (absolute number as the process does not work well with negatves and normally does not need to)
      # Adjust for xp adding (RARE) / dropping
      #   Be sure to pass absolute  value then adjust based on sign of level change
      - define xp_for_change <proc[fxp_points_for_level].context[<[level_change].abs>].mul[<[sign]>]>
      - define player_desired_xp <[player_prior_xp].add[<[xp_for_change]>]>
      #- debug log "<gold>Change: <[xp_for_change]> points, <[player_desired_xp]> level(s)"

      - experience set <[player_desired_xp]> player:<[player]>

      # ****
      # Get feedback
      - define fair_level <player.xp_level>
      - define savings_xp <[player_desired_xp].sub[<[minecraft_player_xp]>]>
      - define savings_level <[fair_level].sub[<[minecraft_player_level]>]>

      # Levels are not perfect due to rounding but hey, we will show it anyway
      #- debug log "<green>Fair XP savings: <[savings_xp]> points, <[savings_level]> level(s)"
      - narrate "<green>Fair XP savings: <[savings_xp]> points, <[savings_level]> level(s)"

      # **** 
      # Clear cost flag
      - flag <[player]> fxp.anvil_prior_xp:!
      - flag <[player]> fxp.anvil_prior_level:!

      - stop





# === Get current points for a player (round down)
fxp_points_for_player:
  type: procedure
  debug: false
  definitions: player
  script:
    # Level to lowest integer (floor)
    - define level <[player].xp_level>
    # Get amount of XP the player has to the next level
    - define progress <[player].xp>
    # Number of XP required to reach next level
    - define to_next <[player].xp_to_next_level>
    # Convert level to XP
    - define base_xp <proc[fxp_points_for_level].context[<[level].round_down>]>

    - define extra_xp <[progress].div[100].mul[<[to_next]>]>
    - define total_xp <[base_xp].add[<[extra_xp]>]>
    - determine <[total_xp].round_down>

# === Get points for a specific level. This forces whole number levels only (round down)
# Best used to identify how many points a cost of 5 levels means without regard to current players level.
fxp_points_for_level:
  type: procedure
  debug: false
  definitions: level
  script:
    - define level <[level].round_down>
    - if <[level].is_less_than_or_equal_to[16]>:
      - define base_xp <[level].mul[<[level]>].add[<[level].mul[6]>]>
    - else :
      - if <[level].is_less_than_or_equal_to[31]>:
          - define base_xp <[level].mul[2.5].mul[<[level]>].sub[<[level].mul[40.5]>].add[360]>
      - else:
        - define base_xp <[level].mul[4.5].mul[<[level]>].sub[<[level].mul[162.5]>].add[2220]>

    # Not all callers can handle fractional amounts (points)
    - determine <[base_xp].round>




resetworkcost:
  type: command
  name: resetworkcost
  description: Resets the anvil work cost of the item in your hand.
  usage: /resetworkcost
  permission: true
  script:
    - define item <player.item_in_hand>
    - if <[item].name> == air:
        - narrate "<red>You must be holding an item to reset work cost."
        - stop

    - define current_cost <[item].repair_cost||0>
    - narrate "<gray>Current work cost: <[current_cost]>"

    #- define clean_item <[item].with[repair_cost=0]>
    #- inventory set slot:<player.item_in_hand_slot> <[clean_item]> in:player
    #- adjust <player.item_in_hand> repair_cost:0
    #- define new_cost <player.item_in_hand.repair_cost>
    #- narrate "<green>Work cost reset! New value: <[new_cost]>"

    - define clean_item <[item].with[repair_cost=0]>
    - give <[clean_item]> tO:<player> slot:hand
    - define new_cost <player.item_in_hand.repair_cost>
    - narrate "<green>B)Work cost reset! New value: <[new_cost]>"
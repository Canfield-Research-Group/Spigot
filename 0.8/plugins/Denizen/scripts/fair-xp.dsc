
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
    # Fires when anvil result is calculated, lets us see cost
    # this can fire 3-4 times but the cost to track and debounce is almost as high as just recalcuting so recalc (easier)
    on player prepares anvil craft item:
      # TODO: Consider changing this to do all work in pick up, this may make enchanter easier
      #   Save player_lavel and player_xp to flags. That's it
      #   In INVENTORY PICKUP (after event) claculate the actual level cost abse don new player level and flag
      #     If there is no level change then assume no action and clear flags (TEST)
      #   Use that to get XP point cost
      #   set player exp to flag XP + point cost
      #- if !<player.is_op>:
      #  - stop

      - define player <player>
      - define cost_levels <context.repair_cost||0>
      - define player_level <[player].xp_level>

        # When cost is 0 or less (-1 was seen) ingrediants were probably removed or anvil canceled
        # When levels are more than player has just let GUI tell them. Our cost calculations are ALWAYS less than GAME (XP Fair)
        #    In both case CLEAR any excisting Anvil flag
      - define prior_desired_xp <player.flag[fxp.anvil_desired_xp]||0>
      - if <[cost_levels]> <= 0 or <[cost_levels].is_more_than[<[player_level]>]>:
          - if <[prior_desired_xp]> 0:
              - flag <[player]> fxp.anvil_desired_xp:!
          - stop

      - define player_xp <proc[fxp_points_for_player].context[<[player]>]>
      - define cost_xp <proc[fxp_points_for_level].context[<[cost_levels]>]>
      # checking foe xp is not need here since we are using LESS XP than the game so let the GUI handle the display check

      # A duration is often used (duration 5s) to make sure the flag is cleared. In our case we  localize
      # flags so I don't think this will be a problem and so no duration is used
      #   Set a long duration so flag eventually garbage collects. But it should that on any anvil change die to cost check above
      - define desired_xp <[player_xp].sub[<[cost_xp]>]>
      # Very simple de-bouncer that does not require more flags
      - if <[prior_desired_xp]> != <[desired_xp]>:
        - flag <[player]> fxp.anvil_desired_xp:<[desired_xp]> duration:5m
        - narrate "<gold>Fair XP cost: <[cost_xp]>"



    # Fires when player clicks the result slot to complete the anvil merge
    #   Inventory objct: <context.inventory||null>
    #   Inventory Type: <context.inventory.inventory_type||none>   -- (UPPERCASED) ANVIL / ...
    #   Slot type: <context.slot_type||null> -- (UPPERCASED) CRAFTING / RESULT / ...
    #   Action : <context.action||null> -- (UPPERCASED) PLACE / PICKUP_ALL / NOTHING (usually not enough xp)
    #
    # On sucess will set player xp to the calculated level at anvil setup
    #   Limitation: If the player accumulated XP between placing items in anvil and taking result then they
    #   will loose that XP. This is considered rare and in any case, the loss is typical far less than what was gained with FAIR XP.
    #   The work around is a rather complex 'on player' check, followed by waiting for a clock tick then applying a COST adjustment.
    #   That is VERY fragile and has added complexity over farr simpler and good enough solution:
    #         See: https://meta.denizenscript.com/Docs/Search/clicks%20in%20inventory
    after player clicks in inventory:
      #- if !<player.is_op>:
      #  - stop

      - define player <player>


      #- debug log "<red>Clicks in inventory: inventory -- <context.inventory||NA>"
      #- debug log "<red>Clicks in inventory: inventory_type -- <context.inventory.inventory_type||NA>"
      #- debug log "<red>Clicks in inventory: slot_type -- <context.slot_type||NA>"
      #- debug log "<red>Clicks in inventory: action --  <context.action||NA>"

      - if <context.inventory.inventory_type||null> != ANVIL:
        - stop
      - if <context.slot_type||null> != RESULT:
        - stop
      - if <context.action||null> != PICKUP_ALL:
        - narrate "<red>You are not a high enough level to perform this enchantment"
        - stop

      # Get cost calculated when anvil was prepared, this flag may not be set if the anvil repair cost was not set or 0
      - define player_desired_xp <[player].flag[fxp.anvil_desired_xp]||0>
      - if <[player_desired_xp]>:
          # Set player XP to exactly what it costs to perform the action. This allows any expereince
          # that might be assigned to the player during the upcomming WAIT to still be abosrbed instead of lost
          # While gaining XP from some event while processing the ANVIL action would be rare it is possible
          - define minecraft_player_xp <proc[fxp_points_for_player].context[<player>]>
          - define minecraft_player_level <player.xp_level>
          # TIP: This 'set' works on absolute xp. THis is unlike Minecradts /expereince command where
          # points are the amount accumulated between the current levels to the next level.
          - experience set <[player_desired_xp]> player:<[player]>
          - define fair_level <player.xp_level>

          - define savings_xp <[player_desired_xp].sub[<[minecraft_player_xp]>]>
          - define savings_level <[fair_level].sub[<[minecraft_player_level]>]>
          # Levels are not perfect due to rounding but hey, we will show it anyway
          - narrate "<green>Fair XP savings: <[savings_xp]> points, <[savings_level]> level(s)"

          # Clear cost flag
          - flag <[player]> fxp.anvil_desired_xp:!



# === Get current points for a player (round down)
fxp_points_for_player:
  type: procedure
  debug: false
  definitions: player
  script:
    - define level <[player].xp_level>
    - define progress <[player].xp>
    - define to_next <[player].xp_to_next_level>
    - define base_xp <proc[fxp_points_for_level].context[<[level]>]>

    # progress to next level is in percentage, we need it in decimal
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

    # progress to next level is in percentage, we need it in decimal
    - determine <[base_xp].round>

